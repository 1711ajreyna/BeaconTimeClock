import Foundation

/// Debug-only trial credentials mapped to existing seeded DemoStaffDirectory users.
/// Menu selection fills login fields; it never grants privileges by itself.
enum DemoTrialAccounts {
    static func employeeEmail(for department: Department) -> String {
        if department == .electrical { return AppConfig.demoEmployeeEmail }
        // Seed starts each department with six employees, starting at 1, 7, 13, 19, 25.
        return "employee\(department.sortOrder * 6 + 1)@demo.containersupply"
    }

    static func supervisorEmail(for department: Department) -> String {
        switch department {
        case .electrical: return AppConfig.demoSupervisorEmail
        case .machineShop: return AppConfig.demoMachineShopSupervisorEmail
        case .metals: return AppConfig.demoMetalsSupervisorEmail
        case .plastics: return AppConfig.demoPlasticsSupervisorEmail
        case .litho: return AppConfig.demoLithoSupervisorEmail
        }
    }
}
