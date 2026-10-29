import Foundation
import LocalAuthentication

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
struct BiometricManager {
    
    func authenticate() async throws {
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
