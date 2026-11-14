// FILE PURPOSE: Central demo/release settings, public backend settings, beacon and break defaults.
import Foundation

///Define the demo switch, company timezone, default break lengths, beacon UUID,
/// and public Supabase settings before other code refers to them.
///
/// Central configuration shared by demo and production builds.
///
/// Production values should come from an `.xcconfig`/Info.plist build setting,
/// not from source control. Only the public Supabase publishable key belongs in
/// the mobile app; service-role/email-provider keys remain on the backend.
// This type groups related state and behavior under a clear responsibility.
enum AppConfig {

    // MARK: - Demonstration Mode

    // Never ship a Release build with the fake beacon and demo authentication.
    // Release fails closed until the production Supabase environment is set.
    // Compile-time distinction: DEBUG can show demos; Release must not authenticate fake users.
    #if DEBUG
    // Select -UseLiveSupabase in the Xcode scheme's Run Arguments to test
    // a real staging backend while retaining debugger/test tools.
    static var demoMode: Bool {
        !ProcessInfo.processInfo.arguments.contains("-UseLiveSupabase")
    }
    #else
    static let demoMode = false
    #endif

    /// Demo users let the capstone show role-based login without Supabase.
    static let demoEmployeeEmail = "employee@demo.containersupply"
    static let demoSupervisorEmail = "supervisor@demo.containersupply"
    static let demoAdminEmail = "admin@demo.containersupply"
    static let demoHREmail = "hr@demo.containersupply"
    // Extra test logins make department scoping visible in demo mode.
    static let demoMachineShopSupervisorEmail = "machineshop@demo.containersupply"
    static let demoMetalsSupervisorEmail = "metals@demo.containersupply"
    static let demoPlasticsSupervisorEmail = "plastics@demo.containersupply"
    static let demoLithoSupervisorEmail = "litho@demo.containersupply"
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

    // MARK: - App Store support links

    /// Real, published HTTPS URLs must be supplied in app Info settings.
    /// Never invent a privacy policy URL or hard-code a placeholder link.
    static var privacyPolicyURL: URL? { publicHTTPSURL(forKey: "PRIVACY_POLICY_URL") }
    static var supportURL: URL? { publicHTTPSURL(forKey: "SUPPORT_URL") }

    private static func publicHTTPSURL(forKey key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
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
