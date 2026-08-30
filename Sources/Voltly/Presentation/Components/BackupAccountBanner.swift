import SwiftUI

public struct BackupAccountBanner: View {
    private let onCreateAccount: () -> Void
    private let onLater: () -> Void
    private let onClose: () -> Void

    public init(
        onCreateAccount: @escaping () -> Void,
        onLater: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onCreateAccount = onCreateAccount
        self.onLater = onLater
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Label("Verilerini güvene al", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bannerı kapat")
            }

            Text("Şarj kayıtlarını kaybetmemek ve farklı cihazlarda aynı verilere ulaşmak için hesap oluşturabilirsin.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Hesap oluştur") {
                    onCreateAccount()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.publicACColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Daha sonra") {
                    onLater()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.publicACColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.publicACColor.opacity(0.22), lineWidth: 1)
        )
    }
}

#if DEBUG
struct BackupAccountBanner_Previews: PreviewProvider {
    static var previews: some View {
        BackupAccountBanner(
            onCreateAccount: {},
            onLater: {},
            onClose: {}
        )
        .padding()
        .background(AppTheme.surface)
    }
}
#endif
