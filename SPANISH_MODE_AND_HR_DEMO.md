# BeaconTimeClock — English/Spanish Mode + HR Demo PDF

## What changed

1. **Language selector:** `Views/LanguagePreferencePicker.swift` appears on the login page and in Account → Language. Choices are English and Español. Selection persists in UserDefaults at `BeaconTimeClock.language`.
2. **View localization:** The app entry point sets the SwiftUI locale for the whole window. `Localizable.xcstrings` contains Spanish translations for the major employee, login, supervisor, scheduling, roster, and HR UI strings. `Utilities/AppLocalization.swift` translates model-generated labels and a few runtime status messages that SwiftUI cannot localize automatically.
3. **HR navigation:** `Views/AuthenticatedRootView.swift` now adds an HR Payroll tab **only for HR and Admin roles**, using existing `HRPayrollView` and the shared workflow API. Other roles remain excluded from this tab. Authorization must still be enforced by the production backend.
4. **HR demo PDF:** `HRPayrollView` now displays **Demo PDF Preview → Preview Demo Payroll PDF** in DEBUG/demo mode. Tapping it prepares *simulated* signed department packets using `DemoAPIClient`, generates a combined PDF via `PayrollPDFExporter`, and opens the iOS Quick Look preview. This is not a production payroll approval or ADP submission.
5. **Date labels:** The app's own week/date formatting helpers now honor the selected language where they were using `DateFormatter`.
6. **Schedules icon:** Replaced the unsupported `calendar.badge.gearshape` tab symbol with the system `calendar` SF Symbol. The tab is available only to supervisors, HR, and administrators; employees use **My Shift**.

## How to try it in Xcode

1. Open `BeaconTimeClock.xcodeproj` in the updated project. Let Xcode resolve Swift packages.
2. Build and run in **Debug** mode. Demo login buttons only appear in Debug (`AppConfig.demoMode`).
3. On the login screen, switch **App language → Español**. Sign in as Employee, Supervisor, HR, or Admin. The choice persists when you sign out and relaunch.
4. Sign out and select **HR** demo login. The demo password is prefilled when you tap the HR demo button; tap **Sign In**.
5. Select the **HR Payroll** tab, then **Preview Demo Payroll PDF**. The app should create signed sample data and open the five-department PDF. You can also use the per-department export buttons and the Share or Save Last PDF action.
6. From **Account → Language**, switch back to English without restarting the application.

## Architecture notes

- `AppLocalization.text()` is for runtime values (such as `Department.displayName`, `PunchType.displayName`, and `BrandHeaderView`'s subtitle). It does not translate arbitrary backend strings or personally entered names.
- Native operating system alerts (such as biometric security prompts) and server-generated error messages may use the device/backend language.
- The payroll PDF itself retains its existing payroll-entry layout and English labels; this update translates the **HR PDF screen**, not the PDF template. A fully localized PDF layout would need separate field-width and document reviews.
- Some interpolated/coded messages may still show English. Translate or recompose these in `Localizable.xcstrings` when you add new UI flows, and validate on a real iPhone and in Spanish Xcode previews.
- The original project settings, SwiftData models, Supabase client, and payroll API authorization code were not replaced.

## Files added

- `BeaconTimeClock/Utilities/AppLocalization.swift`
- `BeaconTimeClock/Views/LanguagePreferencePicker.swift`
- `BeaconTimeClock/Localizable.xcstrings`

## Files modified

- `BeaconTimeClock/App/BeaconTimeClockApp.swift`
- `BeaconTimeClock/Views/AuthenticatedRootView.swift`
- `BeaconTimeClock/Views/LoginView.swift`
- `BeaconTimeClock/Views/AccountView.swift`
- `BeaconTimeClock/Views/BrandHeaderView.swift`
- `BeaconTimeClock/Views/EmployeeClockView.swift`
- `BeaconTimeClock/Views/HRPayrollView.swift`
- `BeaconTimeClock/Views/CompanySubmissionStatusView.swift`
- `BeaconTimeClock/Views/SupervisorPortalView.swift`
- `BeaconTimeClock/Views/DepartmentTimeSheetDetailView.swift`
- `BeaconTimeClock/Views/TimeCardsView.swift`
- `BeaconTimeClock/Models/Department.swift`
- `BeaconTimeClock/Models/PunchType.swift`
- `BeaconTimeClock/Models/ShiftModels.swift`
- `BeaconTimeClock/Models/workflowModels.swift`
- `BeaconTimeClock/Models/PayrollAccessModels.swift`
- `BeaconTimeClock/ViewModels/EmployeeClockViewModel.swift`
- `BeaconTimeClock/ViewModels/HRPayrollViewModel.swift`
- `BeaconTimeClock/Utilities/DateFormatting.swift`
- `BeaconTimeClock.xcodeproj/project.pbxproj`

## Validation

Checked Swift source syntax with `swiftc -frontend -parse`, project structure with `plutil -lint`, and string catalog with JSON parsing. **A full iOS build and simulator test still need to be run in Xcode on macOS** because `xcodebuild` is not available in this environment.
