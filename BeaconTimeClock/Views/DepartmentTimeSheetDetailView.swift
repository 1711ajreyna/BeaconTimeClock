import SwiftUI
import PencilKit

/// Supervisor review screen for one department's previous-week packet.
struct DepartmentTimesheetDetailView:
    View
{
    @StateObject
    private var viewModel:
        DepartmentTimesheetViewModel

    let canEdit: Bool

    @State
    private var selectedPunch:
        PunchRecord?

    @State
    private var supervisorName =
        ""

    @State
    private var signature =
        PKDrawing()

    @State
    private var showApprovalAlert =
        false

    init(
        viewModel:
            DepartmentTimesheetViewModel,
        canEdit: Bool
    ) {
        _viewModel =
            StateObject(
                wrappedValue:
                    viewModel
            )

        self.canEdit = canEdit
    }

    var body: some View {
        List {
            if let sheet =
                viewModel.timesheet
            {
                statusSection(sheet)
                .listRowBackground(
                    sheet.status ==
                        .pending
                    ? Color.orange
                        .opacity(0.10)
                    : Color.green
                        .opacity(0.10)
                )

                totalsSection(sheet)

                ForEach(
                    sheet.employees
                ) { employee in
                    employeeSection(
                        employee,
                        editable:
                            canEdit &&
                            sheet.status ==
                                .pending
                    )
                }

                if canEdit &&
                    sheet.status ==
                        .pending
                {
                    signatureSection(
                        sheet
                    )
                } else if let signedAt =
                    sheet.signedAt
                {
                    Section(
                        "Approval"
                    ) {
                        LabeledContent(
                            "Supervisor",
                            value:
                                sheet
                                    .supervisorName
                                    ?? "Unknown"
                        )

                        LabeledContent(
                            "Signed"
                        ) {
                            Text(
                                signedAt,
                                format:
                                    .dateTime
                                    .year()
                                    .month()
                                    .day()
                                    .hour()
                                    .minute()
                            )
                        }

                        Label(
                            "Digital signature recorded",
                            systemImage:
                                "signature"
                        )
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView(
                    "Loading department packet…"
                )
            }

            if !viewModel
                .errorMessage
                .isEmpty
            {
                Text(
                    viewModel
                        .errorMessage
                )
                .foregroundStyle(
                    .red
                )
            }

            if !viewModel
                .successMessage
                .isEmpty
            {
                Text(
                    viewModel
                        .successMessage
                )
                .foregroundStyle(
                    .green
                )
            }
        }
        .navigationTitle(
            viewModel
                .timesheet?
                .department
                .displayName
            ?? "Timesheet"
        )
        .task {
            await viewModel.load()
        }
        .sheet(
            item:
                $selectedPunch
        ) { punch in
            PunchAdjustmentSheet(
                punch: punch
            ) {
                correctedDate,
                reason in

                Task {
                    await viewModel
                        .adjustPunch(
                            punchID:
                                punch.id,
                            correctedDate:
                                correctedDate,
                            reason:
                                reason
                        )
                }
            }
        }
        .alert(
            "Approve Department?",
            isPresented:
                $showApprovalAlert
        ) {
            Button(
                "Cancel",
                role: .cancel
            ) {}

            Button(
                "Approve & Sign"
            ) {
                approve()
            }
        } message: {
            Text(
                "This locks the department packet. Further punch changes require an administrative reopen workflow."
            )
        }
    }

    private func statusSection(
        _ sheet:
            DepartmentTimesheet
    ) -> some View {
        Section {
            if sheet.status ==
                .pending
            {
                Label(
                    "UNAPPROVED — SUPERVISOR REVIEW",
                    systemImage:
                        "exclamationmark.shield.fill"
                )
                .font(
                    .headline
                )
                .foregroundStyle(
                    .orange
                )
            } else {
                Label(
                    sheet.status
                        .displayName,
                    systemImage:
                        "checkmark.seal.fill"
                )
                .font(.headline)
                .foregroundStyle(
                    .green
                )
            }

            Text(
                "Week \(DateFormatting.friendlyWeek(start: sheet.weekStart, end: sheet.weekEnd))"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func totalsSection(
        _ sheet:
            DepartmentTimesheet
    ) -> some View {
        Section(
            "Department Totals"
        ) {
            LabeledContent(
                "Regular Hours"
            ) {
                Text(
                    sheet
                        .regularHours,
                    format:
                        .number
                        .precision(
                            .fractionLength(
                                2
                            )
                        )
                )
                .foregroundStyle(
                    .green
                )
                .fontWeight(
                    .semibold
                )
            }

            LabeledContent(
                "Overtime"
            ) {
                Text(
                    sheet
                        .overtimeHours,
                    format:
                        .number
                        .precision(
                            .fractionLength(
                                2
                            )
                        )
                )
                .foregroundStyle(
                    sheet
                        .overtimeHours
                        > 0
                    ? .red
                    : .green
                )
                .fontWeight(
                    .bold
                )
            }

            LabeledContent(
                "Total",
                value:
                    String(
                        format:
                            "%.2f",
                        sheet
                            .totalHours
                    )
            )
        }
    }

    private func employeeSection(
        _ employee:
            EmployeeWeeklySummary,
        editable: Bool
    ) -> some View {
        Section {
            VStack(
                alignment:
                    .leading,
                spacing: 7
            ) {
                HStack {
                    Text(
                        employee
                            .employeeName
                    )
                    .font(
                        .headline
                    )

                    Spacer()

                    if employee.hasException {
                        Label(
                            "Punch Exception",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    } else if employee.hasBreakException {
                        Label(
                            "Break Review",
                            systemImage: "cup.and.saucer.fill"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    }
                }

                HStack {
                    Text(
                        String(
                            format:
                                "Regular %.2f",
                            employee
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
                            employee
                                .overtimeHours
                        )
                    )
                    .foregroundStyle(
                        employee
                            .overtimeHours
                            > 0
                        ? .red
                        : .green
                    )
                    .fontWeight(
                        .bold
                    )
                }
            }

            ForEach(
                employee.punches
            ) { punch in
                HStack {
                    VStack(
                        alignment:
                            .leading
                    ) {
                        Text(
                            punch
                                .type
                                .displayName
                        )

                        Text(
                            punch
                                .effectiveOccurredAt
                                .formatted(
                                    date:
                                        .abbreviated,
                                    time:
                                        .shortened
                                )
                        )
                        .font(.caption)

                        if punch
                            .isAdjusted
                        {
                            Text(
                                "Original: \(punch.occurredAt.formatted(date: .omitted, time: .shortened))"
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .orange
                            )

                            if let reason =
                                punch
                                    .adjustmentReason
                            {
                                Text(
                                    "Reason: \(reason)"
                                )
                                .font(
                                    .caption2
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }

                    Spacer()

                    if editable {
                        Button(
                            "Adjust"
                        ) {
                            selectedPunch =
                                punch
                        }
                        .buttonStyle(
                            .bordered
                        )
                    }
                }
            }

            if !employee.shiftEvents.isEmpty {
                Divider()

                Text("Rest Break Activity")
                    .font(.subheadline.bold())

                ForEach(employee.shiftEvents) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(shiftEventName(event.type))
                            Text(
                                event.occurredAt.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let note = event.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if event.type.isNotTaken {
                            Label(
                                "Not Taken",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        } header: {
            Text(
                "\(employee.employeeID) • \(String(format: "%.2f", employee.totalHours)) total hours"
            )
        }
    }

    private func shiftEventName(_ type: ShiftEventType) -> String {
        switch type {
        case .restBreak1Started: return "Rest Break 1 Started"
        case .restBreak1Ended: return "Rest Break 1 Ended"
        case .restBreak1NotTaken: return "Rest Break 1 Not Taken"
        case .restBreak2Started: return "Rest Break 2 Started"
        case .restBreak2Ended: return "Rest Break 2 Ended"
        case .restBreak2NotTaken: return "Rest Break 2 Not Taken"
        }
    }

    private func signatureSection(
        _ sheet:
            DepartmentTimesheet
    ) -> some View {
        Section(
            "Supervisor Approval"
        ) {
            if sheet
                .hasUnresolvedExceptions
            {
                Label(
                    "Fix all punch exceptions before approval.",
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(
                    .orange
                )
            }

            TextField(
                "Supervisor printed name",
                text:
                    $supervisorName
            )

            VStack(
                alignment:
                    .leading,
                spacing: 8
            ) {
                Text(
                    "Digital Signature"
                )
                .font(
                    .subheadline
                    .bold()
                )

                SignatureCanvasView(
                    drawing:
                        $signature
                )
                .frame(height: 150)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            10
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius:
                            10
                    )
                    .stroke(
                        .secondary
                            .opacity(0.4)
                    )
                }

                Button(
                    "Clear Signature"
                ) {
                    signature =
                        PKDrawing()
                }
                .font(.caption)
            }

            Button {
                showApprovalAlert =
                    true
            } label: {
                Label(
                    "Approve, Date & Digitally Sign",
                    systemImage:
                        "signature"
                )
                .frame(
                    maxWidth:
                        .infinity
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .disabled(
                sheet
                    .hasUnresolvedExceptions
                ||
                supervisorName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
                ||
                signature.bounds
                    .isEmpty
            )

            Text(
                "The backend records the authoritative approval date, stores the signature privately, and hashes the approved timesheet snapshot."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func approve() {
        guard let png =
            SignatureRenderer
                .pngData(
                    from:
                        signature
                )
        else {
            viewModel
                .errorMessage =
                "Please provide a signature."
            return
        }

        Task {
            let success =
                await viewModel
                    .approve(
                        supervisorName:
                            supervisorName,
                        signaturePNG:
                            png
                    )

            if success {
                signature =
                    PKDrawing()
            }
        }
    }
}
