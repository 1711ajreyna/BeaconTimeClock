import Foundation

/// Converts dates between Beacon, the backend, and the employee's local screen.
/// "Date" always represents an absolute instant. A Calendar/TimeZone decides
/// what that instant looks like on a company schedule.
enum DateFormatting {

    // MARK: - JSON Encoder

    /// Reusable encoder for sending Swift models to Supabase as JSON.
    static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder() // Construct the formatter one time.
        encoder.dateEncodingStrategy = .iso8601 // Example: 2026-10-19T13:00:00Z.
        return encoder // Share this configuration across API calls.
    }()

    // MARK: - JSON Decoder

    /// Reusable decoder for reading Supabase JSON responses.
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder() // Construct the JSON reader one time.
        decoder.dateDecodingStrategy = .iso8601 // Interpret ISO-8601 timestamps.
        return decoder // Share it across API calls.
    }()

    // MARK: - Company Time Zone

    /// Company schedules use Pacific time, not the phone's travel time zone.
    static var companyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian) // Conventional calendar.
        calendar.timeZone = TimeZone(
            identifier: AppConfig.companyTimeZoneIdentifier
        ) ?? .current // Fallback only if configuration is invalid.
        calendar.firstWeekday = 2 // Monday starts the displayed workweek.
        return calendar
    }

    /// Converts the company-local date to the database-friendly YYYY-MM-DD key.
    static func companyDateKey(_ date: Date) -> String {
        let formatter = DateFormatter() // Create a date-only formatter.
        formatter.calendar = companyCalendar
        formatter.timeZone = companyCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd" // Preserve leading zeroes.
        return formatter.string(from: date)
    }

    // MARK: - Build Shifts on a Specific Day

    enum ShiftDateError: LocalizedError {
        case invalidLocalTime

        var errorDescription: String? {
            "This clock time is not valid on that date in the company time zone."
        }
    }

    /// Builds an actual Date from a selected calendar day and a clock time.
    /// Example: Monday + 22:00 produces Monday at 10 PM Pacific.
    static func companyDate(
        on workDate: Date,
        hour: Int,
        minute: Int
    ) throws -> Date {
        let calendar = companyCalendar // Work in the company time zone.
        var parts = calendar.dateComponents(
            [.year, .month, .day], from: workDate
        ) // Keep only the requested local date.
        parts.hour = hour // Insert the desired hour (0 through 23).
        parts.minute = minute // Insert the desired minute (0 through 59).
        parts.second = 0
        parts.timeZone = calendar.timeZone

        guard let result = calendar.date(from: parts) else {
            throw ShiftDateError.invalidLocalTime
        }
        let actual = calendar.dateComponents([.hour, .minute], from: result)
        guard actual.hour == hour, actual.minute == minute else {
            // Avoid silently shifting nonexistent local times during DST.
            throw ShiftDateError.invalidLocalTime
        }
        return result
    }

    /// Creates a shift end when the supervisor selects only the clock time.
    /// If the end is at or before the start, the shift ends the following day.
    static func resolvedShiftEnd(
        start: Date,
        endHour: Int,
        endMinute: Int
    ) throws -> Date {
        let calendar = companyCalendar
        let todayEnd = try companyDate(
            on: start, hour: endHour, minute: endMinute
        )
        if todayEnd > start { return todayEnd } // Same-day shift.

        guard let nextDay = calendar.date(
            byAdding: .day, value: 1, to: start
        ) else {
            throw ShiftDateError.invalidLocalTime
        }
        return try companyDate(
            on: nextDay, hour: endHour, minute: endMinute
        ) // Overnight shift.
    }

    // MARK: - Work Hours

    /// Counts actual elapsed time (including crossing midnight or DST).
    static func elapsedHours(from start: Date, to end: Date) -> Double {
        max(0, end.timeIntervalSince(start) / 3600)
    }

    // MARK: - Week Formatting

    /// Renders a friendly week label; gracefully falls back to raw dates.
    static func friendlyWeek(start: String, end: String) -> String {
        let parser = DateFormatter() // Parse dates from Supabase.
        parser.calendar = companyCalendar
        parser.timeZone = companyCalendar.timeZone
        parser.dateFormat = "yyyy-MM-dd"

        guard let first = parser.date(from: start),
              let last = parser.date(from: end) else {
            return "\(start) – \(end)" // Never crash on malformed API dates.
        }
        let display = DateFormatter() // Human-readable label for the app.
        display.calendar = companyCalendar
        display.timeZone = companyCalendar.timeZone
        display.dateFormat = "MMM d"
        return "\(display.string(from: first)) – \(display.string(from: last))"
    }
}
