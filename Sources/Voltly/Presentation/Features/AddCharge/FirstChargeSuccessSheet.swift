import SwiftUI

public struct FirstChargeSuccessSheet: View {
    private let onContinue: () -> Void
    private let onShowAnalysis: (() -> Void)?

    public init(
        onContinue: @escaping () -> Void,
        onShowAnalysis: (() -> Void)? = nil
    ) {
        self.onContinue = onContinue
        self.onShowAnalysis = onShowAnalysis
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.publicACColor)
                Text("İlk şarjın kaydedildi")
                    .font(.title3.weight(.bold))
            }

            Text("Artık EV maliyetini ve tasarrufunu takip edebilirsin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                if let onShowAnalysis {
                    Button("Analizi gör") {
                        onShowAnalysis()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.publicACColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Devam et") {
                    onContinue()
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.publicACColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDragIndicator(.visible)
    }
}

#if DEBUG
struct FirstChargeSuccessSheet_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FirstChargeSuccessSheet(onContinue: {})
                .previewDisplayName("Sadece Devam")
            FirstChargeSuccessSheet(onContinue: {}, onShowAnalysis: {})
                .previewDisplayName("Analiz Aksiyonu")
        }
    }
}
#endif
