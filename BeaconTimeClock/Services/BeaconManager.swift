// FILE PURPOSE: Presents beacon proximity status to the rest of the app.
import Foundation

/// Observable facade between SwiftUI and the selected beacon scanner.
///
/// This file is intentionally scanner agnostic. Swap the scanner implementation
/// without changing employee/business logic.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class BeaconManager: ObservableObject {
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var beaconDetected = false
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var rssi = 0
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var estimatedDistanceMeters: Double?

    private let scanner: any BeaconScanning

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        scanner: (any BeaconScanning)? = nil
    ) {
        if let scanner {
            self.scanner = scanner
        } else if AppConfig.demoMode {
            self.scanner = DemoBeaconScanner()
        } else {
            self.scanner = CoreLocationBeaconScanner()
        }

        self.scanner.observationHandler = { [weak self] observation in
            self?.beaconDetected = observation.detected
            self?.rssi = observation.rssi
            self?.estimatedDistanceMeters = observation.estimatedDistanceMeters
        }
    }

    var isInsideAllowedZone: Bool {
        guard beaconDetected,
              let distance = estimatedDistanceMeters,
              distance >= 0 else {
            return false
        }

        return distance <= AppConfig.allowedDistanceMeters
    }

    // Ask for relevant location permission and start scanning.
    func requestPermissionAndStart() {
        scanner.start()
    }

    // Stop beacon observations when they are not needed.
    func stopRanging() {
        scanner.stop()
    }
}
