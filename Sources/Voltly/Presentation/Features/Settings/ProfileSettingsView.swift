import SwiftUI

public struct ProfileSettingsView: View {
    private let badges: [ProfileAchievementBadge]

    public init(badges: [ProfileAchievementBadge]) {
        self.badges = badges
    }

    public var body: some View {
        Form {
            SettingsAchievementsSection(badges: badges)
        }
        .navigationTitle("Profil")
    }
}

#if DEBUG
struct ProfileSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileSettingsView(badges: [])
        }
    }
}
#endif
