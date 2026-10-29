import SwiftUI

/// New supervisor-facing screen. Other supervisor features remain in Approvals
/// and Schedules (individual break-time adjustment).
struct ShiftRosterView: View {
    // MARK: - State
    @StateObject private var viewModel: ShiftRosterViewModel
    @State private var showingCreate = false // Sheet for new shifts.
    @State private var selectedShift: WorkShift? // Which roster to edit.

    init(viewModel: ShiftRosterViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if let roster = viewModel.roster {
                    Section("Company Shifts") {
                        ForEach(roster.shifts) { shift in
                            Button {
                                selectedShift = shift // Opens roster editor.
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(shift.name).font(.headline)
                                    Text(shift.department.displayName)
                                    Text("\(shift.startTime.formatted(date: .abbreviated, time: .shortened)) – \(shift.endTime.formatted(date: .abbreviated, time: .shortened))")
                                    Text("\(viewModel.assignments(for: shift).count) assigned employees")
                                }
                                .font(.subheadline)
                            }
                            .accessibilityIdentifier("roster_\(shift.name.lowercased())")
                        }
                    }
                }
                if viewModel.isLoading {
                    ProgressView("Loading shifts…")
                }
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage).foregroundStyle(.red)
                }
                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage).foregroundStyle(.green)
                }
            }
            .navigationTitle("Shift Rosters")
            .toolbar {
                Button("New Shift", systemImage: "plus") {
                    showingCreate = true
                }
                .accessibilityIdentifier("new_shift_button")
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showingCreate) {
                ShiftEditorView { name, department, day, sh, sm, eh, em in
                    Task {
                        let created = await viewModel.create(
                            name: name, department: department, workDate: day,
                            startHour: sh, startMinute: sm, endHour: eh, endMinute: em
                        )
                        if created { showingCreate = false }
                    }
                }
            }
            .sheet(item: $selectedShift) { shift in
                EmployeeAssignmentView(
                    shift: shift,
                    assignments: viewModel.assignments(for: shift),
                    availableEmployees: viewModel.availableEmployees(for: shift),
                    onAssign: { employeeID in
                        Task {
                            if await viewModel.assign(employeeID: employeeID, to: shift.id) {
                                selectedShift = nil // Reopen for refreshed roster.
                            }
                        }
                    },
                    onRemove: { assignmentID in
                        Task {
                            if await viewModel.remove(assignmentID: assignmentID) {
                                selectedShift = nil
                            }
                        }
                    }
                )
            }
        }
    }
}
