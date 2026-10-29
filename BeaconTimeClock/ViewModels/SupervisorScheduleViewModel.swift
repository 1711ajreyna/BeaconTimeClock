import Foundation

@MainActor
final class SupervisorScheduleViewModel:
    ObservableObject
{
    @Published private(set)
    var response:
        SupervisorScheduleResponse?

    @Published
    var errorMessage = ""

    @Published
    var successMessage = ""

    @Published private(set)
    var isLoading = false

    private let api:
        WorkflowAPI

    init(
        api: WorkflowAPI
    ) {
        self.api = api
    }

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
