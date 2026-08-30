import SwiftUI

public struct UserChargingProfileCard: View {
    private let profile: UserChargingProfileReport?

    public init(profile: UserChargingProfileReport?) {
        self.profile = profile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kullanım Profilin")
                .font(.headline)

            if let profile {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: profile.type.iconName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(profile.type.accentMethod.uiColor)
                        .frame(width: 18, height: 18)
                        .padding(8)
                        .background(profile.type.accentMethod.uiColor.opacity(0.16))
                        .clipShape(Circle())

                    Text(profile.headline)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(profile.type.accentMethod.uiColor.opacity(0.14))
                        .foregroundStyle(profile.type.accentMethod.uiColor)
                        .clipShape(Capsule())
                }

                Text(profile.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(profile.ratioSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(profile.sessionCount) seans üzerinden güncellenir")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.9))
            } else {
                EmptyInfoCard(
                    title: "Profil için veri henüz yeterli değil",
                    subtitle: "Daha güvenilir profil için en az birkaç ek seans gerekli.",
                    iconName: "person.crop.circle.badge.questionmark"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#if DEBUG
struct UserChargingProfileCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            UserChargingProfileCard(
                profile: UserChargingProfileReport(
                    type: .speedFocused,
                    headline: "Hız odaklı",
                    description: "DC kullanımın yüksek, hız odaklı görünüyorsun. Hız kazanımı sağlarken maliyeti dengelemek için AC seanslarını artırabilirsin.",
                    ratioSummary: "Ev %8 • AC %18 • DC %74",
                    confidence: DataConfidenceScore(
                        score: 87,
                        source: .real,
                        sampleCount: 14,
                        exactSampleCount: 14,
                        estimatedSampleCount: 0,
                        missingSampleCount: 0
                    ),
                    sessionCount: 14,
                    generatedAt: .now
                )
            )
            UserChargingProfileCard(profile: nil)
        }
        .padding()
    }
}
#endif
