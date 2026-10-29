import Foundation

enum RestBreakSlot: String, Codable, CaseIterable, Identifiable, Hashable {
    case first
    case second

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .first:
            return "Rest Break 1"
        case .second:
            return "Rest Break 2"
        }
    }
}

enum ShiftEventType: String, Codable, CaseIterable, Hashable {
    /// A "started" event is also the employee's acceptance of the scheduled
    /// paid rest break.
    case restBreak1Started = "rest_break_1_started"
    case restBreak1Ended = "rest_break_1_ended"
    case restBreak1NotTaken = "rest_break_1_not_taken"

    case restBreak2Started = "rest_break_2_started"
    case restBreak2Ended = "rest_break_2_ended"
    case restBreak2NotTaken = "rest_break_2_not_taken"

    var breakSlot: RestBreakSlot {
        switch self {
        case .restBreak1Started,
             .restBreak1Ended,
             .restBreak1NotTaken:
            return .first

        case .restBreak2Started,
             .restBreak2Ended,
             .restBreak2NotTaken:
            return .second
        }
    }

    var isNotTaken: Bool {
        self == .restBreak1NotTaken ||
        self == .restBreak2NotTaken
    }
}

struct ShiftEventRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let type: ShiftEventType
    let occurredAt: Date
    let biometricVerified: Bool
    let beaconVerified: Bool
    let note: String?
}

struct ShiftSchedule: Codable, Hashable, Identifiable {
    let id: UUID
    let employeeID: UUID
    let employeeNumber: String
    let employeeName: String
    let department: Department
    let workDate: String

    let shiftStart: Date
    let break1Start: Date
    let lunchStart: Date
    let break2Start: Date
    let shiftEnd: Date

    let restBreakDurationMinutes: Int
    let lunchDurationMinutes: Int

    func scheduledStart(
        for slot: RestBreakSlot
    ) -> Date {
        slot == .first
            ? break1Start
            : break2Start
    }

    func scheduledEnd(
        for slot: RestBreakSlot
    ) -> Date {
        scheduledStart(for: slot)
            .addingTimeInterval(
                TimeInterval(
                    restBreakDurationMinutes * 60
                )
            )
    }

    var legalDefaultRecommendation:
        CaliforniaRestBreakPolicy.Recommendation
    {
        CaliforniaRestBreakPolicy
            .recommendedBreakStarts(
                shiftStart: shiftStart,
                lunchStart: lunchStart,
                lunchDurationMinutes:
                    lunchDurationMinutes,
                shiftEnd: shiftEnd
            )
    }
}

struct MyShiftResponse: Codable, Hashable {
    let schedule: ShiftSchedule
    let events: [ShiftEventRecord]
    let weeklyHoursWorked: Double
    let projectedWeeklyHours: Double
    let projectedOvertimeHours: Double
}

struct RecordShiftEventRequest: Codable {
    let shiftAssignmentID: UUID
    let type: ShiftEventType
    let biometricVerified: Bool
    let beaconVerified: Bool
    let note: String?
}

struct RecordShiftEventResponse: Codable {
    let success: Bool
    let event: ShiftEventRecord
    let message: String?
}

struct SupervisorScheduleRow: Codable, Hashable, Identifiable {
    let id: UUID
    let employeeID: UUID
    let employeeNumber: String
    let employeeName: String
    let department: Department

    let shiftStart: Date
    let break1Start: Date
    let lunchStart: Date
    let break2Start: Date
    let shiftEnd: Date

    let restBreakDurationMinutes: Int
    let lunchDurationMinutes: Int

    let break1AdjustmentReason: String?
    let break2AdjustmentReason: String?

    var recommendedBreaks:
        CaliforniaRestBreakPolicy.Recommendation
    {
        CaliforniaRestBreakPolicy
            .recommendedBreakStarts(
                shiftStart: shiftStart,
                lunchStart: lunchStart,
                lunchDurationMinutes:
                    lunchDurationMinutes,
                shiftEnd: shiftEnd
            )
    }
}

struct SupervisorScheduleResponse: Codable, Hashable {
    let workDate: String
    let rows: [SupervisorScheduleRow]
}

struct UpdateShiftScheduleRequest: Codable {
    let shiftAssignmentID: UUID
    let break1Start: Date
    let break2Start: Date
    let break1AdjustmentReason: String?
    let break2AdjustmentReason: String?
}

struct UpdateShiftScheduleResponse: Codable {
    let success: Bool
    let row: SupervisorScheduleRow
    let message: String?
}

struct ShiftNotificationPlan: Equatable {
    let break1StartWarning: Date
    let lunchWarning: Date
    let break2StartWarning: Date
    let clockOutWarning: Date

    static func make(
        schedule: ShiftSchedule,
        restBreakWarningMinutes: Int =
            AppConfig.restBreakStartWarningMinutes,
        mealAndClockOutWarningMinutes: Int =
            AppConfig.mealAndClockOutWarningMinutes
    ) -> ShiftNotificationPlan {
        let breakSeconds = TimeInterval(
            restBreakWarningMinutes * 60
        )

        let generalSeconds = TimeInterval(
            mealAndClockOutWarningMinutes * 60
        )

        return ShiftNotificationPlan(
            break1StartWarning:
                schedule.break1Start
                    .addingTimeInterval(
                        -breakSeconds
                    ),
            lunchWarning:
                schedule.lunchStart
                    .addingTimeInterval(
                        -generalSeconds
                    ),
            break2StartWarning:
                schedule.break2Start
                    .addingTimeInterval(
                        -breakSeconds
                    ),
            clockOutWarning:
                schedule.shiftEnd
                    .addingTimeInterval(
                        -generalSeconds
                    )
        )
    }
}
