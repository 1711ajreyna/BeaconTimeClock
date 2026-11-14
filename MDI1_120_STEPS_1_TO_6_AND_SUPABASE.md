# BeaconTimeClock — MDI1 120: six steps, trial accounts, HR demo and Supabase

This guide is for the branch `mdi2-120-auth-payroll-review` that was pushed before this update. Your next feature branch may be named `mdi1-120-account-controls-demo`.

> **Important:** The supplied code was parsed for Swift syntax, but cannot be compiled or UI/biometric-tested on an iOS simulator or iPhone in this environment. The Supabase migration and Edge Function are starter examples and are **not a complete deployable timeclock backend**. Work in a staging Supabase project, not one holding real payroll information.

## Step 1 — Safely install the patch matching your branch

1. Open Terminal in the BeaconTimeClock project. Run `git status`. Commit or stash any new work first; never discard unfinished changes or use `git reset --hard`.
2. The provided ZIP contains **two ALTERNATIVE patches**. Do **not** apply both:
   - `01_FROM_SAVED_MDI2_BRANCH.patch` is a complete cumulative update if you are still on the last confirmed `mdi2-120-auth-payroll-review` branch, without the earlier MDI1 finalization patch.
   - `02_IF_FINALIZATION_ALREADY_APPLIED.patch` is only the newest account/payroll/Supabase changes, for a project that already has the earlier MDI1 finalization files and tests.
3. Choose your current branch. On the previously saved version, run `git switch mdi2-120-auth-payroll-review` then `git switch -c mdi1-120-account-controls-demo`. If you already created `mdi1-120-finalization`, stay there and create a new working branch after preserving changes.
4. Download and unzip `BeaconTimeClock_MDI1_120_Trial_Accounts_and_Supabase.zip`. Find the appropriate patch in Finder or Terminal. If you're starting from the confirmed MDI2 branch, use:

```bash
PATCH=$(find ~/Downloads -type f -name '01_FROM_SAVED_MDI2_BRANCH.patch' -print -quit)
echo "$PATCH"
git apply --check "$PATCH"
# Only if the check succeeds:
git apply "$PATCH"
git status
```

If the prior finalization patch was **already applied** to your current files, choose the incremental alternative instead:

```bash
PATCH=$(find ~/Downloads -type f -name '02_IF_FINALIZATION_ALREADY_APPLIED.patch' -print -quit)
echo "$PATCH"
git apply --check "$PATCH"
# Only if the check succeeds:
git apply "$PATCH"
git status
```

**If any check reports a conflict, stop** rather than forcing it. The complete source ZIP is for visual comparison and is not a replacement for your existing project.

## Step 2 — Verify role permissions and trial accounts

- Build in Xcode with Product → Build (⌘B), Debug configuration.
- On the login screen, under demonstration accounts, open **Trial employee by department** or **Trial supervisor by department**. All five departments are available in both menus. Selecting one fills the form; tap the full-width **Sign In** button. The existing demo password is `Demo123!` in Debug only.
- Trial employee first emails: Electrical `employee@demo.containersupply`; Machine Shop `employee7@demo.containersupply`; Metals `employee13@demo.containersupply`; Plastics `employee19@demo.containersupply`; Litho `employee25@demo.containersupply`.
- Trial supervisor emails: Electrical `supervisor@demo.containersupply`; Machine Shop `machineshop@demo.containersupply`; Metals `metals@demo.containersupply`; Plastics `plastics@demo.containersupply`; Litho `litho@demo.containersupply`.
- HR: `hr@demo.containersupply`. Employee must have no account-creation controls; supervisor can create/edit **employees only within assigned department**, not supervisors; **only HR** can create or promote supervisor accounts. Neither HR nor admins can edit operational schedules/approvals in this policy.
- Cross-department negative tests: Electrical must not be able to access/change Metals schedules or approvals. Verify that a denied action leaves underlying data unchanged.
- Run `MDI1120StaffAndPayrollTests` and `MDI1120TrialAndSimulationTests` under Test Navigator (⌘6). These are XCTest tests, and Xcode is required to execute them.

## Step 3 — HR demo approvals and PDF behavior

- Sign in as HR. Open HR Payroll. **Preview Demo Payroll PDF** must not modify source approvals, as before.
- Choose **Simulate All Five Approvals (Demo Only)**, confirm, then verify all five departmental rows say **Simulated Approved** in the HR screen. The screen separately displays the *actual* approval count and the simulated count.
- Preview the PDF: it must be labeled **DEMO PREVIEW – NOT AN APPROVAL**. The separate **Share WATERMARKED Demo PDF** action may be used for a presentation, but never as a real signed payroll export. Real signed PDF and CSV export remain locked until the five department supervisors actually approve their own records.
- End the simulation; statuses return to actual data without modifying the `DemoAPIClient` timesheets. No real signature, database write, email or ADP submission is created.
- The **PDF heading** can be edited in HR Payroll with the `Report heading` text field (default `PAYROLL`, stored on that device; tap **Reset heading to PAYROLL** to restore). Example: `PAYROLL 15/11/2026` for the Sunday ending that week. All exported payroll PDFs default to this format, including department-specific reports and clearly marked demo previews. The heading is checked before exporting. The actual week-ending Sunday date comes from the loaded payroll packet, not freeform text. Only the heading is editable in this version; a different week requires fetching that week's packet from the backend (historical-week selection is not yet implemented), to avoid falsifying source data. Filenames use `15-11-2026` because `/` is not allowed in filenames.
- Run `MDI1120RegressionTests`, `MDI1120StaffAndPayrollTests` and `MDI1120TrialAndSimulationTests`.

## Step 4 — Biometric punches, daily reports, and UI tests

