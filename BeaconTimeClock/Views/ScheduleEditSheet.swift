import SwiftUI

/// Individual employee rest-break editor.
///
/// California's manufacturing rest-break rule uses "insofar as practicable"
/// rather than an exact mandatory clock time. The UI therefore:
///
/// 1. shows the midpoint recommendation,
/// 2. lets the supervisor stagger one employee's breaks,
/// 3. requires a reason when moving away from the recommendation,
/// 4. refuses schedules that place the first break outside the first work
///    period or the second break outside the second work period.
struct ScheduleEditSheet: View {
    let row:
        SupervisorScheduleRow

    let onSave:
        (
            Date,
            Date,
            String?,
            String?
        ) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var break1Start: Date

    @State
    private var break2Start: Date

    @State
    private var break1Reason: String

    @State
    private var break2Reason: String

    init(
        row:
            SupervisorScheduleRow,
        onSave:
            @escaping
            (
                Date,
                Date,
                String?,
                String?
            ) -> Void
    ) {
        self.row = row
        self.onSave = onSave

        _break1Start =
            State(
                initialValue:
                    row.break1Start
            )

        _break2Start =
            State(
                initialValue:
                    row.break2Start
            )

        _break1Reason =
            State(
                initialValue:
                    row.break1AdjustmentReason ??
                    ""
            )

        _break2Reason =
            State(
                initialValue:
                    row.break2AdjustmentReason ??
                    ""
            )
    }

    var body: some View {
        NavigationStack {
            Form {
                employeeSection
                legalTimingSection
                break1Section
                break2Section
                auditSection
            }
            .navigationTitle(
                "Edit Employee Breaks"
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button(
                        "Cancel"
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {
                    Button(
                        "Save"
                    ) {
                        onSave(
                            break1Start,
                            break2Start,
                            cleaned(
                                break1Reason
                            ),
                            cleaned(
                                break2Reason
                            )
                        )
                    }
                    .disabled(
                        !isValid
                    )
                }
            }
        }
    }

    private var employeeSection:
        some View
    {
        Section(
            "Employee"
        ) {
            Text(
                row.employeeName
            )

            Text(
                row.employeeNumber
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                row.department
                    .displayName
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var legalTimingSection:
        some View
    {
        Section(
            "Shift / Meal"
        ) {
            LabeledContent(
                "Shift",
                value:
                    "\(format(row.shiftStart)) – \(format(row.shiftEnd))"
            )

            LabeledContent(
                "Lunch",
                value:
                    "\(format(row.lunchStart)) – \(format(lunchEnd))"
            )

            LabeledContent(
                "Paid rest-break duration",
                value:
                    "\(row.restBreakDurationMinutes) min"
            )

            Text(
                "The default recommendation places each paid rest break near the midpoint of its work period. Supervisors may stagger an individual employee when operations require it, but the break must remain inside that employee's applicable work period."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var break1Section:
        some View
    {
        Section(
            "Rest Break 1"
        ) {
            LabeledContent(
                "Recommended midpoint",
                value:
                    format(
                        row
                            .recommendedBreaks
                            .break1Start
                    )
            )

            DatePicker(
                "Employee break time",
                selection:
                    $break1Start,
                displayedComponents:
                    .hourAndMinute
            )

            if break1Adjusted {
                TextField(
                    "Reason for changing this employee's Break 1",
                    text:
                        $break1Reason,
                    axis:
                        .vertical
                )

                Label(
                    "Adjustment reason is required for the audit trail.",
                    systemImage:
                        "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    .orange
                )
            }
        }
    }

    private var break2Section:
        some View
    {
        Section(
            "Rest Break 2"
        ) {
            LabeledContent(
                "Recommended midpoint",
                value:
                    format(
                        row
                            .recommendedBreaks
                            .break2Start
                    )
            )

            DatePicker(
                "Employee break time",
                selection:
                    $break2Start,
                displayedComponents:
                    .hourAndMinute
            )

            if break2Adjusted {
                TextField(
                    "Reason for changing this employee's Break 2",
                    text:
                        $break2Reason,
                    axis:
                        .vertical
                )

                Label(
                    "Adjustment reason is required for the audit trail.",
                    systemImage:
                        "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    .orange
                )
            }
        }
    }

    private var auditSection:
        some View
    {
        Section {
            if let validationError {
                Label(
                    validationError,
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(
                    .red
                )
            } else {
                Label(
                    "Breaks remain inside their applicable work periods.",
                    systemImage:
                        "checkmark.shield.fill"
                )
                .foregroundStyle(
                    .green
                )
            }

            Text(
                "Lunch is intentionally read-only in this employee-level editor. A separate HR/admin policy workflow should control meal-period changes."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private var lunchEnd:
        Date
    {
        row.lunchStart
            .addingTimeInterval(
                TimeInterval(
                    row
                        .lunchDurationMinutes
                        * 60
                )
            )
    }

    private var break1Adjusted:
        Bool
    {
        CaliforniaRestBreakPolicy
            .isAdjusted(
                actual:
                    break1Start,
                recommended:
                    row
                        .recommendedBreaks
                        .break1Start
            )
    }

    private var break2Adjusted:
        Bool
    {
        CaliforniaRestBreakPolicy
            .isAdjusted(
                actual:
                    break2Start,
                recommended:
                    row
                        .recommendedBreaks
                        .break2Start
            )
    }

    private var validationError:
        String?
    {
        do {
            try CaliforniaRestBreakPolicy
                .validate(
                    shiftStart:
                        row.shiftStart,
                    break1Start:
                        break1Start,
                    lunchStart:
                        row.lunchStart,
                    lunchDurationMinutes:
                        row
                            .lunchDurationMinutes,
                    break2Start:
                        break2Start,
                    shiftEnd:
                        row.shiftEnd,
                    restBreakDurationMinutes:
                        row
                            .restBreakDurationMinutes
                )

            if break1Adjusted &&
                cleaned(
                    break1Reason
                ) == nil
            {
                return "Enter a reason for changing Rest Break 1."
            }

            if break2Adjusted &&
                cleaned(
                    break2Reason
                ) == nil
            {
                return "Enter a reason for changing Rest Break 2."
            }

            return nil

        } catch {
            return error
                .localizedDescription
        }
    }

    private var isValid:
        Bool
    {
        validationError == nil
    }

    private func cleaned(
        _ value: String
    ) -> String? {
        let result =
            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return result.isEmpty
            ? nil
            : result
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
