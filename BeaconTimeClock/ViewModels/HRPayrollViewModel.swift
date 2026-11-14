// FILE PURPOSE: Loads approved HR packets and controls per-department PDF export.
import Foundation

/// HR-only presenter. Production and demo return the SAME HRPayrollPacket type.
/// IMPORTANT: SwiftUI role checks are not security; the endpoint must enforce them.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class HRPayrollViewModel: ObservableObject {
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var packet: HRPayrollPacket?
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var isLoading = false
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var errorMessage = ""
    /// HR-only fictional overlay, not a signed department approval or database write.
    @Published private(set) var demoApprovalSimulationActive = false

    private let profile: UserProfile
    // Dependency injection: tests can use a fake API and production can use real HTTP.
    private let api: WorkflowAPI

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(profile: UserProfile, api: WorkflowAPI) {
        self.profile = profile
        self.api = api
    }

    var isAuthorized: Bool { profile.canAccessPayroll }
    /// Never silently export partial weeks, unsigned forms or unresolved punches.
    var canExport: Bool {
        guard isAuthorized, !isLoading, let packet else { return false }
        let sheets = packet.departments
        let actualDepartments = Set(sheets.map(\.department))
        let expectedDepartments = Set(Department.allCases)
        return sheets.count == expectedDepartments.count &&
            actualDepartments == expectedDepartments &&
            sheets.allSatisfy { sheet in
                (sheet.status == .approved || sheet.status == .sentToHR) &&
                sheet.signaturePresent && sheet.signedAt != nil &&
                !sheet.hasUnresolvedExceptions &&
                sheet.weekStart == packet.weekStart &&
                sheet.weekEnd == packet.weekEnd
            }
    }

    var sheets: [DepartmentTimesheet] {
        (packet?.departments ?? []).sorted {
            $0.department.sortOrder < $1.department.sortOrder
        }
    }

    var approvalCount: Int {
        sheets.filter { $0.status != .pending }.count
    }

    /// Screen-only copies with fictional signoffs. Real `packet` and API state stay untouched.
    var displayedSheets: [DepartmentTimesheet] {
        guard demoApprovalSimulationActive, AppConfig.demoMode, profile.role == .hr else {
            return sheets
        }
        return sheets.map { original in
            var copy = original
            copy.status = .approved
            copy.supervisorName = "SIMULATED SIGNOFF - NOT REAL"
            copy.signedAt = Date(timeIntervalSince1970: 1_700_000_000)
            copy.signaturePresent = true
            return copy
        }
    }

    var simulatedApprovalCount: Int { displayedSheets.filter { $0.status != .pending }.count }

    func enableDemoApprovalSimulation() {
        guard AppConfig.demoMode, profile.role == .hr, packet != nil else { return }
        demoApprovalSimulationActive = true
    }

    func disableDemoApprovalSimulation() {
        demoApprovalSimulationActive = false
    }

    // Refresh this screen from its API or local source of truth.
    func load() async {
        guard isAuthorized else {
            packet = nil
            errorMessage = AppLocalization.text("HR or administrator access is required.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            // The response is intentionally HR-only. Never build it by
            // allowing ordinary employees to fetch department timesheets.
            packet = try await api.fetchHRPayrollPacket()
            // Keep an explicit HR demonstration active after a manual refresh.
            errorMessage = ""
        } catch {
            packet = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Non-mutating: render the currently loaded snapshots as a clearly labeled
    /// demo preview. Do NOT call the approval endpoint from a preview action.
    func previewDemoPDF(heading: String = "PAYROLL") throws -> URL {
        guard AppConfig.demoMode, isAuthorized, !isLoading, !sheets.isEmpty else {
            throw HRPayrollError.incomplete
        }
        return try PayrollPDFExporter.export(sheets: displayedSheets, demoPreview: true,
                                             heading: heading)
    }


    // Export one row per employee/week: ideal for manually entering approved totals.
    func exportWeeklyCSV() throws -> URL {
        guard canExport else { throw HRPayrollError.incomplete }
        return try PayrollCSVExporter.export(sheets: sheets, kind: .weeklyTotals)
    }

    // Export individual dated shifts without repeating weekly hour totals.
    func exportDailyCSV() throws -> URL {
        guard canExport else { throw HRPayrollError.incomplete }
        return try PayrollCSVExporter.export(sheets: sheets, kind: .dailyPunches)
    }

    // Generate a combined PDF containing separate forms for all five departments.
    func exportAll(heading: String = "PAYROLL") throws -> URL {
        guard canExport else { throw HRPayrollError.incomplete }
        return try PayrollPDFExporter.export(sheets: sheets, heading: heading)
    }

    // Generate an HR payroll-entry PDF for one department.
    func exportDepartment(_ department: Department, heading: String = "PAYROLL") throws -> URL {
        guard canExport, let sheet = sheets.first(where: {
            $0.department == department
        }) else { throw HRPayrollError.incomplete }
        return try PayrollPDFExporter.export(sheets: [sheet], heading: heading)
    }
}

// This type groups related state and behavior under a clear responsibility.
enum HRPayrollError: LocalizedError {
    case incomplete
    var errorDescription: String? {
        "Five distinct department packets must be approved, signed, and free " +
        "of unresolved time-punch exceptions before HR PDF export."
    }
}
