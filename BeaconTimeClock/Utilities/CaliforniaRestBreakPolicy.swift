import Foundation

/// Scheduling helper for the capstone's California manufacturing workflow.
///
/// California Wage Order 1 requires covered employees to be authorized and
/// permitted a net 10-minute paid rest period for each four hours worked or
/// major fraction, and says the rest period should be near the middle of each
/// work period insofar as practicable.
///
/// This helper does NOT decide whether a particular real-world schedule is
/// legally compliant. It gives the app safe defaults and prevents obviously
/// invalid schedules such as placing Rest Break 1 after lunch or Rest Break 2
/// before lunch ends. Company HR/counsel should approve final production rules.
enum CaliforniaRestBreakPolicy {

    static let minimumRestMinutes = 10
    static let minimumMealMinutes = 30

    struct Recommendation: Equatable {
        let break1Start: Date
        let break2Start: Date
    }

    enum ValidationError: LocalizedError, Equatable {
        case restBreakTooShort
        case mealTooShort
        case mealStartsTooLate
        case firstBreakOutsideFirstWorkPeriod
        case secondBreakOutsideSecondWorkPeriod

        var errorDescription: String? {
            switch self {
            case .restBreakTooShort:
                return "California rest periods must provide at least 10 net minutes."
            case .mealTooShort:
                return "The configured meal period must be at least 30 minutes."
            case .mealStartsTooLate:
                return "For this 8-hour manufacturing schedule, lunch must begin no later than the end of the fifth hour."
            case .firstBreakOutsideFirstWorkPeriod:
                return "Rest Break 1 must fit inside the first work period before lunch."
            case .secondBreakOutsideSecondWorkPeriod:
                return "Rest Break 2 must fit inside the second work period after lunch."
            }
        }
    }

    /// Recommended starts are the midpoints of the two work periods.
    ///
    /// Example:
    /// 7:00 AM shift start
    /// 11:30 AM lunch
    /// 12:00 PM lunch end
    /// 3:30 PM shift end
    ///
    /// Recommended starts:
    /// Break 1 ≈ 9:15 AM
    /// Break 2 ≈ 1:45 PM
    static func recommendedBreakStarts(
        shiftStart: Date,
        lunchStart: Date,
        lunchDurationMinutes: Int,
        shiftEnd: Date
    ) -> Recommendation {
        let lunchEnd = lunchStart.addingTimeInterval(
            TimeInterval(lunchDurationMinutes * 60)
        )

        return Recommendation(
            break1Start: midpoint(
                shiftStart,
                lunchStart
            ),
            break2Start: midpoint(
                lunchEnd,
                shiftEnd
            )
        )
    }

    /// Validates the boundaries we can safely enforce in software.
    ///
    /// We deliberately do not invent a fixed legal "one-hour window" around
    /// the midpoint because California's rule is "insofar as practicable."
    static func validate(
        shiftStart: Date,
        break1Start: Date,
        lunchStart: Date,
        lunchDurationMinutes: Int,
        break2Start: Date,
        shiftEnd: Date,
        restBreakDurationMinutes: Int
    ) throws {
        guard restBreakDurationMinutes >= minimumRestMinutes else {
            throw ValidationError.restBreakTooShort
        }

        guard lunchDurationMinutes >= minimumMealMinutes else {
            throw ValidationError.mealTooShort
        }

        guard lunchStart <= shiftStart.addingTimeInterval(5 * 3600) else {
            throw ValidationError.mealStartsTooLate
        }

        let restDuration = TimeInterval(
            restBreakDurationMinutes * 60
        )

        let lunchEnd = lunchStart.addingTimeInterval(
            TimeInterval(lunchDurationMinutes * 60)
        )

        guard break1Start > shiftStart,
              break1Start.addingTimeInterval(restDuration) <= lunchStart else {
            throw ValidationError.firstBreakOutsideFirstWorkPeriod
        }

        guard break2Start >= lunchEnd,
              break2Start.addingTimeInterval(restDuration) <= shiftEnd else {
            throw ValidationError.secondBreakOutsideSecondWorkPeriod
        }
    }

    static func isAdjusted(
        actual: Date,
        recommended: Date,
        toleranceSeconds: TimeInterval = 60
    ) -> Bool {
        abs(actual.timeIntervalSince(recommended)) > toleranceSeconds
    }

    private static func midpoint(
        _ start: Date,
        _ end: Date
    ) -> Date {
        start.addingTimeInterval(
            end.timeIntervalSince(start) / 2
        )
    }
}
