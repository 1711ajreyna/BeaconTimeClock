// FILE PURPOSE: Tracks and formats a lunch countdown with notification integration.
import Foundation
import UserNotifications

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class LunchTimerManager: ObservableObject {
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var secondsRemaining = 0
    
    private var endDate: Date?
    private var timer: Timer?
    
    var isRunning: Bool {
        secondsRemaining > 0
    }
    
    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func start() {
        endDate = Date().addingTimeInterval(
            TimeInterval(AppConfig.lunchDurationMinutes*60)
        )
        
        tick()
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ){ [weak self] _ in
            Task { @MainActor in self?.tick()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
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
            self.endDate = nil
        }
    }
}
