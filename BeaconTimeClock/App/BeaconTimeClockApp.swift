// FILE PURPOSE: SwiftUI app entry point: builds local persistence and injects shared service objects.
import SwiftUI
import SwiftData
import UIKit

@main
// This type groups related state and behavior under a clear responsibility.
struct BeaconTimeClockApp: App {
    @AppStorage(AppLocalization.storageKey) private var languageCode = AppLanguage.english.rawValue
    private let modelContainer: ModelContainer

    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var authManager: AuthManager
    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var services: AppServices
    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var timeCardStore: TimeCardStore
    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var beaconManager = BeaconManager()
    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var lunchTimer = LunchTimerManager()

    // Create this object with the dependencies or state it needs; avoid hidden global services.
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

            // Create the SDK client once and pass it into other services.
            let supabase = SupabaseClientProvider.make()
            // Use one authentication manager across the app to avoid diverging login state.
            let auth = AuthManager(supabase: supabase)
            // Select the real or demo API behind a shared interface.
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
        // Each launched app window starts with this root view and injected dependencies.
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: languageCode))
                .tint(CSCTheme.blue)
                .environmentObject(authManager)
                .environmentObject(services)
                .environmentObject(timeCardStore)
                .environmentObject(beaconManager)
                .environmentObject(lunchTimer)
                .modelContainer(modelContainer)
        }
    }
}
