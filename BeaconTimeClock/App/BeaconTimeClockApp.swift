import SwiftUI
import SwiftData
import UIKit

@main
struct BeaconTimeClockApp: App {
    private let modelContainer: ModelContainer

    @StateObject private var authManager: AuthManager
    @StateObject private var services: AppServices
    @StateObject private var timeCardStore: TimeCardStore
    @StateObject private var beaconManager = BeaconManager()
    @StateObject private var lunchTimer = LunchTimerManager()

    init() {
        /// These launch arguments mirror the pattern used in the LoginKit
        /// XCUITest exercises from class.
        if ProcessInfo.processInfo.arguments.contains("-UITesting-Reset") {
            UserDefaults.standard.removeObject(
                forKey: "BeaconTimeClock.demoSessionEmail"
            )
        }

        if ProcessInfo.processInfo.arguments.contains("-UITesting-NoAnimations") {
            UIView.setAnimationsEnabled(false)
        }

        do {
            let container = try ModelContainer(
                for: TimeCard.self
            )
            modelContainer = container

            let supabase = SupabaseClientProvider.make()
            let auth = AuthManager(supabase: supabase)
            let api = APIClientFactory.make(auth: auth)

            _authManager = StateObject(
                wrappedValue: auth
            )

            _services = StateObject(
                wrappedValue: AppServices(
                    auth: auth,
                    api: api,
                    supabase: supabase
                )
            )

            _timeCardStore = StateObject(
                wrappedValue: TimeCardStore(
                    context: container.mainContext
                )
            )
        } catch {
            fatalError(
                "Unable to create SwiftData container: \(error)"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(services)
                .environmentObject(timeCardStore)
                .environmentObject(beaconManager)
                .environmentObject(lunchTimer)
                .modelContainer(modelContainer)
        }
    }
}
