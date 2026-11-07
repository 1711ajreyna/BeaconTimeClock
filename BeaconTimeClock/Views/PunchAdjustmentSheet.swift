// FILE PURPOSE: Edit a punch timestamp and supply a mandatory audit reason.
import SwiftUI

/// Manual override editor for an incorrect clock-in/out/lunch punch.
///
/// A reason is mandatory. The backend records an audit entry rather than
/// overwriting the original time.
// This type groups related state and behavior under a clear responsibility.
struct PunchAdjustmentSheet: View {

    let punch: PunchRecord
    let onSave: (Date, String) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var correctedDate: Date

    @State
    private var reason = ""

    // Create this object with the dependencies or state it needs; avoid hidden global services.
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

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
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
