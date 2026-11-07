// FILE PURPOSE: SwiftData repository that saves, updates and fetches local TimeCard records.
import Foundation
import SwiftData

/// Local SwiftData repository for the employee's own recently submitted punches.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class TimeCardStore: ObservableObject {

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set)
    var timeCards: [TimeCard] = []

    private let context: ModelContext

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        context: ModelContext
    ) {
        self.context = context
        refresh()
    }

    var latestPunch: TimeCard? {
        timeCards.first
    }

    /// Avoid taking the next punch state from another employee's local cache.
    // Find the most recent punch for this employee, not another user's data.
    func latestPunch(for employeeNumber: String) -> TimeCard? {
        timeCards.first { $0.employeeID == employeeNumber }
    }

    /// Demo data reset affects only the signed-in employee.
    // Clear only the selected employee's local demo records.
    func clearDemoPunches(for employeeNumber: String) throws {
        for card in timeCards where card.employeeID == employeeNumber {
            context.delete(card)
        }
        // Persist the SwiftData change; saving can throw and must be handled.
        try context.save()
        refresh()
    }

    // Insert a record into local SwiftData and persist it.
    func add(
        _ card: TimeCard
    ) throws {
        context.insert(card)
        // Persist the SwiftData change; saving can throw and must be handled.
        try context.save()
        refresh()
    }

    // Update local state with a server-issued record ID and timestamp.
    func markSynced(
        card: TimeCard,
        remoteID: UUID,
        serverTimestamp: Date
    ) throws {
        card.remoteID = remoteID
        card.timestamp = serverTimestamp
        card.syncStatus = "synced"

        // Persist the SwiftData change; saving can throw and must be handled.
        try context.save()
        refresh()
    }

    // Retain the failed record for user feedback and possible retry.
    func markFailed(
        card: TimeCard
    ) throws {
        card.syncStatus = "failed"
        // Persist the SwiftData change; saving can throw and must be handled.
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
