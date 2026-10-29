import Foundation

/// Manages one department's supervisor review.
@MainActor
final class DepartmentTimesheetViewModel: ObservableObject {

    @Published private(set)
    var timesheet: DepartmentTimesheet?

    @Published private(set)
    var isLoading = false

    @Published var errorMessage = ""
    @Published var successMessage = ""

    private let timesheetID: UUID
    private let api: WorkflowAPI

    init(
        timesheetID: UUID,
        api: WorkflowAPI
    ) {
        self.timesheetID = timesheetID
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            timesheet =
                try await api
                    .fetchDepartmentTimesheet(
                        timesheetID: timesheetID
                    )
            errorMessage = ""
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    /// Manual override is allowed only before approval.
    ///
    /// The backend never destroys the original punch; it creates an adjustment
    /// audit record and returns a recalculated packet.
    func adjustPunch(
        punchID: UUID,
        correctedDate: Date,
        reason: String
    ) async {
        guard timesheet?.status == .pending else {
            errorMessage =
                "Approved timesheets are locked."
            return
        }

        do {
            let response =
                try await api.adjustPunch(
                    PunchAdjustmentRequest(
                        timesheetID:
                            timesheetID,
                        punchID:
                            punchID,
                        correctedOccurredAt:
                            correctedDate,
                        reason:
                            reason
                    )
                )

            successMessage =
                response.message ??
                "Punch adjusted."

            await load()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    /// Sends the supervisor's drawn signature to the backend.
    ///
    /// The backend supplies signedAt, stores the signature privately, hashes
    /// the approved packet, and triggers the final HR merge when appropriate.
    func approve(
        supervisorName: String,
        signaturePNG: Data
    ) async -> Bool {
        guard let timesheet else {
            return false
        }

        guard !timesheet.hasUnresolvedExceptions else {
            errorMessage =
                "Resolve all punch exceptions before approval."
            return false
        }

        do {
            let result =
                try await api.approveDepartment(
                    ApproveDepartmentRequest(
                        timesheetID:
                            timesheetID,
                        supervisorPrintedName:
                            supervisorName,
                        signaturePNGBase64:
                            signaturePNG
                                .base64EncodedString()
                    )
                )

            successMessage =
                result.message ??
                "Timesheet approved."

            await load()
            return true

        } catch {
            errorMessage =
                error.localizedDescription
            return false
        }
    }
}
