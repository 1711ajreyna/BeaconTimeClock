import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 135, height: 135)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 28)
                        )

                    VStack(spacing: 5) {
                        Text("BeaconTimeClock")
                            .font(.largeTitle.bold())

                        Text("Container Supply Co.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        TextField(
                            "Work email",
                            text: $email
                        )
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("email_field")

                        SecureField(
                            "Password",
                            text: $password
                        )
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("password_field")

                        Button {
                            Task {
                                await auth.signIn(
                                    email: email,
                                    password: password
                                )
                            }
                        } label: {
                            HStack {
                                if auth.isWorking {
                                    ProgressView()
                                }

                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("login_button")
                        .disabled(
                            email.isEmpty ||
                            password.isEmpty ||
                            auth.isWorking
                        )
                    }

                    if !auth.errorMessage.isEmpty {
                        Text(auth.errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    if AppConfig.demoMode {
                        demoCredentials
                    }
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var demoCredentials: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Label(
                "Demonstration Accounts",
                systemImage: "testtube.2"
            )
            .font(.headline)

            Text("Password for every demo account: \(AppConfig.demoPassword)")
                .font(.caption)

            Button("Use Employee Demo") {
                email = AppConfig.demoEmployeeEmail
                password = AppConfig.demoPassword
            }
            .accessibilityIdentifier("employee_demo_button")

            Button("Use Supervisor Demo") {
                email = AppConfig.demoSupervisorEmail
                password = AppConfig.demoPassword
            }
            .accessibilityIdentifier("supervisor_demo_button")

            Button("Use Admin Demo") {
                email = AppConfig.demoAdminEmail
                password = AppConfig.demoPassword
            }
            .accessibilityIdentifier("admin_demo_button")

            Text(
                "The production Supabase SDK persists the user's session in Apple platform local storage/Keychain, so a valid session is restored when the app reopens."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}
