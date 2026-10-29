import Foundation
import CoreLocation

/// Native iOS implementation for detecting real iBeacon-compatible
/// Bluetooth Low Energy (BLE) beacons.
///
/// A multi-protocol beacon can broadcast iBeacon for iOS
/// and another BLE format for a future Android app.

@MainActor
final class CoreLocationBeaconScanner: NSObject, BeaconScanning {

    // MARK: - Properties

    /// Sends beacon information to BeaconManager.
    var observationHandler: ((BeaconObservation) -> Void)?

    /// Apple's location manager handles beacon detection.
    private let manager = CLLocationManager()

    /// Identifies which beacon UUID the app should search for.
    private let constraint = CLBeaconIdentityConstraint(
        uuid: AppConfig.beaconUUID
    )

    // MARK: - Initialization

    override init() {
        super.init()

        // Receive CoreLocation updates through delegate methods.
        manager.delegate = self
    }

    // MARK: - Start Scanning

    /// Starts scanning when location permission is available.
    func start() {

        switch manager.authorizationStatus {

        case .notDetermined:

            // Ask the employee for location permission.
            manager.requestWhenInUseAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:

            // Start searching for beacons matching our UUID.
            manager.startRangingBeacons(
                satisfying: constraint
            )

        case .denied, .restricted:

            // Permission denied: report no available beacon.
            emitEmpty()

        @unknown default:

            // Handle unexpected authorization states.
            emitEmpty()
        }
    }

    // MARK: - Stop Scanning

    /// Stops detecting beacons and clears previous results.
    func stop() {

        manager.stopRangingBeacons(
            satisfying: constraint
        )

        emitEmpty()
    }

    // MARK: - Clear Beacon Detection

    /// Reports that no valid beacon is currently detected.
    private func emitEmpty() {

        observationHandler?(
            BeaconObservation(
                detected: false,
                rssi: 0,
                estimatedDistanceMeters: nil
            )
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationBeaconScanner: CLLocationManagerDelegate {

    // MARK: - Authorization Changes

    /// Called when the employee grants or changes location access.
    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        Task { @MainActor in

            // Recheck permission and begin scanning if authorized.
            self.start()
        }
    }

    // MARK: - Beacon Detection

    /// Called whenever CoreLocation reports nearby beacons.
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {

        Task { @MainActor in

            // Ignore beacons without a usable signal.
            // Choose the beacon with the smallest valid
            // estimated distance.
            guard let nearest = beacons
                .filter({ $0.rssi != 0 })
                .min(by: {

                    let left = $0.accuracy >= 0
                        ? $0.accuracy
                        : .greatestFiniteMagnitude

                    let right = $1.accuracy >= 0
                        ? $1.accuracy
                        : .greatestFiniteMagnitude

                    return left < right
                })
            else {

                // No valid beacon detected.
                self.emitEmpty()
                return
            }

            // Send the nearest beacon's signal information
            // to BeaconManager.
            self.observationHandler?(
                BeaconObservation(
                    detected: true,
                    rssi: nearest.rssi,
                    estimatedDistanceMeters:
                        nearest.accuracy >= 0
                        ? nearest.accuracy
                        : nil
                )
            )
        }
    }

    // MARK: - Beacon Ranging Errors

    /// Called when CoreLocation cannot complete beacon ranging.
    ///
    /// Correct delegate method for CLBeaconIdentityConstraint.
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailRangingFor constraint: CLBeaconIdentityConstraint,
        error: Error
    ) {

        Task { @MainActor in

            // Print the reason for failure in Xcode.
            print(
                "Beacon ranging failed: \(error.localizedDescription)"
            )

            // Prevent the app from trusting outdated readings.
            self.emitEmpty()
        }
    }
}

