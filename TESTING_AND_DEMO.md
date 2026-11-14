# HR staff management and consolidated tests

## What changed

In Debug, sign in as HR, then open Account > Manage Staff. Add a name, email, unique employee number, role (Employee or Supervisor), and department. Edit existing staff or deactivate them. Existing employee numbers are fixed to preserve local timecard lookup. HR/admin identities cannot be edited or created from this screen.

Staff details persist locally across relaunches. New demo staff can sign in with their email and Demo123!; no invitation is sent. Use fictional data. Release does not expose this local management feature, and the production API rejects these operations until real server support exists.

The directory drives login and available shift employees. A person can exist without a shift. After adding someone, assign a shift through Shift Rosters. Promotions retain employee identity and attendance access. Demoting one of the original management-only supervisors creates their employee identity. Changing department or deactivating a person unassigns their current demo schedule; assign a new shift explicitly. Existing historical weekly packets are not rewritten. Staff changes persist, while the existing demonstration schedules, break events, and weekly packets remain in-memory samples regenerated at app launch/reset. Newly added staff do not receive fabricated historical payroll entries.

Profiles refresh on login and foreground activation. Production cross-device access changes still require server enforcement and a real profile-refresh strategy.

## File cleanup

All unit tests are now in BeaconTimeClockTests/BeaconTimeClockTests.swift, organized by MARK sections and separate test classes. The core harness excludes only SDK-dependent authentication tests using CORE_TESTS; Xcode includes them. The UI test target remains separate.

Removed the unused Hello World view and empty UI test placeholders. BasicAPIResponse lives in APIModels.swift, payroll access models live in workflowModels.swift, and TimerManagers.swift shares the countdown implementation while keeping lunch and breaks independent. Notification permission requests now have one owner. Added Face ID and location purpose descriptions to both app build configurations.

## Verification

33 core tests passed with zero failures using the actual model, demo API, directory, timer, and SwiftData sources. See TestResults/core-tests.log. New tests cover persistence/reload, duplicate validation, corrupt-data preservation, HR-only writes/reads, protected accounts, roster assignment, promotion/demotion, transfer/deactivation history, and independent timers.

The combined Swift source syntax and Xcode project plist were checked. Two authentication tests and six UI tests (including the new HR editor check) are supplied but NOT executed here. The full iOS build remains unverified: the environment could not connect to CoreSimulatorService or resolve the Supabase package manifest inside the sandbox. See TestResults/ios-build-attempt.log. CoreData store-notification registration warnings occurred in the restricted environment; the persistence tests passed.

Run locally from the project directory:

```sh
swift test --disable-sandbox
open BeaconTimeClock.xcodeproj
```

In Xcode select BeaconTimeClock and an installed iPhone simulator, then Command-U. Use Debug for the demo. Test on a physical iPhone before presenting. The Debug biometric implementation returns success automatically and uses a simulated beacon; these tests do not verify real biometric or beacon behavior.

## Rehearsal

1. HR > Account > Manage Staff: add a fictional employee and assign a department.
2. Shift Rosters: assign that employee to a same-department shift.
3. Sign out; sign in with the new email and Demo123!. Check attendance and My Shift.
4. HR: promote the person, then verify their next login has supervisor access limited to their department and still has their own attendance access. Extra tabs may appear under More on iPhone.
5. Transfer the person and verify the old assignment disappears; assign a new shift in the new department.
6. Deactivate them, then verify their login fails and they disappear from available roster choices.
7. Relaunch and verify the staff record persists. Reassign demonstration shifts as necessary after relaunch.
8. Recheck approvals, signature entry, PDF export, English/Spanish, notification timing, and sign-out.

The original demo supervisors are management-only until changed to Employee. Promoting an existing employee preserves clock access. Authentication unit fixtures use an isolated in-memory directory, while UI tests use the app's saved demo staff; keep the original HR/supervisor demo accounts active during UI tests.
