import Foundation

@MainActor
enum APIClientFactory {
    static func make(
        auth: AuthManager
    ) -> WorkflowAPI {
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
