
import Foundation

// MARK: - Employee Punch API

/// Information submitted when an employee clocks in or out.
struct SubmitPunchRequest: Codable {

    /// Employee submitting the punch.
    let employeeID: String

    /// Clock-in or clock-out event.
    let type: PunchType

    /// UUID of the detected workplace beacon.
    let beaconUUID: String?

    /// Bluetooth received signal strength.
    let rssi: Int

    /// Approximate distance from the beacon.
    let estimatedDistance: Double?
}

/// Response returned after the backend processes a punch.
struct SubmitPunchResponse: Codable {

    /// Whether the operation succeeded.
    let success: Bool

    /// Unique identifier for the recorded punch.
    let punchID: UUID

    /// Official time recorded by the server.
    let serverTimestamp: Date

    /// Optional confirmation or error message.
    let message: String?
}

// MARK: - Supervisor Corrections

/// Manual time correction submitted by a supervisor.
///
/// The backend should preserve the original punch
/// and create a separate audit record.
///
/// Existing property names are retained for
/// compatibility with your other files.
struct PunchAdjustmentRequest: Codable {

    /// Timesheet containing the punch.
    let timesheetID: UUID

    /// Punch being corrected.
    let punchID: UUID

    /// Corrected time requested by the supervisor.
    let correctedOccurredAt: Date

    /// Explanation for the adjustment.
    let reason: String
}

/// Response after requesting a time correction.
struct PunchAdjustmentResponse: Codable {

    let success: Bool
    let message: String?
}

// MARK: - Digital Approval

/// Request submitted when a supervisor approves
/// a department's weekly timesheet.

// MARK: - Digital Approval

/// Request submitted when a supervisor approves
/// a department's weekly timesheet.
struct ApproveDepartmentRequest: Codable {

    /// Identifies the department timesheet to approve.
    let timesheetID: UUID

    /// Supervisor's printed name recorded with
    /// the digital approval.
    let supervisorPrintedName: String

    /// Supervisor's drawn signature converted
    /// into a Base64-encoded PNG image.
    let signaturePNGBase64: String
}


/// Response returned after a department approval.

struct ApproveDepartmentResponse: Codable {

    /// Whether the approval succeeded.
    let success: Bool

    /// Official server-recorded approval timestamp.
    let signedAt: Date

    /// Whether every department is approved.
    let allDepartmentsApproved: Bool

    /// Whether the HR packet generation was triggered.
    let hrMergeTriggered: Bool

    /// Optional confirmation message.
    let message: String?
}

