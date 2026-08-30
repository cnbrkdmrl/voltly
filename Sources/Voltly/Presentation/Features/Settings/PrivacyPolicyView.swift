import SwiftUI

public struct PrivacyPolicyView: View {
    public init() {}

    public var body: some View {
        List {
            Section {
                Text("Voltly Gizlilik Politikası")
                    .font(.headline)
                Text("Son Güncelleme: 10 Mart 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Voltly uygulaması (\"Uygulama\"), elektrikli araç kullanıcılarının şarj maliyetlerini, enerji tüketimini ve şarj geçmişini takip etmelerine yardımcı olmak amacıyla geliştirilmiştir. Bu gizlilik politikası, uygulamayı kullanırken hangi bilgilerin toplandığını ve bu bilgilerin nasıl kullanıldığını açıklar.")
            }

            Section("1. Toplanan Bilgiler") {
                Text("Voltly aşağıdaki bilgileri kullanıcı deneyimini geliştirmek amacıyla saklayabilir:")
                Text("Kullanıcı Tarafından Girilen Bilgiler")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Araç markası ve modeli\nBatarya kapasitesi\nŞarj başlangıç ve bitiş yüzdesi\nŞarj edilen enerji miktarı (kWh)\nŞarj maliyeti (TL)\nŞarj türü (AC / DC)\nŞarj tarihi ve zamanı")
                Text("Bu bilgiler tamamen kullanıcı tarafından manuel olarak girilir.")
                Text("Cihaz Bilgileri")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Uygulama performansını iyileştirmek amacıyla anonim cihaz bilgileri toplanabilir: cihaz modeli, işletim sistemi sürümü, uygulama sürümü. Bu veriler kullanıcıyı doğrudan tanımlamaz.")
            }

            Section("2. Verilerin Kullanımı") {
                Text("Toplanan veriler şu amaçlarla kullanılır:\nşarj maliyetlerinin hesaplanması\nenerji tüketimi analizleri oluşturulması\nuygulama performansının iyileştirilmesi\nkullanıcı deneyiminin geliştirilmesi")
                Text("Voltly kullanıcı verilerini satmaz, kiralamaz veya üçüncü taraflarla ticari amaçla paylaşmaz.")
            }

            Section("3. Veri Saklama") {
                Text("Kullanıcı tarafından girilen veriler cihaz üzerinde yerel olarak saklanabilir veya kullanıcının onayı doğrultusunda güvenli sunucularda saklanabilir.")
                Text("Kullanıcı istediği zaman uygulamadan verilerini silebilir.")
            }

            Section("4. Lokasyon Verisi") {
                Text("Voltly bazı özelliklerde şarj istasyonlarını göstermek amacıyla konum verisi kullanabilir. Konum verisi yalnızca kullanıcı izin verdiğinde kullanılır ve sürekli olarak takip edilmez.")
            }

            Section("5. Üçüncü Taraf Servisler") {
                Text("Voltly aşağıdaki üçüncü taraf servisleri kullanabilir:\nApple App Store servisleri\nanonim kullanım analitiği servisleri")
                Text("Bu servisler kendi gizlilik politikalarına tabidir.")
            }

            Section("6. Veri Güvenliği") {
                Text("Voltly kullanıcı verilerinin güvenliğini sağlamak için makul teknik ve idari önlemler uygular.")
            }

            Section("7. Çocukların Gizliliği") {
                Text("Voltly 13 yaş altındaki çocuklara yönelik değildir ve bilerek çocuklardan kişisel veri toplamaz.")
            }

            Section("8. Gizlilik Politikası Güncellemeleri") {
                Text("Bu gizlilik politikası zaman zaman güncellenebilir. Güncellenmiş versiyon uygulama içinde veya ilgili web sayfasında yayınlanacaktır.")
            }
        }
        .listStyle(privacyListStyle)
        .navigationTitle("Gizlilik Politikası")
        .toolbar {
            ToolbarItem(placement: .voltlyPrimaryAction) {
                DismissButton()
            }
        }
    }

    private var privacyListStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .automatic
        #endif
    }
}

private struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Kapat") {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
