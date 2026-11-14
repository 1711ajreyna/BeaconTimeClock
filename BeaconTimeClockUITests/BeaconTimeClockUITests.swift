import XCTest

@MainActor
final class BeaconTimeClockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting-NoAnimations", "-BeaconTimeClock.language", "en"]
        if reset { app.launchArguments.insert("-UITesting-Reset", at: 0) }

        addUIInterruptionMonitor(withDescription: "System permissions") { alert in
            for title in ["Allow While Using App", "Allow", "OK"] {
                if alert.buttons[title].exists {
                    alert.buttons[title].tap()
                    return true
                }
            }
            return false
        }

        app.launch()
        let email = app.textFields["email_field"]
        guard email.waitForExistence(timeout: 25) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Login did not appear"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("Login field absent after launch. Inspect the attached screenshot and accessibility tree: \(app.debugDescription)")
            return app
        }
        XCTAssertTrue(app.secureTextFields["password_field"].exists, "Password field is missing")
        return app
    }

    // Find tab buttons across Xcode/iOS simulator accessibility variations.
    private func tab(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let item = app.tabBars.buttons[name]
        return item.exists ? item : app.buttons[name]
    }

    private func tapWhenVisible(_ element: XCUIElement, in app: XCUIApplication, direction: String = "up") {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing UI element: \(element.identifier). Tree: \(app.debugDescription)")
        for _ in 0..<4 where !element.isHittable {
            if direction == "up" { app.swipeUp() }
            else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable, "Element exists but is not tappable: \(element.identifier). Tree: \(app.debugDescription)")
        element.tap()
    }

    private func login(_ role: String, in app: XCUIApplication) {
        // Quick-fill buttons are below the sign-in form on compact iPhones.
        tapWhenVisible(app.buttons["\(role)_demo_button"], in: app, direction: "up")
        let signIn = app.buttons["login_button"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        for _ in 0..<4 where !signIn.isHittable { app.swipeDown() }
        XCTAssertTrue(signIn.isEnabled, "Demo button did not fill credentials")
        XCTAssertTrue(signIn.isHittable, "Sign-in button is off-screen")
        signIn.tap()
        XCTAssertTrue(tab("Account", in: app).waitForExistence(timeout: 25),
                      "Login did not reach Account tab. Possible auth failure, wrong build configuration, or permission dialog. Tree: \(app.debugDescription)")
    }

    func testInvalidPasswordDisplaysError() {
        let app = launch()
        let email = app.textFields["email_field"]
        email.tap()
        email.typeText("employee@demo.containersupply")
        let password = app.secureTextFields["password_field"]
        password.tap()
        password.typeText("incorrect") // Do not send newline: it may trigger an implicit submit.
        tapWhenVisible(app.buttons["login_button"], in: app, direction: "down")
        XCTAssertTrue(app.descendants(matching: .any)["login_error"].waitForExistence(timeout: 10),
                      "Expected an invalid-password message. Tree: \(app.debugDescription)")
        XCTAssertFalse(tab("Account", in: app).exists)
    }

    func testEmployeeLoginAndSessionSurvivesRelaunch() {
        let app = launch()
        login("employee", in: app)
        XCTAssertTrue(tab("Clock", in: app).exists)
        XCTAssertTrue(tab("My Shift", in: app).exists)
        XCTAssertFalse(tab("Approvals", in: app).exists)
        app.terminate()
        // Crucially, no -UITesting-Reset on relaunch: session should persist.
        app.launchArguments = ["-UITesting-NoAnimations", "-BeaconTimeClock.language", "en"]
        app.launch()
        XCTAssertTrue(tab("My Shift", in: app).waitForExistence(timeout: 25),
                      "Saved session was not restored. Tree: \(app.debugDescription)")
    }

    func testSupervisorHasApprovalsAndSchedules() {
        let app = launch()
        login("supervisor", in: app)
        XCTAssertTrue(tab("Approvals", in: app).exists)
        XCTAssertTrue(tab("Schedules", in: app).exists)
        XCTAssertFalse(tab("HR Payroll", in: app).exists)
        XCTAssertFalse(tab("Clock", in: app).exists)
    }

    func testHRCanOpenPayroll() {
        let app = launch()
        login("hr", in: app)
        let payroll = tab("HR Payroll", in: app)
        XCTAssertTrue(payroll.exists)
        payroll.tap()
        XCTAssertTrue(app.buttons["preview_demo_payroll_pdf_button"].waitForExistence(timeout: 15),
                      "HR demo preview button missing. Tree: \(app.debugDescription)")
    }

    func testHRCanOpenStaffEditorAndRejectBlankDetails() {
        let app = launch()
        login("hr", in: app)
        tab("Account", in: app).tap()
        tapWhenVisible(app.descendants(matching: .any)["manage_staff_link"], in: app)
        tapWhenVisible(app.buttons["add_staff_button"], in: app)
        XCTAssertTrue(app.textFields["staff_name"].waitForExistence(timeout: 10))
        tapWhenVisible(app.buttons["save_staff_button"], in: app, direction: "down")
        XCTAssertTrue(app.descendants(matching: .any)["staff_error"].waitForExistence(timeout: 10),
                      "Expected a validation error for blank staff details. Tree: \(app.debugDescription)")
    }
}


