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
            errorMessage = ""
        } catch {
            packet = nil
            errorMessage = error.localizedDescription
        }
    }

    /// DEMO-ONLY shortcut to inspect five signed example forms.
    func prepareSample() async {
        guard AppConfig.demoMode && isAuthorized else { return }
        do {
            try await api.prepareDemoHRPacket()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Generate a combined PDF containing separate forms for all five departments.
    func exportAll() throws -> URL {
        guard canExport else { throw HRPayrollError.incomplete }
        return try PayrollPDFExporter.export(sheets: sheets)
    }

    // Generate an HR payroll-entry PDF for one department.
    func exportDepartment(_ department: Department) throws -> URL {
        guard canExport, let sheet = sheets.first(where: {
            $0.department == department
        }) else { throw HRPayrollError.incomplete }
        return try PayrollPDFExporter.export(sheets: [sheet])
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
