// FILE PURPOSE: Branded sign-in and demo account quick-fill buttons.
import SwiftUI

// This type groups related state and behavior under a clear responsibility.
struct LoginView: View {
    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var auth: AuthManager
    @State private var email = ""
    @State private var password = ""

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    credentialsCard

                    if !auth.errorMessage.isEmpty {
                        Label(auth.errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Stable accessibility ID allows repeatable XCUITest element lookup.
                            .accessibilityIdentifier("login_error")
                    }

                    // Choose the explicit demo path; production must use real backend controls.
                    if AppConfig.demoMode { demoCredentials }

                    Text("RELIABLE  ·  FUNCTIONAL  ·  SUSTAINABLE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.7)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 18)
                }
                .padding(20)
                .frame(maxWidth: 550)
                .frame(maxWidth: .infinity)
            }
            .background(CSCTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(CSCTheme.blue)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                // This asset must exist in Assets.xcassets; image names are case-sensitive.
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("BeaconTimeClock emblem")
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONTAINER SUPPLY")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.1)
                    Text("MANUFACTURING · SINCE 1947")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.75)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(.white.opacity(0.23))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("BeaconTimeClock")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    // Stable accessibility ID allows repeatable XCUITest element lookup.
                    .accessibilityIdentifier("login_app_title")
                Text("Your workday. Clearly recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(CSCTheme.navy, in: RoundedRectangle(cornerRadius: 22))
    }

    private var credentialsCard: some View {
        CSCCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Employee sign in")
                        .font(.title3.bold())
                        .foregroundStyle(CSCTheme.ink)
                    Text("Use your assigned company account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("WORK EMAIL")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CSCTheme.steel)
                    TextField("name@company.com", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        // Stable accessibility ID allows repeatable XCUITest element lookup.
                        .accessibilityIdentifier("email_field")
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("PASSWORD")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CSCTheme.steel)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        // Stable accessibility ID allows repeatable XCUITest element lookup.
                        .accessibilityIdentifier("password_field")
                }

                Button {
                    Task {
                        await auth.signIn(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    }
                } label: {
                    HStack(spacing: 10) {
                        if auth.isWorking { ProgressView().tint(.white) }
                        Text("Sign In")
                            .fontWeight(.bold)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(CSCTheme.blue, in: RoundedRectangle(cornerRadius: 12))
                .disabled(email.isEmpty || password.isEmpty || auth.isWorking)
                .opacity(email.isEmpty || password.isEmpty ? 0.65 : 1)
                // Stable accessibility ID allows repeatable XCUITest element lookup.
                .accessibilityIdentifier("login_button")
            }
        }
    }

    private var demoCredentials: some View {
        CSCCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("DEMONSTRATION ACCOUNTS", systemImage: "testtube.2")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(CSCTheme.steel)
                Text("For class testing only. Password: \(AppConfig.demoPassword)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    demoButton("Employee", email: AppConfig.demoEmployeeEmail, id: "employee_demo_button")
                    demoButton("Supervisor", email: AppConfig.demoSupervisorEmail, id: "supervisor_demo_button")
                }
                HStack(spacing: 10) {
                    demoButton("HR", email: AppConfig.demoHREmail, id: "hr_demo_button")
                    demoButton("Admin", email: AppConfig.demoAdminEmail, id: "admin_demo_button")
                }

                Menu {
                    Button("Machine Shop") { fillDemo(AppConfig.demoMachineShopSupervisorEmail) }
                    Button("Metals") { fillDemo(AppConfig.demoMetalsSupervisorEmail) }
                    Button("Plastics") { fillDemo(AppConfig.demoPlasticsSupervisorEmail) }
                    Button("Litho") { fillDemo(AppConfig.demoLithoSupervisorEmail) }
                } label: {
                    Label("Other department supervisors", systemImage: "person.3")
                        .font(.subheadline)
                }
                // Stable accessibility ID allows repeatable XCUITest element lookup.
                .accessibilityIdentifier("other_supervisors_menu")
            }
        }
    }

    private func demoButton(_ label: String, email: String, id: String) -> some View {
        Button(label) { fillDemo(email) }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            // Stable accessibility ID allows repeatable XCUITest element lookup.
            .accessibilityIdentifier(id)
    }

    private func fillDemo(_ demoEmail: String) {
        email = demoEmail
        password = AppConfig.demoPassword
    }
}
