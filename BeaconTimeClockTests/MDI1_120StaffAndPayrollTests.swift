import Foundation
import XCTest
@testable import BeaconTimeClock

@MainActor
final class MDI1120StaffAndPayrollTests: XCTestCase {
    private func member(role: UserRole = .employee, department: Department = .electrical) -> StaffMember {
        StaffMember(id: UUID(), employeeID: nil, name: "New Worker", email: "worker@example.com",
                    employeeNumber: "EMP-888", role: role, department: department, isActive: true)
    }

    func testSupervisorCanCreateOnlyOwnDepartmentEmployees() async throws {
        let directory = DemoStaffDirectory()
        let supervisor = try XCTUnwrap(directory.profile(email: AppConfig.demoSupervisorEmail))
        let api = DemoAPIClient(profileProvider: { supervisor }, staffDirectory: directory)
        let roster = try await api.fetchStaff()
        XCTAssertTrue(roster.allSatisfy { $0.role == .employee && $0.department == .electrical })

        let created = try await api.saveStaff(member())
        XCTAssertEqual(created.role, .employee)
        XCTAssertEqual(created.department, .electrical)
        XCTAssertNotNil(directory.profile(email: created.email))

        do {
            _ = try await api.saveStaff(member(role: .supervisor))
            XCTFail("Supervisor cannot create another supervisor")
        } catch DemoAPIClient.DemoError.unauthorized {}

        do {
            _ = try await api.saveStaff(member(department: .metals))
            XCTFail("Supervisor cannot create employees in other departments")
        } catch DemoAPIClient.DemoError.unauthorized {}

        var promotion = created
        promotion.role = .supervisor
        do {
            _ = try await api.saveStaff(promotion)
            XCTFail("Supervisor cannot promote employees")
        } catch DemoAPIClient.DemoError.unauthorized {}

        let elsewhere = try XCTUnwrap(directory.members.first {
            $0.role == .employee && $0.department == .metals
        })
        var forged = elsewhere
        forged.department = .electrical
        do {
            _ = try await api.saveStaff(forged)
            XCTFail("Supervisor cannot transfer other department accounts into their scope")
        } catch DemoAPIClient.DemoError.unauthorized {}
    }

    func testOnlyHRCanCreateOrEditSupervisors() async throws {
        let directory = DemoStaffDirectory()
        let hr = try XCTUnwrap(directory.profile(email: AppConfig.demoHREmail))
        let api = DemoAPIClient(profileProvider: { hr }, staffDirectory: directory)
        let newSupervisor = member(role: .supervisor, department: .metals)
        let created = try await api.saveStaff(newSupervisor)
        XCTAssertEqual(created.role, .supervisor)
        let staff = try await api.fetchStaff()
        XCTAssertTrue(staff.contains { $0.id == created.id })
        var edited = created
        edited.name = "Updated Supervisor"
        let saved = try await api.saveStaff(edited)
        XCTAssertEqual(saved.name, "Updated Supervisor")
    }

