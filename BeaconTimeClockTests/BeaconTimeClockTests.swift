import XCTest
import SwiftData
@testable import BeaconTimeClock

// MARK: - BeaconTimeClockTests

final class BeaconTimeClockTests: XCTestCase {
    func testRolePermissions() {
        for role in [UserRole.employee, .supervisor, .hr, .admin] {
            let profile = UserProfile(id: UUID(), displayName: "Tester", email: "test@example.com",
                role: role, employeeID: nil, employeeNumber: nil, department: .electrical)
            XCTAssertEqual(profile.canAccessPayroll, role == .hr || role == .admin)
            XCTAssertEqual(profile.canManageDepartment(.electrical), role == .supervisor)
            XCTAssertFalse(profile.canManageDepartment(.metals))
        }
    }
}

// MARK: - BreakWorkflowTDDTests

@MainActor
final class BreakWorkflowTDDTests: XCTestCase {
    func testAdjustedScheduleRequiresReasonAndPreservesStateOnFailure() async throws {
        let user = UserProfile(id: UUID(), displayName: "Supervisor", email: "test@example.com",
            role: .supervisor, employeeID: nil, employeeNumber: nil, department: .electrical)
        let api = DemoAPIClient { user }
        let initial = try await api.fetchSupervisorSchedule()
        let row = try XCTUnwrap(initial.rows.first)
        let changed = row.recommendedBreaks.break1Start.addingTimeInterval(300)
        func request(_ reason: String?) -> UpdateShiftScheduleRequest {
            .init(shiftAssignmentID: row.id, break1Start: changed,
                  break2Start: row.recommendedBreaks.break2Start,
                  break1AdjustmentReason: reason, break2AdjustmentReason: nil)
        }
        do { _ = try await api.updateShiftSchedule(request("   ")); XCTFail("Blank reason accepted") }
        catch { guard case DemoAPIClient.DemoError.breakAdjustmentReasonRequired = error else { return XCTFail("Unexpected: \(error)") } }
        let unchanged = try await api.fetchSupervisorSchedule()
        XCTAssertEqual(unchanged.rows.first { $0.id == row.id }, row)
        let result = try await api.updateShiftSchedule(request("  Coverage needed  "))
        XCTAssertEqual(result.row.break1Start, changed)
        XCTAssertEqual(result.row.break1AdjustmentReason, "Coverage needed")
    }
}

// MARK: - CaliforniaRestBreakPolicyTests

final class CaliforniaRestBreakPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private func validate(first: Double = 2.25, lunch: Double = 4.5, second: Double = 6.75,
                          meal: Int = 30, rest: Int = 10) throws {
        try CaliforniaRestBreakPolicy.validate(shiftStart: start,
            break1Start: start.addingTimeInterval(first * 3600),
            lunchStart: start.addingTimeInterval(lunch * 3600), lunchDurationMinutes: meal,
            break2Start: start.addingTimeInterval(second * 3600),
            shiftEnd: start.addingTimeInterval(8.5 * 3600), restBreakDurationMinutes: rest)
    }
    func testDefaultRecommendationsAndValidSchedule() throws {
        let result = CaliforniaRestBreakPolicy.recommendedBreakStarts(shiftStart: start,
            lunchStart: start.addingTimeInterval(4.5 * 3600), lunchDurationMinutes: 30,
            shiftEnd: start.addingTimeInterval(8.5 * 3600))
        XCTAssertEqual(result.break1Start, start.addingTimeInterval(2.25 * 3600))
        XCTAssertEqual(result.break2Start, start.addingTimeInterval(6.75 * 3600))
        try validate()
    }
    func testShortRestRejected() {
        XCTAssertThrowsError(try validate(rest: 9)) { XCTAssertEqual($0 as? CaliforniaRestBreakPolicy.ValidationError, .restBreakTooShort) }
    }
    func testShortMealRejected() {
        XCTAssertThrowsError(try validate(meal: 29)) { XCTAssertEqual($0 as? CaliforniaRestBreakPolicy.ValidationError, .mealTooShort) }
    }
    func testLateMealRejectedAndFifthHourAccepted() throws {
        try validate(lunch: 5)
        XCTAssertThrowsError(try validate(lunch: 5.01)) { XCTAssertEqual($0 as? CaliforniaRestBreakPolicy.ValidationError, .mealStartsTooLate) }
    }
    func testBreaksMustFitWorkPeriods() {
        for first in [0.0, 4.4] {
            XCTAssertThrowsError(try validate(first: first)) { XCTAssertEqual($0 as? CaliforniaRestBreakPolicy.ValidationError, .firstBreakOutsideFirstWorkPeriod) }
        }
        for second in [4.9, 8.4] {
            XCTAssertThrowsError(try validate(second: second)) { XCTAssertEqual($0 as? CaliforniaRestBreakPolicy.ValidationError, .secondBreakOutsideSecondWorkPeriod) }
        }
    }
    func testAdjustmentToleranceBoundary() {
        XCTAssertFalse(CaliforniaRestBreakPolicy.isAdjusted(actual: start.addingTimeInterval(60), recommended: start))
        XCTAssertTrue(CaliforniaRestBreakPolicy.isAdjusted(actual: start.addingTimeInterval(-61), recommended: start))
    }
}

