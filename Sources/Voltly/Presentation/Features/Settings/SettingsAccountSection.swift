import SwiftUI

public struct SettingsAccountSection: View {
    private let sessionState: SessionState
    private let syncStatus: AccountSyncStatus
    private let lastSyncDate: Date?
    private let onSignIn: () -> Void
    private let onSync: () -> Void
    private let onSignOut: () -> Void
    private let onDeleteAccount: () -> Void

    public init(
        sessionState: SessionState,
        syncStatus: AccountSyncStatus,
        lastSyncDate: Date?,
        onSignIn: @escaping () -> Void,
        onSync: @escaping () -> Void,
        onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void
    ) {
        self.sessionState = sessionState
        self.syncStatus = syncStatus
        self.lastSyncDate = lastSyncDate
        self.onSignIn = onSignIn
        self.onSync = onSync
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
    }

    public var body: some View {
        Section("Hesap") {
            switch sessionState {
            case .guest:
                guestContent
            case .signedOut:
                signedOutContent
            case .authenticated(let user):
                authenticatedContent(user: user)
            }
        }
    }

    private var guestContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            GuestModeBadge(
                subtitle: "Veriler bu cihazda tutuluyor",
                style: .detailed
            )
            Text("İstersen daha sonra hesabını oluşturabilirsin.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Hesap olustur / giris yap") {
                onSignIn()
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Giris yapilmamis", systemImage: "person.crop.circle")
                .font(.subheadline.weight(.semibold))
            Text("Hesapla devam edersen kayıtların yedeklenir ve farklı cihazlarda aynı verilere ulaşırsın.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Hesap olustur / giris yap") {
                onSignIn()
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private func authenticatedContent(user: AuthUser) -> some View {
        let backupContent = AccountBackupCopy.content(for: syncStatus)

        return VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Kullanici", value: accountIdentity(for: user))
            LabeledContent("Saglayici", value: user.provider.titleTR)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(AccountBackupCopy.statusLabel)
                    Spacer()
                    Label(backupContent.title, systemImage: syncStatus.iconName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(syncStatus.tintColor)
                }
                Text(backupContent.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastSyncDate {
                LabeledContent(AccountBackupCopy.lastBackupLabel, value: NumberFormatting.dateTime(lastSyncDate))
            }

            Button(AccountBackupCopy.triggerBackupAction) {
                onSync()
            }
            .disabled(syncStatus == .syncing)
            .buttonStyle(.borderless)

            Button("Cikis yap") {
                onSignOut()
            }
            .buttonStyle(.borderless)

            Button("Hesabi sil") {
                onDeleteAccount()
            }
            .foregroundStyle(.red)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private func accountIdentity(for user: AuthUser) -> String {
        if let email = user.email, !email.isEmpty {
            return email
        }
        if let displayName = user.displayName, !displayName.isEmpty {
            return displayName
        }
        return "Kullanici \(user.id.prefix(8))"
    }
}

private extension AccountSyncStatus {
    var iconName: String {
        switch self {
        case .idle:
            return "exclamationmark.triangle.fill"
        case .syncing:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .idle:
            return .orange
        case .syncing:
            return AppTheme.publicACColor
        case .success:
            return .green
        case .failed:
            return .orange
        }
    }
}

#if DEBUG
struct SettingsAccountSection_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            SettingsAccountSection(
                sessionState: .guest,
                syncStatus: .idle,
                lastSyncDate: nil,
                onSignIn: {},
                onSync: {},
                onSignOut: {},
                onDeleteAccount: {}
            )
            SettingsAccountSection(
                sessionState: .authenticated(
                    AuthUser(
                        id: UUID().uuidString,
                        email: "canberk@voltly.app",
                        displayName: nil,
                        provider: .apple
                    )
                ),
                syncStatus: .success,
                lastSyncDate: Date(),
                onSignIn: {},
                onSync: {},
                onSignOut: {},
                onDeleteAccount: {}
            )
        }
    }
}
#endif
