import Foundation
import Combine

/// Shared countdown mechanics; separate instances keep lunch and rest breaks independent.
@MainActor
class CountdownTimer: ObservableObject {
    @Published private(set) var secondsRemaining = 0
    private var timer: Timer?
    private var endDate: Date?
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) { self.now = now }
    deinit { timer?.invalidate() }

    var isRunning: Bool { secondsRemaining > 0 }

    func start(minutes: Int) {
        timer?.invalidate()
        endDate = now().addingTimeInterval(TimeInterval(max(0, minutes) * 60))
        tick()
        guard isRunning else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        secondsRemaining = 0
    }

    func formatted() -> String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    func tick() {
        guard let endDate else { secondsRemaining = 0; return }
        secondsRemaining = Int(max(0, endDate.timeIntervalSince(now()).rounded(.up)))
        if secondsRemaining == 0 {
            timer?.invalidate()
            timer = nil
            self.endDate = nil
        }
    }
}

@MainActor
final class LunchTimerManager: CountdownTimer {
    func start() { super.start(minutes: AppConfig.lunchDurationMinutes) }
}

@MainActor
final class BreakTimerManager: CountdownTimer {
    @Published private(set) var activeSlot: RestBreakSlot?

    func start(slot: RestBreakSlot, minutes: Int = AppConfig.restBreakDurationMinutes) {
        stop()
        activeSlot = slot
        super.start(minutes: minutes)
    }

    override func stop() {
        super.stop()
        activeSlot = nil
    }
}
