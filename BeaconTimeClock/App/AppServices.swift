import Foundation
import Supabase

@MainActor
final class AppServices: ObservableObject {
    let auth: AuthManager
    let api: WorkflowAPI
    let supabase: SupabaseClient?
    let notificationScheduler: NotificationScheduler

    @Published private(set) var profile: UserProfile?
    @Published var profileError = ""

    
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

    func clearProfile() {
        profile = nil
    }
}
