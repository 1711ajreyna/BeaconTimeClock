import Foundation

struct BeaconObservation: Equatable, Sendable {
    let detected: Bool
    let rssi: Int
    let estimatedDistanceMeters: Double?
}

/// Platform neutral contract used by the iOS application.
///
///  Android can implement the same conceptual contract using kotlin and the
///  Android Beacon Library / BluetooLeScanner without changing the backend logic.
@MainActor
protocol BeaconScanning: AnyObject {
    var observationHandler: ((BeaconObservation) -> Void)? { get set }
    func start()
    func stop()
}
