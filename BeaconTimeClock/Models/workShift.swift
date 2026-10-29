import Foundation

// MARK: - Named Work Shift

/// A supervisor-created, dated shift for one department.
/// Absolute Date values allow night shifts to finish the following day.
struct WorkShift: Identifiable, Codable, Hashable {
    let id: UUID // Unique database ID for this shift.
    let name: String // e.g., "Morning", "Evening", "Night".
    let department: Department // Supervisor's assigned department.
    let workDate: String // Day shift BEGINS, formatted YYYY-MM-DD.
    let startTime: Date // Actual beginning instant.
    let endTime: Date // May be on the next calendar day.
    let break1Start: Date // Recommended first paid rest period.
    let lunchStart: Date // Scheduled unpaid meal start.
    let break2Start: Date // Recommended second paid rest period.
    let lunchDurationMinutes: Int // Usually 30.
    let restBreakDurationMinutes: Int // Usually 10.

    /// Useful for a UI row without recalculating elapsed time.
    var elapsedHours: Double {
        DateFormatting.elapsedHours(from: startTime, to: endTime)
    }

    /// The current employee screen supports exactly two rest-break slots.
    /// New templates are limited to a standard 8 paid-hour day until we build
    /// configurable rest-break counts for short/extended shifts.
    static func makeEightHourShift(
        name: String,
        department: Department,
        workDate: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) throws -> WorkShift {
        let start = try DateFormatting.companyDate(
            on: workDate, hour: startHour, minute: startMinute
        )
        let end = try DateFormatting.resolvedShiftEnd(
            start: start, endHour: endHour, endMinute: endMinute
        )
        let mealMinutes = AppConfig.lunchDurationMinutes
        let restMinutes = AppConfig.restBreakDurationMinutes

        // We can teach/payroll-test a standard eight paid-hour shift first.
        let paidHours = DateFormatting.elapsedHours(from: start, to: end)
            - Double(mealMinutes) / 60
        guard abs(paidHours - 8) < 0.01 else {
            throw ShiftError.unsupportedDuration
        }

        // Place meal after 4.5 elapsed hours: by the fifth-hour boundary.
        let lunch = start.addingTimeInterval(4.5 * 3600)
        let recommended = CaliforniaRestBreakPolicy.recommendedBreakStarts(
            shiftStart: start,
            lunchStart: lunch,
            lunchDurationMinutes: mealMinutes,
            shiftEnd: end
        )
        try CaliforniaRestBreakPolicy.validate(
            shiftStart: start,
            break1Start: recommended.break1Start,
            lunchStart: lunch,
            lunchDurationMinutes: mealMinutes,
            break2Start: recommended.break2Start,
            shiftEnd: end,
            restBreakDurationMinutes: restMinutes
        )
        return WorkShift(
            id: UUID(), name: name, department: department,
            workDate: DateFormatting.companyDateKey(start),
            startTime: start, endTime: end,
            break1Start: recommended.break1Start, lunchStart: lunch,
            break2Start: recommended.break2Start,
            lunchDurationMinutes: mealMinutes,
            restBreakDurationMinutes: restMinutes
        )
    }

    enum ShiftError: LocalizedError {
        case unsupportedDuration
        var errorDescription: String? {
            "This version supports standard eight paid-hour shifts (8.5 elapsed hours including lunch)."
        }
    }
}

// MARK: - Roster / Employee Assignments

/// One employee scheduled to work one named shift.
struct WorkShiftAssignment: Identifiable, Codable, Hashable {
    let id: UUID // Unique assignment ID.
    let employeeID: UUID // Employee database ID.
    let employeeNumber: String // HR-friendly identifier.
    let employeeName: String // Supervisor display name.
    let shiftID: UUID // Connects the employee to WorkShift.id.
}

/// One network response includes shifts, assigned people, and available staff.
struct ShiftRosterResponse: Codable {
    let shifts: [WorkShift]
    let assignments: [WorkShiftAssignment]
    let employees: [RosterEmployee]
}

/// Minimal employee data needed by the assignment picker.
struct RosterEmployee: Identifiable, Codable, Hashable {
    let id: UUID
    let employeeNumber: String
    let employeeName: String
    let department: Department
}

// MARK: - API Contracts

/// Request to create one named shift in the chosen department/date.
struct CreateWorkShiftRequest: Codable {
    let shift: WorkShift
}

/// Request to add an employee to a specific named shift.
struct AssignWorkShiftRequest: Codable {
    let shiftID: UUID
    let employeeID: UUID
}

/// Request to remove an assignment without deleting the employee.
struct RemoveWorkShiftAssignmentRequest: Codable {
    let assignmentID: UUID
}
