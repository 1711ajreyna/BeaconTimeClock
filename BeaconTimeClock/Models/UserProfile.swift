// FILE PURPOSE: Signed-in user identity, role and department-scope helpers.
import Foundation

// MARK: - User Roles

/// Defines the different account roles in BeaconTimeClock.
///
/// Roles determine which features employees, supervisors,
/// HR personnel, and administrators can access.
// This type groups related state and behavior under a clear responsibility.
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
        // HR may manage accounts and payroll but cannot modify a department.
        self == .supervisor
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

// This type groups related state and behavior under a clear responsibility.
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



// MARK: - Single-department supervisor permissions
extension UserProfile {
    /// UI/demo convenience only. The production backend must recheck the JWT,
    /// role, and supervisor_departments assignment on EVERY sensitive request.
    // A supervisor must be assigned to the EXACT department being changed.
    // HR can assign staff accounts to departments, but cannot edit operational
    // schedules, punches, or approvals. Admin/employee likewise cannot.
    func canManageDepartment(_ target: Department) -> Bool {
        role == .supervisor && department == target
    }

    /// Operational changes are owned only by the supervisor assigned to that department.
    /// HR can assign people to departments and view payroll, but cannot edit operations.
    func canEditDepartment(_ target: Department) -> Bool {
        role == .supervisor && department == target
    }

    var canAccessPayroll: Bool { role == .hr || role == .admin }
}


// MARK: - Staff account administration (UI convenience; API must recheck)
extension UserProfile {
    /// Only supervisors and HR can add or edit accounts. Admin is deliberately excluded.
    var canManageStaffAccounts: Bool { role == .supervisor || role == .hr }

    /// Department supervisors can manage employees in their own department only.
    /// Only HR can create/edit supervisor accounts or promote employees.
    func canSaveStaff(_ proposed: StaffMember, existing: StaffMember?) -> Bool {
        switch role {
        case .employee, .admin:
            return false
        case .supervisor:
            guard let department else { return false }
            return proposed.role == .employee && proposed.department == department &&
                (existing == nil || (existing?.role == .employee && existing?.department == department))
        case .hr:
            return (proposed.role == .employee || proposed.role == .supervisor) &&
                (existing == nil || (existing?.role == .employee || existing?.role == .supervisor))
        }
    }
}
