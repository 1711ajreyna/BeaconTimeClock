// FILE PURPOSE: Handles demo login, real authentication sessions and sign-out.
import Foundation
import Supabase

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class AuthManager: ObservableObject {
    // This type groups related state and behavior under a clear responsibility.
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var state: State = .checking
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var userID: UUID?
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var email: String?
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var errorMessage = ""
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var isWorking = false

    let staffDirectory: DemoStaffDirectory
    private let supabase: SupabaseClient?
    private var authListenerTask: Task<Void, Never>?

    private let demoSessionEmailKey =
        "BeaconTimeClock.demoSessionEmail"

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        supabase: SupabaseClient?,
        staffDirectory: DemoStaffDirectory? = nil
    ) {
        self.supabase = supabase
        self.staffDirectory = staffDirectory ?? DemoStaffDirectory(defaults: .standard)
    }

    deinit {
        authListenerTask?.cancel()
    }

    // Restore a saved session or determine whether login is required.
    func bootstrap() async {
        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            if let savedEmail = UserDefaults.standard.string(
                forKey: demoSessionEmailKey
            ) {
                applyDemoSession(email: savedEmail)
            } else {
                state = .signedOut
            }
            return
        }

        guard let supabase else {
            errorMessage =
                "Supabase URL/publishable key are not configured."
            state = .signedOut
            return
        }

        authListenerTask?.cancel()
        authListenerTask = Task { [weak self] in
            guard let self else { return }

            for await (_, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.applyProductionSession(session)
                }
            }
        }

        if let current = supabase.auth.currentSession {
            applyProductionSession(current)
            return
        }

        do {
            let restored = try await supabase.auth.session
            applyProductionSession(restored)
        } catch {
            state = .signedOut
        }
    }

    // Authenticate the entered account; demo accounts are only for local testing.
    func signIn(
        email: String,
        password: String
    ) async {
        isWorking = true
        defer { isWorking = false }
        errorMessage = ""

        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            guard password == AppConfig.demoPassword,
                  staffDirectory.profile(email: email) != nil else {
                errorMessage =
                    staffDirectory.loadError?.localizedDescription ?? "Use an active demo staff email and Demo123!."
                return
            }

            UserDefaults.standard.set(
                email.lowercased(),
                forKey: demoSessionEmailKey
            )
            applyDemoSession(email: email)
            return
        }

        guard let supabase else {
            errorMessage = "Supabase is not configured."
            return
        }

        do {
            _ = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            let session = try await supabase.auth.session
            applyProductionSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Clear the session so protected views are no longer displayed.
    func signOut() async {
        isWorking = true
        defer { isWorking = false }

        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            UserDefaults.standard.removeObject(
                forKey: demoSessionEmailKey
            )
            userID = nil
            email = nil
            state = .signedOut
            return
        }

        do {
            try await supabase?.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        userID = nil
        email = nil
        state = .signedOut
    }

    // Obtain a short-lived token for authenticated API calls.
    func accessToken() async -> String? {
        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            return "demo-access-token"
        }

        do {
            return try await supabase?.auth.session.accessToken
        } catch {
            return nil
        }
    }

    var demoProfile: UserProfile? {
        guard AppConfig.demoMode, let email else { return nil }
        return staffDirectory.profile(email: email)
    }

    private func applyDemoSession(email: String) {
        guard let profile = staffDirectory.profile(email: email) else {
            userID = nil
            self.email = nil
            state = .signedOut
            errorMessage = staffDirectory.loadError?.localizedDescription ?? "This demo account is inactive or unavailable."
            return
        }
        userID = profile.id
        self.email = profile.email
        state = .signedIn
    }

    private func applyProductionSession(
        _ session: Session?
    ) {
        guard let session else {
            userID = nil
            email = nil
            state = .signedOut
            return
        }

        userID = session.user.id
        email = session.user.email
        state = .signedIn
    }

}
