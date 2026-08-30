import SwiftUI

public struct SettingsAchievementsSection: View {
    private let badges: [ProfileAchievementBadge]
    @State private var selectedBadge: ProfileAchievementBadge?
    @State private var showingUnlockedBadges = false

    public init(badges: [ProfileAchievementBadge]) {
        self.badges = badges
    }

    public var body: some View {
        Section("Başarı Rozetleri") {
            if badges.isEmpty {
                Text("Rozetler için henüz yeterli veri yok.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if let nextBadge {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sıradaki rozet")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Button {
                            selectedBadge = nextBadge
                        } label: {
                            badgeRow(nextBadge)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !inProgressBadges.isEmpty {
                    achievementGroup(title: "Tamamlanmayanlar", badges: inProgressBadges)
                }

                if !unlockedBadges.isEmpty {
                    Button {
                        showingUnlockedBadges = true
                    } label: {
                        HStack {
                            Label("Tamamlananları gör", systemImage: "checkmark.seal")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(unlockedBadges.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedBadge) { badge in
            AchievementBadgeDetailSheet(badge: badge)
        }
        .sheet(isPresented: $showingUnlockedBadges) {
            UnlockedAchievementsSheet(badges: unlockedBadges) { badge in
                selectedBadge = badge
            }
        }
    }

    private var unlockedBadges: [ProfileAchievementBadge] {
        badges
            .filter(\.isUnlocked)
            .sorted { $0.title < $1.title }
    }

    private var inProgressBadges: [ProfileAchievementBadge] {
        badges
            .filter { !$0.isUnlocked && $0.id != nextBadge?.id }
            .sorted { lhs, rhs in
                if lhs.progress == rhs.progress {
                    return lhs.title < rhs.title
                }
                return lhs.progress > rhs.progress
            }
    }

    private var nextBadge: ProfileAchievementBadge? {
        badges
            .filter { !$0.isUnlocked }
            .max(by: { $0.progress < $1.progress })
    }

    private func achievementGroup(title: String, badges: [ProfileAchievementBadge]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(badges) { badge in
                Button {
                    selectedBadge = badge
                } label: {
                    badgeRow(badge)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func badgeRow(_ badge: ProfileAchievementBadge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: badge.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(badge.isUnlocked ? AppTheme.homeColor : .secondary)
                    .frame(width: 30, height: 30)
                    .background((badge.isUnlocked ? AppTheme.homeColor : Color.secondary).opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(badge.title)
                        .font(.subheadline.weight(.semibold))
                    Text(badge.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badge.isUnlocked ? "Tamamlandı" : "Devam")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((badge.isUnlocked ? AppTheme.homeColor : Color.secondary).opacity(0.15))
                    .foregroundStyle(badge.isUnlocked ? AppTheme.homeColor : .secondary)
                    .clipShape(Capsule())
            }

            ProgressView(value: badge.progress, total: 1)
                .tint(badge.isUnlocked ? AppTheme.homeColor : AppTheme.publicACColor)

            Text(badge.progressLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct UnlockedAchievementsSheet: View {
    let badges: [ProfileAchievementBadge]
    let onSelect: (ProfileAchievementBadge) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(badges) { badge in
                    Button {
                        dismiss()
                        onSelect(badge)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: badge.iconName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.homeColor)
                                    .frame(width: 30, height: 30)
                                    .background(AppTheme.homeColor.opacity(0.14))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(badge.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(badge.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("Tamamlandı")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.homeColor.opacity(0.15))
                                    .foregroundStyle(AppTheme.homeColor)
                                    .clipShape(Capsule())
                            }

                            Text(badge.progressLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Tamamlanan Rozetler")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }
}

private struct AchievementBadgeDetailSheet: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case overview = "Genel"
        case detail = "Detay"

        var id: String { rawValue }
    }

    let badge: ProfileAchievementBadge
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .overview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Sekme", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: badge.iconName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(badge.isUnlocked ? AppTheme.homeColor : .secondary)
                            .frame(width: 46, height: 46)
                            .background((badge.isUnlocked ? AppTheme.homeColor : Color.secondary).opacity(0.14))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(badge.title)
                                .font(.headline.weight(.semibold))
                            Text(badge.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    if selectedTab == .overview {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(badge.isUnlocked ? "Rozet kazanıldı" : "İlerleme sürüyor")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(badge.isUnlocked ? AppTheme.homeColor : .primary)

                            ProgressView(value: badge.progress, total: 1)
                                .tint(badge.isUnlocked ? AppTheme.homeColor : AppTheme.publicACColor)

                            Text(badge.progressLabel)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("Kategori", value: badge.category.titleTR)
                                .font(.subheadline)
                            Text(badge.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Başarı Rozeti")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }
}

#if DEBUG
struct SettingsAchievementsSection_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            SettingsAchievementsSection(
                badges: [
                    ProfileAchievementBadge(
                        id: "first_charge",
                        title: "İlk şarj",
                        subtitle: "İlk şarj kaydını tamamla",
                        detail: "İlk kayıt davranış analizlerini başlatır.",
                        iconName: "sparkles",
                        isUnlocked: true,
                        progress: 1,
                        progressLabel: "Kazanıldı",
                        category: .milestone
                    ),
                    ProfileAchievementBadge(
                        id: "ten_charges",
                        title: "10 şarj",
                        subtitle: "Toplam 10 şarj kaydı oluştur",
                        detail: "Daha güçlü trend ve maliyet analizi için temel eşik.",
                        iconName: "bolt.circle",
                        isUnlocked: false,
                        progress: 0.4,
                        progressLabel: "4/10",
                        category: .milestone
                    )
                ]
            )
        }
    }
}
#endif
