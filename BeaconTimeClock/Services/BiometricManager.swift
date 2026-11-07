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
            return "Face ID or touch ID is unavailable."
        case .failed:
            return "Identity verification failed or was cancelled."
        }
    }
}

/// The app recieves only an authentication result. It never recieves the
///  person's fingerprint, face image, or biometric template.
// This type groups related state and behavior under a clear responsibility.
struct BiometricManager {
    
    // Invoke Face ID / Touch ID for protected actions in production.
    func authenticate() async throws {
        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            return
        }
        
        let context = LAContext()
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
