import Foundation

/// Loads company-wide approval progress for the previous workweek.
@MainActor
final class SupervisorPortalViewModel: ObservableObject {

    @Published private(set)
    var dashboard: SupervisorDashboard?

    @Published private(set)
    var isLoading = false

    @Published var errorMessage = ""

    private let api: WorkflowAPI

    init(
        api: WorkflowAPI
    ) {
        self.api = api
    }

    var pendingNames: String {
        guard let dashboard else {
            return ""
        }

        return dashboard.pendingDepartments
            .map { $0.department.displayName }
            .joined(separator: ", ")
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            dashboard =
                try await api
                    .fetchSupervisorDashboard()

            errorMessage = ""
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    func resetDemo() async {
        await api.resetDemoData()
        await load()
    }
}
