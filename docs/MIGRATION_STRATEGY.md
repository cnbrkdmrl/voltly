# Voltly Migration & Upgrade Strategy

Bu doküman Voltly'nin V0 -> V1 -> V2 büyüme yolunda veri güvenliğini koruyarak sürüm yükseltme yapabilmesi için standartları tanımlar.

## 1) App Version vs Schema Version

- `App Version` (`CFBundleShortVersionString`, ör: `1.4.0`):
  - Ürünün yayınlanan uygulama sürümüdür.
  - Pazarlama/release takibi için kullanılır.
- `Schema Version` (ör: `6`, `7`, `8`):
  - Local persistence yapısının teknik sürümüdür.
  - Migration zincirinin çalışma hedefini belirler.

Kural:
- App version ve schema version bire bir artmak zorunda değildir.
- Bir app sürümü schema değiştirmeyebilir.
- Bir app sürümü birden fazla migration adımı içerebilir.

## 2) Yeni Sürüm Çıkarken Geliştirici Ne Yapmalı?

1. Değişiklikleri sınıflandır:
   - Sadece UI/iş kuralı mı?
   - Kalıcı veri modeli etkileniyor mu?
2. Veri modeli etkileniyorsa migration ihtiyacını değerlendir.
3. Gerekliyse:
   - `LocalSchemaVersion.current` artır.
   - Yeni migration sınıfı ekle.
   - `MigrationRegistry.makeDefault()` zincirine ekle.
   - Gerekirse `requiresBackup = true` işaretle.
4. Testleri yaz/yenile:
   - Zincir testi
   - Eksik adım testi
   - Başarısız adımda schema ilerlememe testi
5. Debug ekranından migration history + backup durumunu doğrula.

## 3) Yeni Migration Ne Zaman Yazılmalı?

Migration yaz:
- Kalıcı depolamada yeni alan ekleniyorsa
- Alan adı/formatı değişiyorsa
- Enum raw value/semantik dönüşümü varsa
- Eski veriyi yeni kurala göre normalize etmek gerekiyorsa
- Feature flag defaultlarının eski kullanıcıya güvenli taşınması gerekiyorsa

Migration yazma:
- Sadece görünüm metni/layout değişiyorsa
- Hesaplama algoritması sadece runtime datadan çalışıyorsa
- Local depolamada format değişikliği yoksa

## 4) Hangi Değişiklik Migration Gerektirir?

Migration gerektirir:
- Persisted modelde zorunlu alan ekleme
- Persisted enum dönüşümü
- Persisted key rename/split/merge
- Eski datanın yeni kurala göre dönüştürülmesi
- Legacy key -> yeni key geçişi

Migration gerektirmez:
- Feature flag ile aç/kapa yapılabilen yeni modül
- Sadece ekran davranışı
- Sadece network çağrısı veya servis katmanı iyileştirmesi

## 5) Hangi Değişiklik Sadece Feature Flag ile Yönetilir?

Sadece feature flag:
- Yeni kart/öneri paneli
- Deneysel analiz metni
- Opsiyonel workflow (ör. beta dashboard kartları)
- Export butonu gibi modüler UI parçaları

Flag + migration birlikte:
- Eski kullanıcı için flag key bootstrap gerekiyorsa
- Yeni flag setine legacy key map yapılacaksa

## 6) Backward Compatibility Kuralları

- Migrationlar ileri yönlü ve sıralı çalışır (`fromVersion -> toVersion`).
- Unknown/legacy değerlerde güvenli fallback kullanılmalıdır.
- Migration adımı tek sorumluluk taşımalıdır.
- Migration idempotent olmalıdır (aynı adım yeniden çalışsa sistemi bozmaz).
- Migration başarısızsa schema marker ileri alınmamalıdır.
- Eksik zincir adımı release blocker kabul edilir.

## 7) Veri Alanı Ekleme Kuralları

- Önce `optional` düşün:
  - İlk geçişte veri kaybı ve crash riski azalır.
- Zorunlu alan eklenecekse:
  - Migration içinde deterministic default üret.
  - Default üretilemiyorsa alanı geçici optional taşıyıp ikinci sürümde zorunluya çevir.