    func testOnlyAssignedSupervisorsCanEditDepartment() async throws {
        let directory = DemoStaffDirectory()
        let hr = try XCTUnwrap(directory.profile(email: AppConfig.demoHREmail))
        let electrical = try XCTUnwrap(directory.profile(email: AppConfig.demoSupervisorEmail))
        let metals = try XCTUnwrap(directory.profile(email: AppConfig.demoMetalsSupervisorEmail))
        var current: UserProfile? = hr
        // Use ONE API instance so we test the exact same protected demo records.
        let api = DemoAPIClient(profileProvider: { current }, staffDirectory: directory)
        let packet = try await api.fetchHRPayrollPacket()
        let metalsSheet = try XCTUnwrap(packet.departments.first { $0.department == .metals })
        let electricalSheet = try XCTUnwrap(packet.departments.first { $0.department == .electrical })
        let crossDepartmentApproval = ApproveDepartmentRequest(
            timesheetID: metalsSheet.id, supervisorPrintedName: "Forged",
            signaturePNGBase64: "test-signature")

        current = electrical
        XCTAssertTrue(electrical.canManageDepartment(.electrical))
        XCTAssertFalse(electrical.canManageDepartment(.metals))
        do {
            _ = try await api.fetchDepartmentTimesheet(timesheetID: metalsSheet.id)
            XCTFail("Electrical supervisor read Metals payroll")
        } catch DemoAPIClient.DemoError.unauthorized {}
        do {
            _ = try await api.approveDepartment(crossDepartmentApproval)
            XCTFail("Electrical supervisor approved Metals")
        } catch DemoAPIClient.DemoError.unauthorized {}
        let ownSheet = try await api.fetchDepartmentTimesheet(timesheetID: electricalSheet.id)
        XCTAssertEqual(ownSheet.department, .electrical)
        let roster = try await api.fetchShiftRoster()
        XCTAssertTrue(roster.shifts.allSatisfy { $0.department == .electrical })
        XCTAssertTrue(roster.employees.allSatisfy { $0.department == .electrical })

        current = metals
        XCTAssertTrue(metals.canManageDepartment(.metals))
        XCTAssertFalse(metals.canManageDepartment(.electrical))
        let ownMetalsSheet = try await api.fetchDepartmentTimesheet(timesheetID: metalsSheet.id)
        XCTAssertEqual(ownMetalsSheet.department, .metals)

        for account in [hr, try XCTUnwrap(directory.profile(email: AppConfig.demoAdminEmail))] {
            current = account
            XCTAssertFalse(account.canManageDepartment(.metals))
            do { _ = try await api.approveDepartment(crossDepartmentApproval); XCTFail("Non-supervisor approved") }
            catch DemoAPIClient.DemoError.unauthorized {}
            do { _ = try await api.fetchShiftRoster(); XCTFail("Non-supervisor edited rosters") }
            catch DemoAPIClient.DemoError.unauthorized {}
        }

        current = hr
        let after = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(after.departments, packet.departments, "Denied attempts must not mutate any department")
    }

    func testOnlyOwnDepartmentApprovalResetIsPermitted() async throws {
        let directory = DemoStaffDirectory()
        let hr = try XCTUnwrap(directory.profile(email: AppConfig.demoHREmail))
        let electrical = try XCTUnwrap(directory.profile(email: AppConfig.demoSupervisorEmail))
        var current: UserProfile? = electrical
        let api = DemoAPIClient(profileProvider: { current }, staffDirectory: directory)
        let dashboard = try await api.fetchSupervisorDashboard()
        let sheet = try XCTUnwrap(dashboard.departments.first)
        let signed = try await api.approveDepartment(ApproveDepartmentRequest(
            timesheetID: sheet.id, supervisorPrintedName: "Not Trusted",
            signaturePNGBase64: "demo-signature"))
        XCTAssertTrue(signed.success)
        current = hr
        await api.resetDemoData()  // HR cannot reset department approvals.
        let afterHR = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(afterHR.departments.first { $0.department == .electrical }?.status, .approved)
        current = electrical
        await api.resetDemoData()  // Only the assigned department approval is cleared.
        current = hr
        let afterSupervisor = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(afterSupervisor.departments.first { $0.department == .electrical }?.status, .pending)
        XCTAssertTrue(afterSupervisor.departments.filter { $0.department != .electrical }
            .allSatisfy { $0.status == .pending })
    }

    func testSundayPayrollReportTitleAndFilename() throws {
        let title = try PayrollReportNaming.displayTitle(weekEnd: "2026-11-15")
        XCTAssertEqual(title, "PAYROLL 15/11/2026")
        let file = try PayrollReportNaming.fileName(weekEnd: "2026-11-15",
            department: .electrical, demoPreview: false)
        XCTAssertEqual(file, "PAYROLL 15-11-2026 - ELECTRICAL.pdf")
        let renamed = try PayrollReportNaming.displayTitle(weekEnd: "2026-11-15", heading: "WEEKLY PAYROLL")
        XCTAssertEqual(renamed, "WEEKLY PAYROLL 15/11/2026")
        XCTAssertThrowsError(try PayrollReportNaming.displayTitle(weekEnd: "2026-11-14"))
        XCTAssertThrowsError(try PayrollReportNaming.displayTitle(weekEnd: "not a date"))
        XCTAssertThrowsError(try PayrollReportNaming.displayTitle(weekEnd: "2026-11-15", heading: "../escape"))
    }
}
