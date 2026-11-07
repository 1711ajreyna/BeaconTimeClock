// FILE PURPOSE: In-memory mock workflow for timecards, shift rosters, approvals and HR demo data.
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
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class DemoAPIClient: WorkflowAPI {
    private let profileProvider: () -> UserProfile?

    private var timesheets: [UUID: DepartmentTimesheet] = [:]
    private var dashboardGeneratedAt = Date()

    private var shiftRows: [UUID: SupervisorScheduleRow] = [:]
    private var shiftEvents: [UUID: [ShiftEventRecord]] = [:]

    // MARK: - Multiple Shift Demo State
    private var workShifts: [UUID: WorkShift] = [:] // Named shift occurrences.
    private var rosterAssignments: [UUID: WorkShiftAssignment] = [:] // Employee rosters.

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        profileProvider: @escaping () -> UserProfile?
    ) {
        self.profileProvider = profileProvider
        seed()
    }

    // Return the authenticated employee/role profile.
    func fetchMyProfile() async throws -> UserProfile {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider() else {
            throw DemoError.notSignedIn
        }

        return profile
    }

    // Submit a clock action and save the authoritative server response.
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

    // Retrieve the signed-in employee's current assigned shift.
    func fetchMyShift() async throws -> MyShiftResponse {
        // Obtain the signed-in user before exposing any private data.
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

    // Record a paid rest-break event or exception.
    func recordShiftEvent(
        _ request: RecordShiftEventRequest
    ) async throws -> RecordShiftEventResponse {
        // Obtain the signed-in user before exposing any private data.
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

    // Load named shifts, assigned staff and available employees with department scoping.
    func fetchShiftRoster() async throws -> ShiftRosterResponse {
        try requireSupervisor()
        let employees = shiftRows.values.map { row in
            RosterEmployee(
                id: row.employeeID, employeeNumber: row.employeeNumber,
                employeeName: row.employeeName, department: row.department
            )
        }
        // One supervisor sees only their department; HR/admin see all five.
        let profile = profileProvider()!
        let allowedShifts = workShifts.values.filter {
            profile.canManageDepartment($0.department)
        }
        let allowedIDs = Set(allowedShifts.map(\.id))
        return ShiftRosterResponse(
            shifts: allowedShifts.sorted { $0.startTime < $1.startTime },
            assignments: rosterAssignments.values.filter {
                allowedIDs.contains($0.shiftID)
            },
            employees: employees.filter {
                profile.canManageDepartment($0.department)
            }.sorted { $0.employeeName < $1.employeeName }
        )
    }

    // Create a new shift after validating its department and time window.
    func createWorkShift(_ request: CreateWorkShiftRequest) async throws -> WorkShift {
        try requireSupervisor()
        let shift = request.shift
        try requireDepartment(shift.department)
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

    // Attach an authorized employee to the selected shift.
    func assignWorkShift(_ request: AssignWorkShiftRequest) async throws -> WorkShiftAssignment {
        try requireSupervisor()
        guard let shift = workShifts[request.shiftID],
              let employee = shiftRows.values.first(where: { $0.employeeID == request.employeeID }),
              employee.department == shift.department else {
            throw DemoError.unauthorized
        }
        try requireDepartment(shift.department)
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

    // Remove a roster link without erasing past punches.
    func removeWorkShiftAssignment(_ request: RemoveWorkShiftAssignmentRequest) async throws {
        try requireSupervisor()
        guard let assignment = rosterAssignments[request.assignmentID],
              let shift = workShifts[assignment.shiftID] else {
            throw DemoError.notFound
        }
        try requireDepartment(shift.department) // Authorize BEFORE mutation.
        rosterAssignments.removeValue(forKey: request.assignmentID)
        // A production system also checks whether payroll events already exist.
    }

    // Reused by ALL demo reads and writes. Not a production security boundary.
    // Reject attempts to read or edit departments outside the signed-in user's scope.
    private func requireDepartment(_ department: Department) throws {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(),
              profile.canManageDepartment(department) else {
            throw DemoError.unauthorized
        }
    }

    // Reject detailed payroll access from non-HR accounts.
    private func requireHR() throws {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(), profile.canAccessPayroll else {
            throw DemoError.unauthorized
        }
    }

    // Check the caller has management privileges before continuing.
    private func requireSupervisor() throws {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(), profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }
    }

    // Retrieve schedules that this supervisor is allowed to manage.
    func fetchSupervisorSchedule()
    async throws -> SupervisorScheduleResponse {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        return SupervisorScheduleResponse(
            workDate: Self.todayString(),
            rows: shiftRows.values.filter {
                profile.canManageDepartment($0.department)
            }.sorted { $0.employeeName < $1.employeeName }
        )
    }

    // Submit changes to break times with adjustment reasons.
    func updateShiftSchedule(
        _ request: UpdateShiftScheduleRequest
    ) async throws -> UpdateShiftScheduleResponse {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard var row = shiftRows[request.shiftAssignmentID] else {
            throw DemoError.employeeShiftNotFound
        }

        try requireDepartment(row.department)

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

    // MARK: - HR Submission Status (safe for ALL signed-in roles)
    // Return non-sensitive completion states visible to signed-in staff.
    func fetchCompanySubmissionStatus() async throws -> CompanySubmissionStatus {
        guard profileProvider() != nil else { throw DemoError.notSignedIn }
        let range = Self.previousWeekStrings()
        let departments = Department.allCases.sorted { $0.sortOrder < $1.sortOrder }
        let rows = departments.map { department -> CompanyDepartmentStatus in
            guard let sheet = timesheets.values.first(where: { $0.department == department }) else {
                return CompanyDepartmentStatus(department: department, stage: .notGenerated)
            }
            let stage: CompanyDepartmentStage
            switch sheet.status {
            case .pending: stage = .pending
            case .approved: stage = .approved
            case .sentToHR: stage = .sentToHR
            }
            return CompanyDepartmentStatus(department: department, stage: stage)
        }
        return CompanySubmissionStatus(
            weekStart: range.start, weekEnd: range.end,
            departments: rows,
            hrDeliveryConfirmed: rows.allSatisfy { $0.stage == .sentToHR }
        )
    }

    // MARK: - HR-only weekly packet (one complete timesheet per department)
    // Load sensitive payroll records for HR/admin use only.
    func fetchHRPayrollPacket() async throws -> HRPayrollPacket {
        try requireHR()
        let range = Self.previousWeekStrings()
        return HRPayrollPacket(
            weekStart: range.start,
            weekEnd: range.end,
            departments: timesheets.values.sorted {
                $0.department.sortOrder < $1.department.sortOrder
            }
        )
    }

    /// Makes a complete *simulated* signed packet, for capstone HR PDF demos.
    /// Does NOT send email, certify actual hours or submit real payroll.
    // Seed an approved sample packet for a repeatable HR demonstration.
    func prepareDemoHRPacket() async throws {
        try requireHR()
        for id in Array(timesheets.keys) {
            timesheets[id]?.status = .approved
            timesheets[id]?.signedAt = Date()
            timesheets[id]?.supervisorName = "DEMO SIGNOFF - NOT REAL"
            timesheets[id]?.signaturePresent = true
        }
    }

    // Load department approval progress and edit permissions.
    func fetchSupervisorDashboard()
    async throws -> SupervisorDashboard {
        try requireSupervisor()
        let profile = profileProvider()!
        let sheets = timesheets.values.filter {
            profile.canManageDepartment($0.department)
        }.sorted { $0.department.sortOrder < $1.department.sortOrder }

        let summaries = sheets.map { sheet in
            DepartmentApprovalSummary(
                id: sheet.id, department: sheet.department,
                status: sheet.status, employeeCount: sheet.employees.count,
                regularHours: sheet.regularHours,
                overtimeHours: sheet.overtimeHours,
                totalHours: sheet.totalHours, supervisorName: sheet.supervisorName,
                signedAt: sheet.signedAt,
                canEdit: sheet.status == .pending && profile.canManageDepartment(sheet.department)
            )
        }
        let allApproved = !timesheets.isEmpty && timesheets.values.allSatisfy {
            $0.status != .pending
        }
        let anySent = timesheets.values.contains { $0.status == .sentToHR }
        let hrStatus: HRPacketStatus = anySent ? .emailed :
            (allApproved ? .ready : .waitingForDepartments)
        let range = Self.previousWeekStrings()
        return SupervisorDashboard(
            weekStart: range.start, weekEnd: range.end,
            generatedAt: dashboardGeneratedAt,
            departments: summaries, hrPacketStatus: hrStatus
        )
    }

    // Retrieve a selected department's detailed weekly timesheet.
    func fetchDepartmentTimesheet(
        timesheetID: UUID
    ) async throws -> DepartmentTimesheet {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard let sheet = timesheets[timesheetID] else {
            throw DemoError.notFound
        }

        try requireDepartment(sheet.department)
        return sheet
    }

    // Change an effective punch time without silently discarding the original.
    func adjustPunch(
        _ request: PunchAdjustmentRequest
    ) async throws -> PunchAdjustmentResponse {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard var sheet = timesheets[request.timesheetID] else {
            throw DemoError.notFound
        }

        try requireDepartment(sheet.department)
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

    // Approve a department sheet only after role, exception and signature checks.
    func approveDepartment(
        _ request: ApproveDepartmentRequest
    ) async throws -> ApproveDepartmentResponse {
        // Obtain the signed-in user before exposing any private data.
        guard let profile = profileProvider(),
              profile.role.canUseSupervisorTools else {
            throw DemoError.unauthorized
        }

        guard var sheet = timesheets[request.timesheetID] else {
            throw DemoError.notFound
        }

        try requireDepartment(sheet.department)
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

        // Demo timestamp only; a production approval must use the server clock.
        let signedAt = Date()
        sheet.status = .approved
        sheet.supervisorName = printedName
        sheet.signedAt = signedAt
        sheet.signaturePresent = true
        timesheets[sheet.id] = sheet

        let allApproved = timesheets.values.allSatisfy {
            $0.status == .approved || $0.status == .sentToHR
        }

        // Approval != delivery: leave sheets approved until a real delivery receipt.
        // Demo status stays 'ready', never falsely claims an email was sent.

        return ApproveDepartmentResponse(
            success: true,
            signedAt: signedAt,
            allDepartmentsApproved: allApproved,
            hrMergeTriggered: false, // No real delivery job runs in demo mode.
            message: allApproved
                ? "All departments approved. HR packet ready for review (demo; not emailed)."
                : "Department approved. HR is waiting for the remaining departments."
        )
    }

    func resetDemoData() async {
        // The reset impacts ALL departments, so ordinary supervisors cannot run it.
        guard (try? requireHR()) != nil else { return }
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

        // Six distinct fictional employees in EACH of the five departments.
        // EMP-001 is the existing demo login, preserving My Shift compatibility.
        let names: [[String]] = [
            ["Demo Employee", "Avery Brooks", "Jordan Hale", "Casey Rivera", "Morgan Quinn", "Cameron Ellis"],
            ["Taylor Stone", "Robin Diaz", "Parker Lin", "Finley Ross", "Quinn Avery", "Jamie Wells"],
            ["Skyler Young", "Dakota Reed", "Harper Grant", "Sage Bennett", "Jules Morgan", "Drew Parker"],
            ["Reese Cooper", "Alex Kendall", "Sam Carter", "Blake Turner", "Remy Jordan", "Charlie Ellis"],
            ["Emerson Lane", "Riley Cole", "Ellis Morgan", "Lee Harper", "Mika Reed", "Rowan Brooks"]
        ]

        for department in Department.allCases {
            for index in 0..<6 {
                let serial = department.sortOrder * 6 + index + 1
                let employeeID = serial == 1
                    ? UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
                    : UUID()
                let dayStart = calendar.date(
                    bySettingHour: 7, minute: 0, second: 0, of: today
                )!
                let row = SupervisorScheduleRow(
                    id: UUID(), employeeID: employeeID,
                    employeeNumber: String(format: "EMP-%03d", serial),
                    employeeName: names[department.sortOrder][index],
                    department: department,
                    shiftStart: dayStart,
                    break1Start: dayStart.addingTimeInterval(2.25 * 3600),
                    lunchStart: dayStart.addingTimeInterval(4.5 * 3600),
                    break2Start: dayStart.addingTimeInterval(6.75 * 3600),
                    shiftEnd: dayStart.addingTimeInterval(8.5 * 3600),
                    restBreakDurationMinutes: AppConfig.restBreakDurationMinutes,
                    lunchDurationMinutes: AppConfig.lunchDurationMinutes,
                    break1AdjustmentReason: nil, break2AdjustmentReason: nil
                )
                shiftRows[row.id] = row
            }
        }
    }

    // MARK: - Sample Multiple Shifts

    private func seedNamedShifts() {
        workShifts.removeAll()
        rosterAssignments.removeAll()
        // Every department has three shift examples with two employees each.
        let sampleTimes: [(String, Int, Int, Int, Int)] = [
            ("Morning", 6, 0, 14, 30),
            ("Evening", 14, 0, 22, 30),
            ("Night", 22, 0, 6, 30)
        ]
        for department in Department.allCases {
            let employees = shiftRows.values.filter {
                $0.department == department
            }.sorted { $0.employeeNumber < $1.employeeNumber }

            for (index, sample) in sampleTimes.enumerated() {
                let (name, sh, sm, eh, em) = sample
                do {
                    let shift = try WorkShift.makeEightHourShift(
                        name: name, department: department, workDate: Date(),
                        startHour: sh, startMinute: sm,
                        endHour: eh, endMinute: em
                    )
                    workShifts[shift.id] = shift
                    // Only one roster assignment per employee on this date.
                    for row in employees.dropFirst(index * 2).prefix(2) {
                        let assignment = WorkShiftAssignment(
                            id: UUID(), employeeID: row.employeeID,
                            employeeNumber: row.employeeNumber,
                            employeeName: row.employeeName, shiftID: shift.id
                        )
                        rosterAssignments[assignment.id] = assignment
                    }
                } catch {
                    print("Could not seed demo shift: \(error)")
                }
            }
        }
    }

    private func seedWeeklyTimesheets() {
        let range = Self.previousWeekStrings()
        // Generate one department packet containing ALL six people, not one
        // fake employee per department. Each packet maps to exactly one HR form.
        timesheets = [:]
        for department in Department.allCases {
            let employees = shiftRows.values.filter {
                $0.department == department
            }.sorted { $0.employeeNumber < $1.employeeNumber }

            let weekly = employees.enumerated().map { index, row in
                Self.makeWeeklyEmployee(
                    employeeNumber: row.employeeNumber,
                    employeeName: row.employeeName,
                    totalHours: [38.0, 40.0, 43.5, 37.5, 45.0, 39.25][index],
                    skippedBreak: department == .plastics && index == 2
                )
            }
            let sheet = DepartmentTimesheet(
                id: UUID(), department: department,
                weekStart: range.start, weekEnd: range.end,
                status: .pending, employees: weekly,
                generatedAt: Date(), sentToSupervisorAt: Date(),
                supervisorName: nil, signedAt: nil, signaturePresent: false
            )
            timesheets[sheet.id] = sheet
        }
    }

    private static func makeWeeklyEmployee(
        employeeNumber: String,
        employeeName: String,
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
            employeeID: employeeNumber,
            employeeName: employeeName,
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
