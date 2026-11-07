// FILE PURPOSE: Loads employee schedules and handles rest-break event actions.
import Foundation

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class MyShiftViewModel: ObservableObject {
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var response: MyShiftResponse?
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var errorMessage = ""
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published var statusMessage = ""
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var isLoading = false
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set) var isWorking = false

    // Dependency injection: tests can use a fake API and production can use real HTTP.
    private let api: WorkflowAPI
    private let beacon: BeaconManager
    private let biometric: BiometricManager
    private let notifications: NotificationScheduler
    let breakTimer: BreakTimerManager

    
    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        api: WorkflowAPI,
        beacon: BeaconManager,
        notifications: NotificationScheduler,
        biometric: BiometricManager = BiometricManager(),
        breakTimer: BreakTimerManager? = nil
    ) {
        self.api = api
        self.beacon = beacon
        self.notifications = notifications
        self.biometric = biometric
        self.breakTimer = breakTimer ?? BreakTimerManager()
    }


    // Refresh this screen from its API or local source of truth.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Await the workflow API instead of handling backend details directly in the ViewModel.
            let loaded = try await api.fetchMyShift()
            response = loaded
            errorMessage = ""
            await notifications.scheduleShiftWarnings(
                for: loaded.schedule
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Record that an employee accepted and began a paid rest break.
    func startBreak(_ slot: RestBreakSlot) async {
        guard let schedule = response?.schedule else {
            return
        }

        let type: ShiftEventType = slot == .first
            ? .restBreak1Started
            : .restBreak2Started

        await record(
            schedule: schedule,
            type: type,
            biometricVerified: false,
            note: nil
        )

        if errorMessage.isEmpty {
            breakTimer.start(
                slot: slot,
                minutes: schedule.restBreakDurationMinutes
            )
            await notifications.scheduleBreakCountdown(
                slot: slot,
                minutes: schedule.restBreakDurationMinutes
            )
        }
    }

    // Record the completion of an active paid rest break.
    func endBreak(_ slot: RestBreakSlot) async {
        guard let schedule = response?.schedule else {
            return
        }

        let type: ShiftEventType = slot == .first
            ? .restBreak1Ended
            : .restBreak2Ended

        await record(
            schedule: schedule,
            type: type,
            biometricVerified: false,
            note: nil
        )

        if errorMessage.isEmpty {
            breakTimer.stop()
            notifications.cancelBreakCountdown(
                slot: slot
            )
        }
    }

    /// "Not taken" is deliberately an exception event, not a legal waiver.
    /// The employee must biometrically acknowledge it.
    // Record a rest-break exception that must be reviewed.
    func markBreakNotTaken(
        _ slot: RestBreakSlot
    ) async {
        guard let schedule = response?.schedule else {
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await biometric.authenticate()

            let type: ShiftEventType = slot == .first
                ? .restBreak1NotTaken
                : .restBreak2NotTaken

            // Await the workflow API instead of handling backend details directly in the ViewModel.
            let result = try await api.recordShiftEvent(
                RecordShiftEventRequest(
                    shiftAssignmentID: schedule.id,
                    type: type,
                    biometricVerified: true,
                    beaconVerified: beacon.isInsideAllowedZone,
                    note: "Employee recorded scheduled rest break as not taken."
                )
            )

            statusMessage = result.message ?? "Break denial recorded for supervisor review."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// In production, employees can respond to the offered rest break starting
    /// with the two-minute warning. Demo mode keeps actions available so the
    /// workflow can be shown in class at any time of day.
    // Determine whether this break action is currently allowed.
    func canRespondToBreak(
        _ slot: RestBreakSlot,
        now: Date = Date()
    ) -> Bool {
        // Choose the explicit demo path; production must use real backend controls.
        if AppConfig.demoMode {
            return true
        }

        guard let schedule =
            response?.schedule
        else {
            return false
        }

        let scheduled =
            schedule
                .scheduledStart(
                    for: slot
                )

        let opens =
            scheduled
                .addingTimeInterval(
                    TimeInterval(
                        -AppConfig
                            .restBreakStartWarningMinutes
                        * 60
                    )
                )

        let closes: Date

        switch slot {
        case .first:
            closes =
                schedule
                    .lunchStart

        case .second:
            closes =
                schedule
                    .shiftEnd
        }

        return now >= opens &&
            now < closes
    }

    // Derive available/in-progress/completed status from saved break events.
    func state(for slot: RestBreakSlot) -> BreakState {
        guard let events = response?.events else {
            return .available
        }

        let slotEvents = events.filter {
            $0.type.breakSlot == slot
        }

        if slotEvents.contains(where: { $0.type.isNotTaken }) {
            return .notTaken
        }

        let startType: ShiftEventType = slot == .first
            ? .restBreak1Started
            : .restBreak2Started
        let endType: ShiftEventType = slot == .first
            ? .restBreak1Ended
            : .restBreak2Ended

        if slotEvents.contains(where: { $0.type == endType }) {
            return .completed
        }

        if slotEvents.contains(where: { $0.type == startType }) {
            return .inProgress
        }

        return .available
    }

    private func record(
        schedule: ShiftSchedule,
        type: ShiftEventType,
        biometricVerified: Bool,
        note: String?
    ) async {
        isWorking = true
        errorMessage = ""
        defer { isWorking = false }

        do {
            // Await the workflow API instead of handling backend details directly in the ViewModel.
            let result = try await api.recordShiftEvent(
                RecordShiftEventRequest(
                    shiftAssignmentID: schedule.id,
                    type: type,
                    biometricVerified: biometricVerified,
                    beaconVerified: beacon.isInsideAllowedZone,
                    note: note
                )
            )

            statusMessage = result.message ?? "Shift event logged."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    enum BreakState: Equatable {
        case available
        case inProgress
        case completed
        case notTaken
    }
}