- Key adı değişecekse:
  - Eski key bir süre okunabilir tutulmalı veya migration ile taşınmalı.

## 8) Enum / Model Değişim Kuralları

- Enum dönüşümünde:
  - Bilinmeyen değerler için fallback raw value zorunlu.
  - Fallback davranışı kod içinde açık yorumla belirtilmeli.
- Model dönüşümünde:
  - Tek migration tek model dönüşümü prensibi.
  - Bir migration başka migration'ın işini tekrar etmemeli.

## 9) Backup Gerektiren Değişiklik Tipleri

`requiresBackup = true` önerilir:
- Enum semantik dönüşümü (ör. string -> enum)
- Veri kaybı riski olan field merge/split
- Silme/temizleme yapan migration adımları
- Birden fazla persisted alanın birlikte yeniden yazılması

`requiresBackup = false` olabilir:
- Sadece yeni optional alan ekleme
- Salt default değer bootstrapı
- Veri kaybı riski taşımayan key ekleme

Not:
- Backup alınamazsa:
  - `requiresBackup = true` adımlarında migration durmalıdır.
  - Kritik değilse loglanıp kontrollü devam edilebilir.

## 10) Release Checklist

- [ ] `LocalSchemaVersion.current` doğru sürümde.
- [ ] Yeni migration registry zincirine eklendi.
- [ ] `fromVersion/toVersion` zinciri kopuksuz.
- [ ] Duplicate migration id yok.
- [ ] Gerekli adımlarda `requiresBackup` tanımlı.
- [ ] Feature flag default/legacy map doğrulandı.
- [ ] Launch akışında migration success/failure state doğrulandı.
- [ ] Debug migration ekranında:
  - [ ] Current/target schema doğru
  - [ ] Migration history kayıtları doğru
  - [ ] Last error alanı doğru
  - [ ] Backup state doğru

## 11) Test Checklist

- [ ] Fresh install testi
- [ ] Eski schema -> yeni schema yükseltme testi
- [ ] Çok adımlı zincir testi
- [ ] Eksik migration adımı testi
- [ ] Duplicate id testi
- [ ] Hatalı sıra uyarısı testi
- [ ] Idempotent tekrar çalışma testi
- [ ] Feature flag migration testi
- [ ] Backup tetiklenme testi
- [ ] Başarısız migration sonrası schema ilerlememe testi

## 12) Migration Ekleme Şablonu

```swift
import Foundation

public struct MigrateXToY: Migration {
    public let id = "migration.vX_to_vY.your_change_name"
    public let name = "Kisa ve acik migration adi"
    public let fromVersion = X
    public let toVersion = Y
    public let isRequired = true
    public let requiresBackup = false // veri kaybi riski varsa true

    public init() {}

    public func run(context: MigrationContext) throws {
        // 1) Eski veriyi oku
        // 2) Donusumu deterministic uygula
        // 3) Guvenli fallback kullan
        // 4) Kaydet
        // Not: Adim idempotent olmali
    }
}
```

Registry ekleme:

```swift
try MigrationRegistry(
    migrations: [
        /* ...onceki adimlar... */
        MigrateXToY()
    ]
)
```

## 13) V0 -> V1 -> V2 Büyüme Notları

- V0 (MVP):
  - Hızlı iteration, düşük schema churn hedefi.
  - Yeni alanları mümkün olduğunca optional tut.
- V1 (ölçeklenen ürün):
  - Migration + backup + feature flag üçlüsünü standartlaştır.
  - Her release migration checklist zorunlu.
- V2 (modüler platform):
  - Migrationları domain bazlı paketle.
  - Daha ayrıntılı rollback stratejisine geç (snapshot restore veya selective restore).
  - Migration telemetrisi ile release kalitesini ölç.

## 14) Operasyonel Kural (Kısa)

- "Veri formatı değişiyorsa migration düşün."
- "Veri kaybı riski varsa backup zorunlu yap."
- "Kullanıcıya hemen açmak zorunda değilsen feature flag kullan."
