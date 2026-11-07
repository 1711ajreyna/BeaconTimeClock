// FILE PURPOSE: Small typed acknowledgement returned by API operations.
import Foundation

/// Simple acknowledgement for API actions that do not return a whole model.
// This type groups related state and behavior under a clear responsibility.
struct BasicAPIResponse: Codable {
    let success: Bool // True when the requested operation was accepted.
}
