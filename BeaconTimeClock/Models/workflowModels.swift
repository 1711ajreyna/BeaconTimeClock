import Foundation

enum ApprovalStatus: String, Codable, Hashable {
    case pending
    case approved
    case sentToHR = "sent_to_hr"

    var displayName: String {
        switch self {
        case .pending: return "Awaiting Approval"
        case .approved: return "Approved"
        case .sentToHR: return "Sent to HR"
        }
    }
}

enum HRPacketStatus: String, Codable, Hashable {
    case waitingForDepartments = "waiting_for_departments"
    case ready
    case emailed
}

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
