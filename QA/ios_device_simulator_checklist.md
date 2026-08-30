# Voltly iOS + Widget QA Checklist

## Simulator Smoke
- Launch app on latest iPhone simulator
- Add vehicle, set active vehicle
- Add charge with missing kWh and verify `~ Tahmini`
- Verify dashboard hero TL/100km and watermark
- Verify Insights recommendations and temperature card
- Verify Savings card render/share button appears
- Add widget to home screen and verify small + medium content

## Device Smoke
- Install on physical device via Xcode
- Verify haptic on save in Add Charge
- Grant notifications and confirm unplug reminder scheduling
- Verify share sheet for 9:16 savings card opens

## Data/Logic Checks
- Full charge sets `is_full_charge`
- Home/AC/DC split values sum to ~100%
- Gasoline baseline changes affect savings modules
- Station comparison ranking remains stable across refresh

## Regression
- No crash when no active vehicle
- No crash when no sessions
- Widget extension builds with app
