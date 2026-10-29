import Foundation
// This file provides the Models layer used by the larger BeaconTimeClock workflow

/// The Five departments participating in the weekly approval workflow.
///
/// Raw values match the backend database enum values.
enum Department: String, Codable, CaseIterable, Identifiable, Hashable {
    case electrical = "electrical"
    case machineShop = "machine_shop"
    case metals = "metals"
    case plastics = "plastics"
    case litho = "litho"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .electrical:
            return "Electrical"
        case .machineShop:
            return "Machine Shop"
        case .metals:
            return "Metals"
        case .plastics:
            return "Plastics"
        case .litho:
            return "Litho"
        }
    }
    
    /// Keeps the Supervisor Portal in a consistant business order
    var sortOrder: Int {
        switch self {
        case .electrical: return 0
        case .machineShop: return 1
        case .metals: return 2
        case .plastics: return 3
        case .litho: return 4
        }
    }
}
