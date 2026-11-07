// FILE PURPOSE: HR-only payroll screen, approval status and PDF sharing.
import SwiftUI
import QuickLook

/// Private HR area. The public status board is a DIFFERENT view and API call.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
struct HRPayrollView: View {
    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var viewModel: HRPayrollViewModel
    @State private var previewURL: URL?
    @State private var readyToShare: URL?

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(profile: UserProfile, api: WorkflowAPI) {
        _viewModel = StateObject(
            wrappedValue: HRPayrollViewModel(profile: profile, api: api)
        )
    }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            List {
                Section {
                    BrandHeaderView(subtitle: "HR Payroll")
                }
                if !viewModel.isAuthorized {
                    ContentUnavailableView(
                        "Restricted Payroll Area", systemImage: "lock.shield",
                        description: Text("Only HR and administrators can view payroll details.")
                    )
                } else {
                    // The demo button prepares the simulated signed packets and
                    // opens the combined PDF in a single, discoverable action.
                    // It cannot submit payroll or approve production records.
                    if AppConfig.demoMode {
                        Section("Demo PDF Preview") {
                            Button {
                                Task {
                                    await viewModel.prepareSample()
                                    if viewModel.canExport {
                                        generatePDF(for: nil)
                                    }
                                }
                            } label: {
                                Label("Preview Demo Payroll PDF", systemImage: "doc.richtext")
                            }
                            .disabled(viewModel.isLoading)
                            .accessibilityIdentifier("preview_demo_payroll_pdf_button")

                            Text("Generates five simulated, signed example forms for class demonstrations only. No real payroll is sent or approved.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let packet = viewModel.packet {
                        Section("Pay Period") {
                            LabeledContent("Week", value:
                                "\(packet.weekStart) to \(packet.weekEnd)")
                            LabeledContent("Department forms", value:
                                "\(viewModel.sheets.count) / 5")
                            LabeledContent("Approved", value:
                                "\(viewModel.approvalCount) / 5")
                            Text("Source: weekly backend snapshots. Approved hours are not recalculated on the phone.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Section("Department Payroll Forms") {
                        ForEach(viewModel.sheets) { sheet in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(sheet.department.displayName).font(.headline)
                                    Spacer()
                                    Text(sheet.status.displayName)
                                        .foregroundStyle(sheet.status == .pending ? .orange : .green)
                                        .font(.caption)
                                }
                                Text("\(sheet.employees.count) \(AppLocalization.text("employees")) · " +
                                     String(format: AppLocalization.text("Regular %.2f / OT %.2f / Total %.2f"),
                                            sheet.regularHours, sheet.overtimeHours, sheet.totalHours))
                                    .font(.caption).monospacedDigit()

                                // One separately shareable PDF per department.
                                Button {
                                    generatePDF(for: sheet.department)
                                } label: {
                                    Label {
                                        Text("\(AppLocalization.text("Open")) \(sheet.department.displayName) \(AppLocalization.text("Form"))")
                                    } icon: {
                                        Image(systemName: "doc.richtext")
                                    }
                                }
                                .disabled(!viewModel.canExport)
                            }
                            .padding(.vertical, 5)
                        }
                    }

                    Section("Combined Packet") {
                        Button {
                            generatePDF(for: nil)
                        } label: {
                            Label("Open All Five Department Forms", systemImage: "doc.on.doc")
                        }
                        .disabled(!viewModel.canExport)

                        if let readyToShare {
                            ShareLink(item: readyToShare) {
                                Label("Share or Save Last PDF", systemImage: "square.and.arrow.up")
                            }
                        }
                        Text("Each department begins on its OWN payroll-entry form, with individual daily punch detail pages afterward. PDF export is not an ADP/payroll submission.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    if !viewModel.canExport && !viewModel.isLoading {
                        Label("Forms are locked until all five departments have signed, approved timesheets.", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if viewModel.isLoading { ProgressView("Loading HR packets…") }
                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .cscListStyle()
            .navigationTitle("HR Payroll")
            // Start asynchronous work when SwiftUI presents this view; handle loading and errors.
            .task { await viewModel.load() }
            // Enable pull-to-refresh without duplicating API logic.
            .refreshable { await viewModel.load() }
            .quickLookPreview($previewURL)
        }
    }

    // Export the chosen data and hand it to the iOS sharing/preview UI.
    private func generatePDF(for department: Department?) {
        do {
            let url = try department.map { try viewModel.exportDepartment($0) }
                ?? viewModel.exportAll()
            readyToShare = url
            previewURL = url
            viewModel.errorMessage = ""
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
