import Foundation

/// Safe display titles and filenames for Sunday-ending payroll weeks.
/// A PDF filename cannot contain '/' because it is a path separator.
enum PayrollReportNaming {
    enum NamingError: LocalizedError {
        case invalidWeekEnd, notSunday, invalidPrefix

        var errorDescription: String? {
            switch self {
            case .invalidWeekEnd: return "The payroll packet has an invalid week-ending date."
            case .notSunday: return "The payroll packet must end on a Sunday. Check the source week."
            case .invalidPrefix: return "Use a short PDF title with letters, numbers, spaces, or hyphens."
            }
        }
    }

    private static var calendar: Calendar { DateFormatting.companyCalendar }

    static func weekEndingSunday(_ isoDate: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: isoDate),
              formatter.string(from: date) == isoDate else { throw NamingError.invalidWeekEnd }
        guard calendar.component(.weekday, from: date) == 1 else { throw NamingError.notSunday }
        return date
    }

    /// Users can edit the PDF heading, but cannot silently relabel a signed week.
    static func sanitizedHeading(_ text: String) throws -> String {
        let heading = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " ")).union(CharacterSet(charactersIn: "-_"))
        guard !heading.isEmpty, heading.count <= 35,
              heading.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw NamingError.invalidPrefix
        }
        return heading
    }

    private static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func displayTitle(weekEnd: String, heading: String = "PAYROLL") throws -> String {
        let sunday = try weekEndingSunday(weekEnd)
        return "\(try sanitizedHeading(heading)) \(format(sunday, pattern: "dd/MM/yyyy"))"
    }

    static func fileName(weekEnd: String, heading: String = "PAYROLL",
                         department: Department?, demoPreview: Bool) throws -> String {
        let sunday = try weekEndingSunday(weekEnd)
        let cleanHeading = try sanitizedHeading(heading)
        let suffix = department.map { " - \($0.displayName.uppercased())" } ?? ""
        let demo = demoPreview ? " - DEMO ONLY" : ""
        return "\(cleanHeading) \(format(sunday, pattern: "dd-MM-yyyy"))\(suffix)\(demo).pdf"
    }
}
