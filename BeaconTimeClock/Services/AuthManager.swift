import Foundation
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var userID: UUID?
    @Published private(set) var email: String?
    @Published var errorMessage = ""
    @Published var isWorking = false

    private let supabase: SupabaseClient?
    private var authListenerTask: Task<Void, Never>?

    private let demoSessionEmailKey =
        "BeaconTimeClock.demoSessionEmail"

    init(
        supabase: SupabaseClient?
    ) {
        self.supabase = supabase
    }

    deinit {
        authListenerTask?.cancel()
    }

    func bootstrap() async {
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

    func signIn(
        email: String,
        password: String
    ) async {
        isWorking = true
        defer { isWorking = false }
        errorMessage = ""

        if AppConfig.demoMode {
            guard password == AppConfig.demoPassword,
                  Self.demoRole(for: email) != nil else {
                errorMessage =
                    "Use one of the documented demo accounts and Demo123!."
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

    func signOut() async {
        isWorking = true
        defer { isWorking = false }

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

    func accessToken() async -> String? {
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
        guard AppConfig.demoMode,
              let email,
              let role = Self.demoRole(for: email) else {
            return nil
        }

        return UserProfile(
            id: userID ?? UUID(),
            displayName: Self.demoDisplayName(for: role),
            email: email,
            role: role,
            employeeID: role == .employee ? Self.demoEmployeeID : nil,
            employeeNumber: role == .employee ? "EMP-001" : nil,
            department: role == .employee ? .electrical : nil
        )
    }

    private func applyDemoSession(
        email: String
    ) {
        guard Self.demoRole(for: email) != nil else {
            state = .signedOut
            return
        }

        self.userID = Self.demoUserID(for: email)
        self.email = email.lowercased()
        self.state = .signedIn
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

    private static let demoEmployeeID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!

    private static func demoRole(
        for email: String
    ) -> UserRole? {
        switch email.lowercased() {
        case AppConfig.demoEmployeeEmail:
            return .employee
        case AppConfig.demoSupervisorEmail:
            return .supervisor
        case AppConfig.demoAdminEmail:
            return .admin
        default:
            return nil
        }
    }

    private static func demoDisplayName(
        for role: UserRole
    ) -> String {
        switch role {
        case .employee:
            return "Demo Employee"
        case .supervisor:
            return "Demo Supervisor"
        case .hr:
            return "Demo HR"
        case .admin:
            return "Demo Administrator"
        }
    }

    private static func demoUserID(
        for email: String
    ) -> UUID {
        switch demoRole(for: email) {
        case .employee:
            return demoEmployeeID
        case .supervisor:
            return UUID(
                uuidString: "22222222-2222-2222-2222-222222222222"
            )!
        case .admin:
            return UUID(
                uuidString: "33333333-3333-3333-3333-333333333333"
            )!
        default:
            return UUID()
        }
    }
}
