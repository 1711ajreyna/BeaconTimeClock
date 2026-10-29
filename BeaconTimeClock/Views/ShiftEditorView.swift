import SwiftUI

/// Creates a dated eight-paid-hour shift. Breaks are calculated automatically.
/// The current UI supports two paid rest breaks, not arbitrary shift lengths.
struct ShiftEditorView: View {
    // MARK: - Input Fields
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Morning" // Employee-friendly shift name.
    @State private var department: Department = .electrical
    @State private var workDate = Date()
    @State private var startHour = 6
    @State private var startMinute = 0
    @State private var endHour = 14
    @State private var endMinute = 30

    let onSave: (String, Department, Date, Int, Int, Int, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Shift Details") {
                    TextField("Shift name", text: $name)
                        .accessibilityIdentifier("shift_name_field")
                    Picker("Department", selection: $department) {
                        ForEach(Department.allCases) { dep in
                            Text(dep.displayName).tag(dep)
                        }
                    }
                    DatePicker("Work date", selection: $workDate, displayedComponents: .date)
                }
                Section("Start Time") {
                    Picker("Hour", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in Text("\(hour)").tag(hour) }
                    }
                    Picker("Minute", selection: $startMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in Text("\(minute)").tag(minute) }
                    }
                }
                Section("End Time") {
                    Picker("Hour", selection: $endHour) {
                        ForEach(0..<24, id: \.self) { hour in Text("\(hour)").tag(hour) }
                    }
                    Picker("Minute", selection: $endMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in Text("\(minute)").tag(minute) }
                    }
                }
                Section {
                    Text("An end clock time earlier than the start automatically means the next calendar day. This first version supports an 8-hour paid shift plus a 30-minute meal.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Shift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, department, workDate,
                               startHour, startMinute, endHour, endMinute)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save_shift_button")
                }
            }
        }
    }
}
