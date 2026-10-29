import Foundation

/// Simple acknowledgement for API actions that do not return a whole model.
struct BasicAPIResponse: Codable {
    let success: Bool // True when the requested operation was accepted.
}
