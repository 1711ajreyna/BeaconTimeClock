import Foundation

/// In-memory backend for the class demonstration.
///
/// It supports:
/// - role-aware login/profile,
/// - today's supervisor-controlled breaks/lunch schedule,
/// - rest-break start/end/not-taken events,
/// - biometric requirement for "not taken",
/// - overtime projection,
/// - weekly department approval workflow,
/// - manual punch correction,
/// - digital approval and simulated HR merge.
@MainActor
final class DemoAPIClient: WorkflowAPI {
    private let profileProvider: () -> UserProfile?

    private var timesheets: [UUID: DepartmentTimesheet] = [:]
    private var dashboardGeneratedAt = Date()

    private var shiftRows: [UUID: SupervisorScheduleRow] = [:]
    private var shiftEvents: [UUID: [ShiftEventRecord]] = [:]

    // MARK: - Multiple Shift Demo State
    private var workShifts: [UUID: WorkShift] = [:] // Named shift occurrences.
    private var rosterAssignments: [UUID: WorkShiftAssignment] = [:] // Employee rosters.

    init(
        profileProvider: @escaping () -> UserProfile?
    ) {
        self.profileProvider = profileProvider
        seed()
    }

    func fetchMyProfile() async throws -> UserProfile {
        guard let profile = profileProvider() else {
            throw DemoError.notSignedIn
        }

        return profile
    }

    func submitPunch(
        _ request: SubmitPunchRequest
    ) async throws -> SubmitPunchResponse {
        SubmitPunchResponse(
            success: true,
            punchID: UUID(),
            serverTimestamp: Date(),
            message: "Demo backend accepted the punch."
        )
    }

    func fetchMyShift() async throws -> MyShiftResponse {
        guard let profile = profileProvider(),
              profile.role == .employee,
              let employeeID = profile.employeeID,
              let row = shiftRows.values.first(
                where: { $0.employeeID == employeeID }
              ) else {
            throw DemoError.employeeShiftNotFound
        }

        let schedule = Self.schedule(from: row)
        let events = shiftEvents[row.id] ?? []

        /// Fixed demonstration values make the overtime forecast visible
        /// regardless of the time of day the capstone is presented.
        let weeklyWorked = 37.50
        let scheduledRemaining = 5.00
        let projected = WeeklyHoursCalculator.rounded(
            weeklyWorked + scheduledRemaining
        )
        let projectedOT = max(
            0,
            projected - AppConfig.demoWeeklyRegularLimitHours
        )

        return MyShiftResponse(
            schedule: schedule,
            events: events,
            weeklyHoursWorked: weeklyWorked,
            projectedWeeklyHours: projected,
            projectedOvertimeHours:
                WeeklyHoursCalculator.rounded(projectedOT)
        )
    }

    func recordShiftEvent(
        _ request: RecordShiftEventRequest
    ) async throws -> RecordShiftEventResponse {
        guard let profile = profileProvider(),
              profile.role == .employee,
              let employeeID = profile.employeeID,
              let row = shiftRows[request.shiftAssignmentID],
              row.employeeID == employeeID else {
            throw DemoError.unauthorized
        }

        if request.type.isNotTaken && !request.biometricVerified {
            throw DemoError.biometricRequired
        }

        var existing = shiftEvents[row.id] ?? []

        /// Only one "not taken" or one start event per rest-break slot.
        let sameSlot = existing.filter {
            $0.type.breakSlot == request.type.breakSlot
        }

        if request.type.isNotTaken,
           sameSlot.contains(where: { $0.type.isNotTaken }) {
            throw DemoError.duplicateEvent
        }

        let event = ShiftEventRecord(
            id: UUID(),
            type: request.type,
            occurredAt: Date(),
            biometricVerified: request.biometricVerified,
            beaconVerified: request.beaconVerified,
            note: request.note
        )

        existing.append(event)
        shiftEvents[row.id] = existing

        return RecordShiftEventResponse(
            success: true,
            event: event,
            message: request.type.isNotTaken
                ? "Break marked not taken and logged as a supervisor exception."
                : "Break event logged."
        )
    }

