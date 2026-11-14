// FILE PURPOSE: Face ID / Touch ID verification for protected punch-related actions.
import Foundation
import LocalAuthentication

// This type groups related state and behavior under a clear responsibility.
enum BiometricError: LocalizedError {
    case unavailable
    case failed
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Face ID or Touch ID is unavailable or not enrolled. Set up biometrics in device settings before punching."
        case .failed:
            return "Identity verification failed or was cancelled."
        }
    }
}

/// Use a protocol so a denied or cancelled biometric attempt can be
/// regression-tested without requesting actual Face ID in the test runner.
@MainActor
protocol PunchBiometricAuthenticating {
    func authenticate() async throws
}

/// The app receives only an authentication result, never biometric templates.
struct BiometricManager: PunchBiometricAuthenticating {
    
    // A NEW context forces a fresh Face ID / Touch ID attempt for each action.
    // Demo mode also prompts: never ship or demonstrate a silent identity bypass.
    func authenticate() async throws {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        var error: NSError?
        
        guard context.canEvaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        error: &error
        ) else {
            throw BiometricError.unavailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Verify your identity before recording this time punch"
                )
            
            guard success else {
                throw BiometricError.failed
            }
        } catch {
            throw BiometricError.failed
        }
    }
}
