import XCTest
import SwiftData
@testable import BeaconTimeClock

/// MDI1 120: regression tests for payroll preview and punch security.
@MainActor
final class MDI1120RegressionTests: XCTestCase {
    private func hrProfile() -> UserProfile {
        UserProfile(id: UUID(), displayName: "HR Tester", email: "hr@test.com",
                    role: .hr, employeeID: nil, employeeNumber: nil, department: nil)
    }

    func testPreviewPDFDoesNotApproveDepartmentTimesheets() async throws {
        guard AppConfig.demoMode else { throw XCTSkip("Demo preview is Debug-only") }
        let hr = hrProfile()
        let api = DemoAPIClient { hr }
        let vm = HRPayrollViewModel(profile: hr, api: api)
        await vm.load()
        let before = try await api.fetchHRPayrollPacket()
        XCTAssertTrue(before.departments.allSatisfy { $0.status == .pending })
        XCTAssertFalse(vm.canExport)

        let previewURL = try vm.previewDemoPDF()
        XCTAssertTrue(FileManager.default.fileExists(atPath: previewURL.path))
        XCTAssertTrue(previewURL.lastPathComponent.contains("DEMO ONLY"))

        let after = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(after.weekStart, before.weekStart)
        XCTAssertEqual(after.weekEnd, before.weekEnd)
        XCTAssertEqual(after.departments, before.departments,
                       "Viewing a PDF must not alter live approvals")
        XCTAssertFalse(vm.canExport, "Preview must not unlock real payroll exports")
    }

    func testHRHasNoBulkDepartmentApprovalOverride() async throws {
        guard AppConfig.demoMode else { throw XCTSkip("Demo uses local records") }
        let hr = hrProfile()
        let api = DemoAPIClient { hr }
        let before = try await api.fetchHRPayrollPacket()
        do { try await api.prepareDemoHRPacket(); XCTFail("HR bulk approval bypass") }
        catch { guard case DemoAPIClient.DemoError.unauthorized = error else { return XCTFail("Unexpected: \(error)") } }
        let after = try await api.fetchHRPayrollPacket()
        XCTAssertEqual(after.departments, before.departments)
    }

    private final class DeniedBiometric: PunchBiometricAuthenticating {
        var attempts = 0
        func authenticate() async throws {
            attempts += 1
            throw BiometricError.failed
        }
    }

    func testDeniedBiometricNeverRecordsAnyPunchType() async throws {
        guard AppConfig.demoMode else { throw XCTSkip("Uses demo scanner") }
        let employee = UserProfile(id: UUID(), displayName: "Employee Tester",
            email: "employee@test.com", role: .employee, employeeID: UUID(),
            employeeNumber: "EMP-001", department: .electrical)

        let previous: [(PunchType, PunchType?)] = [
            (.clockIn, nil), (.lunchOut, .clockIn),
            (.lunchIn, .lunchOut), (.clockOut, .lunchIn)
        ]
        for (punch, prior) in previous {
            let container = try ModelContainer(for: TimeCard.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let store = TimeCardStore(context: container.mainContext)
            if let prior {
                let card = TimeCard(employeeID: "EMP-001", employeeName: "Tester",
                    type: prior, timestamp: Date(), beaconUUID: "demo", rssi: -55,
                    estimatedDistanceMeters: 2)
                try store.add(card)
                try store.markSynced(card: card, remoteID: UUID(), serverTimestamp: Date())
            }
            let beacon = BeaconManager(scanner: DemoBeaconScanner())
            beacon.requestPermissionAndStart()
            let denied = DeniedBiometric()
            let vm = EmployeeClockViewModel(profile: employee, store: store,
                beaconManager: beacon, lunchTimer: LunchTimerManager(),
                api: DemoAPIClient { employee }, biometricManager: denied)
            let existingCount = store.timeCards.count
            XCTAssertEqual(vm.nextExpectedPunch, punch)
            await vm.submit(punch)
            XCTAssertEqual(denied.attempts, 1, "Every punch requires a new biometric attempt")
            XCTAssertEqual(store.timeCards.count, existingCount,
                "Denied Face ID cannot create a punch")
            XCTAssertTrue(vm.showError)
        }
    }
}