// MARK: - DemoAuthPersistenceTests
#if !CORE_TESTS

@MainActor
final class DemoAuthPersistenceTests: XCTestCase {
    private let key = "BeaconTimeClock.demoSessionEmail"

    func testDemoLoginRestoresAndSignOutRemovesSession() async throws {
        guard AppConfig.demoMode else { throw XCTSkip("Demo authentication requires Debug") }
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        let auth = AuthManager(supabase: nil, staffDirectory: DemoStaffDirectory())
        await auth.bootstrap()
        XCTAssertEqual(auth.state, .signedOut)
        await auth.signIn(email: AppConfig.demoEmployeeEmail, password: AppConfig.demoPassword)
        XCTAssertEqual(auth.state, .signedIn)
        XCTAssertEqual(auth.demoProfile?.employeeNumber, "EMP-001")
        let restored = AuthManager(supabase: nil, staffDirectory: DemoStaffDirectory())
        await restored.bootstrap()
        XCTAssertEqual(restored.state, .signedIn)
        XCTAssertEqual(restored.userID, auth.userID)
        await restored.signOut()
        XCTAssertEqual(restored.state, .signedOut)
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
    }

    func testWrongPasswordDoesNotCreateSession() async throws {
        guard AppConfig.demoMode else { throw XCTSkip("Demo authentication requires Debug") }
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        let auth = AuthManager(supabase: nil, staffDirectory: DemoStaffDirectory())
        await auth.bootstrap()
        await auth.signIn(email: AppConfig.demoEmployeeEmail, password: "incorrect")
        XCTAssertEqual(auth.state, .signedOut)
        XCTAssertFalse(auth.errorMessage.isEmpty)
        XCTAssertNil(UserDefaults.standard.object(forKey: key))
    }
}

#endif

// MARK: - DemoBreakWorkflowTests

@MainActor
final class DemoBreakWorkflowTests: XCTestCase {
    func testStartedAndEndedBreakEventsPersistForBothSlots() async throws {
        let user = UserProfile(id: UUID(), displayName: "Employee", email: "test@example.com",
            role: .employee, employeeID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            employeeNumber: "EMP-001", department: .electrical)
        let api = DemoAPIClient { user }
        let shift = try await api.fetchMyShift()
        let sequence: [ShiftEventType] = [.restBreak1Started, .restBreak1Ended, .restBreak2Started, .restBreak2Ended]
        for type in sequence {
            let result = try await api.recordShiftEvent(.init(shiftAssignmentID: shift.schedule.id,
                type: type, biometricVerified: true, beaconVerified: true, note: nil))
            XCTAssertTrue(result.success)
            XCTAssertEqual(result.event.type, type)
        }
        let refreshed = try await api.fetchMyShift()
        XCTAssertEqual(refreshed.events.map(\.type), sequence)
        XCTAssertTrue(refreshed.events.allSatisfy { $0.beaconVerified && $0.biometricVerified })
    }
}

