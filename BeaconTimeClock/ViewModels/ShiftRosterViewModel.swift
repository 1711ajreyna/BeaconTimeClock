
import Foundation

/// Manages the supervisor's shift roster screen.
/// Uses WorkflowAPI for demo and production operations.
@MainActor
final class ShiftRosterViewModel: ObservableObject {

    // MARK: - Published Screen State

    @Published private(set) var roster: ShiftRosterResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""

    // MARK: - API Dependency

    private let api: WorkflowAPI

    init(api: WorkflowAPI) {
        self.api = api
    }

    // MARK: - Load Shift Roster

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            roster = try await api.fetchShiftRoster()
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create a New Shift

    func create(
        name: String,
        department: Department,
        workDate: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) async -> Bool {

        do {
            let shift = try WorkShift.makeEightHourShift(
                name: name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                department: department,
                workDate: workDate,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute
            )

            _ = try await api.createWorkShift(
                CreateWorkShiftRequest(shift: shift)
            )

            successMessage = "Created \(shift.name) shift."
            await load()
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Assign Employee to Shift

    func assign(
        employeeID: UUID,
        to shiftID: UUID
    ) async -> Bool {

        do {
            _ = try await api.assignWorkShift(
                AssignWorkShiftRequest(
                    shiftID: shiftID,
                    employeeID: employeeID
                )
            )

            successMessage = "Employee added to this shift."
            await load()
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Remove Employee from Shift

    func remove(assignmentID: UUID) async -> Bool {

        do {
            try await api.removeWorkShiftAssignment(
                RemoveWorkShiftAssignmentRequest(
                    assignmentID: assignmentID
                )
            )

            successMessage = "Employee removed from the roster."
            await load()
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Current Shift Assignments

    func assignments(
        for shift: WorkShift
    ) -> [WorkShiftAssignment] {

        (roster?.assignments ?? [])
            .filter { $0.shiftID == shift.id }
            .sorted { $0.employeeName < $1.employeeName }
    }

    // MARK: - Available Employees

    func availableEmployees(
        for shift: WorkShift
    ) -> [RosterEmployee] {

        let assigned = Set(
            (roster?.assignments ?? []).map(\.employeeID)
        )

        return (roster?.employees ?? [])
            .filter {
                $0.department == shift.department &&
                !assigned.contains($0.id)
            }
            .sorted { $0.employeeName < $1.employeeName }
    }
}
