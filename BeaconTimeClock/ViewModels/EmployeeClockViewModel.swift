// FILE PURPOSE: Orchestrates clock button actions through beacon, biometrics, API and local cache.
import Foundation

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class EmployeeClockViewModel: ObservableObject {
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var statusMessage = ""
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var showError = false
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var isProcessing = false

    private let profile: UserProfile
    private let store: TimeCardStore
    private let beaconManager: BeaconManager
    private let lunchTimer: LunchTimerManager
    private let biometricManager: BiometricManager
    // Dependency injection: tests can use a fake API and production can use real HTTP.
    private let api: WorkflowAPI

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        profile: UserProfile,
        store: TimeCardStore,
        beaconManager: BeaconManager,
        lunchTimer: LunchTimerManager,
        api: WorkflowAPI,
        biometricManager: BiometricManager = BiometricManager()
    ) {
        self.profile = profile
        self.store = store
        self.beaconManager = beaconManager
        self.lunchTimer = lunchTimer
        self.api = api
        self.biometricManager = biometricManager
    }

    var nextExpectedPunch: PunchType {
        guard let latest = store.latestPunch(
            for: profile.employeeNumber ?? "UNKNOWN"
        ) else {
            return .clockIn
        }

        switch latest.type {
        // A clock-in changes which attendance event is valid next.
        case .clockIn: return .lunchOut
        case .lunchOut: return .lunchIn
        case .lunchIn: return .clockOut
        // Clock-out completes the current punch sequence.
        case .clockOut: return .clockIn
        }
    }

    func isAllowed(_ type: PunchType) -> Bool {
        beaconManager.isInsideAllowedZone &&
        nextExpectedPunch == type &&
        !isProcessing
    }

    func submit(_ type: PunchType) async {
        guard beaconManager.isInsideAllowedZone else {
            fail("Move into the approved beacon zone before punching.")
            return
        }

        guard nextExpectedPunch == type else {
            fail("The next expected action is \(nextExpectedPunch.displayName).")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await biometricManager.authenticate()

            let employeeNumber = profile.employeeNumber ?? "UNKNOWN"

            let localCard = TimeCard(
                employeeID: employeeNumber,
                employeeName: profile.displayName,
                type: type,
                timestamp: Date(),
                beaconUUID: AppConfig.beaconUUID.uuidString,
                rssi: beaconManager.rssi,
                estimatedDistanceMeters:
                    beaconManager.estimatedDistanceMeters
            )

            try store.add(localCard)

            // MARK: - Submit Punch to Backend

            // Send the employee's punch information to the API.
            // Demo mode uses DemoAPIClient.
            // Production mode uses ProductionAPIClient.

            // Await the workflow API instead of handling backend details directly in the ViewModel.
            let response = try await api.submitPunch(
                SubmitPunchRequest(

                    // Identifies the employee submitting the punch.
                    employeeID: employeeNumber,

                    // Identifies the action: clock-in, clock-out, etc.
                    type: type,

                    // UUID of the detected workplace beacon.
                    beaconUUID: AppConfig.beaconUUID.uuidString,

                    // Bluetooth signal strength from BeaconManager.
                    rssi: beaconManager.rssi,

                    // Estimated distance from the beacon.
                    // The label must match APIModels.swift.
                    estimatedDistance:
                        beaconManager.estimatedDistanceMeters
                )
            )

            try store.markSynced(
                card: localCard,
                remoteID: response.punchID,
                serverTimestamp: response.serverTimestamp
            )

            if type == .lunchOut {
                lunchTimer.start()
            } else if type == .lunchIn {
                lunchTimer.stop()
            }

            statusMessage =
                "\(type.displayName) accepted at \(response.serverTimestamp.formatted(date: .omitted, time: .shortened))."
        } catch {
            if let latest = store.latestPunch,
               latest.syncStatus == "pending" {
                try? store.markFailed(card: latest)
            }

            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        statusMessage = message
        showError = true
    }
}