// MARK: - DemoWorkflowTests

@MainActor
final class DemoWorkflowTests: XCTestCase {
    private func profile(_ role: UserRole, department: Department? = .electrical) -> UserProfile {
        UserProfile(id: UUID(), displayName: "Verified Supervisor", email: "test@example.com", role: role,
            employeeID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            employeeNumber: "EMP-001", department: department)
    }
    func testSignedOutCannotReadProfileOrCompanyStatus() async {
        let api = DemoAPIClient { nil }
        do { _ = try await api.fetchMyProfile(); XCTFail("Signed-out read accepted") }
        catch { guard case DemoAPIClient.DemoError.notSignedIn = error else { return XCTFail("Unexpected: \(error)") } }
        do { _ = try await api.fetchCompanySubmissionStatus(); XCTFail("Signed-out status accepted") }
        catch { guard case DemoAPIClient.DemoError.notSignedIn = error else { return XCTFail("Unexpected: \(error)") } }
    }
    func testSupervisorDepartmentScopeAndPayrollDenial() async throws {
        let user = profile(.supervisor)
        let api = DemoAPIClient { user }
        let roster = try await api.fetchShiftRoster()
        XCTAssertEqual(roster.employees.count, 6)
        XCTAssertEqual(roster.shifts.count, 3)
        XCTAssertTrue(roster.employees.allSatisfy { $0.department == .electrical })
        let dashboard = try await api.fetchSupervisorDashboard()
        XCTAssertEqual(dashboard.departments.map(\.department), [.electrical])
        do { _ = try await api.fetchHRPayrollPacket(); XCTFail("Supervisor accessed payroll") }
        catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("Unexpected: \(error)") } }
    }
    func testEmployeeShiftAndBreakExceptionRequireBiometrics() async throws {
        let user = profile(.employee)
        let api = DemoAPIClient { user }
        let shift = try await api.fetchMyShift()
        XCTAssertEqual(shift.schedule.employeeNumber, "EMP-001")
        XCTAssertEqual(shift.projectedWeeklyHours, 42.5)
        XCTAssertEqual(shift.projectedOvertimeHours, 2.5)
        func request(_ verified: Bool) -> RecordShiftEventRequest {
            .init(shiftAssignmentID: shift.schedule.id, type: .restBreak1NotTaken,
                  biometricVerified: verified, beaconVerified: true, note: "Demo exception")
        }
        do { _ = try await api.recordShiftEvent(request(false)); XCTFail("Missing biometric accepted") }
        catch { guard case DemoAPIClient.DemoError.biometricRequired = error else { return XCTFail("Unexpected: \(error)") } }
        let result = try await api.recordShiftEvent(request(true))
        XCTAssertTrue(result.success)
        let refreshed = try await api.fetchMyShift()
        XCTAssertEqual(refreshed.events.map(\.type), [.restBreak1NotTaken])
        do { _ = try await api.recordShiftEvent(request(true)); XCTFail("Duplicate accepted") }
        catch { guard case DemoAPIClient.DemoError.duplicateEvent = error else { return XCTFail("Unexpected: \(error)") } }
    }
    func testAnotherEmployeesShiftCannotBeModified() async throws {
        var user = profile(.supervisor)
        let api = DemoAPIClient { user }
        let schedule = try await api.fetchSupervisorSchedule()
        let other = try XCTUnwrap(schedule.rows.first { $0.employeeNumber != "EMP-001" })
        user = profile(.employee)
        do {
            _ = try await api.recordShiftEvent(.init(shiftAssignmentID: other.id,
                type: .restBreak1Started, biometricVerified: true, beaconVerified: true, note: nil))
            XCTFail("Cross-employee write accepted")
        } catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("Unexpected: \(error)") } }
    }
    func testHRCanReadButCannotApproveOrResetDepartments() async throws {
        let user = profile(.hr)
        let api = DemoAPIClient { user }
        let before = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(Set(before.departments.map(\.department)), Set(Department.allCases))
        do { try await api.prepareDemoHRPacket(); XCTFail("HR approved five departments") }
        catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("Unexpected: \(error)") } }
        await api.resetDemoData()
        let after = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(after.departments, before.departments)
        let status = try await api.fetchCompanySubmissionStatus()
        XCTAssertFalse(status.hrDeliveryConfirmed)
        do { _ = try await api.fetchSupervisorDashboard(); XCTFail("HR accessed supervisor edits") }
        catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("Unexpected: \(error)") } }
    }
    func testApprovalUsesAuthenticatedNameAndLocksSheet() async throws {
        let user = profile(.supervisor)
        let api = DemoAPIClient { user }
        let dashboard = try await api.fetchSupervisorDashboard()
        let summary = try XCTUnwrap(dashboard.departments.first)
        let selected = try await api.fetchDepartmentTimesheet(timesheetID: summary.id)
        XCTAssertFalse(selected.hasUnresolvedExceptions)
        let request = ApproveDepartmentRequest(timesheetID: selected.id,
            supervisorPrintedName: "Untrusted name", signaturePNGBase64: "demo-signature")
        let result = try await api.approveDepartment(request)
        XCTAssertFalse(result.hrMergeTriggered)
        let approved = try await api.fetchDepartmentTimesheet(timesheetID: selected.id)
        XCTAssertEqual(approved.supervisorName, user.displayName)
        XCTAssertEqual(approved.status, .approved)
        do { _ = try await api.approveDepartment(request); XCTFail("Repeated approval accepted") }
        catch { guard case DemoAPIClient.DemoError.alreadyApproved = error else { return XCTFail("Unexpected: \(error)") } }
    }
}

