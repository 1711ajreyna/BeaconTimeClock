import SwiftUI

struct AuthenticatedRootView: View {
    let profile: UserProfile

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var store: TimeCardStore
    @EnvironmentObject private var beacon: BeaconManager
    @EnvironmentObject private var lunch: LunchTimerManager

    var body: some View {
        TabView {
            if profile.employeeID != nil {
                EmployeeClockView(
                    profile: profile,
                    viewModel: EmployeeClockViewModel(
                        profile: profile,
                        store: store,
                        beaconManager: beacon,
                        lunchTimer: lunch,
                        api: services.api
                    )
                )
                .tabItem {
                    Label("Clock", systemImage: "clock.fill")
                }

                MyShiftView(
                    viewModel: MyShiftViewModel(
                        api: services.api,
                        beacon: beacon,
                        notifications: services.notificationScheduler
                    )
                )
                .tabItem {
                    Label("My Shift", systemImage: "calendar.badge.clock")
                }

                TimeCardsView()
                    .tabItem {
                        Label("My Time", systemImage: "list.bullet.rectangle")
                    }
            }

            if profile.role.canUseSupervisorTools {
                SupervisorPortalView(
                    viewModel: SupervisorPortalViewModel(
                        api: services.api
                    ),
                    api: services.api
                )
                .tabItem {
                    Label(
                        "Approvals",
                        systemImage: "checkmark.seal.fill"
                    )
                }

                ShiftRosterView(
                    viewModel: ShiftRosterViewModel(api: services.api)
                )
                .tabItem {
                    Label("Shift Rosters", systemImage: "person.3.sequence.fill")
                }

                SupervisorScheduleView(
                    viewModel: SupervisorScheduleViewModel(
                        api: services.api
                    )
                )
                .tabItem {
                    Label(
                        "Schedules",
                        systemImage: "calendar.badge.gearshape"
                    )
                }
            }

            AccountView(profile: profile)
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .task {
            beacon.requestPermissionAndStart()
            await lunch.requestNotificationPermission()
            await services.notificationScheduler.requestPermission()
        }
    }
}
