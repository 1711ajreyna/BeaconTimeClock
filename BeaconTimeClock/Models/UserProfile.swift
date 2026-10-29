
import Foundation

// MARK: - User Roles

/// Defines the different account roles in BeaconTimeClock.
///
/// Roles determine which features employees, supervisors,
/// HR personnel, and administrators can access.
enum UserRole: String, Codable, Hashable {

    case employee
    case supervisor
    case hr
    case admin

    // MARK: - Supervisor Permissions

    /// Determines whether the user's role is eligible
    /// to access supervisor-related features.
    ///
    /// IMPORTANT:
    /// This is for controlling the app's interface.
    /// The production backend must independently verify
    /// each user's permissions.
    var canUseSupervisorTools: Bool {

        switch self {

        case .supervisor, .hr, .admin:
            return true

        case .employee:
            return false
        }
    }
}

// MARK: - User Profile

/// Company profile returned by the authenticated backend.
///
/// Production roles come from the database after the
/// server validates the authenticated user's identity.
///
/// Codable: Supports JSON encoding and decoding.
/// Hashable: Allows profiles to be compared and stored in sets.
/// Identifiable: Provides a unique ID for SwiftUI.

struct UserProfile: Codable, Hashable, Identifiable {

    // MARK: - Identity

    /// Unique account identifier.
    let id: UUID

    /// Name displayed in the application.
    let displayName: String

    /// Employee's login email.
    let email: String

    // MARK: - Authorization

    /// Determines the user's access level.
    let role: UserRole

    // MARK: - Employee Information

    /// Internal employee identifier.
    /// Optional because supervisors or HR users
    /// may not have an employee record.
    let employeeID: UUID?

    /// Human-readable employee number.
    /// Example: EMP-001
    let employeeNumber: String?

    /// Department assigned to the employee.
    /// Example: Electrical, Plastics, Metals.
    let department: Department?
}