// MARK: - ShiftNotificationPlanTests

final class ShiftNotificationPlanTests: XCTestCase {
    func testWarningsUseSeparateBreakAndMealOffsets() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let schedule = ShiftSchedule(id: UUID(), employeeID: UUID(), employeeNumber: "EMP-001",
            employeeName: "Test", department: .electrical, workDate: "2023-11-14",
            shiftStart: start, break1Start: start.addingTimeInterval(8100),
            lunchStart: start.addingTimeInterval(16200), break2Start: start.addingTimeInterval(24300),
            shiftEnd: start.addingTimeInterval(30600), restBreakDurationMinutes: 10, lunchDurationMinutes: 30)
        let plan = ShiftNotificationPlan.make(schedule: schedule)
        XCTAssertEqual(plan.break1StartWarning, schedule.break1Start.addingTimeInterval(-120))
        XCTAssertEqual(plan.break2StartWarning, schedule.break2Start.addingTimeInterval(-120))
        XCTAssertEqual(plan.lunchWarning, schedule.lunchStart.addingTimeInterval(-300))
        XCTAssertEqual(plan.clockOutWarning, schedule.shiftEnd.addingTimeInterval(-300))
        let custom = ShiftNotificationPlan.make(schedule: schedule, restBreakWarningMinutes: 3, mealAndClockOutWarningMinutes: 7)
        XCTAssertEqual(custom.break1StartWarning, schedule.break1Start.addingTimeInterval(-180))
        XCTAssertEqual(custom.clockOutWarning, schedule.shiftEnd.addingTimeInterval(-420))
        XCTAssertEqual(schedule.scheduledEnd(for: .second), schedule.break2Start.addingTimeInterval(600))
    }
}

// MARK: - TimeCardStoreTests


