# BeaconTimeClock — MDI1 120 Finalization Guide

This guide applies **on top of** the biometric + HR CSV update you already committed to your `mdi2-120-auth-payroll-review` development branch. This is **MDI1 120**, not MDI2. The patch is built from the **uploaded BeaconTimeClock source + the earlier applied biometric/HR patch**, rather than a live clone of your latest GitHub branch. A clean `git apply --check` is mandatory.

**Safety rule:** Work on a new branch. Do not overwrite your current folder with the source ZIP, stage `.build/`, use `git reset --hard`, or force a failing patch. Keep your existing UI-test file intact; this update adds a *new* XCUITest file rather than replacing it.

## First: save/prepare the branch

In Terminal, from your existing `BeaconTimeClock` repository:

```bash
git status
git branch --show-current
# If you still have edits, first commit/stash them intentionally. Do not blindly discard them.
git switch mdi2-120-auth-payroll-review
git switch -c mdi1-120-finalization
```

Download `BeaconTimeClock_MDI1_120_Finalization_Patch.zip` and double-click it in Finder. It contains this guide and the `.patch` file. From the project directory:

```bash
PATCH=$(find "$HOME/Downloads" -type f -name 'BeaconTimeClock_MDI1_120_Finalization.patch' -print -quit)
printf 'Patch: %s\n' "$PATCH"
test -n "$PATCH" || { echo 'Patch not downloaded/extracted'; exit 1; }
git apply --check "$PATCH"
```

**Only if the check prints no errors:**

```bash
git apply "$PATCH"
git status
git diff --stat
```

If Git reports a conflict, stop: preserve the error and inspect the exact file; the current Mac version has diverged from the uploaded source. Do **not** substitute the full source ZIP over your project. The source ZIP is a read-only reference.

## 1. Stop HR PDF preview from approving all departments

**Files:** `HRPayrollView.swift`, `HRPayrollViewModel.swift`, `PayrollPDFExporter.swift`.

- **Preview Demo Payroll PDF** now calls `viewModel.previewDemoPDF()` and renders the currently loaded weekly packet. It never calls the approval API, never signs records, and never enables approved-only CSV/PDF exports.
- Preview documents are labeled **DEMO PREVIEW — NOT AN APPROVAL**, including the filename. Departments retain their actual pending/approved status.
- **Generate Simulated Demo Approvals** is an entirely separate action requiring an explicit confirmation. It intentionally calls the existing `prepareDemoHRPacket()` method, so **use only for classroom sample data**. HR cannot silently approve real records by previewing.
- Production exports still reject incomplete or unsigned packets, and demo-preview mode is disabled in Release builds.

**Manual validation:** Debug → HR login → inspect `Approved: 0 / 5` → tap **Preview Demo Payroll PDF** → close it → still `Approved: 0 / 5` → normal export buttons still disabled. Then try the separate simulated-approval button: cancel and confirm it changes nothing; confirm and check that *only then* the demo approvals become approved. Reset weekly demo afterward.

**Regression test:** `MDI1120RegressionTests.testPreviewPDFDoesNotApproveDepartmentTimesheets`.

## 2. Diagnose and stabilize UI tests

