import SwiftUI

struct SupervisorScheduleView: View {
    @StateObject
    private var viewModel:
        SupervisorScheduleViewModel

    @State
    private var editingRow:
        SupervisorScheduleRow?

    init(
        viewModel:
            SupervisorScheduleViewModel
    ) {
        _viewModel =
            StateObject(
                wrappedValue:
                    viewModel
            )
    }

    var body: some View {
        NavigationStack {
            List {
                if let response =
                    viewModel.response
                {
                    Section(
                        "Work Date"
                    ) {
                        Text(
                            response
                                .workDate
                        )
                        .font(
                            .headline
                        )

                        Text(
                            "Choose one employee below to stagger only that employee's two paid rest breaks."
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    ForEach(
                        response.rows
                    ) { row in
                        employeeSection(
                            row
                        )
                    }
                }

                if viewModel.isLoading {
                    ProgressView(
                        "Loading schedules…"
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
                "Shift Schedules"
            )
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .sheet(
                item:
                    $editingRow
            ) { row in
                ScheduleEditSheet(
                    row: row
                ) {
                    break1,
                    break2,
                    break1Reason,
                    break2Reason in

                    Task {
                        let saved =
                            await viewModel
                                .save(
                                    row:
                                        row,
                                    break1Start:
                                        break1,
                                    break2Start:
                                        break2,
                                    break1Reason:
                                        break1Reason,
                                    break2Reason:
                                        break2Reason
                                )

                        if saved {
                            editingRow =
                                nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func employeeSection(
        _ row:
            SupervisorScheduleRow
    ) -> some View {
        Section {
            VStack(
                alignment:
                    .leading,
                spacing: 8
            ) {
                HStack {
                    Text(
                        row.employeeName
                    )
                    .font(
                        .headline
                    )

                    Spacer()

                    Text(
                        row.department
                            .displayName
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                scheduleLine(
                    "Shift",
                    row.shiftStart,
                    row.shiftEnd
                )

                timeLine(
                    "Break 1",
                    row.break1Start,
                    recommended:
                        row
                            .recommendedBreaks
                            .break1Start
                )

                timeLine(
                    "Lunch",
                    row.lunchStart,
                    recommended:
                        nil
                )

                timeLine(
                    "Break 2",
                    row.break2Start,
                    recommended:
                        row
                            .recommendedBreaks
                            .break2Start
                )

                if let reason =
                    row
                        .break1AdjustmentReason
                {
                    Text(
                        "Break 1 adjustment: \(reason)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .orange
                    )
                }

                if let reason =
                    row
                        .break2AdjustmentReason
                {
                    Text(
                        "Break 2 adjustment: \(reason)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .orange
                    )
                }

                Button(
                    "Edit This Employee's Rest Breaks"
                ) {
                    editingRow = row
                }
                .buttonStyle(
                    .bordered
                )
                .accessibilityIdentifier(
                    "edit_breaks_\(row.employeeNumber)_button"
                )
            }
        } header: {
            Text(
                row.employeeNumber
            )
        }
    }

    private func timeLine(
        _ label: String,
        _ date: Date,
        recommended:
            Date?
    ) -> some View {
        HStack {
            Text(label)

            Spacer()

            VStack(
                alignment:
                    .trailing,
                spacing: 2
            ) {
                Text(
                    format(date)
                )

                if let recommended,
                   CaliforniaRestBreakPolicy
                    .isAdjusted(
                        actual:
                            date,
                        recommended:
                            recommended
                    )
                {
                    Text(
                        "Midpoint \(format(recommended))"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .orange
                    )
                }
            }
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func scheduleLine(
        _ label: String,
        _ start: Date,
        _ end: Date
    ) -> some View {
        HStack {
            Text(label)

            Spacer()

            Text(
                "\(format(start)) – \(format(end))"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func format(
        _ date: Date
    ) -> String {
        date.formatted(
            date: .omitted,
            time: .shortened
        )
    }
}
