// FILE PURPOSE: Draws HR-friendly PDF timesheets, department forms and daily punch details.
import Foundation
import UIKit

/// Produces payroll-entry PDFs, not automatic payroll submissions.
/// IMPORTANT: This exports AUTHORITATIVE backend weekly totals; it does not
/// recalculate wages or apply California overtime rules on the iPhone.
// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
enum PayrollPDFExporter {
    private static let paper = CGRect(x: 0, y: 0, width: 792, height: 612)
    private static let left: CGFloat = 32
    private static let right: CGFloat = 760
    private static let maxY: CGFloat = 542

    /// One summary FORM starts each department section, followed by employee
    /// daily detail pages. A single-department export produces only that form.
    // Draw a PDF file and return a file URL for preview or sharing.
    static func export(sheets: [DepartmentTimesheet]) throws -> URL {
        guard !sheets.isEmpty,
              Set(sheets.map(\.department)).count == sheets.count,
              let first = sheets.first,
              sheets.allSatisfy({
                  ($0.status == .approved || $0.status == .sentToHR) &&
                  $0.signaturePresent && $0.signedAt != nil &&
                  !$0.hasUnresolvedExceptions &&
                  $0.weekStart == first.weekStart &&
                  $0.weekEnd == first.weekEnd
              }) else { throw HRPayrollError.incomplete }

        let period = "\(first.weekStart) to \(first.weekEnd)"
        // Use Apple's PDF renderer to create a shareable payroll document.
        let renderer = UIGraphicsPDFRenderer(bounds: paper)
        let data = renderer.pdfData { context in
            var pageNo = 0
            for sheet in sheets.sorted(by: {
                $0.department.sortOrder < $1.department.sortOrder
            }) {
                writeDepartmentForm(sheet, period: period,
                                    context: context, pageNo: &pageNo)
                for employee in sheet.employees.sorted(by: {
                    $0.employeeID < $1.employeeID
                }) {
                    writeDailyDetail(employee, sheet: sheet, period: period,
                                     context: context, pageNo: &pageNo)
                }
            }
        }

        // Use a unique file to avoid accidentally sharing an older pay period.
        let fileName = sheets.count == 1
            ? "Beacon_\(sheets[0].department.rawValue)_HR_\(first.weekStart).pdf"
            : "Beacon_All_5_Departments_HR_\(first.weekStart).pdf"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true)
        let output = url.appendingPathComponent(fileName)
        try data.write(to: output, options: [.atomic, .completeFileProtection])
        return output
    }

    // Start an individual department form with totals and HR entry fields.
    private static func writeDepartmentForm(
        _ sheet: DepartmentTimesheet, period: String,
        context: UIGraphicsPDFRendererContext, pageNo: inout Int
    ) {
        startPage(context, title: "\(sheet.department.displayName)  -  Payroll Entry Form",
                  period: period, pageNo: &pageNo)
        draw("ONE FORM PER DEPARTMENT  |  SUPERVISOR-APPROVED SOURCE", x: left, y: 91,
             width: 710, font: .boldSystemFont(ofSize: 10))
        draw("Supervisor: \(sheet.supervisorName ?? "-")", x: left, y: 113,
             width: 360, font: .systemFont(ofSize: 10))
        draw("Signed: \(sheet.signedAt.map { dateTime($0) } ?? "-")", x: 403,
             y: 113, width: 350, font: .systemFont(ofSize: 10))
        draw("Pay period: \(period)  |  Employees: \(sheet.employees.count)",
             x: left, y: 136, width: 708, font: .systemFont(ofSize: 10))
        draw("HR: Enter the following verified totals in the payroll system, then mark each row.",
             x: left, y: 156, width: 708, font: .systemFont(ofSize: 9))

        let widths: [CGFloat] = [83, 215, 84, 84, 83, 88, 90]
        tableHeader(["Emp. ID", "Employee", "Regular h", "OT h", "Total h", "Entered?", "HR Initial"],
                    widths: widths, y: 181)
        var y: CGFloat = 208
        for employee in sheet.employees.sorted(by: { $0.employeeID < $1.employeeID }) {
            if y + 26 > maxY {
                // Handles departments larger than the six employee demo set.
                startPage(context, title: "\(sheet.department.displayName) Form (continued)",
                          period: period, pageNo: &pageNo)
                tableHeader(["Emp. ID", "Employee", "Regular h", "OT h", "Total h", "Entered?", "HR Initial"],
                            widths: widths, y: 91)
                y = 118
            }
            tableRow([employee.employeeID, employee.employeeName,
                      hours(employee.regularHours), hours(employee.overtimeHours),
                      hours(employee.totalHours), "[  ]", "________"],
                     widths: widths, y: y, rowHeight: 27)
            y += 27
        }
        y += 12
        if y + 95 > maxY {
            startPage(context, title: "\(sheet.department.displayName) Sign-off (continued)",
                      period: period, pageNo: &pageNo)
            y = 98
        }
        draw("DEPARTMENT TOTAL", x: left, y: y, width: 200,
             font: .boldSystemFont(ofSize: 10))
        draw("REG  \(hours(sheet.regularHours))     OT  \(hours(sheet.overtimeHours))" +
             "     ALL  \(hours(sheet.totalHours))", x: 238, y: y,
             width: 490, font: .boldSystemFont(ofSize: 10))
        y += 30
        draw("HR processed by: _____________________   Date: ______________   Batch ID: ______________",
             x: left, y: y, width: 728, font: .systemFont(ofSize: 10))
        draw("Exceptions or entry notes: ________________________________________________________________",
             x: left, y: y + 27, width: 728, font: .systemFont(ofSize: 9))
        draw("Source totals are weekly; validate daily overtime, premiums and employer policy before payroll.",
             x: left, y: y + 48, width: 728, font: .italicSystemFont(ofSize: 8))
    }

    // Produce the daily punches and break rows for a payroll PDF.
    private static func writeDailyDetail(
        _ employee: EmployeeWeeklySummary, sheet: DepartmentTimesheet,
        period: String, context: UIGraphicsPDFRendererContext, pageNo: inout Int
    ) {
        startPage(context, title: "\(sheet.department.displayName)  /  \(employee.employeeName)",
                  period: period, pageNo: &pageNo)
        draw("Employee ID: \(employee.employeeID)   |   " +
             "Regular: \(hours(employee.regularHours))   OT: \(hours(employee.overtimeHours))" +
             "   Total: \(hours(employee.totalHours))", x: left, y: 90,
             width: 720, font: .boldSystemFont(ofSize: 10))
        draw("Approved punch timestamps (Pacific). Breaks are paid; lunch is separate.",
             x: left, y: 111, width: 720, font: .systemFont(ofSize: 9))

        let columns: [CGFloat] = [91, 89, 89, 89, 89, 89, 89, 103]
        tableHeader(["Workday", "Clock In", "Lunch Out", "Lunch In", "Clock Out",
                     "Rest 1", "Rest 2", "Review"], widths: columns, y: 137)
        guard let monday = parseDate(sheet.weekStart) else { return }
        let grouped = workdayPunches(employee.punches)
        var y: CGFloat = 164
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset,
                                          to: monday) else { continue }
            let key = calendar.startOfDay(for: day)
            let punches = grouped[key] ?? []
            let types = Dictionary(grouping: punches, by: { $0.type })
            let maxCount = max(1, types.values.map(\.count).max() ?? 0)
            let events = employee.shiftEvents.filter {
                calendar.isDate($0.occurredAt, inSameDayAs: day)
            }
            for index in 0..<maxCount {
                let clockIn = types[.clockIn]?[safe: index]
                let lunchOut = types[.lunchOut]?[safe: index]
                let lunchIn = types[.lunchIn]?[safe: index]
                let clockOut = types[.clockOut]?[safe: index]
                let changed = [clockIn, lunchOut, lunchIn, clockOut]
                    .compactMap { $0 }.contains(where: { $0.isAdjusted })
                let missing = !punches.isEmpty &&
                    [clockIn, lunchOut, lunchIn, clockOut].contains(where: { $0 == nil })
                let rest1 = index == 0 ? breakStatus(events, slot: .first) : ""
                let rest2 = index == 0 ? breakStatus(events, slot: .second) : ""
                let review = changed ? "Adjusted" : missing ? "Incomplete" : ""
                let label = index == 0 ? dayLabel(day) : "Extra shift"
                tableRow([label, time(clockIn, key), time(lunchOut, key),
                          time(lunchIn, key), time(clockOut, key), rest1, rest2, review],
                         widths: columns, y: y, rowHeight: 34)
                y += 34
            }
        }
        draw("* +1 means the punch occurred next calendar day (overnight shift).", x: left,
             y: y + 17, width: 720, font: .systemFont(ofSize: 9))
        draw("Rest events without explicit shift IDs are shown on their event date. Verify overnight breaks.",
             x: left, y: y + 35, width: 720, font: .systemFont(ofSize: 8))
        draw("Any missing or altered punch requires review of the source timesheet and audit reason.",
             x: left, y: y + 52, width: 720, font: .systemFont(ofSize: 8))
    }

    private static func startPage(_ context: UIGraphicsPDFRendererContext,
                                  title: String, period: String,
                                  pageNo: inout Int) {
        context.beginPage()
        pageNo += 1
        UIColor(red: 0.12, green: 0.19, blue: 0.31, alpha: 1).setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 792, height: 9))
        draw("BEACONTIMECLOCK / HR PAYROLL", x: left, y: 20, width: 500,
             font: .boldSystemFont(ofSize: 15))
        draw(title, x: left, y: 45, width: 560,
             font: .boldSystemFont(ofSize: 12))
        draw(period, x: 594, y: 48, width: 164,
             font: .systemFont(ofSize: 9), alignment: .right)
        UIColor.lightGray.setFill()
        UIRectFill(CGRect(x: left, y: 76, width: 728, height: 1))
        draw("CONFIDENTIAL - HR/ADMIN ONLY   |   Manual payroll entry - not confirmation of submission" +
             "   |   Page \(pageNo)", x: left, y: 576, width: 728,
             font: .systemFont(ofSize: 8), color: .darkGray)
    }

    private static func hours(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: AppConfig.companyTimeZoneIdentifier) ?? .current
        c.firstWeekday = 2
        return c
    }

    private static func parseDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: text)
    }

    private static func dayLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEE MM/dd"
        return f.string(from: day)
    }

    private static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = "MM/dd/yyyy h:mm a"
        return f.string(from: date)
    }

    private static func time(_ punch: PunchRecord?, _ workday: Date) -> String {
        guard let punch else { return "–" }
        let f = DateFormatter()
        f.timeZone = calendar.timeZone
        f.dateFormat = "h:mm a"
        let nextDay = calendar.isDate(punch.effectiveOccurredAt, inSameDayAs: workday)
            ? "" : " +1"
        return f.string(from: punch.effectiveOccurredAt) + nextDay
    }

    private static func breakStatus(_ events: [WeeklyShiftEventRecord],
                                     slot: RestBreakSlot) -> String {
        let selected = events.filter { $0.type.breakSlot == slot }
        if selected.isEmpty { return "–" }
        if selected.contains(where: { $0.type.isNotTaken }) { return "NOT taken" }
        let ended = selected.contains { item in
            item.type == (slot == .first ? .restBreak1Ended : .restBreak2Ended)
        }
        return ended ? "Taken" : "Started"
    }

    private static func workdayPunches(_ records: [PunchRecord]) -> [Date: [PunchRecord]] {
        var result: [Date: [PunchRecord]] = [:]
        var activeStart: Date?
        for punch in records.sorted(by: { $0.effectiveOccurredAt < $1.effectiveOccurredAt }) {
            if punch.type == .clockIn { activeStart = punch.effectiveOccurredAt }
            let date = calendar.startOfDay(for: activeStart ?? punch.effectiveOccurredAt)
            result[date, default: []].append(punch)
            if punch.type == .clockOut { activeStart = nil }
        }
        return result
    }

    private static func tableHeader(_ texts: [String], widths: [CGFloat], y: CGFloat) {
        UIColor(white: 0.90, alpha: 1).setFill()
        UIRectFill(CGRect(x: left, y: y, width: widths.reduce(0, +), height: 26))
        tableText(texts, widths: widths, y: y + 4, bold: true)
    }

    private static func tableRow(_ texts: [String], widths: [CGFloat],
                                 y: CGFloat, rowHeight: CGFloat) {
        UIColor(white: 0.83, alpha: 1).setFill()
        UIRectFill(CGRect(x: left, y: y + rowHeight - 1, width: widths.reduce(0, +), height: 0.7))
        tableText(texts, widths: widths, y: y + 6, bold: false)
    }

    private static func tableText(_ texts: [String], widths: [CGFloat],
                                  y: CGFloat, bold: Bool) {
        var x = left
        for (text, width) in zip(texts, widths) {
            draw(text, x: x + 4, y: y, width: width - 8,
                 font: bold ? .boldSystemFont(ofSize: 9) : .systemFont(ofSize: 9))
            x += width
        }
    }

    private static func draw(_ text: String, x: CGFloat, y: CGFloat,
                             width: CGFloat, font: UIFont,
                             color: UIColor = .black,
                             alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(
            in: CGRect(x: x, y: y, width: width, height: 22),
            withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
