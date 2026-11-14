// FILE PURPOSE: Displays the signed-in user and account actions.
import SwiftUI

// This type groups related state and behavior under a clear responsibility.
struct AccountView: View {
    let profile: UserProfile

    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var services: AppServices

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        // This asset must exist in Assets.xcassets; image names are case-sensitive.
                        Image("BrandLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 14)
                            )

                        VStack(alignment: .leading) {
                            Text("CONTAINER SUPPLY")
                                .font(.caption.weight(.bold))
                                .tracking(1.0)
                                .foregroundStyle(CSCTheme.steel)
                            Text(profile.displayName)
                                .font(.headline)
                            Text(profile.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Company Access") {
                    LabeledContent(
                        "Role",
                        value: AppLocalization.text(profile.role == .hr ? "HR" : profile.role.rawValue.capitalized)
                    )

                    if let department = profile.department {
                        LabeledContent(
                            "Department",
                            value: department.displayName
                        )
                    }

                    if let number = profile.employeeNumber {
                        LabeledContent(
                            "Employee #",
                            value: number
                        )
                    }
                }

                if profile.canManageStaffAccounts {
                    Section("Staff Accounts") {
                        NavigationLink("Manage Staff Accounts") {
                            StaffManagementView(profile: profile, api: services.api)
                        }
                        .accessibilityIdentifier("manage_staff_link")
                        Text(profile.role == .hr
                             ? "HR can create employees and supervisors in any department."
                             : "Supervisors can create and edit employees in their own department only.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Language") {
                    LanguagePreferencePicker()
                }

                Section("Privacy & Support") {
                    if let url = AppConfig.privacyPolicyURL {
                        Link("Privacy Policy", destination: url)
                    }
                    if let url = AppConfig.supportURL {
                        Link("Help & Support", destination: url)
                    }
                    #if DEBUG
                    if AppConfig.privacyPolicyURL == nil || AppConfig.supportURL == nil {
                        Text("App Store checklist: set real PRIVACY_POLICY_URL and SUPPORT_URL in the target's Info settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                }

                Section {
                    Button(
                        "Sign Out",
                        role: .destructive
                    ) {
                        Task {
                            await auth.signOut()
                        }
                    }
                }

                Section {
                    Text(
                        "Production sessions are restored automatically after relaunch while the refresh session remains valid. Face ID/Touch ID is still required for sensitive attendance actions."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .cscListStyle()
            .navigationTitle("Account")
        }
    }
}
