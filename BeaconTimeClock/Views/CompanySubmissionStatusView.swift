// FILE PURPOSE: Read-only company-wide submission status without exposing payroll details.
import SwiftUI

/// Read-only company-wide status: safe for every authenticated employee.
/// It never requests names, punches, regular hours or payroll data.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
struct CompanySubmissionStatusView: View {
    // Dependency injection: tests can use a fake API and production can use real HTTP.
    private let api: WorkflowAPI
    @State private var response: CompanySubmissionStatus?
    @State private var errorMessage = ""
    @State private var loading = false

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(api: WorkflowAPI) { self.api = api }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            List {
                Section {
                    BrandHeaderView(subtitle: "Company HR Status")
                }
                if let response {
                    Section("Previous Payroll Week") {
                        Text("\(response.weekStart) – \(response.weekEnd)")
                        Label(
                            response.hrDeliveryConfirmed ? "HR delivery confirmed" :
                                "Some departments still need approval or delivery",
                            systemImage: response.hrDeliveryConfirmed
                                ? "checkmark.seal.fill" : "clock"
                        )
                    }
                    Section("Company Departments") {
                        ForEach(response.departments.sorted {
                            $0.department.sortOrder < $1.department.sortOrder
                        }) { item in
                            HStack {
                                Text(item.department.displayName)
                                Spacer()
                                Text(item.stage.displayName)
                                    .foregroundStyle(item.stage == .sentToHR ? .green : .secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                if loading { ProgressView("Loading status…") }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .cscListStyle()
            .navigationTitle("HR Status")
            // Start asynchronous work when SwiftUI presents this view; handle loading and errors.
            .task { await load() }
            // Enable pull-to-refresh without duplicating API logic.
            .refreshable { await load() }
        }
    }

    // Refresh this screen from its API or local source of truth.
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            response = try await api.fetchCompanySubmissionStatus()
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
