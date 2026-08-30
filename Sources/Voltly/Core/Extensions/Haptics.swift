import Foundation
#if os(iOS)
import UIKit
#endif

public enum Haptics {
    /// Küçük seçim değişimlerinde hafif geri bildirim verir.
    public static func selection() {
        #if os(iOS)
        #if targetEnvironment(simulator)
        return
        #else
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
        #endif
    }

    /// Düşük yoğunluklu etkileşimlerde yumuşak dokunsal geri bildirim verir.
    public static func softImpact() {
        #if os(iOS)
        #if targetEnvironment(simulator)
        return
        #else
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
        #endif
        #endif
    }

    /// Başarılı tamamlanma durumlarında güçlü bildirim verir.
    public static func success() {
        #if os(iOS)
        #if targetEnvironment(simulator)
        return
        #else
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
        #endif
    }

    /// Hata veya başarısız işlem durumlarında uyarı verir.
    public static func error() {
        #if os(iOS)
        #if targetEnvironment(simulator)
        return
        #else
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
        #endif
    }
}
