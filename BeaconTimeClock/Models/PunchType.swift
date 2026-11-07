// FILE PURPOSE: Finite set of clock-in, lunch-start, lunch-end and clock-out punch actions.
import Foundation

/// All employee attendance events accepted by the app/backend
// This type groups related state and behavior under a clear responsibility.
enum PunchType: String, Codable, CaseIterable, Identifiable, Hashable {
    case clockIn = "clock_in"
    case lunchOut = "lunch_out"
    case lunchIn = "lunch_in"
    case clockOut = "clock_out"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        // A clock-in changes which attendance event is valid next.
        case .clockIn: return "Clock In"
        case .lunchOut: return "Lunch Out"
        case .lunchIn: return "Lunch In"
        // Clock-out completes the current punch sequence.
        case .clockOut: return "Clock Out"
        }
    }
    
    var systemImage: String {
        switch self {
        // A clock-in changes which attendance event is valid next.
        case .clockIn:
            return "arrow.right.circle.fill"
        case .lunchOut:
            return "fork.knife.circle.fill"
        case .lunchIn:
            return "arrow.uturn.left.circle.fill"
        // Clock-out completes the current punch sequence.
        case .clockOut:
            return "arrow.left.circle.fill"
        }
    }
}