@MainActor
final class TimeCardStoreTests: XCTestCase {
    private func card(_ employee: String, at timestamp: Double) -> TimeCard {
        TimeCard(employeeID: employee, employeeName: "Test", type: .clockIn,
            timestamp: Date(timeIntervalSince1970: timestamp), beaconUUID: "test", rssi: -45,
            estimatedDistanceMeters: 1)
    }
    func testEmployeeIsolationAndSelectiveReset() throws {
        let container = try ModelContainer(for: TimeCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = TimeCardStore(context: container.mainContext)
        try store.add(card("EMP-A", at: 100))
        try store.add(card("EMP-B", at: 300))
        try store.add(card("EMP-A", at: 200))
        XCTAssertEqual(store.latestPunch?.employeeID, "EMP-B")
        XCTAssertEqual(store.latestPunch(for: "EMP-A")?.timestamp, Date(timeIntervalSince1970: 200))
        XCTAssertNil(store.latestPunch(for: "EMP-C"))
        try store.clearDemoPunches(for: "EMP-A")
        XCTAssertEqual(store.timeCards.map(\.employeeID), ["EMP-B"])
    }
    func testSyncAndFailurePersistAcrossStoreRefresh() throws {
        let container = try ModelContainer(for: TimeCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = TimeCardStore(context: container.mainContext)
        let punch = card("EMP-A", at: 100)
        try store.add(punch)
        XCTAssertEqual(punch.syncStatus, "pending")
        try store.markFailed(card: punch)
        XCTAssertEqual(punch.syncStatus, "failed")
        let remote = UUID()
        let serverDate = Date(timeIntervalSince1970: 500)
        try store.markSynced(card: punch, remoteID: remote, serverTimestamp: serverDate)
        let restored = TimeCardStore(context: ModelContext(container))
        XCTAssertEqual(restored.latestPunch?.remoteID, remote)
        XCTAssertEqual(restored.latestPunch?.timestamp, serverDate)
        XCTAssertEqual(restored.latestPunch?.syncStatus, "synced")
        try store.clearAll()
        XCTAssertTrue(store.timeCards.isEmpty)
    }
}

// MARK: - WeeklyHoursCalculatorTests

final class WeeklyHoursCalculatorTests: XCTestCase {
    func testWeeklyThresholdAndNegativeHours() {
        XCTAssertEqual(WeeklyHoursCalculator.split(totalHours: -2), .init(regular: 0, overtime: 0, total: 0))
        XCTAssertEqual(WeeklyHoursCalculator.split(totalHours: 40), .init(regular: 40, overtime: 0, total: 40))
        XCTAssertEqual(WeeklyHoursCalculator.split(totalHours: 42.5), .init(regular: 40, overtime: 2.5, total: 42.5))
        XCTAssertEqual(WeeklyHoursCalculator.split(totalHours: 35, regularLimit: 32), .init(regular: 32, overtime: 3, total: 35))
    }
    func testRoundingAndIndicator() {
        XCTAssertEqual(WeeklyHoursCalculator.rounded(12.346), 12.35)
        XCTAssertEqual(HoursIndicator.status(overtimeHours: 0), .withinRegularLimit)
        XCTAssertEqual(HoursIndicator.status(overtimeHours: 0.01), .overtime)
    }
    func testOvernightShiftSubtractsOnlyUnpaidLunch() throws {
        let day = ISO8601DateFormatter().date(from: "2026-10-20T19:00:00Z")!
        let shift = try WorkShift.makeEightHourShift(name: "Night", department: .electrical,
            workDate: day, startHour: 22, startMinute: 0, endHour: 6, endMinute: 30)
        XCTAssertEqual(shift.elapsedHours, 8.5)
        XCTAssertEqual(DateFormatting.companyDateKey(shift.endTime), "2026-10-21")
        XCTAssertEqual(WeeklyHoursCalculator.projectedPaidHours(shifts: [shift, shift]), 16)
        XCTAssertEqual(WeeklyHoursCalculator.projectedPaidHours(shifts: []), 0)
    }
    func testUnsupportedShiftDurationIsRejected() {
        XCTAssertThrowsError(try WorkShift.makeEightHourShift(name: "Short", department: .metals,
            workDate: Date(), startHour: 7, startMinute: 0, endHour: 12, endMinute: 0))
    }
    func testNonexistentPacificDSTTimeIsRejected() {
        let day = ISO8601DateFormatter().date(from: "2026-03-08T20:00:00Z")!
        XCTAssertThrowsError(try DateFormatting.companyDate(on: day, hour: 2, minute: 30))
    }
}

// MARK: - Staff management and persistence
@MainActor
final class StaffManagementTests: XCTestCase {
    private func hr() -> UserProfile {
        UserProfile(id: UUID(), displayName: "HR", email: "hr@test.com", role: .hr,
                    employeeID: nil, employeeNumber: nil, department: nil)
    }
    private func newMember() -> StaffMember {
        StaffMember(id: UUID(), employeeID: nil, name: "New Person", email: "new@example.com",
                    employeeNumber: "EMP-100", role: .employee, department: .metals, isActive: true)
    }

    func testSavedStaffSurvivesDirectoryReloadAndNormalizesInput() throws {
        let suite = "StaffTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = DemoStaffDirectory(defaults: defaults)
        var member = newMember()
        member.email = "  NEW@EXAMPLE.COM  "
        let saved = try directory.save(member)
        let restored = DemoStaffDirectory(defaults: defaults)
        XCTAssertEqual(restored.profile(email: "new@example.com")?.employeeID, saved.id)
        XCTAssertEqual(restored.profile(email: "new@example.com")?.department, .metals)
        XCTAssertEqual(restored.members.count, 38)
    }

    func testDuplicateEmailNumberAndInvalidFieldsDoNotMutateDirectory() throws {
        let directory = DemoStaffDirectory()
        let original = directory.members
        var member = newMember()
        member.email = AppConfig.demoEmployeeEmail.uppercased()
        XCTAssertThrowsError(try directory.save(member))
        member.email = "new@example.com"
        member.employeeNumber = "emp-001"
        XCTAssertThrowsError(try directory.save(member))
        member.employeeNumber = "EMP-100"
        member.name = " "
        XCTAssertThrowsError(try directory.save(member))
        XCTAssertEqual(directory.members, original)
    }

    func testCorruptSavedStaffIsPreservedAndFailsClosed() throws {
        let suite = "StaffTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("broken".utf8)
        defaults.set(corrupt, forKey: DemoStaffDirectory.storageKey)
        let directory = DemoStaffDirectory(defaults: defaults)
        XCTAssertNil(directory.profile(email: AppConfig.demoHREmail))
        XCTAssertThrowsError(try directory.save(newMember()))
        XCTAssertEqual(defaults.data(forKey: DemoStaffDirectory.storageKey), corrupt)
    }

    func testEmployeeAndAdminCannotCreateStaff() async throws {
        let directory = DemoStaffDirectory()
        var current = directory.profile(email: AppConfig.demoEmployeeEmail)
        let api = DemoAPIClient(profileProvider: { current }, staffDirectory: directory)
        for email in [AppConfig.demoEmployeeEmail, AppConfig.demoAdminEmail] {
            current = directory.profile(email: email)
            do { _ = try await api.fetchStaff(); XCTFail("Unauthorized read") }
            catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("\(error)") } }
            do { _ = try await api.saveStaff(newMember()); XCTFail("Unauthorized write") }
            catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("\(error)") } }
        }
        XCTAssertNil(directory.profile(email: "new@example.com"))
    }

    func testCannotPromoteToHRorModifyProtectedAccount() async throws {
        let directory = DemoStaffDirectory()
        let api = DemoAPIClient(profileProvider: { self.hr() }, staffDirectory: directory)
        var member = newMember()
        member.role = .hr
        do { _ = try await api.saveStaff(member); XCTFail("HR role accepted") }
        catch { guard case StaffError.protectedAccount = error else { return XCTFail("\(error)") } }
        member = try XCTUnwrap(directory.members.first { $0.role == .hr })
        member.role = .employee
        do { _ = try await api.saveStaff(member); XCTFail("Protected account overwritten") }
        catch { guard case StaffError.protectedAccount = error else { return XCTFail("\(error)") } }
    }

    func testNewStaffAppearsInRosterBeforeSchedulingAndCanBeAssigned() async throws {
        let directory = DemoStaffDirectory()
        var current = hr()
        let api = DemoAPIClient(profileProvider: { current }, staffDirectory: directory)
        let saved = try await api.saveStaff(newMember())
        current = try XCTUnwrap(directory.profile(email: AppConfig.demoMetalsSupervisorEmail))
        let roster = try await api.fetchShiftRoster()
        XCTAssertTrue(roster.employees.contains { $0.id == saved.employeeID })
        XCTAssertFalse(roster.assignments.contains { $0.employeeID == saved.employeeID })
        let shift = try XCTUnwrap(roster.shifts.first { $0.department == .metals })
        let assigned = try await api.assignWorkShift(.init(shiftID: shift.id, employeeID: saved.id))
        XCTAssertEqual(assigned.employeeNumber, "EMP-100")
        let schedule = try await api.fetchSupervisorSchedule()
        XCTAssertTrue(schedule.rows.contains { $0.employeeID == saved.id && $0.shiftStart == shift.startTime })
    }

    func testTransferAndDeactivationPreserveHistoryAndIdentity() async throws {
        let directory = DemoStaffDirectory()
        var current = hr()
        let api = DemoAPIClient(profileProvider: { current }, staffDirectory: directory)
        let before = try await api.fetchHRPayrollPacket()
        var member = try XCTUnwrap(directory.members.first { $0.employeeNumber == "EMP-001" })
        let identity = member.employeeID
        member.department = .metals
        member.role = .supervisor
        member.employeeNumber = "SHOULD-NOT-CHANGE"
        let saved = try await api.saveStaff(member)
        XCTAssertEqual(saved.employeeID, identity)
        XCTAssertEqual(saved.employeeNumber, "EMP-001")
        let profile = try XCTUnwrap(directory.profile(email: member.email))
        XCTAssertTrue(profile.canManageDepartment(.metals))
        XCTAssertFalse(profile.canManageDepartment(.electrical))
        current = try XCTUnwrap(directory.profile(email: AppConfig.demoMetalsSupervisorEmail))
        let roster = try await api.fetchShiftRoster()
        XCTAssertFalse(roster.assignments.contains { $0.employeeID == identity })
        let after = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(before.departments, after.departments)
        member = saved
        member.isActive = false
        current = hr()
        _ = try await api.saveStaff(member)
        XCTAssertNil(directory.profile(email: member.email))
        current = try XCTUnwrap(directory.profile(email: AppConfig.demoMetalsSupervisorEmail))
        let inactiveRoster = try await api.fetchShiftRoster()
        XCTAssertFalse(inactiveRoster.employees.contains { $0.id == identity })
    }

    func testExistingSupervisorCanBecomeAnEmployee() throws {
        let directory = DemoStaffDirectory()
        var member = try XCTUnwrap(directory.members.first { $0.email == AppConfig.demoSupervisorEmail })
        XCTAssertNil(member.employeeID)
        member.role = .employee
        let saved = try directory.save(member)
        XCTAssertEqual(saved.employeeID, saved.id)
        XCTAssertFalse(saved.profile.canManageDepartment(.electrical))
        XCTAssertNotNil(directory.profile(email: saved.email)?.employeeNumber)
    }

    func testPromotedEmployeeKeepsOwnShift() async throws {
        let directory = DemoStaffDirectory()
        var current = hr()
        let api = DemoAPIClient(profileProvider: { current }, staffDirectory: directory)
        var member = try XCTUnwrap(directory.members.first { $0.employeeNumber == "EMP-001" })
        member.role = .supervisor
        _ = try await api.saveStaff(member)
        current = try XCTUnwrap(directory.profile(email: member.email))
        let shift = try await api.fetchMyShift()
        XCTAssertEqual(shift.schedule.employeeNumber, "EMP-001")
    }
}

