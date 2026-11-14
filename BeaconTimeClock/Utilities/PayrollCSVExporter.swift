// FILE PURPOSE: HR-only CSV exports with one payroll total per employee per week,
// and a separate work-date row for each shift (including overnight punches).
import Foundation

/// These files are designed for manual HR data entry, not unattended payroll import.
/// Export only approved, signed, exception-reviewed backend snapshots.
@MainActor
enum PayrollCSVExporter {
    enum Kind { case weeklyTotals, dailyPunches }

    static func export(sheets: [DepartmentTimesheet], kind: Kind) throws -> URL {
        guard !sheets.isEmpty,
              Set(sheets.map(\.department)).count == sheets.count,
              let first = sheets.first,
              sheets.allSatisfy({
                  ($0.status == .approved || $0.status == .sentToHR) &&
                  $0.signaturePresent && $0.signedAt != nil &&
                  !$0.hasUnresolvedExceptions &&
                  $0.weekStart == first.weekStart && $0.weekEnd == first.weekEnd
              }) else { throw HRPayrollError.incomplete }

        var rows: [[String]]
        switch kind {
        case .weeklyTotals:
            rows = [["Week Start", "Week End", "Department", "Employee ID",
                     "Employee Name", "Regular Hours", "Overtime Hours", "Total Hours"]]
        case .dailyPunches:
            rows = [["Week Start", "Week End", "Department", "Employee ID",
                     "Employee Name", "Work Date (Pacific)", "Shift #",
                     "Clock In", "Lunch Out", "Lunch In", "Clock Out", "Review"]]
        }

        for sheet in sheets.sorted(by: { $0.department.sortOrder < $1.department.sortOrder }) {
            for employee in sheet.employees.sorted(by: { $0.employeeID < $1.employeeID }) {
                let prefix = [sheet.weekStart, sheet.weekEnd, sheet.department.displayName,
                              employee.employeeID, employee.employeeName]
                switch kind {
                case .weeklyTotals:
                    rows.append(prefix + [hours(employee.regularHours),
                                          hours(employee.overtimeHours), hours(employee.totalHours)])
                case .dailyPunches:
                    appendDailyRows(for: employee, sheet: sheet, prefix: prefix, to: &rows)
                }
            }
        }

        // UTF-8 BOM improves Excel compatibility. Quote every cell, neutralize
        // spreadsheet formulas and keep each source field on one CSV line.
        let contents = "\u{FEFF}" + rows.map { $0.map(escape).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = kind == .weeklyTotals ? "Payroll_Weekly_Totals" : "Payroll_Daily_Punches"
        let file = folder.appendingPathComponent("Beacon_\(name)_\(first.weekStart).csv")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        // This is sensitive payroll data and should be protected at rest on iPhone/iPad.
        try (file as NSURL).setResourceValue(FileProtectionType.complete,
                                             forKey: .fileProtectionKey)
        return file
    }

    private static func appendDailyRows(
        for employee: EmployeeWeeklySummary, sheet: DepartmentTimesheet,
        prefix: [String], to rows: inout [[String]]
    ) {
        guard let monday = parseDay(sheet.weekStart) else { return }
        let grouped = workdayPunches(employee.punches)
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let key = calendar.startOfDay(for: date)
            let punches = grouped[key] ?? []
            guard !punches.isEmpty else { continue }
            let byType = Dictionary(grouping: punches, by: { $0.type })
            let count = byType.values.map(\.count).max() ?? 0
            for index in 0..<count {
                let clockIn = byType[.clockIn]?[safeCSV: index]
                let lunchOut = byType[.lunchOut]?[safeCSV: index]
                let lunchIn = byType[.lunchIn]?[safeCSV: index]
                let clockOut = byType[.clockOut]?[safeCSV: index]
                let oneShift = [clockIn, lunchOut, lunchIn, clockOut].compactMap { $0 }
                let adjusted = oneShift.contains(where: \.isAdjusted)
                let missingEnd = clockIn == nil || clockOut == nil
                let partialLunch = (lunchOut == nil) != (lunchIn == nil)
                var notes: [String] = []
                if adjusted { notes.append("Adjusted - check audit trail") }
                if missingEnd { notes.append("Missing clock in/out") }
                if partialLunch { notes.append("Incomplete lunch pair") }
                if employee.shiftEvents.contains(where: {
                    $0.isException && calendar.isDate($0.occurredAt, inSameDayAs: date)
                }) { notes.append("Break exception") }
                rows.append(prefix + [dayKey(date), String(index + 1),
                                      time(clockIn, workday: date),
                                      time(lunchOut, workday: date),
                                      time(lunchIn, workday: date),
                                      time(clockOut, workday: date),
                                      notes.joined(separator: "; ")])
            }
        }
    }

    private static var calendar: Calendar { DateFormatting.companyCalendar }

    private static func parseDay(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: text)
    }

    private static func dayKey(_ date: Date) -> String {
        DateFormatting.companyDateKey(date)
    }

    private static func hours(_ hours: Double) -> String { String(format: "%.2f", hours) }

    private static func time(_ punch: PunchRecord?, workday: Date) -> String {
        guard let punch else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = "h:mm a"
        let nextDay = calendar.isDate(punch.effectiveOccurredAt, inSameDayAs: workday)
            ? "" : " +1 day"
        return f.string(from: punch.effectiveOccurredAt) + nextDay
    }

    private static func workdayPunches(_ punches: [PunchRecord]) -> [Date: [PunchRecord]] {
        var grouped: [Date: [PunchRecord]] = [:]
        var activeShiftStart: Date?
        for punch in punches.sorted(by: { $0.effectiveOccurredAt < $1.effectiveOccurredAt }) {
            if punch.type == .clockIn { activeShiftStart = punch.effectiveOccurredAt }
            let workday = calendar.startOfDay(for: activeShiftStart ?? punch.effectiveOccurredAt)
            grouped[workday, default: []].append(punch)
            if punch.type == .clockOut { activeShiftStart = nil }
        }
        return grouped
    }

    private static func escape(_ raw: String) -> String {
        let flattened = raw.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let firstNonSpace = flattened.first(where: { !$0.isWhitespace })
        let safe = firstNonSpace.map({ "=+-@".contains($0) }) == true
            ? "'" + flattened : flattened
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

private extension Array {
    subscript(safeCSV index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
