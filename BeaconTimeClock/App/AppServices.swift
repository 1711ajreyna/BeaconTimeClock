// FILE PURPOSE: Application dependency container: holds authentication, workflow API, Supabase access and notifications.
import Foundation
import Supabase

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class AppServices: ObservableObject {
    let auth: AuthManager
    let api: WorkflowAPI
    let supabase: SupabaseClient?
    let notificationScheduler: NotificationScheduler

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var profile: UserProfile?
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var profileError = ""

    
    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        auth: AuthManager,
        api: WorkflowAPI,
        supabase: SupabaseClient?,
        notificationScheduler: NotificationScheduler? = nil
    ) {
        self.auth = auth
        self.api = api
        self.supabase = supabase
        self.notificationScheduler =
            notificationScheduler ?? NotificationScheduler()
    }


    // Load company role and department permissions after authentication.
    func loadProfile() async {
        guard auth.state == .signedIn else {
            profile = nil
            return
        }

        do {
            profile = try await api.fetchMyProfile()
            profileError = ""
        } catch {
            profile = nil
            profileError = error.localizedDescription
        }
    }

    // Discard profile data after sign-out or session changes.
    func clearProfile() {
        profile = nil
    }
}
