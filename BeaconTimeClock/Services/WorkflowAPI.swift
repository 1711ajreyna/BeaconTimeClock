import Foundation

/// Single app-facing backend contract.
///
/// DemoAPIClient and ProductionAPIClient implement the same methods so the UI
/// can be demonstrated locally and later deployed without being rewritten.
@MainActor
protocol WorkflowAPI: AnyObject {
    // Identity / role
    func fetchMyProfile() async throws -> UserProfile

    // Employee punches
    func submitPunch(
        _ request: SubmitPunchRequest
    ) async throws -> SubmitPunchResponse

    // Daily shift / breaks
    func fetchMyShift() async throws -> MyShiftResponse

    func recordShiftEvent(
        _ request: RecordShiftEventRequest
    ) async throws -> RecordShiftEventResponse

    // MARK: - Named Shifts and Employee Rosters

    /// The same contract is implemented by DemoAPIClient and production API.
    func fetchShiftRoster() async throws -> ShiftRosterResponse

    /// Creates a Morning/Evening/Night/Custom shift for one department/date.
    func createWorkShift(_ request: CreateWorkShiftRequest) async throws -> WorkShift

    /// Assigns one employee to the selected shift; backend checks permissions.
    func assignWorkShift(_ request: AssignWorkShiftRequest) async throws -> WorkShiftAssignment

    /// Removes one employee assignment, not the employee's account.
    func removeWorkShiftAssignment(_ request: RemoveWorkShiftAssignmentRequest) async throws

    // Supervisor schedule configuration
    func fetchSupervisorSchedule() async throws -> SupervisorScheduleResponse

    func updateShiftSchedule(
        _ request: UpdateShiftScheduleRequest
    ) async throws -> UpdateShiftScheduleResponse

    // Weekly supervisor approval workflow
    func fetchSupervisorDashboard() async throws -> SupervisorDashboard

    func fetchDepartmentTimesheet(
        timesheetID: UUID
    ) async throws -> DepartmentTimesheet

    func adjustPunch(
        _ request: PunchAdjustmentRequest
    ) async throws -> PunchAdjustmentResponse

    func approveDepartment(
        _ request: ApproveDepartmentRequest
    ) async throws -> ApproveDepartmentResponse

    // Demo reset
    func resetDemoData() async
}
