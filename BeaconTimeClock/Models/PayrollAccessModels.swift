// FILE PURPOSE: Distinct public HR submission status and privileged HR payroll response types.
import Foundation

// MARK: - Public, minimal company status (no payroll details)
/// The company-wide board intentionally omits employee names, hours and IDs.
// This type groups related state and behavior under a clear responsibility.
enum CompanyDepartmentStage: String, Codable, Hashable {
    case notGenerated = "not_generated"
    case pending
    case approved
    case sentToHR = "sent_to_hr"

    var displayName: String {
        switch self {
        case .notGenerated: return "Not generated"
        case .pending: return "Awaiting supervisor"
        case .approved: return "Approved - waiting for HR"
        case .sentToHR: return "Delivered to HR"
        }
    }
}

// This type groups related state and behavior under a clear responsibility.
struct CompanyDepartmentStatus: Codable, Hashable, Identifiable {
    let department: Department
    let stage: CompanyDepartmentStage
    var id: Department { department }
}

// This type groups related state and behavior under a clear responsibility.
struct CompanySubmissionStatus: Codable, Hashable {
    let weekStart: String
    let weekEnd: String
    let departments: [CompanyDepartmentStatus]
    let hrDeliveryConfirmed: Bool
}

// MARK: - Private HR-only API response
/// HR/admin receive the five complete signed department snapshots in ONE call.
/// Backend must derive access from the authenticated token, not a role supplied
/// by the phone. It must verify that the weekly snapshot is complete/consistent.
// This type groups related state and behavior under a clear responsibility.
struct HRPayrollPacket: Codable {
    let weekStart: String
    let weekEnd: String
    let departments: [DepartmentTimesheet]
}
