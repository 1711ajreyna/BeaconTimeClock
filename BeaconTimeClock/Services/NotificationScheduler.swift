import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    private let center =
        UNUserNotificationCenter.current()

    func requestPermission() async {
        do {
            _ = try await center
                .requestAuthorization(
                    options: [
                        .alert,
                        .sound,
                        .badge
                    ]
                )
        } catch {
            print(
                "Notification permission error: \(error.localizedDescription)"
            )
        }
    }

    func scheduleShiftWarnings(
        for schedule: ShiftSchedule
    ) async {
        await cancelShiftWarnings()

        let plan =
            ShiftNotificationPlan.make(
                schedule: schedule
            )

        await self.schedule(
            identifier:
                "shift-\(schedule.id)-break1-start-warning",
            title:
                "Rest Break 1 in 2 minutes",
            body:
                "Your paid 10-minute Rest Break 1 is scheduled for \(schedule.break1Start.formatted(date: .omitted, time: .shortened)).",
            date:
                plan.break1StartWarning
        )

        await self.schedule(
            identifier:
                "shift-\(schedule.id)-lunch-warning",
            title:
                "Lunch in 5 minutes",
            body:
                "Lunch is scheduled for \(schedule.lunchStart.formatted(date: .omitted, time: .shortened)).",
            date:
                plan.lunchWarning
        )

        await self.schedule(
            identifier:
                "shift-\(schedule.id)-break2-start-warning",
            title:
                "Rest Break 2 in 2 minutes",
            body:
                "Your paid 10-minute Rest Break 2 is scheduled for \(schedule.break2Start.formatted(date: .omitted, time: .shortened)).",
            date:
                plan.break2StartWarning
        )

        await self.schedule(
            identifier:
                "shift-\(schedule.id)-clockout-warning",
            title:
                "Shift ends in 5 minutes",
            body:
                "Remember to clock out at \(schedule.shiftEnd.formatted(date: .omitted, time: .shortened)).",
            date:
                plan.clockOutWarning
        )
    }

    func scheduleBreakCountdown(
        slot: RestBreakSlot,
        minutes: Int
    ) async {
        cancelBreakCountdown(
            slot: slot
        )

        let warningMinutes =
            AppConfig
                .restBreakEndWarningMinutes

        let warningDelay =
            minutes - warningMinutes

        if warningDelay > 0 {
            await scheduleInterval(
                identifier:
                    breakEndWarningIdentifier(
                        slot
                    ),
                title:
                    "\(slot.displayName): 2 minutes remaining",
                body:
                    "Your paid rest break ends in 2 minutes.",
                seconds:
                    TimeInterval(
                        warningDelay * 60
                    )
            )
        }

        await scheduleInterval(
            identifier:
                breakEndIdentifier(
                    slot
                ),
            title:
                "\(slot.displayName) complete",
            body:
                "Your scheduled \(minutes)-minute paid rest break has ended.",
            seconds:
                TimeInterval(
                    minutes * 60
                )
        )
    }

    func cancelBreakCountdown(
        slot: RestBreakSlot
    ) {
        center
            .removePendingNotificationRequests(
                withIdentifiers: [
                    breakEndWarningIdentifier(
                        slot
                    ),
                    breakEndIdentifier(
                        slot
                    )
                ]
            )
    }

    func cancelShiftWarnings() async {
        let pending =
            await center
                .pendingNotificationRequests()

        let ids =
            pending
                .map(\.identifier)
                .filter {
                    $0.hasPrefix("shift-") &&
                    $0.contains("-warning")
                }

        center
            .removePendingNotificationRequests(
                withIdentifiers:
                    ids
            )
    }

    private func breakEndWarningIdentifier(
        _ slot: RestBreakSlot
    ) -> String {
        "active-rest-break-\(slot.rawValue)-two-minute-warning"
    }

    private func breakEndIdentifier(
        _ slot: RestBreakSlot
    ) -> String {
        "active-rest-break-\(slot.rawValue)-end"
    }

    private func schedule(
        identifier: String,
        title: String,
        body: String,
        date: Date
    ) async {
        guard date > Date() else {
            return
        }

        let content =
            UNMutableNotificationContent()

        content.title = title
        content.body = body
        content.sound = .default

        let components =
            Calendar.current
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .hour,
                        .minute
                    ],
                    from: date
                )

        let trigger =
            UNCalendarNotificationTrigger(
                dateMatching:
                    components,
                repeats: false
            )

        do {
            try await center.add(
                UNNotificationRequest(
                    identifier:
                        identifier,
                    content:
                        content,
                    trigger:
                        trigger
                )
            )
        } catch {
            print(
                "Unable to schedule warning: \(error.localizedDescription)"
            )
        }
    }

    private func scheduleInterval(
        identifier: String,
        title: String,
        body: String,
        seconds: TimeInterval
    ) async {
        guard seconds > 0 else {
            return
        }

        let content =
            UNMutableNotificationContent()

        content.title = title
        content.body = body
        content.sound = .default

        let trigger =
            UNTimeIntervalNotificationTrigger(
                timeInterval:
                    seconds,
                repeats:
                    false
            )

        do {
            try await center.add(
                UNNotificationRequest(
                    identifier:
                        identifier,
                    content:
                        content,
                    trigger:
                        trigger
                )
            )
        } catch {
            print(
                "Unable to schedule break countdown notification: \(error.localizedDescription)"
            )
        }
    }
}
