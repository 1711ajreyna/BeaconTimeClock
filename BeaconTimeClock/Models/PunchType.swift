import Foundation

/// All employee attendance events accepted by the app/backend
enum PunchType: String, Codable, CaseIterable, Identifiable, Hashable {
    case clockIn = "clock_in"
    case lunchOut = "lunch_out"
    case lunchIn = "lunch_in"
    case clockOut = "clock_out"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .clockIn: return "Clock In"
        case .lunchOut: return "Lunch Out"
        case .lunchIn: return "Lunch In"
        case .clockOut: return "Clock Out"
        }
    }
    
    var systemImage: String {
        switch self {
        case .clockIn:
            return "arrow.right.circle.fill"
        case .lunchOut:
            return "fork.knife.circle.fill"
        case .lunchIn:
            return "arrow.uturn.left.circle.fill"
        case .clockOut:
            return "arrow.left.circle.fill"
        }
    }
}
