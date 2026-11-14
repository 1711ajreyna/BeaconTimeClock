// FILE PURPOSE: Supervisor approval summaries, timesheets, employee totals and audit records.
import Foundation

// This type groups related state and behavior under a clear responsibility.
enum ApprovalStatus: String, Codable, Hashable {
    case pending
    case approved
    case sentToHR = "sent_to_hr"

    var displayName: String {
        switch self {
        case .pending: return AppLocalization.text("Awaiting Approval")
        case .approved: return AppLocalization.text("Approved")
        case .sentToHR: return AppLocalization.text("Sent to HR")
        }
    }
}

// This type groups related state and behavior under a clear responsibility.
enum HRPacketStatus: String, Codable, Hashable {
    case waitingForDepartments = "waiting_for_departments"
    case ready
    case emailed
}

// This type groups related state and behavior under a clear responsibility.
struct DepartmentApprovalSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let department: Department
    let status: ApprovalStatus
    let employeeCount: Int
    let regularHours: Double
    let overtimeHours: Double
    let totalHours: Double
    let supervisorName: String?
    let signedAt: Date?
    let canEdit: Bool
}

// This type groups related state and behavior under a clear responsibility.
struct SupervisorDashboard: Codable, Hashable {
    let weekStart: String
    let weekEnd: String
    let generatedAt: Date
    let departments: [DepartmentApprovalSummary]
    let hrPacketStatus: HRPacketStatus

    var pendingDepartments: [DepartmentApprovalSummary] {
        departments
            .filter { $0.status == .pending }
            .sorted { $0.department.sortOrder < $1.department.sortOrder }
    }

    var approvedCount: Int {
        departments.filter { $0.status != .pending }.count
    }
}

// This type groups related state and behavior under a clear responsibility.
struct PunchRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let type: PunchType
    let occurredAt: Date
    var effectiveOccurredAt: Date
    var adjustmentReason: String?

    var isAdjusted: Bool {
        abs(
            effectiveOccurredAt.timeIntervalSince(occurredAt)
        ) > 0.5
    }
}

/// Rest-break activity is displayed beside time punches in the weekly packet.
// This type groups related state and behavior under a clear responsibility.
struct WeeklyShiftEventRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let type: ShiftEventType
    let occurredAt: Date
    let biometricVerified: Bool
    let beaconVerified: Bool
    let note: String?

    var isException: Bool {
        type.isNotTaken
    }
}

// This type groups related state and behavior under a clear responsibility.
struct EmployeeWeeklySummary: Identifiable, Codable, Hashable {
    let id: UUID
    let employeeID: String
    let employeeName: String
    var regularHours: Double
    var overtimeHours: Double
    var totalHours: Double
    var hasException: Bool
    var punches: [PunchRecord]
    var shiftEvents: [WeeklyShiftEventRecord]

    var hasBreakException: Bool {
        shiftEvents.contains(where: \.isException)
    }
}

// This type groups related state and behavior under a clear responsibility.
struct DepartmentTimesheet: Identifiable, Codable, Hashable {
    let id: UUID
    let department: Department
    let weekStart: String
    let weekEnd: String
    var status: ApprovalStatus
    var employees: [EmployeeWeeklySummary]
    let generatedAt: Date
    var sentToSupervisorAt: Date?
    var supervisorName: String?
    var signedAt: Date?
    var signaturePresent: Bool

    var regularHours: Double {
        employees.reduce(0) { $0 + $1.regularHours }
    }

    var overtimeHours: Double {
        employees.reduce(0) { $0 + $1.overtimeHours }
    }

    var totalHours: Double {
        employees.reduce(0) { $0 + $1.totalHours }
    }

    /// Broken/missing time punches block payroll approval. A rest break marked
    /// not taken is highlighted as an exception but remains approvable after
    /// supervisor review because the event itself is already documented.
    var hasUnresolvedExceptions: Bool {
        employees.contains { $0.hasException }
    }

    var hasBreakExceptions: Bool {
        employees.contains { $0.hasBreakException }
    }
}

// FILE PURPOSE: Distinct public HR submission status and privileged HR payroll response types.


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
        case .notGenerated: return AppLocalization.text("Not generated")
        case .pending: return AppLocalization.text("Awaiting supervisor")
        case .approved: return AppLocalization.text("Approved - waiting for HR")
        case .sentToHR: return AppLocalization.text("Delivered to HR")
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
