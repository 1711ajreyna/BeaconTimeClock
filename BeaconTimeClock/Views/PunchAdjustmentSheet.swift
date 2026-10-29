import SwiftUI

/// Manual override editor for an incorrect clock-in/out/lunch punch.
///
/// A reason is mandatory. The backend records an audit entry rather than
/// overwriting the original time.
struct PunchAdjustmentSheet: View {

    let punch: PunchRecord
    let onSave: (Date, String) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var correctedDate: Date

    @State
    private var reason = ""

    init(
        punch: PunchRecord,
        onSave:
            @escaping
            (Date, String) -> Void
    ) {
        self.punch = punch
        self.onSave = onSave

        _correctedDate =
            State(
                initialValue:
                    punch
                        .effectiveOccurredAt
            )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    "Original Punch"
                ) {
                    LabeledContent(
                        "Type",
                        value:
                            punch
                                .type
                                .displayName
                    )

                    LabeledContent(
                        "Original"
                    ) {
                        Text(
                            punch
                                .occurredAt
                                .formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                        )
                    }
                }

                Section(
                    "Corrected Time"
                ) {
                    DatePicker(
                        "Corrected",
                        selection:
                            $correctedDate
                    )

                    TextField(
                        "Required reason",
                        text: $reason,
                        axis: .vertical
                    )
                }

                Section {
                    Text(
                        "The original punch is preserved. The correction is stored as a separate supervisor audit record."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .navigationTitle(
                "Adjust Punch"
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
                            correctedDate,
                            reason
                        )
                        dismiss()
                    }
                    .disabled(
                        reason
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
        }
    }
}
