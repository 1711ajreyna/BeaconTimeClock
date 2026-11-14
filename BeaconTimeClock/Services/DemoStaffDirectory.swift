import Foundation

struct StaffMember: Codable, Identifiable, Equatable {
    var id: UUID
    var employeeID: UUID?
    var name: String
    var email: String
    var employeeNumber: String
    var role: UserRole
    var department: Department?
    var isActive: Bool

    var profile: UserProfile {
        UserProfile(id: id, displayName: name, email: email, role: role,
                    employeeID: employeeID, employeeNumber: employeeID == nil ? nil : employeeNumber,
                    department: department)
    }
}

enum StaffError: LocalizedError {
    case invalidFields, duplicateEmail, duplicateNumber, protectedAccount, unavailable, unreadableData
    var errorDescription: String? {
        switch self {
        case .invalidFields: return "Enter a name, valid email, employee number, department, and Employee or Supervisor role."
        case .duplicateEmail: return "That email is already assigned to another account."
        case .duplicateNumber: return "That employee number is already assigned."
        case .protectedAccount: return "HR and administrator accounts cannot be changed here."
        case .unavailable: return "Staff management is currently available in the local demo only."
        case .unreadableData: return "Saved staff data could not be read. It has been preserved; restore a valid backup before continuing."
        }
    }
}

/// Local demo data only. Production role changes must be authorized by the server.
@MainActor
final class DemoStaffDirectory {
    static let storageKey = "BeaconTimeClock.demoStaff.v1"
    private let defaults: UserDefaults?
    private(set) var members: [StaffMember]
    private(set) var loadError: Error?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.storageKey) {
            do { members = try JSONDecoder().decode([StaffMember].self, from: data) }
            catch { members = []; loadError = StaffError.unreadableData }
        } else { members = Self.seedMembers() }
    }

    func profile(email: String) -> UserProfile? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return members.first { $0.email == normalized && $0.isActive }?.profile
    }

    @discardableResult
    func save(_ input: StaffMember) throws -> StaffMember {
        if let loadError { throw loadError }
        var member = input
        member.name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        member.email = member.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        member.employeeNumber = member.employeeNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard member.role == .employee || member.role == .supervisor else { throw StaffError.protectedAccount }
        if let existing = members.first(where: { $0.id == member.id }) {
            guard existing.role == .employee || existing.role == .supervisor else { throw StaffError.protectedAccount }
            // Identity and existing timecards survive promotion, transfers, and deactivation.
            member.employeeID = existing.employeeID ?? (member.role == .employee ? existing.id : nil)
            member.employeeNumber = existing.employeeNumber
        } else { member.employeeID = member.id }
        let emailParts = member.email.split(separator: "@", omittingEmptySubsequences: false)
        guard !member.name.isEmpty, !member.employeeNumber.isEmpty, member.department != nil,
              emailParts.count == 2, !emailParts[0].isEmpty, emailParts[1].contains("."),
              !member.email.contains(where: { $0.isWhitespace }) else { throw StaffError.invalidFields }
        guard !members.contains(where: { $0.id != member.id && $0.email == member.email }) else { throw StaffError.duplicateEmail }
        guard !members.contains(where: { $0.id != member.id && $0.employeeNumber == member.employeeNumber }) else { throw StaffError.duplicateNumber }
        var updated = members.filter { $0.id != member.id }
        updated.append(member)
        let data = try JSONEncoder().encode(updated)
        defaults?.set(data, forKey: Self.storageKey)
        members = updated
        return member
    }

    static func employeeID(serial: Int) -> UUID {
        if serial == 1 { return UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
        return UUID(uuidString: String(format: "11111111-1111-1111-1111-%012d", serial))!
    }

    private static func seedMembers() -> [StaffMember] {
        let names: [[String]] = [
            ["Demo Employee", "Avery Brooks", "Jordan Hale", "Casey Rivera", "Morgan Quinn", "Cameron Ellis"],
            ["Taylor Stone", "Robin Diaz", "Parker Lin", "Finley Ross", "Quinn Avery", "Jamie Wells"],
            ["Skyler Young", "Dakota Reed", "Harper Grant", "Sage Bennett", "Jules Morgan", "Drew Parker"],
            ["Reese Cooper", "Alex Kendall", "Sam Carter", "Blake Turner", "Remy Jordan", "Charlie Ellis"],
            ["Emerson Lane", "Riley Cole", "Ellis Morgan", "Lee Harper", "Mika Reed", "Rowan Brooks"]
        ]
        var result: [StaffMember] = []
        for department in Department.allCases {
            for index in 0..<6 {
                let serial = department.sortOrder * 6 + index + 1
                let id = employeeID(serial: serial)
                result.append(StaffMember(id: id, employeeID: id, name: names[department.sortOrder][index],
                    email: serial == 1 ? AppConfig.demoEmployeeEmail : "employee\(serial)@demo.containersupply",
                    employeeNumber: String(format: "EMP-%03d", serial), role: .employee,
                    department: department, isActive: true))
            }
        }
        let supervisorEmails = [AppConfig.demoSupervisorEmail, AppConfig.demoMachineShopSupervisorEmail,
            AppConfig.demoMetalsSupervisorEmail, AppConfig.demoPlasticsSupervisorEmail, AppConfig.demoLithoSupervisorEmail]
        for department in Department.allCases {
            let n = department.sortOrder
            result.append(StaffMember(id: UUID(uuidString: String(format: "22222222-2222-2222-2222-%012d", n + 1))!,
                employeeID: nil, name: "Demo Supervisor", email: supervisorEmails[n], employeeNumber: "SUP-00\(n + 1)",
                role: .supervisor, department: department, isActive: true))
        }
        result.append(StaffMember(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, employeeID: nil,
            name: "Demo HR", email: AppConfig.demoHREmail, employeeNumber: "HR", role: .hr, department: nil, isActive: true))
        result.append(StaffMember(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, employeeID: nil,
            name: "Demo Administrator", email: AppConfig.demoAdminEmail, employeeNumber: "ADMIN", role: .admin, department: nil, isActive: true))
        return result
    }
}
