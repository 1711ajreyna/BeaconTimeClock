# Supabase staging starter — not a complete live backend

This scaffold implements **staff account listing and creation/editing only**. It is not the attendance, payroll, shift, approval or audit backend required to deploy BeaconTimeClock live.

- `migrations/20261114000001_btc_staff.sql`: one `btc_staff_profiles` table, restricted RLS and self-profile read only for mobile users; no direct mobile writes.
- `functions/staff-list/index.ts`: list employee/supervisor profiles within the signed-in HR/supervisor's allowed scope.
- `functions/staff-save/index.ts`: invite a new employee/supervisor or update the existing account. HR alone can create supervisors; supervisors can manage employees only in their own department. Does **not** email shared passwords or expose service secrets.
- `functions/_shared/staff.ts`: JWT verification, role lookup against server-controlled profiles, and consistent authorization checks.
- `config.toml`: JWT validation on both protected functions.
- `ProductionAPIClient.swift`: `fetchStaff`/`saveStaff` call `staff-list` and `staff-save` and send the signed-in user's JWT plus publishable `apikey` header. Auth, a staff profile, deployed functions and verified role tests are prerequisites.

### Staging prerequisites

1. Create a new *staging* Supabase project. Review migration SQL before `supabase db push`.
2. Disable public signup if company policy requires invitation-only accounts. Bootstrap first HR user through a trusted administrative process: create user in Auth and a matching `btc_staff_profiles` row. No app request can grant `hr`.
3. Set up working SMTP sender, Auth email redirects, key management, policy testing and audit logging. Never embed the secret/service role key in the iPhone client.
4. Validate every role—including unauthenticated and cross-department callers—with actual Edge Function requests and tests.
5. Test failed invitations and manual reconciliation of Auth records created before a profile insert failure.

### Not implemented

`my-profile`, `submit-punch`, `my-shift`, `record-shift-event`, `shift-roster`, `create-work-shift`, `assign-work-shift`, `remove-work-shift-assignment`, `supervisor-schedule`, `update-shift-schedule`, `company-submission-status`, `hr-payroll-packet`, `supervisor-dashboard`, `department-timesheet`, `adjust-punch`, `approve-department`; plus secure audit logs, idempotent punch handling, server timestamp and attendance calculations, policy-compliant HR export history, delivery and production device verification. None of these can be inferred from the demo data.

Before real deployment, implement the missing endpoints, real payroll calculations/policies, RLS, audits, idempotency, data retention/backup and positive/negative security tests. Never migrate real staff payroll data into a demo environment.
