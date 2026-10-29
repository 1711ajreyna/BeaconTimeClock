import Foundation

@MainActor
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
