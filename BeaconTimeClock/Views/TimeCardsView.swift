import SwiftUI

/// Local employee punch history.
///
/// Production reporting uses backend records, but this screen gives the
/// employee immediate confirmation of recently submitted events.
struct TimeCardsView: View {

    @EnvironmentObject
    private var store:
        TimeCardStore

    @State
    private var showClearError = false

    var body: some View {
        NavigationStack {
            Group {
                if store.timeCards.isEmpty {
                    ContentUnavailableView(
                        "No Punches Yet",
                        systemImage:
                            "clock.badge.xmark",
                        description:
                            Text(
                                "Your local punch history will appear here."
                            )
                    )
                } else {
                    List {
                        ForEach(
                            store.timeCards,
                            id: \.id
                        ) { card in
                            VStack(
                                alignment:
                                    .leading,
                                spacing: 5
                            ) {
                                HStack {
                                    Label(
                                        card.type
                                            .displayName,
                                        systemImage:
                                            card.type
                                                .systemImage
                                    )

                                    Spacer()

                                    Text(
                                        card.timestamp,
                                        format:
                                            .dateTime
                                            .weekday()
                                            .hour()
                                            .minute()
                                    )
                                }

                                HStack {
                                    Text(
                                        "RSSI \(card.rssi)"
                                    )

                                    Spacer()

                                    Text(
                                        card.syncStatus
                                            .capitalized
                                    )
                                }
                                .font(.caption)
                                .foregroundStyle(
                                    card.syncStatus ==
                                        "synced"
                                    ? .green
                                    : .secondary
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Time")
            .toolbar {
                if AppConfig.demoMode &&
                    !store.timeCards.isEmpty
                {
                    Button(
                        "Clear Demo"
                    ) {
                        do {
                            try store
                                .clearAll()
                        } catch {
                            showClearError =
                                true
                        }
                    }
                }
            }
            .alert(
                "Unable to Clear",
                isPresented:
                    $showClearError
            ) {
                Button(
                    "OK",
                    role: .cancel
                ) {}
            }
        }
    }
}
