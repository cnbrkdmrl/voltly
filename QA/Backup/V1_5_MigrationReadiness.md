# Voltly Backup V1.5 Migration Readiness

Bu dokuman, V1 yerel-yedek mimarisinin CloudKit tabanli bir V1.5 senkronizasyonuna nasil genisletilecegini ozetler.

## CloudKit'e genisletilebilir mevcut katmanlar

- `BackupServiceProtocol`: Uygulama seviyesindeki disa aktar / ice aktar orkestrasyon noktasi.
- `ExportServiceProtocol` ve `ImportServiceProtocol`: Dosya bazli akislardan ag/senkronizasyon akislarina genisletilebilir.
- `SyncCandidate` ve `SyncMetadata`: Farkli veri kaynaklarinda ortak merge karari icin temel metadata kontrati.
- `BackupMergeEngine`: `updatedAt` ve `isDeleted` metadatasi ile gelen kayitlarin birlestirme kararini verir.

## Sync state nereye eklenmeli

- Yeni bir `SyncStateStore`/`SyncStatusService` katmani `Services/Backup/Core` altina eklenebilir.
- UI tarafinda `Features/Settings/BackupSettingsViewModel` ve gerekiyorsa dashboard banner koordinatori, bu store'dan durum okuyabilir.
- Ornek durumlar: `idle`, `syncing`, `needsRetry`, `lastSyncedAt`.

## Mevcut merge motoru nasil yeniden kullanilir

- CloudKit'ten gelen kayitlar DTO veya model seviyesinde `SyncCandidate` protokolunu uygular.
- Yerel kayitlar da `SyncCandidate` olarak temsil edilir.
- `BackupMergeEngine.decide(local:incoming:)` dogrudan kullanilarak:
  - yeni kayitlar `inserted`
  - daha yeni uzak kayitlar `updated`
  - daha eski kayitlar `skipped`
  - kimlik uyumsuzluklari `failed`
  olarak ele alinir.

Bu yapi sayesinde V1 dosya import mantigi ile V1.5 CloudKit sync mantigi ayni merge davranisini paylasabilir.
