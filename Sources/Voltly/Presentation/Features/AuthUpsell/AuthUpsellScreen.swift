import SwiftUI

public struct AuthUpsellScreen: View {
    private let sessionState: SessionState
    private let onAction: (AuthUpsellAction) -> Void

    public init(
        sessionState: SessionState = .signedOut,
        onAction: @escaping (AuthUpsellAction) -> Void
    ) {
        self.sessionState = sessionState
        self.onAction = onAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.defaultSectionSpacing) {
            Spacer(minLength: 6)

            if sessionState.isGuest {
                GuestModeBadge(
                    subtitle: "İstersen daha sonra hesabını oluşturabilirsin",
                    style: .detailed
                )
            }
            heroCard
            benefitsCard
            actionButtons

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppTheme.surface, AppTheme.publicACColor.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.publicACColor)
                Text("Verilerini güvene al")
                    .font(.title3.weight(.bold))
            }

            Text("Şarj kayıtlarını yedeklemek ve farklı cihazlarda aynı verilere ulaşmak için hesap oluşturabilirsin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
        .shadow(radius: UIConstants.cardShadowRadius)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(icon: "icloud.fill", text: "Kayıtların güvenli şekilde yedeklenir")
            benefitRow(icon: "iphone.badge.checkmark", text: "Farklı cihazlarda aynı veriye erişirsin")
            benefitRow(icon: "chart.bar.fill", text: "Analiz geçmişin kaybolmadan devam eder")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            actionButton(
                title: "Email ile kayıt",
                background: AppTheme.publicACColor,
                foreground: .white
            ) {
                onAction(.email)
            }

            Button("Daha sonra") {
                onAction(.later)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.publicACColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }

    private func actionButton(
        title: String,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#if DEBUG
struct AuthUpsellScreen_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthUpsellScreen(sessionState: .signedOut) { _ in }
            AuthUpsellScreen(sessionState: .guest) { _ in }
        }
    }
}
#endif
