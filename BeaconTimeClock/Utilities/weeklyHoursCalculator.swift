import Foundation

/// Shared calculation helpers used by demo mode and unit tests.
///
/// The production backend repeats the same concept server-side so payroll
/// totals cannot be trusted solely to the phone.
enum WeeklyHoursCalculator {

    struct Split: Equatable {
        let regular: Double
        let overtime: Double
        let total: Double
    }

    /// Simple weekly threshold used by the capstone/demo display.
    ///
    /// Actual payroll deployment should use HR-approved rules and configuration.
    static func split(
        totalHours: Double,
        regularLimit: Double = AppConfig.demoWeeklyRegularLimitHours
    ) -> Split {
        let safeTotal = max(0, totalHours)
        let regular = min(safeTotal, regularLimit)
        let overtime = max(safeTotal - regularLimit, 0)

        return Split(
            regular: rounded(regular),
            overtime: rounded(overtime),
            total: rounded(safeTotal)
        )
    }

    // MARK: - Worked Hours From Multiple Shifts

    /// Adds paid hours from concrete shift intervals; the subtraction is
    /// strictly for unpaid meals, never for paid 10-minute rest breaks.
    /// This is an educational projection, NOT a California payroll engine.
    static func projectedPaidHours(
        shifts: [WorkShift]
    ) -> Double {
        rounded(shifts.reduce(0) { runningTotal, shift in
            let elapsed = DateFormatting.elapsedHours(
                from: shift.startTime, to: shift.endTime
            )
            return runningTotal + max(
                0, elapsed - Double(shift.lunchDurationMinutes) / 60
            )
        })
    }

    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

/// Testable status used by SwiftUI to decide whether the hours should appear
/// green or red.
enum HoursIndicator: Equatable {
    case withinRegularLimit
    case overtime

    static func status(
        overtimeHours: Double
    ) -> HoursIndicator {
        overtimeHours > 0
            ? .overtime
            : .withinRegularLimit
    }
}

