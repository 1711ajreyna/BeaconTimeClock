// FILE PURPOSE: Monday–Sunday employee punch history and current shift break records.
import SwiftUI

/// Local history: the server remains the payroll source of truth.
/// Never show this device's other signed-in employees' cached punches.
// This type groups related state and behavior under a clear responsibility.
struct TimeCardsView: View {
    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var store: TimeCardStore
    // Read a shared dependency injected by BeaconTimeClockApp; do not create it here.
    @EnvironmentObject private var services: AppServices
    @State private var selectedWeek = Date()
    @State private var showClearError = false

    private var companyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: AppConfig.companyTimeZoneIdentifier)
            ?? .current
        calendar.firstWeekday = 2 // Monday to Sunday, company local time.
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var employeeNumber: String? {
        services.profile?.employeeNumber
    }

    private var myCards: [TimeCard] {
        guard let employeeNumber else { return [] }
        return store.timeCards
            .filter { $0.employeeID == employeeNumber }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var weekStart: Date {
        companyCalendar.dateInterval(of: .weekOfYear, for: selectedWeek)?.start
            ?? companyCalendar.startOfDay(for: selectedWeek)
    }

    private var days: [Date] {
        (0..<7).compactMap {
            companyCalendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    private var cardsByWorkday: [Date: [TimeCard]] {
        var grouped: [Date: [TimeCard]] = [:]
        var activeStart: Date?
        for card in myCards {
            if card.type == .clockIn { activeStart = card.timestamp }
            var day = companyCalendar.startOfDay(for: card.timestamp)
            if let start = activeStart,
               card.timestamp.timeIntervalSince(start) >= 0,
               card.timestamp.timeIntervalSince(start) <= 20 * 3600 {
                // Overnight punches belong to the shift's start day when
                // a complete, locally cached sequence is available.
                day = companyCalendar.startOfDay(for: start)
            }
            grouped[day, default: []].append(card)
            if card.type == .clockOut { activeStart = nil }
        }
        return grouped
    }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            List {
                Section {
                    BrandHeaderView(subtitle: "My Weekly Timecard")
                    HStack {
                        Button { moveWeek(-1) } label: {
                            Image(systemName: "chevron.left")
                                .accessibilityLabel("Previous week")
                        }
                        Spacer()
                        Text(weekLabel)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Spacer()
                        Button { moveWeek(1) } label: {
                            Image(systemName: "chevron.right")
                                .accessibilityLabel("Next week")
                        }
                    }
                }

                ForEach(days, id: \.self) { day in
                    Section(dateText(day)) {
                        let punches = cardsByWorkday[companyCalendar.startOfDay(for: day)] ?? []
                        if punches.isEmpty {
                            Text("No punches recorded")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(punches, id: \.id) { card in
                                HStack {
                                    Label(card.type.displayName, systemImage: card.type.systemImage)
                                        .foregroundStyle(CSCTheme.ink)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(timeText(card.timestamp))
                                            .monospacedDigit()
                                        Text(card.syncStatus.capitalized)
                                            .font(.caption2)
                                            .foregroundStyle(card.syncStatus == "synced" ? .green : .secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("These are this device's cached punches. Complete historical rest-breaks and authoritative weekly hours require the production weekly-history API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .cscListStyle()
            .navigationTitle("My Time")
            .toolbar {
                // Choose the explicit demo path; production must use real backend controls.
                if AppConfig.demoMode, let employeeNumber, !myCards.isEmpty {
                    Button("Clear My Demo") {
                        do {
                            try store.clearDemoPunches(for: employeeNumber)
                        } catch {
                            showClearError = true
                        }
                    }
                }
            }
            .alert("Unable to Clear", isPresented: $showClearError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func moveWeek(_ offset: Int) {
        selectedWeek = companyCalendar.date(
            byAdding: .weekOfYear, value: offset, to: selectedWeek
        ) ?? selectedWeek
    }

    private var weekLabel: String {
        let end = companyCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(dateText(weekStart)) – \(dateText(end))"
    }

    private func dateText(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = companyCalendar.timeZone
        formatter.locale = Locale(identifier: UserDefaults.standard.string(
            forKey: AppLocalization.storageKey
        ) ?? AppLanguage.english.rawValue)
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: value)
    }

    private func timeText(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = companyCalendar.timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: value)
    }
}
