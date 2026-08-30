import SwiftUI

public struct AboutVoltlyView: View {
    public init() {}

    public var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    BrandLogoView(size: 96, cornerRadius: 22)
                    Text("Voltly")
                        .font(.title2.weight(.bold))
                    Text("Elektrikli araç şarj kayıtlarını takip et, maliyetini analiz et, tasarrufunu net gör.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Uygulama Özeti") {
                AboutInfoRow(
                    icon: "bolt.car.fill",
                    title: "Şarj Seans Yönetimi",
                    detail: "Ev, AC ve DC şarjlarını tarih, lokasyon, enerji ve maliyet bilgileriyle tek yerde tutar."
                )
                AboutInfoRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Maliyet Analizi",
                    detail: "TL/kWh, TL/100 km, aylık trend ve operatör bazlı farkları otomatik hesaplar."
                )
                AboutInfoRow(
                    icon: "leaf.fill",
                    title: "Tasarruf ve Etki",
                    detail: "Benzin kıyasıyla tasarrufunu ve karbon etkini anlaşılır şekilde gösterir."
                )
            }

            Section("Takip Edilen Temel Metrikler") {
                MetricExplainRow(title: "TL/kWh", detail: "Seansın birim enerji maliyeti.")
                MetricExplainRow(title: "TL/100 km", detail: "Gerçek sürüş maliyetinin standart karşılığı.")
                MetricExplainRow(title: "Aylık EV maliyeti", detail: "İlgili ay içindeki toplam şarj harcaması.")
                MetricExplainRow(title: "Şarj alışkanlığı", detail: "Ev/AC/DC dağılımı, ortalama seans ve tüketim davranışı.")
            }

            Section("Veri ve Yedekleme") {
                AboutInfoRow(
                    icon: "internaldrive.fill",
                    title: "Local-first çalışma",
                    detail: "Verilerin öncelikle cihazında saklanır; uygulama internet olmadan da temel işlevleri sürdürür."
                )
                AboutInfoRow(
                    icon: "externaldrive.fill.badge.icloud",
                    title: "Yedekleme seçenekleri",
                    detail: "JSON yedek alma/içe aktarma ve CSV dışa aktarma ile verilerini güvenli şekilde taşıyabilirsin."
                )
            }

            Section("Sürüm Bilgisi") {
                LabeledContent("Uygulama", value: "Voltly")
                LabeledContent("Sürüm", value: appVersion)
                LabeledContent("Build", value: appBuild)
            }
        }
        .listStyle(aboutListStyle)
        .navigationTitle("Uygulama Hakkında")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var aboutListStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .automatic
        #endif
    }
}

private struct AboutInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MetricExplainRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AboutVoltlyView()
    }
}
