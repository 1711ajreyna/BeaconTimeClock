// FILE PURPOSE: Shared API contract implemented by both demo and production clients.
import Foundation

/// Single app-facing backend contract.
///
/// DemoAPIClient and ProductionAPIClient implement the same methods so the UI
/// can be demonstrated locally and later deployed without being rewritten.
// UI-observed state and these operations run on the main actor.
@MainActor
// Both DemoAPIClient and ProductionAPIClient must satisfy this contract.
protocol WorkflowAPI: AnyObject {
    // Identity / role
    // Return the authenticated employee/role profile.
    func fetchMyProfile() async throws -> UserProfile

    // Employee punches
    // Submit a clock action and save the authoritative server response.
    func submitPunch(
        _ request: SubmitPunchRequest
    ) async throws -> SubmitPunchResponse

    // Daily shift / breaks
    // Retrieve the signed-in employee's current assigned shift.
    func fetchMyShift() async throws -> MyShiftResponse

    // Record a paid rest-break event or exception.
    func recordShiftEvent(
        _ request: RecordShiftEventRequest
    ) async throws -> RecordShiftEventResponse

    // MARK: - Named Shifts and Employee Rosters

    /// The same contract is implemented by DemoAPIClient and production API.
    // Load named shifts, assigned staff and available employees with department scoping.
    func fetchShiftRoster() async throws -> ShiftRosterResponse

    /// Creates a Morning/Evening/Night/Custom shift for one department/date.
    // Create a new shift after validating its department and time window.
    func createWorkShift(_ request: CreateWorkShiftRequest) async throws -> WorkShift

    /// Assigns one employee to the selected shift; backend checks permissions.
    // Attach an authorized employee to the selected shift.
    func assignWorkShift(_ request: AssignWorkShiftRequest) async throws -> WorkShiftAssignment

    /// Removes one employee assignment, not the employee's account.
    // Remove a roster link without erasing past punches.
    func removeWorkShiftAssignment(_ request: RemoveWorkShiftAssignmentRequest) async throws

    // Supervisor schedule configuration
    // Retrieve schedules that this supervisor is allowed to manage.
    func fetchSupervisorSchedule() async throws -> SupervisorScheduleResponse

    // Submit changes to break times with adjustment reasons.
    func updateShiftSchedule(
        _ request: UpdateShiftScheduleRequest
    ) async throws -> UpdateShiftScheduleResponse

    // MARK: - Shared status versus private payroll data
    /// Safe for all signed-in users. No employee-level financial details.
    // Return non-sensitive completion states visible to signed-in staff.
    func fetchCompanySubmissionStatus() async throws -> CompanySubmissionStatus

    /// HR/admin only; backend must enforce authorization before returning data.
    func fetchHRPayrollPacket() async throws -> HRPayrollPacket

    /// Explicit, demo-only convenience; never an implicit production approval.
    func prepareDemoHRPacket() async throws

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
