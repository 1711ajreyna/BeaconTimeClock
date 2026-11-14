import XCTest

@MainActor
final class BeaconTimeClockUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting-Reset", "-UITesting-NoAnimations", "-BeaconTimeClock.language", "en"]
        addUIInterruptionMonitor(withDescription: "System permission") { alert in
            for title in ["Allow", "Allow While Using App", "OK"] {
                if alert.buttons[title].exists { alert.buttons[title].tap(); return true }
            }
            return false
        }
        app.launch()
        XCTAssertTrue(app.textFields["email_field"].waitForExistence(timeout: 10))
        return app
    }

    private func login(_ role: String, in app: XCUIApplication) {
        let button = app.buttons["\(role)_demo_button"]
        if !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        app.buttons["login_button"].tap()
        XCTAssertTrue(app.tabBars.buttons["Account"].waitForExistence(timeout: 15))
    }

    func testInvalidPasswordDisplaysError() {
        let app = launch()
        app.textFields["email_field"].tap()
        app.textFields["email_field"].typeText("employee@demo.containersupply")
        app.secureTextFields["password_field"].tap()
        app.secureTextFields["password_field"].typeText("incorrect\n")
        app.buttons["login_button"].tap()
        XCTAssertTrue(app.staticTexts["login_error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Account"].exists)
    }

    func testEmployeeLoginAndSessionSurvivesRelaunch() {
        let app = launch()
        login("employee", in: app)
        XCTAssertTrue(app.tabBars.buttons["Clock"].exists)
        XCTAssertTrue(app.tabBars.buttons["My Shift"].exists)
        XCTAssertFalse(app.tabBars.buttons["Approvals"].exists)
        app.terminate()
        app.launchArguments = ["-UITesting-NoAnimations", "-BeaconTimeClock.language", "en"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["My Shift"].waitForExistence(timeout: 15))
    }

    func testSupervisorHasApprovalsAndSchedules() {
        let app = launch()
        login("supervisor", in: app)
        XCTAssertTrue(app.tabBars.buttons["Approvals"].exists)
        XCTAssertTrue(app.tabBars.buttons["Schedules"].exists)
        XCTAssertFalse(app.tabBars.buttons["HR Payroll"].exists)
        XCTAssertFalse(app.tabBars.buttons["Clock"].exists)
    }

    func testHRCanOpenPayroll() {
        let app = launch()
        login("hr", in: app)
        let payroll = app.tabBars.buttons["HR Payroll"]
        XCTAssertTrue(payroll.exists)
        payroll.tap()
        XCTAssertTrue(app.buttons["preview_demo_payroll_pdf_button"].waitForExistence(timeout: 10))
    }
    func testHRCanOpenStaffEditorAndRejectBlankDetails() {
        let app = launch()
        login("hr", in: app)
        app.tabBars.buttons["Account"].tap()
        let link = app.buttons["manage_staff_link"]
        if !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        let add = app.buttons["add_staff_button"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields["staff_name"].waitForExistence(timeout: 5))
        app.buttons["save_staff_button"].tap()
        XCTAssertTrue(app.staticTexts["staff_error"].waitForExistence(timeout: 5))
    }

}
