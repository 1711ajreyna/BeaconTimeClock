import SwiftUI

struct AccountView: View {
    let profile: UserProfile

    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image("BrandLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 14)
                            )

                        VStack(alignment: .leading) {
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
                        value: profile.role.rawValue.capitalized
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
            .navigationTitle("Account")
        }
    }
}
