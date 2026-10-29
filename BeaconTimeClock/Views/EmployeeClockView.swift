import SwiftUI

struct EmployeeClockView: View {
    let profile: UserProfile

    @StateObject private var viewModel: EmployeeClockViewModel

    @EnvironmentObject private var beacon: BeaconManager
    @EnvironmentObject private var lunch: LunchTimerManager

    init(
        profile: UserProfile,
        viewModel: EmployeeClockViewModel
    ) {
        self.profile = profile
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
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
                        Text(viewModel.statusMessage)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding()
                            .background(
                                .thinMaterial,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                }
                .padding()
            }
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
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private var beaconCard: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Label(
                beacon.isInsideAllowedZone
                    ? "Inside Approved Clock Zone"
                    : "Outside Clock Zone",
                systemImage: beacon.isInsideAllowedZone
                    ? "checkmark.circle.fill"
                    : "antenna.radiowaves.left.and.right.slash"
            )
            .font(.headline)

            Text("RSSI: \(beacon.rssi) dBm")

            if let distance = beacon.estimatedDistanceMeters {
                Text(
                    String(
                        format: "Estimated distance: %.2f m",
                        distance
                    )
                )
            }

            Text("Next action: \(viewModel.nextExpectedPunch.displayName)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 14)
        )
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
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 14)
        )
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
                .controlSize(.large)
                .disabled(!viewModel.isAllowed(type))
            }
        }
    }
}
