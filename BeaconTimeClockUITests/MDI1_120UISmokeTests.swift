import XCTest

/// Independent smoke tests; leave the existing UI test file untouched.
@MainActor
final class MDI1120UISmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchSignedOut() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting-Reset", "-UITesting-NoAnimations",
                               "-UITesting-NoPermissions", "-BeaconTimeClock.language", "en"]
        app.launch()
        let field = app.textFields["email_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 25),
            "Login not visible. Open UI test failure screenshot and accessibility tree.\n\(app.debugDescription)")
        return app
    }

    func testLoginScreenAppearsOnFreshInstall() {
        let app = launchSignedOut()
        XCTAssertTrue(app.secureTextFields["password_field"].exists)
        XCTAssertTrue(app.buttons["login_button"].exists)
    }

    func testSignInButtonUsesFullWidthTapTarget() {
        let app = launchSignedOut()
        let employee = app.buttons["employee_demo_button"]
        for _ in 0..<5 where !employee.isHittable { app.swipeUp() }
        XCTAssertTrue(employee.waitForExistence(timeout: 10))
        employee.tap()
        let button = app.buttons["login_button"]
        if !button.isHittable { app.swipeDown() }
        XCTAssertTrue(button.isEnabled)
        // Tap near the left edge of the visible button, not just its text label.
        let leftEdge = button.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.5))
        leftEdge.tap()
        XCTAssertTrue(app.tabBars.buttons["Account"].waitForExistence(timeout: 20))
    }

    func testColdLaunchPerformance() {
        // Benchmarks test-runner launch time; compare repeated local runs.
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting-Reset", "-UITesting-NoAnimations",
                               "-UITesting-NoPermissions", "-BeaconTimeClock.language", "en"]
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.terminate()
        }
    }

    func testHRCanNavigateToPreviewWithoutApproving() {
        let app = launchSignedOut()
        let hrButton = app.buttons["hr_demo_button"]
        for _ in 0..<5 where !hrButton.isHittable { app.swipeUp() }
        XCTAssertTrue(hrButton.waitForExistence(timeout: 10))
        hrButton.tap()
        let signIn = app.buttons["login_button"]
        XCTAssertTrue(signIn.isEnabled)
        signIn.tap()
        let payroll = app.tabBars.buttons["HR Payroll"]
        XCTAssertTrue(payroll.waitForExistence(timeout: 25), "HR tab missing: \(app.debugDescription)")
        payroll.tap()
        XCTAssertTrue(app.buttons["preview_demo_payroll_pdf_button"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["simulate_demo_approvals_button"].exists,
            "HR demo needs an explicit simulated-approval button")
        XCTAssertFalse(app.buttons["generate_demo_approvals_button"].exists,
            "No silent bulk-approval action should exist")
    }
}
