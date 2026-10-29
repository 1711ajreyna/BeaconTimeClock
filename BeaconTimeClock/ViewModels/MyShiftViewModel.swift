import Foundation

@MainActor
final class MyShiftViewModel: ObservableObject {
    @Published private(set) var response: MyShiftResponse?
    @Published var errorMessage = ""
    @Published var statusMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false

    private let api: WorkflowAPI
    private let beacon: BeaconManager
    private let biometric: BiometricManager
    private let notifications: NotificationScheduler
    let breakTimer: BreakTimerManager

    
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


    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
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
    func canRespondToBreak(
        _ slot: RestBreakSlot,
        now: Date = Date()
    ) -> Bool {
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
