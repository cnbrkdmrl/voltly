# Voltly iOS Build (Phase 0-7 Scaffold)

This repository contains a SwiftUI + Clean Architecture scaffold for Voltly:

- Phase 0-3: Foundation, vehicle setup, charge logging, dashboard MVP
- Phase 4: UX polish (battery animation, save feedback, hero watermark, empty states)
- Phase 5: Insights V1 (splits, behavior insights, station comparison, full-charge analysis)
- Phase 6: Savings + sharing (savings screen, piggy bank, carbon module, 9:16 card)
- Phase 7 scaffold: where-to-charge recommendations, temperature impact, unplug reminders, widget extension scaffold
- Real Xcode project with iOS app target + widget extension: `Voltly.xcodeproj`

## Architecture

- `Sources/Voltly/App`
- `Sources/Voltly/Core`
- `Sources/Voltly/Domain`
- `Sources/Voltly/Data`
- `Sources/Voltly/Presentation`
- `iOSApp/`
- `WidgetExtension/`

## Xcode Setup

1. Install full Xcode.
2. Select it: `sudo xcode-select -s /Applications/Xcode.app`
3. Open project: `Voltly.xcodeproj`
4. Run QA script: `./scripts/qa_xcode.sh`

## Device Signing

- Real device install requires a valid Apple team for `VoltlyiOS` and `VoltlyWidgetsExtension`.
- If you regenerate the project, persist team id with:
  - `DEVELOPMENT_TEAM=YOUR_TEAM_ID ruby scripts/generate_xcodeproj.rb`

## Firebase (Optional)

Analytics and Crashlytics are powered by Firebase, but the config file is not part of this repository because it contains project-specific keys (`GoogleService-Info.plist` is git-ignored).

- **Without it:** the app builds and runs normally. Firebase is simply not configured and analytics/crash reporting stay disabled (`FirebaseBootstrapper.isConfigured` returns `false`).
- **With your own Firebase project:**
  1. Create a project in the [Firebase console](https://console.firebase.google.com) and register an iOS app with your bundle identifier.
  2. Download `GoogleService-Info.plist`.
  3. Add it to the `VoltlyiOS` target in Xcode (do not commit it).

## Notes

- `scripts/generate_xcodeproj.rb` regenerates the project from the current source tree.

## Migration / Upgrade

Voltly now uses a schema-based migration flow with backup readiness, feature flags, and debug tooling.

- Strategy guide: [`docs/MIGRATION_STRATEGY.md`](docs/MIGRATION_STRATEGY.md)
- Core architecture notes: [`docs/VOLTLY_CORE.md`](docs/VOLTLY_CORE.md)

Quick summary for developers:

1. App version and schema version are separate.
2. Increase schema version only when persisted data contract changes.
3. Add a dedicated migration step per schema transition (`fromVersion -> toVersion`).
4. Mark risky steps with backup requirement (`requiresBackup = true`).
5. Cover release with migration + backup + idempotency tests before shipping.
