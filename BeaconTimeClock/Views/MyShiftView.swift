import SwiftUI

struct MyShiftView: View {
    @StateObject
    private var viewModel:
        MyShiftViewModel

    @State
    private var breakPendingDenial:
        RestBreakSlot?

    init(
        viewModel:
            MyShiftViewModel
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
                    scheduleSection(
                        response
                    )

                    complianceSection(
                        response
                    )

                    overtimeSection(
                        response
                    )

                    restBreakSection(
                        slot: .first,
                        response:
                            response
                    )

                    restBreakSection(
                        slot: .second,
                        response:
                            response
                    )

                    warningSection
                }

                if viewModel.isLoading {
                    ProgressView(
                        "Loading today's shift…"
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
                    .statusMessage
                    .isEmpty
                {
                    Text(
                        viewModel
                            .statusMessage
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .navigationTitle(
                "My Shift"
            )
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .alert(
                "Deny Scheduled Rest Break?",
                isPresented:
                    Binding(
                        get: {
                            breakPendingDenial != nil
                        },
                        set: {
                            if !$0 {
                                breakPendingDenial = nil
                            }
                        }
                    )
            ) {
                Button(
                    "Cancel",
                    role: .cancel
                ) {
                    breakPendingDenial = nil
                }

                Button(
                    "Deny / Did Not Take",
                    role: .destructive
                ) {
                    guard let slot =
                        breakPendingDenial
                    else {
                        return
                    }

                    breakPendingDenial = nil

                    Task {
                        await viewModel
                            .markBreakNotTaken(
                                slot
                            )
                    }
                }
            } message: {
                Text(
                    "This records that the offered paid rest break was not taken. Face ID or Touch ID is required, and the event is flagged for supervisor review. It is not treated as a waiver of workplace rights."
                )
            }
        }
    }

    private func scheduleSection(
        _ response:
            MyShiftResponse
    ) -> some View {
        Section(
            "Today's Schedule"
        ) {
            scheduleRow(
                title:
                    "Shift Start",
                date:
                    response
                        .schedule
                        .shiftStart,
                systemImage:
                    "sunrise.fill"
            )

            scheduleRow(
                title:
                    "Rest Break 1",
                date:
                    response
                        .schedule
                        .break1Start,
                systemImage:
                    "cup.and.saucer.fill"
            )

            scheduleRow(
                title:
                    "Lunch",
                date:
                    response
                        .schedule
                        .lunchStart,
                systemImage:
                    "fork.knife"
            )

            scheduleRow(
                title:
                    "Rest Break 2",
                date:
                    response
                        .schedule
                        .break2Start,
                systemImage:
                    "cup.and.saucer.fill"
            )

            scheduleRow(
                title:
                    "Clock Out",
                date:
                    response
                        .schedule
                        .shiftEnd,
                systemImage:
                    "sunset.fill"
            )
        }
    }

    private func complianceSection(
        _ response:
            MyShiftResponse
    ) -> some View {
        let recommendation =
            response
                .schedule
                .legalDefaultRecommendation

        return Section(
            "Rest-Break Timing"
        ) {
            LabeledContent(
                "Recommended Break 1 midpoint",
                value:
                    recommendation
                        .break1Start
                        .formatted(
                            date:
                                .omitted,
                            time:
                                .shortened
                        )
            )

            LabeledContent(
                "Recommended Break 2 midpoint",
                value:
                    recommendation
                        .break2Start
                        .formatted(
                            date:
                                .omitted,
                            time:
                                .shortened
                        )
            )

            Text(
                "The app defaults paid rest breaks near the middle of each work period. A supervisor may stagger an individual employee's break when operationally necessary, but the backend keeps Break 1 in the first work period and Break 2 in the second."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func overtimeSection(
        _ response:
            MyShiftResponse
    ) -> some View {
        Section(
            "Overtime Forecast"
        ) {
            LabeledContent(
                "Worked this week",
                value:
                    String(
                        format:
                            "%.2f hrs",
                        response
                            .weeklyHoursWorked
                    )
            )

            LabeledContent(
                "Projected total",
                value:
                    String(
                        format:
                            "%.2f hrs",
                        response
                            .projectedWeeklyHours
                    )
            )

            HStack {
                Text(
                    "Projected OT"
                )

                Spacer()

                Text(
                    String(
                        format:
                            "%.2f hrs",
                        response
                            .projectedOvertimeHours
                    )
                )
                .fontWeight(
                    .bold
                )
                .foregroundStyle(
                    response
                        .projectedOvertimeHours
                        > 0
                    ? .red
                    : .green
                )
            }
        }
    }

    private func restBreakSection(
        slot:
            RestBreakSlot,
        response:
            MyShiftResponse
    ) -> some View {
        let state =
            viewModel.state(
                for: slot
            )

        let scheduled =
            response
                .schedule
                .scheduledStart(
                    for: slot
                )

        let scheduledEnd =
            response
                .schedule
                .scheduledEnd(
                    for: slot
                )

        return Section(
            slot.displayName
        ) {
            LabeledContent(
                "Scheduled",
                value:
                    "\(scheduled.formatted(date: .omitted, time: .shortened)) – \(scheduledEnd.formatted(date: .omitted, time: .shortened))"
            )

            LabeledContent(
                "Duration",
                value:
                    "\(response.schedule.restBreakDurationMinutes) min paid"
            )

            if viewModel
                .breakTimer
                .activeSlot
                == slot,
               viewModel
                .breakTimer
                .isRunning
            {
                HStack {
                    Text(
                        "Break timer"
                    )

                    Spacer()

                    Text(
                        viewModel
                            .breakTimer
                            .formatted()
                    )
                    .font(
                        .title3
                        .monospacedDigit()
                        .bold()
                    )
                }
            }

            switch state {
            case .available:
                Button(
                    "Accept & Start \(slot.displayName)"
                ) {
                    Task {
                        await viewModel
                            .startBreak(
                                slot
                            )
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )
                .accessibilityIdentifier(
                    "accept_break_\(slot.rawValue)_button"
                )
                .disabled(
                    !viewModel
                        .canRespondToBreak(
                            slot
                        )
                )

                Button(
                    "Deny / Did Not Take \(slot.displayName)",
                    role:
                        .destructive
                ) {
                    breakPendingDenial =
                        slot
                }
                .accessibilityIdentifier(
                    "deny_break_\(slot.rawValue)_button"
                )
                .disabled(
                    !viewModel
                        .canRespondToBreak(
                            slot
                        )
                )

                if !viewModel
                    .canRespondToBreak(
                        slot
                    )
                {
                    Text(
                        "Break controls open with the 2-minute warning before the scheduled start."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Text(
                    "Accepting starts the paid 10-minute timer. Denying requires biometric confirmation and creates a supervisor-visible exception; it does not reduce paid hours or act as a legal waiver."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            case .inProgress:
                Button(
                    viewModel
                        .breakTimer
                        .isRunning
                    ? "Paid Break In Progress"
                    : "Complete \(slot.displayName)"
                ) {
                    Task {
                        await viewModel
                            .endBreak(
                                slot
                            )
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(
                    !AppConfig.demoMode &&
                    viewModel
                        .breakTimer
                        .activeSlot ==
                        slot &&
                    viewModel
                        .breakTimer
                        .isRunning
                )

                if !AppConfig.demoMode,
                   viewModel
                    .breakTimer
                    .activeSlot ==
                    slot,
                   viewModel
                    .breakTimer
                    .isRunning
                {
                    Text(
                        "The break cannot be completed before the full paid 10-minute period has elapsed."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

            case .completed:
                Label(
                    "Accepted & Completed",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .foregroundStyle(
                    .green
                )

            case .notTaken:
                Label(
                    "Denied / Not Taken — Supervisor Review",
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(
                    .orange
                )
            }
        }
    }

    private var warningSection:
        some View
    {
        Section(
            "Automatic Warnings"
        ) {
            Label(
                "2 minutes before Rest Break 1 begins",
                systemImage:
                    "bell.fill"
            )

            Label(
                "2 minutes before an active rest break ends",
                systemImage:
                    "timer"
            )

            Label(
                "5 minutes before Lunch",
                systemImage:
                    "bell.fill"
            )

            Label(
                "2 minutes before Rest Break 2 begins",
                systemImage:
                    "bell.fill"
            )

            Label(
                "5 minutes before Clock Out",
                systemImage:
                    "bell.fill"
            )

            Text(
                "Warnings are scheduled locally after the shift is downloaded, so they can still fire if network connectivity is temporarily lost."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    private func scheduleRow(
        title: String,
        date: Date,
        systemImage: String
    ) -> some View {
        HStack {
            Label(
                title,
                systemImage:
                    systemImage
            )

            Spacer()

            Text(
                date.formatted(
                    date:
                        .omitted,
                    time:
                        .shortened
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }
}