- Test on a real iPhone with Face ID/Touch ID registered. For **Clock In**, **Lunch Out**, **Lunch In**, **Clock Out**, verify a fresh biometric prompt for each. Reject authentication and ensure no punch is recorded; then accept and verify it is stored on the correct work date and synced. Device biometrics prove device-owner authentication, not necessarily employment identity.
- Verify beacon presence on actual premises; a demo scanner is not acceptable proof of real beacon operation.
- Test overnight punches and shifts crossing Sunday in the employee daily view and the HR CSV/PDF. HR daily CSV should show individual work dates; weekly CSV should have one record per employee, without repeating weekly totals for each date.
- Run the existing unit tests and UI tests with Xcode Product → Test (⌘U). UI test timing can fail independently of model tests; inspect the **first** failure, not only the final count. Use `-UITesting-NoPermissions` when supported for UI startup tests, and leave actual hardware tests separate.

## Step 5 — Supabase staging integration (not yet production complete)

The iOS project already uses `SupabaseClientProvider`, `AuthManager`, and `ProductionAPIClient` with an authenticated JWT. It does **not** include the full deployed backend. `DEBUG` uses local demos, `Release` requires Supabase configuration. This update adds **production staff list/save HTTP calls and staging Edge Function examples** for account management only; none of the timekeeping, scheduling, or payroll functions are deployed or implemented here.

1. Create a *separate staging project* in Supabase and install the CLI per official instructions. Use current official docs: https://supabase.com/docs/guides/functions and https://supabase.com/docs/guides/database/postgres/row-level-security.
2. In Supabase **Authentication settings**, turn off **Allow new users to sign up** for the real employer app. Create staff by trusted invitations from the HR/supervisor functions; test the invitation flow in staging. Without this setting, people may create unaffiliated Auth records even though they cannot automatically get staff roles. Disable anonymous access and require email confirmation. <https://supabase.com/docs/guides/auth/general-configuration>.
3. From a copy of the repository, link to **staging only**: `supabase login`, then `supabase link --project-ref YOUR_STAGING_PROJECT_REF`. Verify which project is linked before migrations.
4. Review `supabase/migrations/20261114000001_btc_staff.sql`; it defines `btc_staff_profiles`, roles, departments and restrictive RLS. Then use `supabase db push` **only in staging** after inspecting the migration. Bootstrap the first HR account manually using trusted Supabase dashboard/admin procedures; a client must not grant itself HR privileges.
5. Review `supabase/functions/staff-list/index.ts`, `supabase/functions/staff-save/index.ts` and their `_shared/staff.ts` security helper. Deploy with `supabase functions deploy staff-list` and `supabase functions deploy staff-save` to staging. Both validate JWT and server-stored role. HR can invite/edit employees and supervisors; a department supervisor can manage only employees in that department. Employees cannot manage accounts. Auth invitations and profile inserts are non-atomic; reconcile partial failures safely.
6. In Xcode, configure `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as app build settings for a non-demo TestFlight/Release build. Use a **publishable** key in the app; never include a secret/service-role key. Production `ProductionAPIClient` now includes the public `apikey` header along with the user session JWT.
7. Before enabling live operation, implement and test ALL remaining production endpoints (`my-profile`, `submit-punch`, `my-shift`, `record-shift-event`, `shift-roster`, `create-work-shift`, `assign-work-shift`, `remove-work-shift-assignment`, `supervisor-schedule`, `update-shift-schedule`, `company-submission-status`, `hr-payroll-packet`, `supervisor-dashboard`, `department-timesheet`, `adjust-punch`, `approve-department`) plus staff listing, role/department editing, audit logging, payroll history and exports. Every change must be authorized server-side. Add database-backed shifts, clock events, approval signatures, idempotency keys, server timestamps, retention policies, and complete role-negative tests. The iOS demo `DemoAPIClient` is not a backend.

**Security:** Do not trust `role`, `department`, `biometricVerified`, timestamp, or GPS/beacon status simply because they arrived in an HTTP request. Associate the authenticated JWT identity with server-controlled staff records; validate server-side department scope, approval status and clock transition; consider device binding/attestation, secure offline retry and audit requirements. Stronger controls may be needed for actual wage payments. Protect employees' confidential payroll data and discuss employer/legal approval before using real staff records.

## Step 6 — Release checks and GitHub

- Test all roles, daily exports, PDF Sunday naming, login accessibility, offline errors, session expiry, push notifications, screenshots, localization, break policies, and physical iBeacon and biometric workflows. The user-facing **Sign In** button is full-width and has a full hit shape.
- Complete privacy policy/support URLs, privacy manifest validation, location/background access justification, App Store screenshots, permission copy and reviewer credentials. Apple App Review requires working credentials and backend access and may request footage of special hardware. See https://developer.apple.com/app-store/review/guidelines/.
- Upload a **staging** TestFlight build only after verified non-demo login and backend tests. Do not claim live readiness based solely on tests of the Debug/demo app. Confirm company trademark/logo use is authorized before publication.
- Stage intended code only. Don't stage `.build`, `xcuserdata`, local backups or secret files:

```bash
git status
git add BeaconTimeClock BeaconTimeClockTests BeaconTimeClockUITests \
        supabase APP_STORE_READINESS.md MDI1_120_FINALIZATION_GUIDE.md \
        MDI1_120_STEPS_1_TO_6_AND_SUPABASE.md .gitignore
git diff --cached --stat
git diff --cached --check
# Review staged changes for passwords, credentials and private employee data.
git commit -m "MDI1 120: Department trial accounts, isolated HR demo, and Supabase staging starter"
git push -u origin mdi1-120-account-controls-demo
```

Do not merge into `main` until tests pass and you have reviewed a GitHub pull request. The migration and invite function are illustrative staging code; a successful push is **not** a deployed Supabase backend.
