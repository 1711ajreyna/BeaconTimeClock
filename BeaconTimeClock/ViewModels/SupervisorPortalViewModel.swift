// FILE PURPOSE: Loads supervisor approval dashboard and demo reset state.
import Foundation

/// Loads company-wide approval progress for the previous workweek.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class SupervisorPortalViewModel: ObservableObject {

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set)
    var dashboard: SupervisorDashboard?

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set)
    var isLoading = false

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var errorMessage = ""

    // Dependency injection: tests can use a fake API and production can use real HTTP.
    private let api: WorkflowAPI

    // Create this object with the dependencies or state it needs; avoid hidden global services.
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

    // Refresh this screen from its API or local source of truth.
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

    // Restore fictional demonstration data without touching production.
    func resetDemo() async {
        await api.resetDemoData()
        await load()
    }
}
