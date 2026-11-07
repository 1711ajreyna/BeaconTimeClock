// FILE PURPOSE: Persistent English/Spanish preference and dynamic UI-string lookup.
import Foundation

/// The choice applies to all SwiftUI screens, independently of the iPhone language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
    var locale: Locale { Locale(identifier: rawValue) }
}

enum AppLocalization {
    static let storageKey = "BeaconTimeClock.language"

    /// Useful for dynamic model labels and backend-independent status messages.
    /// SwiftUI Text("literal") uses the view's locale automatically; String values don't.
    static func text(_ englishKey: String) -> String {
        guard UserDefaults.standard.string(forKey: storageKey) == AppLanguage.spanish.rawValue,
              let path = Bundle.main.path(forResource: "es", ofType: "lproj"),
              let spanishBundle = Bundle(path: path) else {
            return englishKey
        }
        return spanishBundle.localizedString(forKey: englishKey,
                                              value: englishKey, table: "Localizable")
    }
}
