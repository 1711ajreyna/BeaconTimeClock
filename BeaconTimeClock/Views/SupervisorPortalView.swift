// FILE PURPOSE: Company approval progress plus links only to authorized department details.
import SwiftUI

/// Company-wide weekly approval dashboard.
///
/// Every supervisor can see which departments still have not approved their
/// packets. Editing remains restricted by `canEdit` from the backend.
// This type groups related state and behavior under a clear responsibility.
struct SupervisorPortalView: View {

    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var services: AppServices

    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject
    private var viewModel:
        SupervisorPortalViewModel

    private let api:
        WorkflowAPI

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        viewModel:
            SupervisorPortalViewModel,
        api:
            WorkflowAPI
    ) {
        _viewModel =
            StateObject(
                wrappedValue:
                    viewModel
            )
        self.api = api
    }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            List {
                Section {
                    BrandHeaderView(
                        subtitle:
                            "Supervisor Portal"
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: 12,
                            leading: 16,
                            bottom: 12,
                            trailing: 16
                        )
                    )
                }

                if let dashboard =
                    viewModel.dashboard
                {
                    approvalProgress(
                        dashboard
                    )

                    Section(
                        "Department Status"
                    ) {
                        ForEach(
                            dashboard
                                .departments
                                .sorted {
                                    $0
                                        .department
                                        .sortOrder
                                    <
                                    $1
                                        .department
                                        .sortOrder
                                }
                        ) { summary in
                            if summary.canEdit {
                                NavigationLink {
                                    DepartmentTimesheetDetailView(
                                        viewModel:
                                            DepartmentTimesheetViewModel(
                                                timesheetID:
                                                    summary.id,
                                                api:
                                                    api
                                            ),
                                        canEdit:
                                            true
                                    )
                                } label: {
                                    DepartmentStatusRow(
                                        summary:
                                            summary
                                    )
                                }
                            } else {
                                DepartmentStatusRow(
                                    summary:
                                        summary
                                )
                            }
                        }
                    }

                    // Choose the explicit demo path; production must use real backend controls.
                    if AppConfig.demoMode && services.profile?.canAccessPayroll == true {
                        Section(
                            "Demonstration"
                        ) {
                            Button(
                                "Reset Weekly Demo"
                            ) {
                                Task {
                                    await viewModel
                                        .resetDemo()
                                }
                            }

                            Text(
                                "Use this after demonstrating punch corrections and approvals so the five departments return to their starting state."
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }

                if viewModel.isLoading {
                    Section {
                        ProgressView(
                            "Loading weekly workflow…"
                        )
                    }
                }

                if !viewModel
                    .errorMessage
                    .isEmpty
                {
                    Section {
                        Text(
                            viewModel
                                .errorMessage
                        )
                        .foregroundStyle(
                            .red
                        )
                    }
                }
            }
            .cscListStyle()
            .navigationTitle(
                "Supervisor"
            )
            // Enable pull-to-refresh without duplicating API logic.
            .refreshable {
                await viewModel.load()
            }
            // Start asynchronous work when SwiftUI presents this view; handle loading and errors.
            .task {
                await viewModel.load()
            }
            .onAppear {
                Task {
                    await viewModel.load()
                }
            }
        }
    }

    @ViewBuilder
    private func approvalProgress(
        _ dashboard:
            SupervisorDashboard
    ) -> some View {
        Section(
            "Previous Week"
        ) {
            LabeledContent(
                "Workweek",
                value:
                    DateFormatting
                        .friendlyWeek(
                            start:
                                dashboard
                                    .weekStart,
                            end:
                                dashboard
                                    .weekEnd
                        )
            )

            LabeledContent(
                "Approved",
                value:
                    "\(dashboard.approvedCount) / \(dashboard.departments.count)"
            )

            if dashboard
                .pendingDepartments
                .isEmpty
            {
                Label(
                    dashboard
                        .hrPacketStatus
                        == .emailed
                    ? "All departments approved — merged workbook emailed to HR."
                    : "All departments approved — HR packet is ready.",
                    systemImage:
                        "checkmark.seal.fill"
                )
                .foregroundStyle(
                    .green
                )
            } else {
                VStack(
                    alignment:
                        .leading,
                    spacing: 5
                ) {
                    Label(
                        "Still awaiting approval",
                        systemImage:
                            "clock.badge.exclamationmark"
                    )
                    .font(.headline)

                    Text(
                        viewModel
                            .pendingNames
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
    }
}

private struct DepartmentStatusRow:
    View
{
    let summary:
        DepartmentApprovalSummary

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack {
                Text(
                    summary
                        .department
                        .displayName
                )
                .font(.headline)

                Spacer()

                Label(
                    summary
                        .status
                        .displayName,
                    systemImage:
                        summary
                            .status
                            == .pending
                        ? "clock.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(
                    summary.status ==
                        .pending
                    ? .orange
                    : .green
                )
            }

            HStack {
                Text(
                    "\(summary.employeeCount) employee(s)"
                )

                Spacer()

                Text(
                    String(
                        format:
                            "%.2f hrs",
                        summary
                            .totalHours
                    )
                )
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

            HStack {
                Text(
                    String(
                        format:
                            "Regular %.2f",
                        summary
                            .regularHours
                    )
                )
                .foregroundStyle(
                    .green
                )

                Spacer()

                Text(
                    String(
                        format:
                            "OT %.2f",
                        summary
                            .overtimeHours
                    )
                )
                .foregroundStyle(
                    summary
                        .overtimeHours
                        > 0
                    ? .red
                    : .green
                )
            }
            .font(.caption.bold())
        }
        .padding(
            .vertical,
            4
        )
    }
}
