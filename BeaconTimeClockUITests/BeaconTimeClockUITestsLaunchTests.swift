import XCTest

final class BeaconTimeClockUITestsLaunchTests: XCTestCase {
    @MainActor
    func testLoginScreenLaunches() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting-Reset", "-UITesting-NoAnimations", "-BeaconTimeClock.language", "en"]
        app.launch()
        XCTAssertTrue(app.textFields["email_field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.secureTextFields["password_field"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Login Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