// MARK: - Shared countdown behavior
@MainActor
final class CountdownTests: XCTestCase {
    func testLunchAndBreakCountdownsRemainIndependent() {
        var now = Date(timeIntervalSince1970: 1000)
        let lunch = LunchTimerManager(now: { now })
        let rest = BreakTimerManager(now: { now })
        lunch.start()
        rest.start(slot: .second)
        XCTAssertEqual(lunch.secondsRemaining, 1800)
        XCTAssertEqual(rest.formatted(), "10:00")
        now = now.addingTimeInterval(601)
        lunch.tick(); rest.tick()
        XCTAssertTrue(lunch.isRunning)
        XCTAssertFalse(rest.isRunning)
        XCTAssertEqual(rest.activeSlot, .second)
        rest.stop(); lunch.stop()
        XCTAssertNil(rest.activeSlot)
        XCTAssertEqual(lunch.secondsRemaining, 0)
    }
}


// MARK: - MDI2 120 payroll export and demo authorization regression tests
@MainActor
final class MDI2120RegressionTests: XCTestCase {
    func testHRCSVExportsSeparateDailyPunchesFromWeeklyTotals() async throws {
        let hr = UserProfile(id: UUID(), displayName: "HR Tester", email: "hr@test.com",
                             role: .hr, employeeID: nil, employeeNumber: nil, department: nil)
        let api = DemoAPIClient { hr }
        let packet = try await api.fetchHRPayrollPacket()
        // Format-only test. Create signed copies *in memory*; never mutate department approvals.
        let approvedCopies = packet.departments.map { source -> DepartmentTimesheet in
            var sheet = source
            sheet.status = .approved
            sheet.supervisorName = "Formatting Fixture"
            sheet.signedAt = Date()
            sheet.signaturePresent = true
            return sheet
        }
        let totalsURL = try PayrollCSVExporter.export(sheets: approvedCopies, kind: .weeklyTotals)
        let dailyURL = try PayrollCSVExporter.export(sheets: approvedCopies, kind: .dailyPunches)
        let totals = try String(contentsOf: totalsURL, encoding: .utf8)
        let daily = try String(contentsOf: dailyURL, encoding: .utf8)
        XCTAssertTrue(totals.contains("Regular Hours"))
        XCTAssertTrue(totals.contains("Overtime Hours"))
        XCTAssertFalse(totals.contains("Clock In"))
        XCTAssertTrue(daily.contains("Work Date (Pacific)"))
        XCTAssertTrue(daily.contains("Clock In"))
        XCTAssertFalse(daily.contains("Regular Hours"),
                       "Do not repeat week totals on each workday")
        let employees = packet.departments.reduce(0) { $0 + $1.employees.count }
        XCTAssertEqual(totals.split(separator: "\n").count, employees + 1)
    }

    func testDemoAPIRejectsUnsignedAndMismatchedEmployeePunches() async throws {
        let unauthenticated = DemoAPIClient { nil }
        let request = SubmitPunchRequest(employeeID: "EMP-001", type: .clockIn,
                                         beaconUUID: nil, rssi: -55, estimatedDistance: 2)
        do {
            _ = try await unauthenticated.submitPunch(request)
            XCTFail("Unsigned demo punch was accepted")
        } catch {
            guard case DemoAPIClient.DemoError.unauthorized = error else {
                return XCTFail("Unexpected: \(error)")
            }
        }
        let employee = UserProfile(id: UUID(), displayName: "Tester", email: "emp@test.com",
                                   role: .employee, employeeID: UUID(),
                                   employeeNumber: "EMP-999", department: .electrical)
        let wrongAccount = DemoAPIClient { employee }
        do {
            _ = try await wrongAccount.submitPunch(request)
            XCTFail("Cross-employee demo punch was accepted")
        } catch {
            guard case DemoAPIClient.DemoError.unauthorized = error else {
                return XCTFail("Unexpected: \(error)")
            }
        }
    }
}
