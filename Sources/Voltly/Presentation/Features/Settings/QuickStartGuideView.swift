import SwiftUI

public struct QuickStartGuideView: View {
    private enum DemoSeed {
        static let userDefaultsSuite = "com.voltly.quickstart.demo"
    }

    private let environment: AppEnvironment
    @State private var selectedScreenIndex = 0
    @State private var showingAddChargeDemo = false
    @Environment(\.dismiss) private var dismiss

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                heroCard
                immersiveTourSection
                quickActionsSection
                startFlowCard

                ForEach(fieldGroups) { group in
                    GuideFieldGroupCard(group: group)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Kullanım Kılavuzu")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingAddChargeDemo) {
            NavigationStack {
                AddChargeScreen(
                    viewModel: makeDemoAddChargeViewModel(),
                    demoBannerText: "Ornek kayit",
                    isDemoMode: true,
                    onSaved: {
                        showingAddChargeDemo = false
                    }
                )
            }
        }
    }

    private func makeDemoAddChargeViewModel() -> AddChargeViewModel {
        let defaults = UserDefaults(suiteName: DemoSeed.userDefaultsSuite) ?? .standard
        defaults.removePersistentDomain(forName: DemoSeed.userDefaultsSuite)

        let viewModel = AddChargeViewModel(
            environment: environment,
            userDefaults: defaults
        )

        viewModel.setChargeMethod(.publicDC)
        viewModel.selectOperator("ZES")
        viewModel.selectLocation("Kadikoy Emaar")
        viewModel.socStart = 18
        viewModel.socEnd = 82
        viewModel.totalPrice = "420"
        viewModel.tariffPricePerKWh = "9.8"
        viewModel.energyInput = "42.7"
        viewModel.durationMin = "31"
        viewModel.odometerKM = "18450"
        viewModel.outsideTempC = "14"
        viewModel.notes = "Ornek demo kaydi"
        viewModel.setSessionDate(Date())
        return viewModel
    }

    private var immersiveTourSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ürün Turu")
                        .font(.caption.weight(.bold))
                        .kerning(1.2)
                        .foregroundStyle(AppTheme.publicACColor)

                    Text("Ekranları yatay kaydırarak gez")
                        .font(.title3.weight(.bold))

                    Text("Her sayfa, ilgili ekranın ne yaptığını, hangi kartların ne anlattığını ve o bölümde neye dokunacağını gösterir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(selectedScreenIndex + 1)/\(screens.count)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.heroBackground)
                    Text("Swipe ile ilerle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            screenCarouselContent
            screenPageIndicator
            screenNavigationControls

            HStack(spacing: 8) {
                ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedScreenIndex = index
                        }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: screen.icon)
                                .font(.caption.weight(.bold))
                            Text(screen.title)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(selectedScreenIndex == index ? .white : AppTheme.heroBackground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedScreenIndex == index ? AppTheme.publicACColor : AppTheme.overlaySurface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voltly'yi nasıl okuyacağını ve nasıl veri gireceğini burada anlarsın.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Bu kılavuz, uygulama içindeki ekranları tanıtır; kartlardaki sayıların ne anlattığını ve form alanlarının hangi bilgileri istediğini adım adım açıklar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                BrandLogoView(size: 56, cornerRadius: 16)
            }

            HStack(spacing: 10) {
                GuideTag(text: "Ekranları tanı")
                GuideTag(text: "Alanları öğren")
                GuideTag(text: "Doğru veri gir")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: AppTheme.heroBackground.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var startFlowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "İlk Akış",
                title: "Uygulamaya doğru giriş sırası"
            )

            VStack(spacing: 10) {
                GuideStepCard(
                    step: "1",
                    title: "Araç ekle",
                    description: "Önce Ayarlar > Araç Yönetimi ekranından arabanı ekle. Aktif araç seçilmeden şarj kayıtları doğru araca bağlanmaz.",
                    icon: "car.fill"
                )
                GuideStepCard(
                    step: "2",
                    title: "Şarj kaydı oluştur",
                    description: "Şarj Ekle ekranında yöntem, lokasyon, maliyet ve varsa enerji/SOC verilerini gir. Analizler bu verilerden oluşur.",
                    icon: "bolt.fill"
                )
                GuideStepCard(
                    step: "3",
                    title: "Özetleri yorumla",
                    description: "Anasayfa, Analiz ve Tasarruf ekranları kaydettiğin seansların maliyet, alışkanlık ve tasarruf sonucunu yorumlar.",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "Hızlı Erişim",
                title: "Buradan doğrudan ilgili bölüme git"
            )

            VStack(spacing: 10) {
                Button {
                    Haptics.selection()
                    dismiss()
                } label: {
                    GuideActionRow(
                        icon: "arrow.left.circle.fill",
                        title: "Ayarlar'a dön",
                        subtitle: "Kılavuzdan çıkıp ayar menüsüne geri dön."
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AraclarView(environment: environment)
                } label: {
                    GuideActionRow(
                        icon: "car.fill",
                        title: "Araçları yönet",
                        subtitle: "Araç ekle, aktif aracı değiştir veya mevcut aracı düzenle."
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })

                NavigationLink {
                    BackupSettingsView(
                        viewModel: BackupSettingsViewModel(environment: environment)
                    )
                } label: {
                    GuideActionRow(
                        icon: "externaldrive.fill",
                        title: "Data & Backup'a git",
                        subtitle: "JSON yedek al, CSV dışa aktar veya yedeği içeri aktar."
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })

                NavigationLink {
                    ChargingDefaultsView(
                        viewModel: SettingsViewModel(environment: environment)
                    )
                } label: {
                    GuideActionRow(
                        icon: "house.fill",
                        title: "Şarj Varsayılanları",
                        subtitle: "Ev tarifesi, ev profilleri ve otomatik seçim ayarlarını düzenle."
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })

                NavigationLink {
                    OperatorsView(environment: environment)
                } label: {
                    GuideActionRow(
                        icon: "bolt.fill",
                        title: "Operatörleri düzenle",
                        subtitle: "Şarj operatörlerini gizle, favorile veya liste sırasını düzenle."
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })

                Button {
                    Haptics.selection()
                    showingAddChargeDemo = true
                } label: {
                    GuideActionRow(
                        icon: "plus.circle.fill",
                        title: "Şarj Ekle demosunu aç",
                        subtitle: "Formu örnek bir Public DC kaydı ile ön doldurulmuş halde aç."
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    @ViewBuilder
    private var screenCarouselContent: some View {
        #if os(iOS)
        TabView(selection: $selectedScreenIndex) {
            ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                GuideScreenShowcaseCard(
                    screen: screen,
                    position: index + 1,
                    total: screens.count
                )
                    .tag(index)
                    .padding(.bottom, 8.0)
            }
        }
        .frame(height: 540)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        GuideScreenShowcaseCard(
            screen: screens[selectedScreenIndex],
            position: selectedScreenIndex + 1,
            total: screens.count
        )
        .frame(height: 540)
        #endif
    }

    private var screenPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                Capsule()
                    .fill(selectedScreenIndex == index ? AppTheme.publicACColor : AppTheme.overlaySurface)
                    .frame(width: selectedScreenIndex == index ? 26 : 10, height: 8)
                    .overlay {
                        if selectedScreenIndex == index {
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("\(screen.title) sayfası")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var screenNavigationControls: some View {
        HStack(spacing: 10) {
            Button {
                guard selectedScreenIndex > 0 else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    selectedScreenIndex -= 1
                }
                Haptics.selection()
            } label: {
                Label("Geri", systemImage: "arrow.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedScreenIndex == 0 ? .secondary : AppTheme.heroBackground)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedScreenIndex == 0 ? AppTheme.overlaySurface.opacity(0.65) : AppTheme.overlaySurface)
            )
            .disabled(selectedScreenIndex == 0)

            Button {
                guard selectedScreenIndex < screens.count - 1 else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    selectedScreenIndex += 1
                }
                Haptics.selection()
            } label: {
                Label(selectedScreenIndex == screens.count - 1 ? "Son" : "İleri", systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedScreenIndex == screens.count - 1 ? AppTheme.homeColor : AppTheme.publicACColor)
            )
            .disabled(selectedScreenIndex == screens.count - 1)
            .opacity(selectedScreenIndex == screens.count - 1 ? 0.72 : 1)
        }
    }

    private func sectionHeader(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .kerning(1.2)
                .foregroundStyle(AppTheme.publicACColor)
            Text(title)
                .font(.title3.weight(.bold))
        }
    }

    private var screens: [GuideScreen] {
        [
            GuideScreen(
                icon: "house.fill",
                title: "Anasayfa",
                summary: "Aktif araç için aylık maliyet, 100 km gider ve son şarj görünümünü tek ekranda verir.",
                previewStyle: .dashboard,
                bullets: [
                    "Bu Ay EV Maliyeti: Bu ayki toplam elektrikli araç harcaman.",
                    "100 km maliyeti: Sürüş başına maliyetini anlamanı sağlar.",
                    "Benzine göre daha ucuz: Benzin kıyasını tek satırda özetler.",
                    "Aylık harcama trendi: Son aylardaki değişimi görürsün.",
                    "Son şarjlar: En son seansları hızlıca kontrol edersin."
                ]
            ),
            GuideScreen(
                icon: "plus.circle.fill",
                title: "Şarj Ekle",
                summary: "Bir şarj seansını kaydettiğin ana veri giriş ekranıdır.",
                previewStyle: .addCharge,
                bullets: [
                    "Yöntem, lokasyon, maliyet ve enerji bilgileri burada girilir.",
                    "Zorunlu alanlar kaydı oluşturur; opsiyonel alanlar analizleri güçlendirir.",
                    "Kaydetmeden önce anlık özet bölümünden girdiğini kontrol edebilirsin."
                ]
            ),
            GuideScreen(
                icon: "list.bullet.rectangle.portrait",
                title: "Şarjlar",
                summary: "Tüm kayıtlarını filtreleyip karşılaştırdığın detay ekranıdır.",
                previewStyle: .charges,
                bullets: [
                    "Yöntem, dönem ve sıralama filtreleriyle kayıtları daraltırsın.",
                    "Kartlarda tarih, istasyon, enerji, TL/kWh ve süre görünür.",
                    "Eski kayıtları bulup düzenleme mantığı için ana ekrandır."
                ]
            ),
            GuideScreen(
                icon: "waveform.path.ecg",
                title: "Analiz",
                summary: "Şarj alışkanlığı ve maliyet davranışını yorumlar.",
                previewStyle: .insights,
                bullets: [
                    "Home / AC / DC dağılımı hangi yöntemi ne kadar kullandığını gösterir.",
                    "Davranış içgörüleri alışkanlıklarını açık dille yorumlar.",
                    "İstasyon maliyet sıralaması en avantajlı operatörleri bulmana yardım eder.",
                    "Sıcaklık ve full charge kartları kullanım stilini görünür kılar."
                ]
            ),
            GuideScreen(
                icon: "banknote.fill",
                title: "Tasarruf",
                summary: "Elektrikli araç kullanımının maliyet ve karbon etkisini gösterir.",
                previewStyle: .savings,
                bullets: [
                    "Tasarruf Özeti: EV harcaman ve benzin eşdeğerin karşılaştırılır.",
                    "Tasarruf Kumbarası: Tasarrufunun günlük hayattaki karşılıklarını görürsün.",
                    "Karbon Kaçınımı: Kaç kg CO2 önlediğini ve ağaç eşdeğerini okursun.",
                    "Paylaşım kartı: Sonucu görsel veya metin olarak paylaşabilirsin."
                ]
            ),
            GuideScreen(
                icon: "gearshape.fill",
                title: "Ayarlar",
                summary: "Araç, varsayılan, benzin kıyası ve veri yönetimi burada bulunur.",
                previewStyle: .settings,
                bullets: [
                    "Araç Yönetimi: Aktif araç değiştirir veya yeni araç eklersin.",
                    "Şarj Varsayılanları: Ev profili ve otomatik seçim ayarlarını yönetirsin.",
                    "Uygulama Tercihleri: Para birimi ve mesafe birimini ayarlarsın.",
                    "Data & Backup: JSON/CSV export ve import işlemleri burada yapılır."
                ]
            )
        ]
    }

    private var fieldGroups: [GuideFieldGroup] {
        [
            GuideFieldGroup(
                title: "Şarj Ekle Alanları",
                subtitle: "Bu alanlar analizleri besleyen ham veriyi oluşturur.",
                icon: "bolt.badge.clock.fill",
                accent: AppTheme.publicACColor,
                items: [
                    ("Yöntem", "Ev, Public AC veya Public DC seçersin. Bu seçim varsayılan fiyatları ve bazı analizleri etkiler."),
                    ("Operatör / İstasyon markası", "Şarjı hangi operatörde yaptığını belirtir. Operatör maliyet karşılaştırmalarında kullanılır."),
                    ("Lokasyon", "İstasyon veya şube adıdır. Harita ve geçmiş lokasyon eşleştirmeleri bu alanı kullanır."),
                    ("Başlangıç ve bitiş şarj yüzdesi", "Bataryanın şarj öncesi ve sonrası yüzdesidir. Alışkanlık ve dolum analizi için önemlidir."),
                    ("Toplam tutar", "Ödediğin toplam bedeldir. Kaydın zorunlu alanıdır ve tüm maliyet hesaplarının temelidir."),
                    ("Tarife ücreti (TL/kWh)", "KWh başına fiyatı belirtir. Girilirse TL/kWh analizleri daha doğru olur."),
                    ("Enerji (kWh)", "Bu seansta araca aktarılan enerjidir. Tüketim ve operatör karşılaştırmalarını güçlendirir."),
                    ("Süre (dk)", "Şarjın toplam süresidir. Ortalama şarj hızı için kullanılır."),
                    ("Odometre (km)", "Şarj anındaki kilometre. Gerçek sürüş tüketimi ve 100 km maliyeti için çok değerlidir."),
                    ("Dış sıcaklık (C)", "Hava sıcaklığıdır. Sıcaklık etkisi analizinde kullanılır."),
                    ("Not", "Serbest açıklama alanıdır. Kendi bağlam notlarını ekleyebilirsin."),
                    ("Tarih", "Şarjın yapıldığı gün ve saattir. Tüm grafikler buna göre oluşur."),
                    ("Bu şarjın özeti", "Kaydetmeden önce sistemin hesapladığı kısa kontrol alanıdır.")
                ]
            ),
            GuideFieldGroup(
                title: "Araç Ekle / Araç Yönetimi",
                subtitle: "Araç verisi, tüm maliyet ve tüketim yorumlarının temelidir.",
                icon: "car.rear.and.tire.marks",
                accent: AppTheme.publicDCColor,
                items: [
                    ("Marka", "Aracın üreticisidir. Örn: Tesla, Opel, BMW."),
                    ("Model", "Seçtiğin markaya ait model bilgisidir."),
                    ("Donanım / Trim", "Modelin farklı paket veya versiyonunu belirtir."),
                    ("Model yılı", "Batarya kapasitesi ve teknik katalog eşleşmesi için kullanılır."),
                    ("Renk kodu", "Opsiyoneldir. Görsel ayırt etme içindir; analizleri etkilemez."),
                    ("Sistem Teknik Verisi", "Katalogdan gelen batarya, AC/DC hız ve tüketim bilgileridir; manuel giriş değildir.")
                ]
            ),
            GuideFieldGroup(
                title: "Ayarlar Alanları",
                subtitle: "Tasarruf ve varsayılanlar bu alanlardan beslenir.",
                icon: "slider.horizontal.3",
                accent: AppTheme.homeColor,
                items: [
                    ("Para birimi", "Maliyet ekranlarında kullanılacak temel para birimidir."),
                    ("Mesafe birimi", "Uygulamadaki mesafe gösterimini belirler."),
                    ("Benzin fiyatı (TL/litre)", "Tasarruf ve benzin kıyası için litre başına fiyatı ister."),
                    ("Benzin tüketimi (L/100 km)", "Eşdeğer içten yanmalı aracın ortalama tüketimidir."),
                    ("Genel ev elektrik fiyatı", "Ev şarjı kayıtlarında profil fiyatı yoksa varsayılan olarak kullanılır."),
                    ("Ev profilleri", "Ev, iş yeri veya ikinci ev gibi farklı şarj noktalarını ayrı ayrı tanımlarsın."),
                    ("Şarj kayıtlarında otomatik seçim", "Ev profillerinden hangisinin varsayılan geleceğini belirler.")
                ]
            ),
            GuideFieldGroup(
                title: "Data & Backup",
                subtitle: "Verini dışa aktarır, taşır ve geri yüklersin.",
                icon: "externaldrive.fill.badge.icloud",
                accent: AppTheme.dcAccent,
                items: [
                    ("Tam Yedek (JSON)", "Araçlar ve şarj kayıtları dahil tüm veriyi tek dosyada dışa aktarır."),
                    ("Şarj Kayıtları (CSV)", "Seansları tablo/rapor için paylaşılabilir biçimde çıkarır."),
                    ("İçe Aktar", "Daha önce aldığın JSON yedeğini yeniden uygulamaya yükler."),
                    ("İpucu", "Tasarruf yüzdesi için benzin fiyatı ve tüketim alanlarını boş bırakmamak gerekir.")
                ]
            )
        ]
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                AppTheme.surface,
                AppTheme.publicACColor.opacity(0.08),
                AppTheme.homeColor.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                AppTheme.heroBackground,
                AppTheme.publicACColor.opacity(0.92),
                AppTheme.dcAccent.opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(AppTheme.elevatedSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppTheme.publicACColor.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

private struct GuideTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct GuideScreen: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let summary: String
    let previewStyle: GuideMiniPreview.Style
    let bullets: [String]
}

private struct GuideFieldGroup: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let items: [(String, String)]
}

private struct GuideStepCard: View {
    let step: String
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.publicACColor.opacity(0.14))
                    .frame(width: 42, height: 42)

                Text(step)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.publicACColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(AppTheme.publicACColor)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
        )
    }
}

private struct GuideScreenShowcaseCard: View {
    let screen: GuideScreen
    let position: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: screen.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.publicACColor)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(screen.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text(screen.summary)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }

                    Text("Bu sayfada hangi kartı neden okuyacağını ve hangi alana ne gireceğini hızlıca görürsün.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 12)

                Text("\(position)/\(total)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }

            GuideMiniPreview(style: screen.previewStyle)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(screen.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.top, 2)
                        Text(bullet)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill")
                    .font(.caption.weight(.bold))
                Text("Sağa veya sola kaydırarak diğer ekranlara geç.")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.heroBackground,
                            AppTheme.publicACColor.opacity(0.92),
                            AppTheme.dcAccent.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: AppTheme.heroBackground.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

private struct GuideMiniPreview: View {
    enum Style {
        case dashboard
        case addCharge
        case charges
        case insights
        case savings
        case settings
    }

    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Capsule()
                    .fill(AppTheme.publicACColor.opacity(0.22))
                    .frame(width: 78, height: 8)
                Spacer()
                Circle()
                    .fill(AppTheme.publicDCColor.opacity(0.8))
                    .frame(width: 10, height: 10)
            }

            content

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(callouts, id: \.self) { callout in
                        Text(callout)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.heroBackground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.overlaySurface)
                            .clipShape(Capsule())
                    }
                }
                .padding(.trailing, 8)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.publicACColor.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .dashboard:
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.heroBackground, AppTheme.publicACColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 54)
                HStack(spacing: 8) {
                    previewTile
                    previewTile
                }
                previewLine(width: 0.9)
                previewLine(width: 0.72)
            }
        case .addCharge:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    previewPill(color: AppTheme.homeColor)
                    previewPill(color: AppTheme.publicACColor)
                    previewPill(color: AppTheme.publicDCColor)
                }
                previewField
                previewField
                HStack(spacing: 8) {
                    previewField
                    previewField
                }
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.publicACColor)
                    .frame(height: 18)
            }
        case .charges:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    previewPill(color: AppTheme.overlaySurface)
                    previewPill(color: AppTheme.overlaySurface)
                }
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.elevatedSurface)
                        .frame(height: 34)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(AppTheme.publicACColor)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 4) {
                                    previewLine(width: 0.42)
                                    previewLine(width: 0.28)
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                }
            }
        case .insights:
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 6) {
                    previewBar(height: 16, color: AppTheme.homeColor)
                    previewBar(height: 26, color: AppTheme.publicACColor)
                    previewBar(height: 36, color: AppTheme.publicDCColor)
                    previewBar(height: 22, color: AppTheme.dcAccent)
                }
                .frame(height: 40, alignment: .bottomLeading)
                HStack(spacing: 8) {
                    previewTile
                    previewTile
                    previewTile
                }
                previewField
            }
        case .savings:
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.heroBackground, AppTheme.homeColor.opacity(0.84)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 42)
                HStack(spacing: 8) {
                    previewTile
                    previewTile
                }
                HStack(spacing: -6) {
                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: "tree.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green.opacity(1 - (Double(index) * 0.12)))
                            .padding(6)
                            .background(AppTheme.overlaySurface)
                            .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .settings:
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(AppTheme.publicACColor.opacity(0.2))
                            .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 4) {
                            previewLine(width: 0.46)
                            previewLine(width: 0.24)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var callouts: [String] {
        switch style {
        case .dashboard:
            return ["Aylık maliyeti oku", "Grafiğe dokun", "Son şarjları kontrol et"]
        case .addCharge:
            return ["Yöntem seç", "Alanları doldur", "Kaydet'e bas"]
        case .charges:
            return ["Filtre uygula", "Kaydı aç", "Detayları karşılaştır"]
        case .insights:
            return ["Grafiği yorumla", "Kartları oku", "İstasyonları kıyasla"]
        case .savings:
            return ["Tasarrufu gör", "Karbonu oku", "Kartı paylaş"]
        case .settings:
            return ["Bölüm seç", "Tercih güncelle", "Backup aç"]
        }
    }

    private var previewTile: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppTheme.overlaySurface)
            .frame(height: 26)
    }

    private var previewField: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppTheme.overlaySurface)
            .frame(height: 22)
    }

    private func previewPill(color: Color) -> some View {
        Capsule()
            .fill(color.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 16)
    }

    private func previewBar(height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func previewLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.22))
            .frame(width: max(48, 220 * width), height: 8)
    }
}

private struct GuideFieldGroupCard: View {
    let group: GuideFieldGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: group.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(group.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.headline.weight(.bold))
                    Text(group.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(group.items.enumerated()), id: \.offset) { index, item in
                    GuideFieldRow(
                        index: index + 1,
                        title: item.0,
                        description: item.1,
                        accent: group.accent
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(group.accent.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct GuideActionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.publicACColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.publicACColor.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct GuideFieldRow: View {
    let index: Int
    let title: String
    let description: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 28, height: 28)
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
        )
    }
}

#Preview {
    NavigationStack {
        QuickStartGuideView(environment: try! AppEnvironment.live(inMemory: true))
    }
}
