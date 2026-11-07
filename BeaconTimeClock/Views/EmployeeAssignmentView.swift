// FILE PURPOSE: Adds or removes employees from a selected shift roster.
import SwiftUI

/// Shows the supervisor who works this shift, and lets them change the roster.
// This type groups related state and behavior under a clear responsibility.
struct EmployeeAssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    let shift: WorkShift // Selected Morning/Evening/Night shift.
    let assignments: [WorkShiftAssignment] // Currently assigned employees.
    let availableEmployees: [RosterEmployee] // Same department, unassigned.
    let onAssign: (UUID) -> Void // Delegate writes to the ViewModel/API.
    let onRemove: (UUID) -> Void

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            List {
                Section("\(shift.name) — \(shift.department.displayName)") {
                    Text("\(shift.startTime.formatted()) – \(shift.endTime.formatted())")
                    Text("Shift starts on \(shift.workDate)")
                }
                Section("Assigned Employees — \(assignments.count)") {
                    if assignments.isEmpty { Text("Nobody assigned yet.") }
                    ForEach(assignments) { assignment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(assignment.employeeName)
                                Text(assignment.employeeNumber)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") { onRemove(assignment.id) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                Section("Add Employee") {
                    if availableEmployees.isEmpty {
                        Text("No unassigned employees in this department.")
                    }
                    ForEach(availableEmployees) { employee in
                        Button("Add \(employee.employeeName)") { onAssign(employee.id) }
                    }
                }
            }
            .navigationTitle("Shift Employees")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