    // MARK: - Supervisor Shift Management (Demo Mode)

    func fetchShiftRoster() async throws -> ShiftRosterResponse {
        try requireSupervisor()
        let employees = shiftRows.values.map { row in
            RosterEmployee(
                id: row.employeeID, employeeNumber: row.employeeNumber,
                employeeName: row.employeeName, department: row.department
            )
        }
        return ShiftRosterResponse(
            shifts: workShifts.values.sorted { $0.startTime < $1.startTime },
            assignments: Array(rosterAssignments.values),
            employees: employees.sorted { $0.employeeName < $1.employeeName }
        )
    }

    func createWorkShift(_ request: CreateWorkShiftRequest) async throws -> WorkShift {
        try requireSupervisor()
        let shift = request.shift
        guard !shift.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              shift.endTime > shift.startTime else {
            throw DemoError.invalidSchedule
        }
        guard !workShifts.values.contains(where: {
            $0.department == shift.department &&
            $0.workDate == shift.workDate &&
            $0.name.lowercased() == shift.name.lowercased()
        }) else {
            throw DemoError.duplicateShift
        }
        workShifts[shift.id] = shift
        return shift
    }

    func assignWorkShift(_ request: AssignWorkShiftRequest) async throws -> WorkShiftAssignment {
        try requireSupervisor()
        guard let shift = workShifts[request.shiftID],
              let employee = shiftRows.values.first(where: { $0.employeeID == request.employeeID }),
              employee.department == shift.department else {
            throw DemoError.unauthorized
        }
        // One active daily schedule per employee. Reject duplicate assignments.
        let existing = rosterAssignments.values.first { assignment in
            assignment.employeeID == request.employeeID &&
            workShifts[assignment.shiftID]?.workDate == shift.workDate
        }
        guard existing == nil else { throw DemoError.duplicateShiftAssignment }

        let assignment = WorkShiftAssignment(
            id: UUID(), employeeID: employee.employeeID,
            employeeNumber: employee.employeeNumber,
            employeeName: employee.employeeName, shiftID: shift.id
        )
        rosterAssignments[assignment.id] = assignment
        // Sync this person's concrete daily schedule with the assigned shift.
        let updated = SupervisorScheduleRow(
            id: employee.id, employeeID: employee.employeeID,
            employeeNumber: employee.employeeNumber,
            employeeName: employee.employeeName, department: employee.department,
            shiftStart: shift.startTime, break1Start: shift.break1Start,
            lunchStart: shift.lunchStart, break2Start: shift.break2Start,
            shiftEnd: shift.endTime,
            restBreakDurationMinutes: shift.restBreakDurationMinutes,
            lunchDurationMinutes: shift.lunchDurationMinutes,
            break1AdjustmentReason: nil, break2AdjustmentReason: nil
        )
        shiftRows[employee.id] = updated
        return assignment
    }

    func removeWorkShiftAssignment(_ request: RemoveWorkShiftAssignmentRequest) async throws {
        try requireSupervisor()
        guard rosterAssignments.removeValue(forKey: request.assignmentID) != nil else {
            throw DemoError.notFound
        }
        // A production system also checks whether payroll events already exist.
    }

