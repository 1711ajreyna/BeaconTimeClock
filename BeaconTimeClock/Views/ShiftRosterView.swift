// FILE PURPOSE: Supervisor shift roster, creation and employee assignment navigation.
import SwiftUI

/// New supervisor-facing screen. Other supervisor features remain in Approvals
/// and Schedules (individual break-time adjustment).
// This type groups related state and behavior under a clear responsibility.
struct ShiftRosterView: View {
    // MARK: - State
    // SwiftUI owns and preserves this observable object across view redraws.
    @StateObject private var viewModel: ShiftRosterViewModel
    @State private var showingCreate = false // Sheet for new shifts.
    @State private var selectedShift: WorkShift? // Which roster to edit.

    // Create this object with the dependencies or state it needs; avoid hidden global services.
    init(viewModel: ShiftRosterViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // The SwiftUI body describes the visible screen from the current state.
    var body: some View {
        // Maintain a navigation path and allow drill-down screens.
        NavigationStack {
            List {
                Section {
                    BrandHeaderView(subtitle: "Department Rosters")
                }
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
                            // Stable accessibility ID allows repeatable XCUITest element lookup.
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
            .cscListStyle()
            .navigationTitle("Shift Rosters")
            .toolbar {
                Button("New Shift", systemImage: "plus") {
                    showingCreate = true
                }
                // Stable accessibility ID allows repeatable XCUITest element lookup.
                .accessibilityIdentifier("new_shift_button")
            }
            // Start asynchronous work when SwiftUI presents this view; handle loading and errors.
            .task { await viewModel.load() }
            // Enable pull-to-refresh without duplicating API logic.
            .refreshable { await viewModel.load() }
            // Open a modal editor while keeping its state owned by the parent view.
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
            // Open a modal editor while keeping its state owned by the parent view.
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
