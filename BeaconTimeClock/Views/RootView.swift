// FILE PURPOSE: Authentication gate: routes signed-out users to login and others into the app.
import SwiftUI

/// Authentication gate for the entire application.
// This type groups related state and behavior under a clear responsibility.
struct RootView: View {
    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var auth: AuthManager
    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var services: AppServices

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        Group {
            switch auth.state {
            case .checking:
                ProgressView("Restoring secure session…")

            case .signedOut:
                LoginView()

            case .signedIn:
                if let profile = services.profile {
                    AuthenticatedRootView(
                        profile: profile
                    )
                } else if !services.profileError.isEmpty {
                    ContentUnavailableView(
                        "Unable to Load Profile",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(services.profileError)
                    )
                } else {
                    ProgressView("Loading company profile…")
                        // Start asynchronous work when SwiftUI presents this view; handle loading and errors.
                        .task {
                            await services.loadProfile()
                        }
                }
            }
        }
        // Start asynchronous work when SwiftUI presents this view; handle loading and errors.
        .task {
            await auth.bootstrap()
            if auth.state == .signedIn {
                await services.loadProfile()
            }
        }
        .onChange(of: auth.state) { _, newState in
            Task {
                if newState == .signedIn {
                    await services.loadProfile()
                } else {
                    services.clearProfile()
                }
            }
        }
    }
}
