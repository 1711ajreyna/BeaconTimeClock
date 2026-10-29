import SwiftUI

/// Authentication gate for the entire application.
struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var services: AppServices

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
                        .task {
                            await services.loadProfile()
                        }
                }
            }
        }
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
