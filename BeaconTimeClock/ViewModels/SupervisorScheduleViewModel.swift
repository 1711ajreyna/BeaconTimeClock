// FILE PURPOSE: Loads employee break schedules and submits supervisor adjustments.
import Foundation

// UI-observed state and these operations run on the main actor.
@MainActor
// This type groups related state and behavior under a clear responsibility.
final class SupervisorScheduleViewModel:
    ObservableObject
{
    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set)
    var response:
        SupervisorScheduleResponse?

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published
    var errorMessage = ""

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published
    var successMessage = ""

    // Notify SwiftUI subscribers whenever this stored state changes.
    @Published private(set)
    var isLoading = false

    private let api:
        WorkflowAPI

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(
        api: WorkflowAPI
    ) {
        self.api = api
    }

    // Refresh this screen from its API or local source of truth.
    func load() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            response =
                try await api
                    .fetchSupervisorSchedule()

            errorMessage = ""
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    /// Updates one employee's two paid rest-break times.
    ///
    /// If a break is moved away from the recommended midpoint, the UI requires
    /// a supervisor reason and the backend stores it for audit.
    // Send a schedule or attendance adjustment and refresh current data.
    func save(
        row:
            SupervisorScheduleRow,
        break1Start: Date,
        break2Start: Date,
        break1Reason: String?,
        break2Reason: String?
    ) async -> Bool {
        do {
            let result =
                try await api
                    .updateShiftSchedule(
                        UpdateShiftScheduleRequest(
                            shiftAssignmentID:
                                row.id,
                            break1Start:
                                break1Start,
                            break2Start:
                                break2Start,
                            break1AdjustmentReason:
                                break1Reason,
                            break2AdjustmentReason:
                                break2Reason
                        )
                    )

            successMessage =
                result.message ??
                "Employee rest-break schedule updated."

            errorMessage = ""

            await load()
            return true

        } catch {
            errorMessage =
                error.localizedDescription
            return false
        }
    }
}
