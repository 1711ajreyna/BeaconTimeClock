// FILE PURPOSE: Chooses demo or production API client without requiring Views to know the mode.
import Foundation

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
enum APIClientFactory {
    static func make(
        auth: AuthManager
    ) -> WorkflowAPI {
        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            return DemoAPIClient(
                profileProvider: {
                    auth.demoProfile
                }
            )
        }

        return ProductionAPIClient(
            tokenProvider: {
                await auth.accessToken()
            }
        )
    }
}
