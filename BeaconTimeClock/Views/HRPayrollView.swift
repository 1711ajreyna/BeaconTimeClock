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
    @State private var csvReadyToShare: URL?
    // Editable report heading. Week-ending date is derived from the actual packet.
    @AppStorage("payroll.report.heading") private var payrollHeading = "PAYROLL"
    @State private var showDemoApprovalConfirmation = false
    @State private var demoPreviewShareURL: URL?
    private let isHRRole: Bool

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(profile: UserProfile, api: WorkflowAPI) {
        isHRRole = profile.role == .hr
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
                    // Preview and approval preparation must be separate actions.
                    // Preview MUST NOT change the live demo timesheets.
                    if AppConfig.demoMode {
                        Section("Demonstration") {
                            Button {
                                do {
                                    let url = try viewModel.previewDemoPDF(heading: payrollHeading)
                                    previewURL = url
                                    readyToShare = url
                                    demoPreviewShareURL = viewModel.demoApprovalSimulationActive ? url : nil
                                    viewModel.errorMessage = ""
                                } catch {
                                    viewModel.errorMessage = error.localizedDescription
                                }
                            } label: {
                                Label("Preview Demo Payroll PDF", systemImage: "doc.richtext")
                            }
                            .disabled(viewModel.isLoading || viewModel.packet == nil || !isValidPayrollHeading)
                            .accessibilityIdentifier("preview_demo_payroll_pdf_button")

                            if isHRRole && viewModel.demoApprovalSimulationActive {
                                Label("DEMO ONLY: 5 simulated approvals shown. Real approvals are unchanged.",
                                      systemImage: "testtube.2")
                                    .foregroundStyle(.orange)
                                    .font(.subheadline.bold())
                                    .accessibilityIdentifier("demo_payroll_simulation_active")
                                Button("End Demo Approval Simulation") {
                                    viewModel.disableDemoApprovalSimulation()
                                    demoPreviewShareURL = nil
                                    readyToShare = nil
                                }
                                .accessibilityIdentifier("disable_demo_approvals_button")
                            } else if isHRRole {
                                Button("Simulate All Five Approvals (Demo Only)") {
                                    showDemoApprovalConfirmation = true
                                }
                                .accessibilityIdentifier("simulate_demo_approvals_button")
                                .disabled(viewModel.isLoading || viewModel.packet == nil)
                            }
                            if isHRRole && viewModel.demoApprovalSimulationActive,
                               let demoPreviewShareURL {
                                ShareLink(item: demoPreviewShareURL) {
                                    Label("Share WATERMARKED Demo PDF", systemImage: "square.and.arrow.up")
                                }
                                .accessibilityIdentifier("share_simulated_pdf_button")
                            }
                            Text("Simulation affects this HR screen and the demonstration PDF only. No department's real status, signature or server record is changed.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Real departmental approvals remain restricted to each assigned supervisor; HR cannot sign for them.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let packet = viewModel.packet {
                        Section("Pay Period") {
                            LabeledContent("Week", value:
                                "\(packet.weekStart) to \(packet.weekEnd)")
                            LabeledContent("Department forms", value:
                                "\(viewModel.sheets.count) / 5")
                            LabeledContent("Actually approved", value:
                                "\(viewModel.approvalCount) / 5")
                            if viewModel.demoApprovalSimulationActive {
                                LabeledContent("Simulated for HR demo", value:
                                    "\(viewModel.simulatedApprovalCount) / 5")
                            }
                            Text("Source: weekly backend snapshots. Approved hours are not recalculated on the phone.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if let packet = viewModel.packet {
                        Section("Payroll PDF Filename") {
                            TextField("Report heading", text: $payrollHeading)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("payroll_heading_field")
                            Button("Reset heading to PAYROLL") {
                                payrollHeading = "PAYROLL"
                            }
                            .accessibilityIdentifier("reset_payroll_heading_button")
                            if !isValidPayrollHeading {
                                Text("Use 1–35 letters, numbers, spaces, underscores or hyphens.")
                                    .font(.caption).foregroundStyle(.red)
                            }
                            if let title = try? PayrollReportNaming.displayTitle(
                                weekEnd: packet.weekEnd, heading: payrollHeading) {
                                LabeledContent("Title inside PDF", value: title)
                            }
                            if let filename = try? PayrollReportNaming.fileName(
                                weekEnd: packet.weekEnd, heading: payrollHeading,
                                department: nil, demoPreview: viewModel.demoApprovalSimulationActive) {
                                LabeledContent("Saved filename", value: filename)
                            }
                            LabeledContent("Week-ending Sunday", value: packet.weekEnd)
                            Text("The editable heading is saved on this device. The Sunday date comes from the selected pay-period records: never change it just to rename a signed report. Choose the correct weekly packet to change the date. PDF title uses DD/MM/YYYY; filenames use DD-MM-YYYY because '/' is invalid in a filename.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Section("Department Payroll Forms") {
                        ForEach(viewModel.displayedSheets) { sheet in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(sheet.department.displayName).font(.headline)
                                    Spacer()
                                Text(viewModel.demoApprovalSimulationActive
                                     ? "Simulated Approved" : sheet.status.displayName)
                                    .foregroundStyle(viewModel.demoApprovalSimulationActive
                                                     ? .orange : (sheet.status == .pending ? .orange : .green))
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
                                .disabled(!viewModel.canExport || !isValidPayrollHeading)
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
                        .disabled(!viewModel.canExport || !isValidPayrollHeading)

                        if let readyToShare {
                            ShareLink(item: readyToShare) {
                                Label("Share or Save Last PDF", systemImage: "square.and.arrow.up")
                            }
                        }
                        Text("Each department begins on its OWN payroll-entry form, with individual daily punch detail pages afterward. PDF export is not an ADP/payroll submission.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("HR Spreadsheet Exports") {
                        Button { generateCSV(daily: true) } label: {
                            Label("Prepare Daily Punch CSV", systemImage: "calendar")
                        }
                        .disabled(!viewModel.canExport)
                        .accessibilityIdentifier("prepare_daily_csv_button")

                        Button { generateCSV(daily: false) } label: {
                            Label("Prepare Weekly Hours CSV", systemImage: "tablecells")
                        }
                        .disabled(!viewModel.canExport)
                        .accessibilityIdentifier("prepare_weekly_csv_button")

                        if let csvReadyToShare {
                            ShareLink(item: csvReadyToShare) {
                                Label("Share or Save Prepared CSV", systemImage: "square.and.arrow.up")
                            }
                        }
                        Text("Daily CSV: a separate dated row for each shift, including overnight +1-day times. Weekly CSV: one row per employee so hours are not accidentally double-counted. Both require approved packets and must be handled as confidential payroll data.")
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
            .onChange(of: payrollHeading) { _, _ in
                // Never share a previously generated file after editing its title.
                readyToShare = nil
                demoPreviewShareURL = nil
            }
            .confirmationDialog(
                "Demonstration approvals only",
                isPresented: $showDemoApprovalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Show Five Simulated Approvals") {
                    demoPreviewShareURL = nil
                    viewModel.enableDemoApprovalSimulation()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This changes only the HR demo display and read-only PDF. No supervisor approvals, signatures, or actual payroll exports are created.")
            }
        }
    }

    private var isValidPayrollHeading: Bool {
        (try? PayrollReportNaming.sanitizedHeading(payrollHeading)) != nil
    }

    // Prepare a CSV for the share sheet; never silently upload staff records.
    private func generateCSV(daily: Bool) {
        do {
            if daily {
                csvReadyToShare = try viewModel.exportDailyCSV()
            } else {
                csvReadyToShare = try viewModel.exportWeeklyCSV()
            }
            viewModel.errorMessage = ""
        } catch {
            csvReadyToShare = nil
            viewModel.errorMessage = error.localizedDescription
        }
    }

    // Export the chosen data and hand it to the iOS sharing/preview UI.
    private func generatePDF(for department: Department?) {
        do {
            let url = try department.map { try viewModel.exportDepartment($0, heading: payrollHeading) }
                ?? viewModel.exportAll(heading: payrollHeading)
            readyToShare = url
            previewURL = url
            viewModel.errorMessage = ""
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
