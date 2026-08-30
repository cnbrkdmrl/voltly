# VOLTLY CORE

## 1. Ürün Tanımı
Voltly:
Elektrikli araç kullanıcıları için şarj, tüketim, menzil ve tasarruf verilerini takip eden, kullanıcıya anlaşılır ve güvenilir içgörüler sunan mobil uygulamadır.

## 2. Temel Prensipler
- Gerçek veri ile tahmini veri asla karıştırılmaz
- Fabrika verisi kullanılıyorsa açıkça belirtilir
- Eksik veri gizlenmez, doğru etiketlenir
- Kullanıcı güveni, görsellikten daha önemlidir
- Sessiz hata veya gizli fallback yapılmaz

## 3. Hesaplama Kuralları
- Blok mantığı kullanılabilir (1000km+ veri)
- 2500km üstü -> alt blok ile hesap
- 500km altı -> fabrika verisi fallback
- Fabrika fallback -> UI'da etiket zorunlu
- Tasarruf:
  - son ay
  - son yıl
- Veri kaynağı gerektiğinde açıklanmalı

## 4. Veri Kuralları
- Fake data != gerçek veri (ayrı tutulur)
- Operatör verisi eksikse tam gibi gösterilemez
- Kullanıcı verisi sessiz overwrite edilemez
- Export / backup veri bütünlüğü korunmalı

## 5. UI / UX Kuralları
- Sade + premium
- Veri etiketleri zorunlu:
  - gerçek
  - tahmini
  - fabrika
- Ayarlar modüler ve anlaşılır olmalı
- Kullanıcıya kontrol hissi verilmeli

## 6. Geliştirme Kuralları
- Kritik hesaplama değişikliği testsiz yapılmaz
- Fake data prod'a çıkamaz
- Debug ayarları release öncesi temizlenir
- Placeholder içerik bırakılmaz
- Büyük değişiklikte upgrade/migration düşünülür

## 7. Release Mantığı
Release yapılmaz eğer:
- veri güveni şüpheli ise
- hesaplama belirsiz ise
- kullanıcıyı yanıltma riski varsa

## 8. AI Kullanım Talimatı
- Önce bu dosyayı referans al
- Kararlarla çelişiyorsan belirt
- Mevcut sistemi bozma, genişlet
- Hesaplama ve veri alanında muhafazakar ol

## 9. Hızlı Kontrol (Mental Checklist)
- Bu veri gerçek mi tahmin mi?
- Kullanıcıyı yanıltıyor muyum?
- Fallback görünür mü?
- Veri eksik mi?
- Release'e hazır mı?
