// FILE PURPOSE: One persistent language control reused on login and account screens.
import SwiftUI

struct LanguagePreferencePicker: View {
    @AppStorage(AppLocalization.storageKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        Picker("App language", selection: $languageCode) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.name).tag(language.rawValue)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("app_language_picker")
    }
}
