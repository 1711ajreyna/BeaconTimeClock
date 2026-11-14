# App Store readiness — reviewed November 7, 2026

There is no guaranteed first-pass approval. This is currently a demo-oriented project, not a verified production submission.

## Concrete project gaps

- **Build toolchain:** the active toolchain here is Xcode 16.4. Apple currently requires Xcode 26 or later and an iOS 26 SDK or later for uploads. Install a supported release toolchain, build, archive, and validate there. Keeping an iOS 18.5 deployment target is separate from the SDK used to build. [Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)
- **Release backend:** Release disables demo auth. AppConfig expects SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, but these are not configured in this project. ProductionAPIClient expects deployed endpoints. No backend implementation was included. Complete real authentication, server authorization, roster/payroll persistence, and staff invitation/role-management endpoints before advertising those features in Release.
- **Device permissions:** added the missing Face ID and foreground location descriptions. Test permission denial, hardware absence, and recovery on a real iPhone. Debug skips actual biometric checks and simulates the beacon. [Face ID documentation](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id)
- **Privacy:** no published privacy-policy link or complete app privacy manifest was found in the supplied app. Supply your real policy and support URLs; audit SDK manifests and required-reason API use (including UserDefaults); complete accurate App Store privacy disclosures based on the actual backend. Do not declare that attendance, identity, or proximity data is never collected without checking the deployment.

## Useful additions before submission

1. Add an Account > Privacy & Support section with your real privacy policy and support contact. Apple's guidelines require accessible privacy information, functional submissions, and accurate metadata. These URLs cannot be invented from the source code. [Review guidelines](https://developer.apple.com/app-store/review/guidelines/)
2. Implement account deletion if the production app supports account creation. HR deactivation only blocks access and is not account deletion. Define which records must be retained and explain that policy; deletion must have a real backend effect. [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)
3. Give reviewers working accounts for each role, a running backend, and instructions for hardware-dependent workflows. Apple requests a physical-device video for required hardware; arrange the necessary beacon review resources. Do not silently bypass attendance checks in the production build. [Complete-review requirements](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)
4. Add clear permission-denied/settings recovery and network-error/retry states, then test VoiceOver, larger text, iPad layouts, and Spanish. These improve usability and make the core workflow easier to review.

No production staff-management backend, deletion endpoint, policy website, or App Store submission was created in this change. Local HR controls are intentionally labeled as a device-only demo. Decide how this workforce-only app should be distributed before preparing its store listing.
