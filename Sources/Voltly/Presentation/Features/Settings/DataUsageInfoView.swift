import SwiftUI

public struct DataUsageInfoView: View {
    public init() {}

    public var body: some View {
        List {
            Section("Veri Kullanımı") {
                Text("Şarj kayıtların, analiz hesaplamaları ve rozet ilerlemen uygulama deneyimini kişiselleştirmek için kullanılır.")
                Text("Veriler öncelikle bu cihazda saklanır. Hesapla giriş yaparsan yedekleme senaryolarında kullanılabilir.")
                Text("Dışa aktar özelliği ile kayıtlarını CSV formatında paylaşabilir veya arşivleyebilirsin.")
            }
        }
        .listStyle(dataUsageListStyle)
        .navigationTitle("Veri Kullanımı")
    }

    private var dataUsageListStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .automatic
        #endif
    }
}
