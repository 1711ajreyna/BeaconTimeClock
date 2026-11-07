// FILE PURPOSE: Keeps a local rest-break countdown and status.
import Foundation

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class BreakTimerManager: ObservableObject {
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var activeSlot: RestBreakSlot?
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var secondsRemaining = 0

    private var timer: Timer?
    private var endDate: Date?

    var isRunning: Bool {
        activeSlot != nil && secondsRemaining > 0
    }

    func start(
        slot: RestBreakSlot,
        minutes: Int = AppConfig.restBreakDurationMinutes
    ) {
        stop()

        activeSlot = slot
        endDate = Date().addingTimeInterval(
            TimeInterval(minutes * 60)
        )
        tick()

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        activeSlot = nil
        secondsRemaining = 0
    }

    func formatted() -> String {
        String(
            format: "%02d:%02d",
            secondsRemaining / 60,
            secondsRemaining % 60
        )
    }

    private func tick() {
        guard let endDate else {
            secondsRemaining = 0
            return
        }

        secondsRemaining = Int(
            max(0, endDate.timeIntervalSinceNow.rounded(.up))
        )

        if secondsRemaining == 0 {
            timer?.invalidate()
            timer = nil
        }
    }
}
