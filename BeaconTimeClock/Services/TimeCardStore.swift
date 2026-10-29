import Foundation
import SwiftData

/// Local SwiftData repository for the employee's own recently submitted punches.
@MainActor
final class TimeCardStore: ObservableObject {

    @Published private(set)
    var timeCards: [TimeCard] = []

    private let context: ModelContext

    init(
        context: ModelContext
    ) {
        self.context = context
        refresh()
    }

    var latestPunch: TimeCard? {
        timeCards.first
    }

    func add(
        _ card: TimeCard
    ) throws {
        context.insert(card)
        try context.save()
        refresh()
    }

    func markSynced(
        card: TimeCard,
        remoteID: UUID,
        serverTimestamp: Date
    ) throws {
        card.remoteID = remoteID
        card.timestamp = serverTimestamp
        card.syncStatus = "synced"

        try context.save()
        refresh()
    }

    func markFailed(
        card: TimeCard
    ) throws {
        card.syncStatus = "failed"
        try context.save()
        refresh()
    }

    func clearAll() throws {
        for card in timeCards {
            context.delete(card)
        }

        try context.save()
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<TimeCard>(
            sortBy: [
                SortDescriptor(
                    \TimeCard.timestamp,
                    order: .reverse
                )
            ]
        )

        do {
            timeCards = try context.fetch(descriptor)
        } catch {
            timeCards = []
            print(
                "TimeCard fetch failed:",
                error.localizedDescription
            )
        }
    }
}
