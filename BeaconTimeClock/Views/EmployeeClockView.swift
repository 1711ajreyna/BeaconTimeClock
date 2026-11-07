// FILE PURPOSE: Employee time-clock interface, badge/status and punch buttons.
import SwiftUI

// This type groups related state and behavior under a clear responsibility.
struct EmployeeClockView: View {
    let profile: UserProfile

    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var viewModel: EmployeeClockViewModel

    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var beacon: BeaconManager
    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var lunch: LunchTimerManager

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        profile: UserProfile,
        viewModel: EmployeeClockViewModel
    ) {
        self.profile = profile
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BrandHeaderView(
                        subtitle: "Employee Time Clock"
                    )

                    employeeCard
                    beaconCard

                    if lunch.isRunning {
                        lunchCard
                    }

                    punchButtons

                    if !viewModel.statusMessage.isEmpty {
                        Text(AppLocalization.text(viewModel.statusMessage))
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding()
                            .background(CSCTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .background(CSCTheme.canvas)
            .tint(CSCTheme.blue)
            .navigationTitle("Clock")
            .alert(
                "Punch Not Recorded",
                isPresented: $viewModel.showError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.statusMessage)
            }
        }
    }

    private var employeeCard: some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            Text(profile.displayName)
                .font(.headline)

            if let employeeNumber = profile.employeeNumber {
                Text("Employee #: \(employeeNumber)")
                    .foregroundStyle(.secondary)
            }

            // Choose the explicit demo path; production must use real backend controls.
            if AppConfig.demoMode {
                Label(
                    "Demonstration Mode",
                    systemImage: "testtube.2"
                )
                .font(.caption.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(CSCTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(CSCTheme.border, lineWidth: 1)
        }
    }

    private var beaconCard: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Label(
                AppLocalization.text(beacon.isInsideAllowedZone
                    ? "Inside Approved Clock Zone"
                    : "Outside Clock Zone"),
                systemImage: beacon.isInsideAllowedZone
                    ? "checkmark.circle.fill"
                    : "antenna.radiowaves.left.and.right.slash"
            )
            .font(.headline)

            Text("RSSI: \(beacon.rssi) dBm")

            if let distance = beacon.estimatedDistanceMeters {
                Text(
                    String(
                        format: AppLocalization.text("Estimated distance: %.2f m"),
                        distance
                    )
                )
            }

            Text("\(AppLocalization.text("Next action:")) \(viewModel.nextExpectedPunch.displayName)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(CSCTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(CSCTheme.border, lineWidth: 1)
        }
    }

    private var lunchCard: some View {
        VStack {
            Text("Lunch Remaining")
                .font(.headline)

            Text(lunch.formatted())
                .font(
                    .system(
                        size: 40,
                        weight: .bold,
                        design: .monospaced
                    )
                )
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(CSCTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(CSCTheme.border, lineWidth: 1)
        }
    }

    private var punchButtons: some View {
        VStack(spacing: 10) {
            ForEach(PunchType.allCases) { type in
                Button {
                    Task {
                        await viewModel.submit(type)
                    }
                } label: {
                    HStack {
                        Image(systemName: type.systemImage)
                        Text(type.displayName)
                            .fontWeight(.semibold)
                        Spacer()

                        if type == viewModel.nextExpectedPunch {
                            Text("NEXT")
                                .font(.caption.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CSCTheme.blue)
                .controlSize(.large)
                .disabled(!viewModel.isAllowed(type))
            }
        }
    }
}
