import Foundation

///Define the demo switch, company timezone, default break lengths, beacon UUID,
/// and public Supabase settings before other code refers to them.
/// 
/// Central configuration shared by demo and production builds.
///
/// Production values should come from an `.xcconfig`/Info.plist build setting,
/// not from source control. Only the public Supabase publishable key belongs in
/// the mobile app; service-role/email-provider keys remain on the backend.
enum AppConfig {

    // MARK: - Demonstration Mode

    static let demoMode = true

    /// Demo users let the capstone show role-based login without Supabase.
    static let demoEmployeeEmail = "employee@demo.containersupply"
    static let demoSupervisorEmail = "supervisor@demo.containersupply"
    static let demoAdminEmail = "admin@demo.containersupply"
    static let demoPassword = "Demo123!"

    // MARK: - Supabase

    static var supabaseURL: URL? {
        guard let raw = Bundle.main.object(
            forInfoDictionaryKey: "SUPABASE_URL"
        ) as? String,
        !raw.isEmpty else {
            return nil
        }

        return URL(string: raw)
    }

    static var supabasePublishableKey: String? {
        guard let key = Bundle.main.object(
            forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY"
        ) as? String,
        !key.isEmpty else {
            return nil
        }

        return key
    }

    static var apiBaseURL: URL? {
        supabaseURL?
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
    }

    // MARK: - Beacon

    static let beaconUUID = UUID(
        uuidString: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E"
    )!

    static let allowedDistanceMeters: Double = 4.6

    // MARK: - Company / Payroll

    static let companyTimeZoneIdentifier = "America/Los_Angeles"
    static let demoWeeklyRegularLimitHours: Double = 40

    // MARK: - Break / Meal Durations

    static let restBreakDurationMinutes = 10
    static let lunchDurationMinutes = 30
    /// California rest-break start warning requested for the employee UI.
    static let restBreakStartWarningMinutes = 2

    /// Warn again when only two minutes remain in an accepted rest break.
    static let restBreakEndWarningMinutes = 2

    /// Keep the previously requested five-minute warning for meal and clock-out.
    static let mealAndClockOutWarningMinutes = 5
}