**New file:** `BeaconTimeClockUITests/MDI1_120UISmokeTests.swift` (automatically included by the project's filesystem-synchronized test target). Your modified `BeaconTimeClockUITests.swift` remains untouched.

- Uses a clean login state with `-UITesting-Reset`.
- Uses `-UITesting-NoPermissions` to suppress *notification* permission alerts during UI testing; does not turn off biometric security.
- Allows up to 25 seconds for login to appear and reports the accessibility tree on timeout.
- Checks the login screen, HR demo login, and the two independent preview/approval buttons.
- Includes a local cold-launch performance benchmark.

**Xcode sequence:**

1. `open BeaconTimeClock.xcodeproj`.
2. Scheme **BeaconTimeClock**, destination a locally available iPhone simulator.
3. Product → Scheme → Edit Scheme → Test: ensure **BeaconTimeClockTests** and **BeaconTimeClockUITests** are checked, with **Debug** configuration.
4. Build with **⌘B**.
5. Use the Test Navigator (**⌘6**) to run `MDI1120UISmokeTests/testLoginScreenAppearsOnFreshInstall` by itself.
6. Next run `testHRCanNavigateToPreviewWithoutApproving`, and then your existing UI tests. The new tests do **not** guarantee the old tests pass; if any fail, expand the first failed assertion and share its exact line/screenshot, rather than assuming all are fixed.
7. For a command-line test run, first obtain a real installed simulator ID:

```bash
xcodebuild -showdestinations -project BeaconTimeClock.xcodeproj -scheme BeaconTimeClock
xcodebuild test -project BeaconTimeClock.xcodeproj -scheme BeaconTimeClock \
  -configuration Debug -destination 'platform=iOS Simulator,id=YOUR_ACTUAL_SIMULATOR_UUID' \
  -parallel-testing-enabled NO
```

**Why a launch test can fail while the unit tests pass:** XCUI automation depends on a booted simulator, app session state, keyboard focus, an accessible screen, and permissions. The current code includes separate auth bootstrap and SwiftData initialization paths; capture the first failing line, do not randomly delete tests.

## 3. Verify a fresh Face ID / Touch ID check for *every* punch

**Files:** `BiometricManager.swift` and `EmployeeClockViewModel.swift`.

A `PunchBiometricAuthenticating` protocol allows tests to inject an authenticator that always denies. The production class still uses a **new** `LAContext` for each action and a reuse duration of zero. The clock view model still checks proximity before requesting authentication, verifies proximity again afterward, and records nothing after failed/canceled authentication.

`MDI1120RegressionTests.testDeniedBiometricNeverRecordsAnyPunchType` creates a realistic local prior-punch state and tests all four actions: **Clock In**, **Lunch Out**, **Lunch In**, and **Clock Out**. Each denial must leave the punch cache unchanged. This verifies the orchestration logic, not Face ID hardware.

**Physical device test:**

1. On your iPhone, enable Face ID/Touch ID in Settings and trust your development signing profile in Xcode.
2. Build and run **Debug** to a plugged-in iPhone; demo beacon scanning is simulated in Debug. **Do not interpret a Debug beacon success as proof of actual workplace proximity.**
3. Sign in as a demo employee → Clock → Clock In; verify a fresh biometric prompt.
4. Cancel it and verify no new punch, no advancement to Lunch Out, and a visible failure.
5. Retry and accept, then repeat denial/acceptance for Lunch Out, Lunch In, Clock Out.
6. Test lockout, unenrolled biometrics, and permission denial. There must be no silent fallback to recording a punch.
7. Test Release **with real backend and real beacon hardware** before describing it as production-ready. A biometric match identifies the device's enrolled owner, not inherently the signed-in employee; don't use shared personal devices as a security claim.

In Xcode's simulator, Face ID enrollment/matching can be *simulated* using **Features → Face ID** if the selected device supports it; that is not the same as physical-device verification.

## 4. Confirm daily time records and HR CSV exports

The previous update already added:

- `PayrollCSVExporter.swift`
- `HRPayrollViewModel.exportDailyCSV()` (one shift per work date, overnight labeled)
- `HRPayrollViewModel.exportWeeklyCSV()` (one employee per pay period)
- HR buttons **Prepare Daily Punch CSV** and **Prepare Weekly Hours CSV**.

A weekly aggregate should **not** be repeated on each daily row, since that invites double-counting. The HR PDF has one form per department followed by each employee's day-by-day punches. The employee **My Time** screen separately groups local cached punches by work date. The server—not the client—must eventually be the authoritative payroll source.

**Test:** HR demo → explicitly generate demo approvals → export Daily CSV and Weekly CSV → AirDrop to Mac or Save to Files → open in Numbers/Excel. Confirm department, employee ID, Pacific date, four punch timestamps, overnight +1-day notation, regular/OT/total as appropriate, no formula injection or accidental repeated weekly totals; verify no employee is included across departments incorrectly. Exercise skipped breaks, adjusted timestamps, split shifts, and DST boundaries. Export sensitive timesheets only to secure destinations.

## 5. Performance, accessibility and navigation checks

**New UI test:** `testColdLaunchPerformance()` uses `XCTApplicationLaunchMetric` as a repeatable local benchmark. Numbers depend on Mac/simulator and are not guaranteed performance targets.

Run this matrix in both English and Spanish, in light and dark mode, on iPhone and iPad simulators, and on a real iPhone:

| Role | Test |
| --- | --- |
| Employee | Login → Clock → My Shift → My Time → Account → logout/relaunch |
| Supervisor | Approvals → timesheet → edit with reason → sign → Schedules → roster |
| HR | Approvals → HR Payroll → read-only preview → explicit simulated approvals → PDF and CSV → staff management |
| All | Dynamic Type (XL/XXXL), VoiceOver labels, no clipped buttons, quick repeated taps, offline/retry, spinner and errors |

Pay special attention to the TabView overflow on small iPhones, date labels on overnight shifts, PDF dismissal, navigation back/forward, and slow network responses. **Any test failure must be investigated before merging.**

## 6. App Store readiness: what can and cannot be completed here

**Files:** `AppConfig.swift` and `AccountView.swift` now optionally show links for genuine HTTPS `PRIVACY_POLICY_URL` and `SUPPORT_URL`. These URLs have intentionally **not been invented**. Set them in your Xcode app target's **Info** settings (`PRIVACY_POLICY_URL` and `SUPPORT_URL`) using real published sites that you own and maintain. Verify both open on-device.

### Release blockers to resolve

- Build/Archive with a supported release Xcode. As of Nov 2026, Apple's upload minimum is **Xcode 26 and the iOS 26 SDK**; a lower deployment target is distinct from the build SDK.
- Configure real Supabase URL and **publishable/anon** key in Info/build configuration, deploy and validate all required production Edge Functions, authorization policies/RLS, account roles, roster/punch history, timecards, signatures, HR exports, and required audit trail. The uploaded source does not include the production backend. **Do not upload service-role secrets to the app.**
- Verify background/foreground Location/Beacon permissions and physical detection at the workplace. Confirm denied/missing-location recovery. Debug's fake beacon does not validate production.
- Keep `PrivacyInfo.xcprivacy` accurate, check third-party SDK privacy manifests and all required-reason API usage; complete App Store Connect privacy disclosures, retention/deletion terms and a real privacy policy. Do not assert no employee data is collected: you handle identity, attendance, and location proximity.
- Test account deletion process if your app supports creating accounts; coordinate record retention and employee rights with your employer. HR "deactivate" is not necessarily deletion.
- Confirm rights to any company name/logo. Supply screenshots, app description, keywords, age rating, privacy/support links, reviewer credentials for all roles, and a physical-hardware demo video/instructions for beacon-dependent functions.
- Test Release (not only Debug) on hardware, via TestFlight, with working backend. The public App Store may not be the right channel for a company-only workforce app; assess Apple Business Manager Custom Apps and enterprise/internal distribution.
- For watchOS and native macOS, add/test separate targets later; this patch intentionally does not pretend they exist.

Useful Apple documentation:
- Review: https://developer.apple.com/app-store/review/guidelines/
- Review information and required physical hardware: https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/
- SDK upload requirements: https://developer.apple.com/news/upcoming-requirements/
- Privacy manifest: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

### Local verification commands

```bash
# Show available device destinations
xcodebuild -showdestinations -project BeaconTimeClock.xcodeproj -scheme BeaconTimeClock
# Build the iOS Simulator target
xcodebuild build -project BeaconTimeClock.xcodeproj -scheme BeaconTimeClock \
    -configuration Debug -destination 'generic/platform=iOS Simulator'
# Check git working copy and staged content before publishing
git status
git diff --check
git diff --stat
```

Archive and upload only **after** all release blockers are resolved, through Product → Archive → Organizer → Validate/Distribute App → TestFlight → App Store Connect.

## Save the final changes to GitHub (after a successful build/tests)

```bash
git status
git diff --check
git add BeaconTimeClock/Services/BiometricManager.swift \
  BeaconTimeClock/ViewModels/EmployeeClockViewModel.swift \
  BeaconTimeClock/ViewModels/HRPayrollViewModel.swift \
  BeaconTimeClock/Views/HRPayrollView.swift \
  BeaconTimeClock/Views/AccountView.swift \
  BeaconTimeClock/Views/AuthenticatedRootView.swift \
  BeaconTimeClock/Utilities/PayrollPDFExporter.swift \
  BeaconTimeClock/Utilities/AppConfig.swift \
  BeaconTimeClockTests/MDI1_120RegressionTests.swift \
  BeaconTimeClockUITests/MDI1_120UISmokeTests.swift \
  MDI1_120_FINALIZATION_GUIDE.md

git diff --cached --check
git diff --cached --stat
# Inspect git diff --cached for any credentials or sensitive data before push.
git commit -m "MDI1 120: Fix demo PDF approvals and add release regression tests"
git push -u origin mdi1-120-finalization
```

Then create a **pull request** with base `main` and compare `mdi1-120-finalization`, and **only merge after** Xcode build/tests and the known UI failures are resolved. After merge: `git switch main && git pull origin main`.

### Validation that could be performed in this environment

- All modified/new `.swift` files passed a Swift parser syntax check.
- The patch was generated against the reviewed version that includes your prior biometric/payroll changes.
- No Xcode app build, iOS simulation, real Face ID, deployed Supabase backend, App Store Connect review, or TestFlight submission could be verified here. The downloadable files are **source changes requiring your Xcode verification**, not a certified App Store-ready build.
