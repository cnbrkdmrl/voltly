# AGENTS.md

## Verified Workflows
- Run end-to-end Xcode QA checks (schemes, app/widget build, archive, simulator smoke):
  - `./scripts/qa_xcode.sh`
- Regenerate the Xcode project from source tree:
  - `ruby scripts/generate_xcodeproj.rb`
  - Requires Ruby gem: `xcodeproj`
- Run Swift Package tests:
  - `swift test`
  - Current known failure: [`Tests/VoltlyTests/Unit/CalculationUseCasesTests.swift`](/Users/canberk/Desktop/Projeler/Voltly/Tests/VoltlyTests/Unit/CalculationUseCasesTests.swift):15 (`XCTAssertEqual` expects `Double`, got `Double?`).

## App Store Yayın Öncesi Yapılacaklar

- [ ] **Firebase kurulumu:** Firebase konsolundan `GoogleService-Info.plist` indir, Xcode'da `VoltlyiOS` target'ına ekle. Olmadan analytics ve crash raporlama çalışmaz (uygulama sessizce devam eder, `FirebaseBootstrapper.isConfigured` false döner).
- [ ] **App Store ID:** Uygulama App Store Connect'te oluşturulduktan sonra `AppConstants.appStoreReviewURLString` içindeki `id0000000000`'ı gerçek ID ile değiştir. Ayarlar'daki "Uygulamayı değerlendir" butonu da tekrar eklenebilir.
- [ ] **Apple/Google Sign-In:** Gerçek auth entegrasyonu hazır olduğunda `AuthSessionManager.signInWithApple()` ve `signInWithGoogle()`'ı ASAuthorizationController ile implement et; `AuthUpsellScreen` ve `SettingsScreen`'e butonları geri ekle.
- [ ] **Domain:** `voltly.app` canlıya alındığında `AppConstants.feedbackFormURLString` ve `privacyPolicyURLString` URL'lerini test et.
- [ ] **PrivacyInfo.xcprivacy:** `Sources/Voltly/Resources/PrivacyInfo.xcprivacy` oluşturuldu ve `project.pbxproj`'a eklendi. Xcode'da "Resources" grubunda göründüğünü doğrula.

## TODO
- Confirm fallback simulator name in `scripts/qa_xcode.sh` if `iPhone 16` is unavailable on a machine.
