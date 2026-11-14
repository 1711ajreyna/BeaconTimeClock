import SwiftUI

struct StaffManagementView: View {
    let profile: UserProfile
    let api: WorkflowAPI
    @State private var members: [StaffMember] = []
    @State private var query = ""
    @State private var editing: StaffMember?
    @State private var errorMessage: String?
    @State private var loading = true

    private var filtered: [StaffMember] {
        members.filter {
            profile.canSaveStaff($0, existing: $0) &&
            (query.isEmpty || "\($0.name) \($0.email) \($0.employeeNumber)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        List {
            Section {
                Text(AppConfig.demoMode
                     ? "DEMO ONLY: Staff use their email and Demo123!."
                     : "LIVE: New staff are invited by email. Requires secure deployed staff-list and staff-save functions.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if loading { ProgressView("Loading staff…") }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red); Button("Retry") { Task { await load() } } }
            }
            ForEach(filtered) { member in
                Button { editing = member } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name).font(.headline)
                        Text("\(member.employeeNumber) · \(member.role.rawValue.capitalized) · \(member.department?.displayName ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(member.email).font(.caption)
                        if !member.isActive { Text("Inactive").foregroundStyle(.secondary) }
                    }
                }
                .accessibilityIdentifier("staff_\(member.employeeNumber)")
            }
            if !loading && filtered.isEmpty { Text("No matching staff") }
        }
        .navigationTitle("Manage Staff")
        .searchable(text: $query, prompt: "Name, email, or employee number")
        .toolbar {
            Button { editing = StaffMember(id: UUID(), employeeID: nil, name: "", email: "",
                employeeNumber: "", role: .employee,
                department: profile.role == .supervisor ? profile.department : .electrical,
                isActive: true) } label: {
                Label("Add Staff", systemImage: "plus")
            }
            .accessibilityIdentifier("add_staff_button")
            .disabled(!profile.canManageStaffAccounts || loading || errorMessage != nil)
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { member in
            StaffEditor(member: member, isNew: !members.contains { $0.id == member.id },
                        originalMember: members.first { $0.id == member.id },
                        profile: profile, api: api) {
                await load()
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { members = try await api.fetchStaff(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct StaffEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var member: StaffMember
    let isNew: Bool
    /// Original server/demo state; compare edits against this, not the modified form.
    let originalMember: StaffMember?
    let profile: UserProfile
    let api: WorkflowAPI
    let didSave: () async -> Void
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Staff Details") {
                    TextField("Name", text: $member.name).accessibilityIdentifier("staff_name")
                    TextField("Email", text: $member.email)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
                        .disabled(!isNew && !AppConfig.demoMode)
                        .accessibilityIdentifier("staff_email")
                    TextField("Employee Number", text: $member.employeeNumber)
                        .disabled(!isNew).accessibilityIdentifier("staff_number")
                    if !isNew { Text("Employee numbers stay fixed to preserve timecard history.").font(.caption) }
                }
                Section("Company Access") {
                    if profile.role == .hr {
                        Picker("Role", selection: $member.role) {
                            Text("Employee").tag(UserRole.employee)
                            Text("Supervisor").tag(UserRole.supervisor)
                        }
                        .accessibilityIdentifier("staff_role_picker")
                        Picker("Department", selection: $member.department) {
                            ForEach(Department.allCases) { Text($0.displayName).tag(Optional($0)) }
                        }
                    } else {
                        LabeledContent("Role", value: "Employee")
                        LabeledContent("Department", value: profile.department?.displayName ?? "Unassigned")
                        Text("Only HR can create, promote, or edit supervisors.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("Active", isOn: $member.isActive)
                    Text("Changing departments or deactivating staff removes their current demo shift assignment. Historical payroll records are preserved. Assign a new shift from Shift Rosters.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("staff_error") }
            }
            .disabled(saving)
            .navigationTitle(isNew ? "Add Staff" : "Edit Staff")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        if isNew { Task { await save() } } else { confirming = true }
                    }.disabled(saving).accessibilityIdentifier("save_staff_button")
                }
            }
            .confirmationDialog("Save staff access changes?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Save Changes") { Task { await save() } }
            } message: {
                Text("Role and department changes affect access the next time this person signs in or refreshes their profile.")
            }
        }
        .interactiveDismissDisabled(saving)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            guard profile.canSaveStaff(member, existing: originalMember) else {
                throw DemoAPIClient.DemoError.unauthorized
            }
            _ = try await api.saveStaff(member)
            await didSave()
            dismiss()
        }
        catch { errorMessage = error.localizedDescription }
    }
}
