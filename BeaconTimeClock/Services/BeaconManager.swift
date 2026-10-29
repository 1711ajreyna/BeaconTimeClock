import Foundation

/// Observable facade between SwiftUI and the selected beacon scanner.
///
/// This file is intentionally scanner agnostic. Swap the scanner implementation
/// without changing employee/business logic.
@MainActor
final class BeaconManager: ObservableObject {
    @Published private(set) var beaconDetected = false
    @Published private(set) var rssi = 0
    @Published private(set) var estimatedDistanceMeters: Double?

    private let scanner: any BeaconScanning

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

    func requestPermissionAndStart() {
        scanner.start()
    }

    func stopRanging() {
        scanner.stop()
    }
}