    private func requireSupervisor() throws {
        guard let profile = profileProvider(), profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }
    }

    func fetchSupervisorSchedule()
    async throws -> SupervisorScheduleResponse {
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        return SupervisorScheduleResponse(
            workDate: Self.todayString(),
            rows: shiftRows.values.sorted {
                $0.employeeName < $1.employeeName
            }
        )
    }

    func updateShiftSchedule(
        _ request: UpdateShiftScheduleRequest
    ) async throws -> UpdateShiftScheduleResponse {
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard var row = shiftRows[request.shiftAssignmentID] else {
            throw DemoError.employeeShiftNotFound
        }

        do {
            try CaliforniaRestBreakPolicy.validate(
                shiftStart: row.shiftStart,
                break1Start: request.break1Start,
                lunchStart: row.lunchStart,
                lunchDurationMinutes: row.lunchDurationMinutes,
                break2Start: request.break2Start,
                shiftEnd: row.shiftEnd,
                restBreakDurationMinutes: row.restBreakDurationMinutes
            )
        } catch {
            throw DemoError.invalidSchedule
        }

        let recommendation = row.recommendedBreaks

        let break1Adjusted = CaliforniaRestBreakPolicy.isAdjusted(
            actual: request.break1Start,
            recommended: recommendation.break1Start
        )

        let break2Adjusted = CaliforniaRestBreakPolicy.isAdjusted(
            actual: request.break2Start,
            recommended: recommendation.break2Start
        )

        let break1Reason = request.break1AdjustmentReason?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let break2Reason = request.break2AdjustmentReason?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if break1Adjusted,
           break1Reason?.isEmpty != false {
            throw DemoError.breakAdjustmentReasonRequired
        }

        if break2Adjusted,
           break2Reason?.isEmpty != false {
            throw DemoError.breakAdjustmentReasonRequired
        }

        row = SupervisorScheduleRow(
            id: row.id,
            employeeID: row.employeeID,
            employeeNumber: row.employeeNumber,
            employeeName: row.employeeName,
            department: row.department,
            shiftStart: row.shiftStart,
            break1Start: request.break1Start,
            lunchStart: row.lunchStart,
            break2Start: request.break2Start,
            shiftEnd: row.shiftEnd,
            restBreakDurationMinutes: row.restBreakDurationMinutes,
            lunchDurationMinutes: row.lunchDurationMinutes,
            break1AdjustmentReason:
                break1Adjusted ? break1Reason : nil,
            break2AdjustmentReason:
                break2Adjusted ? break2Reason : nil
        )

        shiftRows[row.id] = row

        return UpdateShiftScheduleResponse(
            success: true,
            row: row,
            message:
                "Demo employee break times updated. The next shift refresh reschedules the employee's 2-minute break warnings."
        )
    }

    func fetchSupervisorDashboard()
    async throws -> SupervisorDashboard {
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        let sheets = timesheets.values.sorted {
            $0.department.sortOrder < $1.department.sortOrder
        }

        let summaries = sheets.map { sheet in
            DepartmentApprovalSummary(
                id: sheet.id,
                department: sheet.department,
                status: sheet.status,
                employeeCount: sheet.employees.count,
                regularHours: sheet.regularHours,
                overtimeHours: sheet.overtimeHours,
                totalHours: sheet.totalHours,
                supervisorName: sheet.supervisorName,
                signedAt: sheet.signedAt,
                canEdit: sheet.status == .pending
            )
        }

        let allApproved = !summaries.isEmpty &&
            summaries.allSatisfy { $0.status != .pending }
        let anySent = summaries.contains { $0.status == .sentToHR }

        let hrStatus: HRPacketStatus = anySent
            ? .emailed
            : (allApproved ? .ready : .waitingForDepartments)

        let range = Self.previousWeekStrings()

        return SupervisorDashboard(
            weekStart: range.start,
            weekEnd: range.end,
            generatedAt: dashboardGeneratedAt,
            departments: summaries,
            hrPacketStatus: hrStatus
        )
    }

    func fetchDepartmentTimesheet(
        timesheetID: UUID
    ) async throws -> DepartmentTimesheet {
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard let sheet = timesheets[timesheetID] else {
            throw DemoError.notFound
        }

        return sheet
    }

    func adjustPunch(
        _ request: PunchAdjustmentRequest
    ) async throws -> PunchAdjustmentResponse {
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard var sheet = timesheets[request.timesheetID] else {
            throw DemoError.notFound
        }

        guard sheet.status == .pending else {
            throw DemoError.alreadyApproved
        }

        let reason = request.reason.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !reason.isEmpty else {
            throw DemoError.reasonRequired
        }

        var found = false

        for employeeIndex in sheet.employees.indices {
            if let punchIndex = sheet.employees[employeeIndex]
                .punches
                .firstIndex(where: { $0.id == request.punchID }) {

                sheet.employees[employeeIndex]
                    .punches[punchIndex]
                    .effectiveOccurredAt = request.correctedOccurredAt

                sheet.employees[employeeIndex]
                    .punches[punchIndex]
                    .adjustmentReason = reason

                sheet.employees[employeeIndex] = Self.recalculate(
                    sheet.employees[employeeIndex]
                )

                found = true
                break
            }
        }

        guard found else {
            throw DemoError.punchNotFound
        }

        timesheets[sheet.id] = sheet

        return PunchAdjustmentResponse(
            success: true,
            message: "Punch corrected. Original time preserved for audit."
        )
    }

    func approveDepartment(
        _ request: ApproveDepartmentRequest
    ) async throws -> ApproveDepartmentResponse {
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard var sheet = timesheets[request.timesheetID] else {
            throw DemoError.notFound
        }

        guard sheet.status == .pending else {
            throw DemoError.alreadyApproved
        }

        guard !sheet.hasUnresolvedExceptions else {
            throw DemoError.unresolvedExceptions
        }

        // MARK: - Supervisor Identity

        /// Obtain the supervisor's name from their authenticated profile.
        ///
        /// This prevents the approval record from trusting a name
        /// supplied separately by the employee or client.

        let printedName = profile.displayName
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !printedName.isEmpty else {
            throw DemoError.supervisorNameRequired
        }

        guard !request.signaturePNGBase64.isEmpty else {
            throw DemoError.signatureRequired
        }

        let signedAt = Date()
        sheet.status = .approved
        sheet.supervisorName = printedName
        sheet.signedAt = signedAt
        sheet.signaturePresent = true
        timesheets[sheet.id] = sheet

        let allApproved = timesheets.values.allSatisfy {
            $0.status == .approved || $0.status == .sentToHR
        }

        if allApproved {
            for id in Array(timesheets.keys) {
                timesheets[id]?.status = .sentToHR
            }
        }

        return ApproveDepartmentResponse(
            success: true,
            signedAt: signedAt,
            allDepartmentsApproved: allApproved,
            hrMergeTriggered: allApproved,
            message: allApproved
                ? "All departments approved. Demo HR workbook was merged and emailed."
                : "Department approved. HR is waiting for the remaining departments."
        )
    }

    func resetDemoData() async {
        seed()
    }

    // MARK: - Seed

    private func seed() {
        dashboardGeneratedAt = Date()
        seedDailySchedules()
        seedNamedShifts() // Seed Morning/Evening/Night roster examples.
        seedWeeklyTimesheets()
    }

    private func seedDailySchedules() {
        shiftRows.removeAll()
        shiftEvents.removeAll()

        let calendar = Self.companyCalendar()
        let today = Date()

        func time(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: today
            )!
        }

        let employee = SupervisorScheduleRow(
            id: UUID(),
            employeeID: UUID(
                uuidString: "11111111-1111-1111-1111-111111111111"
            )!,
            employeeNumber: "EMP-001",
            employeeName: "Demo Employee",
            department: .electrical,
            shiftStart: time(7, 0),
            break1Start: time(9, 15),
            lunchStart: time(11, 30),
            break2Start: time(13, 45),
            shiftEnd: time(15, 30),
            restBreakDurationMinutes:
                AppConfig.restBreakDurationMinutes,
            lunchDurationMinutes:
                AppConfig.lunchDurationMinutes,
            break1AdjustmentReason: nil,
            break2AdjustmentReason: nil
        )

        shiftRows[employee.id] = employee

        let otherDepartments: [Department] = [
            .machineShop, .metals, .plastics, .litho
        ]

        for department in otherDepartments {
            let row = SupervisorScheduleRow(
                id: UUID(),
                employeeID: UUID(),
                employeeNumber: "DEMO-\(department.sortOrder + 10)",
                employeeName: "\(department.displayName) Demo Employee",
                department: department,
                shiftStart: time(7, 0),
                break1Start: time(9, 30),
                lunchStart: time(12, 0),
                break2Start: time(14, 0),
                shiftEnd: time(15, 30),
                restBreakDurationMinutes:
                    AppConfig.restBreakDurationMinutes,
                lunchDurationMinutes:
                    AppConfig.lunchDurationMinutes,
                break1AdjustmentReason: nil,
                break2AdjustmentReason: nil
            )
            shiftRows[row.id] = row
        }
    }

    // MARK: - Sample Multiple Shifts

    private func seedNamedShifts() {
        workShifts.removeAll()
        rosterAssignments.removeAll()
        // All three examples are standard eight-paid-hour shifts.
        let samples: [(String, Department, Int, Int, Int, Int)] = [
            ("Morning", .electrical, 6, 0, 14, 30),
            ("Evening", .machineShop, 14, 0, 22, 30),
            ("Night", .metals, 22, 0, 6, 30)
        ]
        for (name, department, startHour, startMinute, endHour, endMinute) in samples {
            do {
                let shift = try WorkShift.makeEightHourShift(
                    name: name, department: department, workDate: Date(),
                    startHour: startHour, startMinute: startMinute,
                    endHour: endHour, endMinute: endMinute
                )
                workShifts[shift.id] = shift
            } catch {
                print("Could not seed demo shift: \(error)")
            }
        }
    }

    private func seedWeeklyTimesheets() {
        let range = Self.previousWeekStrings()
        let seeds: [(Department, Double, Bool)] = [
            (.electrical, 43.5, false),
            (.machineShop, 38.0, false),
            (.metals, 40.0, false),
            (.plastics, 46.25, true),
            (.litho, 39.5, false)
        ]

        timesheets = Dictionary(
            uniqueKeysWithValues: seeds.map { department, hours, skippedBreak in
                let employee = Self.makeWeeklyEmployee(
                    department: department,
                    totalHours: hours,
                    skippedBreak: skippedBreak
                )

                let sheet = DepartmentTimesheet(
                    id: UUID(),
                    department: department,
                    weekStart: range.start,
                    weekEnd: range.end,
                    status: .pending,
                    employees: [employee],
                    generatedAt: Date(),
                    sentToSupervisorAt: Date(),
                    supervisorName: nil,
                    signedAt: nil,
                    signaturePresent: false
                )

                return (sheet.id, sheet)
            }
        )
    }

    private static func makeWeeklyEmployee(
        department: Department,
        totalHours: Double,
        skippedBreak: Bool
    ) -> EmployeeWeeklySummary {
        let range = previousWeekDates()
        let calendar = companyCalendar()
        let dailyHours = totalHours / 5
        var punches: [PunchRecord] = []
        var events: [WeeklyShiftEventRecord] = []

        for dayOffset in 0..<5 {
            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: range.start
            ) else { continue }

            let start = calendar.date(
                bySettingHour: 7,
                minute: 0,
                second: 0,
                of: day
            )!

            let lunchOut = start.addingTimeInterval(
                (dailyHours / 2) * 3600
            )
            let lunchIn = lunchOut.addingTimeInterval(30 * 60)
            let clockOut = lunchIn.addingTimeInterval(
                (dailyHours / 2) * 3600
            )

            punches.append(contentsOf: [
                PunchRecord(
                    id: UUID(),
                    type: .clockIn,
                    occurredAt: start,
                    effectiveOccurredAt: start,
                    adjustmentReason: nil
                ),
                PunchRecord(
                    id: UUID(),
                    type: .lunchOut,
                    occurredAt: lunchOut,
                    effectiveOccurredAt: lunchOut,
                    adjustmentReason: nil
                ),
                PunchRecord(
                    id: UUID(),
                    type: .lunchIn,
                    occurredAt: lunchIn,
                    effectiveOccurredAt: lunchIn,
                    adjustmentReason: nil
                ),
                PunchRecord(
                    id: UUID(),
                    type: .clockOut,
                    occurredAt: clockOut,
                    effectiveOccurredAt: clockOut,
                    adjustmentReason: nil
                )
            ])

            let break1 = start.addingTimeInterval(2.25 * 3600)
            let break2 = start.addingTimeInterval(7 * 3600)

            events.append(
                WeeklyShiftEventRecord(
                    id: UUID(),
                    type: .restBreak1Started,
                    occurredAt: break1,
                    biometricVerified: false,
                    beaconVerified: true,
                    note: nil
                )
            )
            events.append(
                WeeklyShiftEventRecord(
                    id: UUID(),
                    type: .restBreak1Ended,
                    occurredAt: break1.addingTimeInterval(10 * 60),
                    biometricVerified: false,
                    beaconVerified: true,
                    note: nil
                )
            )

            if skippedBreak && dayOffset == 2 {
                events.append(
                    WeeklyShiftEventRecord(
                        id: UUID(),
                        type: .restBreak2NotTaken,
                        occurredAt: break2,
                        biometricVerified: true,
                        beaconVerified: true,
                        note: "Employee recorded break as not taken."
                    )
                )
            } else {
                events.append(
                    WeeklyShiftEventRecord(
                        id: UUID(),
                        type: .restBreak2Started,
                        occurredAt: break2,
                        biometricVerified: false,
                        beaconVerified: true,
                        note: nil
                    )
                )
                events.append(
                    WeeklyShiftEventRecord(
                        id: UUID(),
                        type: .restBreak2Ended,
                        occurredAt: break2.addingTimeInterval(10 * 60),
                        biometricVerified: false,
                        beaconVerified: true,
                        note: nil
                    )
                )
            }
        }

        let split = WeeklyHoursCalculator.split(
            totalHours: totalHours
        )

        return EmployeeWeeklySummary(
            id: UUID(),
            employeeID: "DEMO-\(department.sortOrder + 1)",
            employeeName: "\(department.displayName) Demo Employee",
            regularHours: split.regular,
            overtimeHours: split.overtime,
            totalHours: split.total,
            hasException: false,
            punches: punches,
            shiftEvents: events
        )
    }

    private static func schedule(
        from row: SupervisorScheduleRow
    ) -> ShiftSchedule {
        ShiftSchedule(
            id: row.id,
            employeeID: row.employeeID,
            employeeNumber: row.employeeNumber,
            employeeName: row.employeeName,
            department: row.department,
            workDate: todayString(),
            shiftStart: row.shiftStart,
            break1Start: row.break1Start,
            lunchStart: row.lunchStart,
            break2Start: row.break2Start,
            shiftEnd: row.shiftEnd,
            restBreakDurationMinutes: row.restBreakDurationMinutes,
            lunchDurationMinutes: row.lunchDurationMinutes
        )
    }

    private static func recalculate(
        _ employee: EmployeeWeeklySummary
    ) -> EmployeeWeeklySummary {
        let grouped = Dictionary(
            grouping: employee.punches
        ) {
            Calendar.current.startOfDay(
                for: $0.effectiveOccurredAt
            )
        }

        var seconds: TimeInterval = 0
        var hasException = false

        for dayPunches in grouped.values {
            let sorted = dayPunches.sorted {
                $0.effectiveOccurredAt < $1.effectiveOccurredAt
            }

            let clockIn = sorted.first { $0.type == .clockIn }
            let lunchOut = sorted.first { $0.type == .lunchOut }
            let lunchIn = sorted.first { $0.type == .lunchIn }
            let clockOut = sorted.first { $0.type == .clockOut }

            if let clockIn, let lunchOut,
               lunchOut.effectiveOccurredAt >= clockIn.effectiveOccurredAt {
                seconds += lunchOut.effectiveOccurredAt.timeIntervalSince(
                    clockIn.effectiveOccurredAt
                )
            } else {
                hasException = true
            }

            if let lunchIn, let clockOut,
               clockOut.effectiveOccurredAt >= lunchIn.effectiveOccurredAt {
                seconds += clockOut.effectiveOccurredAt.timeIntervalSince(
                    lunchIn.effectiveOccurredAt
                )
            } else {
                hasException = true
            }
        }

        let split = WeeklyHoursCalculator.split(
            totalHours: seconds / 3600
        )

        var result = employee
        result.regularHours = split.regular
        result.overtimeHours = split.overtime
        result.totalHours = split.total
        result.hasException = hasException
        return result
    }

    private static func companyCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(
            identifier: AppConfig.companyTimeZoneIdentifier
        ) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = companyCalendar()
        formatter.timeZone = companyCalendar().timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func previousWeekDates() -> (start: Date, end: Date) {
        let calendar = companyCalendar()
        let now = Date()
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: now
        )
        let thisMonday = calendar.date(from: components) ?? now
        let previousMonday = calendar.date(
            byAdding: .day,
            value: -7,
            to: thisMonday
        ) ?? now
        let previousSunday = calendar.date(
            byAdding: .day,
            value: 6,
            to: previousMonday
        ) ?? previousMonday
        return (previousMonday, previousSunday)
    }

    private static func previousWeekStrings() -> (start: String, end: String) {
        let dates = previousWeekDates()
        let formatter = DateFormatter()
        formatter.calendar = companyCalendar()
        formatter.timeZone = companyCalendar().timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return (
            formatter.string(from: dates.start),
            formatter.string(from: dates.end)
        )
    }

    enum DemoError: LocalizedError {
        case notSignedIn
        case unauthorized
        case employeeShiftNotFound
        case biometricRequired
        case duplicateEvent
        case invalidSchedule
        case duplicateShift
        case duplicateShiftAssignment
        case breakAdjustmentReasonRequired
        case notFound
        case punchNotFound
        case alreadyApproved
        case reasonRequired
        case unresolvedExceptions
        case supervisorNameRequired
        case signatureRequired

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Sign in to continue."
            case .unauthorized:
                return "This demo account does not have permission for that action."
            case .employeeShiftNotFound:
                return "No shift is assigned for this employee today."
            case .biometricRequired:
                return "Biometric confirmation is required to record a rest break as not taken."
            case .duplicateEvent:
                return "That rest-break event has already been recorded."
            case .duplicateShift:
                return "A shift with this name already exists in that department and date."
            case .duplicateShiftAssignment:
                return "This employee is already assigned to a shift on this workday."
            case .invalidSchedule:
                return "Rest Break 1 must remain in the first work period and Rest Break 2 must remain after lunch and before shift end."
            case .breakAdjustmentReasonRequired:
                return "Enter a supervisor reason when moving an employee's rest break away from the recommended midpoint."
            case .notFound:
                return "The demo timesheet could not be found."
            case .punchNotFound:
                return "The selected punch could not be found."
            case .alreadyApproved:
                return "Approved packets are locked against further changes."
            case .reasonRequired:
                return "A reason is required for every manual punch adjustment."
            case .unresolvedExceptions:
                return "Resolve punch/rest-break exceptions before signing."
            case .supervisorNameRequired:
                return "Enter the supervisor's printed name."
            case .signatureRequired:
                return "A digital signature is required before approval."
            }
        }
    }
}
