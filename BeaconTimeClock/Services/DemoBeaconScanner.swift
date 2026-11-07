// FILE PURPOSE: Simulated beacon observations for development without hardware.
import Foundation

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class DemoBeaconScanner: BeaconScanning {
    var observationHandler: ((BeaconObservation) -> Void)?

    func start() {
        observationHandler?(
            BeaconObservation(
                detected: true,
                rssi: -55,
                estimatedDistanceMeters: 2.0
            )
        )
    }

    func stop() {
        observationHandler?(
            BeaconObservation(
                detected: false,
                rssi: 0,
                estimatedDistanceMeters: nil
            )
        )
    }
}
