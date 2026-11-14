import XCTest
@testable import BeaconTimeClock

@MainActor
final class MDI1120TrialAndSimulationTests: XCTestCase {
    func testEveryDepartmentHasEmployeeAndSupervisorTrialAccounts() throws {
        let directory = DemoStaffDirectory()
        for department in Department.allCases {
            let employee = try XCTUnwrap(directory.profile(email: DemoTrialAccounts.employeeEmail(for: department)))
            XCTAssertEqual(employee.role, .employee)
            XCTAssertEqual(employee.department, department)
            let supervisor = try XCTUnwrap(directory.profile(email: DemoTrialAccounts.supervisorEmail(for: department)))
            XCTAssertEqual(supervisor.role, .supervisor)
            XCTAssertEqual(supervisor.department, department)
            XCTAssertFalse(employee.canManageStaffAccounts)
            XCTAssertTrue(supervisor.canManageStaffAccounts)
            XCTAssertFalse(supervisor.canEditDepartment(Department.allCases.first { $0 != department }!))
        }
    }

    func testHRAutoApprovedSimulationIsNotARealApproval() async throws {
        guard AppConfig.demoMode else { throw XCTSkip("Demo is Debug-only") }
        let directory = DemoStaffDirectory()
        let hr = try XCTUnwrap(directory.profile(email: AppConfig.demoHREmail))
        let api = DemoAPIClient(profileProvider: { hr }, staffDirectory: directory)
        let vm = HRPayrollViewModel(profile: hr, api: api)
        await vm.load()
        let source = try await api.fetchHRPayrollPacket()
        XCTAssertTrue(source.departments.allSatisfy { $0.status == .pending })
        XCTAssertFalse(vm.canExport)
        vm.enableDemoApprovalSimulation()
        XCTAssertTrue(vm.demoApprovalSimulationActive)
        XCTAssertEqual(vm.simulatedApprovalCount, Department.allCases.count)
        XCTAssertTrue(vm.displayedSheets.allSatisfy { $0.status == .approved })
        XCTAssertTrue(vm.displayedSheets.allSatisfy { $0.supervisorName == "SIMULATED SIGNOFF - NOT REAL" })
        let pdf = try vm.previewDemoPDF()
        XCTAssertTrue(pdf.lastPathComponent.contains("DEMO ONLY"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdf.path))
        let unchanged = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(unchanged.departments, source.departments)
        XCTAssertFalse(vm.canExport, "Demo simulation cannot unlock real exports")
        vm.disableDemoApprovalSimulation()
        XCTAssertEqual(vm.simulatedApprovalCount, 0)
        XCTAssertEqual(vm.displayedSheets, source.departments)
    }

    func testEmployeesAndSupervisorsCannotActivateHRSimulation() async throws {
        let directory = DemoStaffDirectory()
        for email in [AppConfig.demoEmployeeEmail, AppConfig.demoSupervisorEmail] {
            let profile = try XCTUnwrap(directory.profile(email: email))
            let api = DemoAPIClient(profileProvider: { profile }, staffDirectory: directory)
            let vm = HRPayrollViewModel(profile: profile, api: api)
            vm.enableDemoApprovalSimulation()
            XCTAssertFalse(vm.demoApprovalSimulationActive)
        }
    }
}
