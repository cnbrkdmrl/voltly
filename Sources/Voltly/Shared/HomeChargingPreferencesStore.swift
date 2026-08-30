import Foundation

public struct HomeChargingProfile: Codable, Equatable, Identifiable {
    public let id: Int
    public var isEnabled: Bool
    public var name: String
    public var location: String
    public var tariffPricePerKWh: Double?

    public init(
        id: Int,
        isEnabled: Bool,
        name: String,
        location: String,
        tariffPricePerKWh: Double? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.name = name
        self.location = location
        self.tariffPricePerKWh = tariffPricePerKWh
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var displayName: String {
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return "Ev \(id)"
    }

    public var hasUsableInfo: Bool {
        !trimmedName.isEmpty || !trimmedLocation.isEmpty
    }
}

public struct HomeChargingPreferences: Codable, Equatable {
    public var profiles: [HomeChargingProfile]
    public var defaultProfileID: Int

    public init(
        profiles: [HomeChargingProfile],
        defaultProfileID: Int
    ) {
        self.profiles = profiles
        self.defaultProfileID = defaultProfileID
    }

    public var enabledProfiles: [HomeChargingProfile] {
        profiles.filter(\.isEnabled).sorted { $0.id < $1.id }
    }

    public var defaultProfile: HomeChargingProfile? {
        enabledProfiles.first(where: { $0.id == defaultProfileID }) ?? enabledProfiles.first
    }

    public static var `default`: HomeChargingPreferences {
        HomeChargingPreferences(
            profiles: [
                HomeChargingProfile(id: 1, isEnabled: true, name: "Ev", location: ""),
                HomeChargingProfile(id: 2, isEnabled: false, name: "", location: ""),
                HomeChargingProfile(id: 3, isEnabled: false, name: "", location: "")
            ],
            defaultProfileID: 1
        )
    }
}

public enum HomeChargingPreferencesStore {
    private static let storageKey = "settings.charging.home.preferences.v1"

    public static func load(defaults: UserDefaults = .standard) -> HomeChargingPreferences {
        guard let data = defaults.data(forKey: storageKey) else {
            return .default
        }

        do {
            let decoded = try JSONDecoder().decode(HomeChargingPreferences.self, from: data)
            return normalized(decoded)
        } catch {
            return .default
        }
    }

    public static func save(_ preferences: HomeChargingPreferences, defaults: UserDefaults = .standard) {
        let normalizedPreferences = normalized(preferences)
        guard let data = try? JSONEncoder().encode(normalizedPreferences) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func normalized(_ preferences: HomeChargingPreferences) -> HomeChargingPreferences {
        let byID = Dictionary(uniqueKeysWithValues: preferences.profiles.map { ($0.id, $0) })
        var profiles: [HomeChargingProfile] = []

        for id in 1...3 {
            if let existing = byID[id] {
                profiles.append(existing)
            } else {
                profiles.append(
                    HomeChargingProfile(
                        id: id,
                        isEnabled: id == 1,
                        name: id == 1 ? "Ev" : "",
                        location: "",
                        tariffPricePerKWh: nil
                    )
                )
            }
        }

        if let secondIndex = profiles.firstIndex(where: { $0.id == 2 }),
           profiles[secondIndex].isEnabled == false,
           let thirdIndex = profiles.firstIndex(where: { $0.id == 3 }) {
            profiles[thirdIndex].isEnabled = false
        }

        if !profiles.contains(where: { $0.id == 1 && $0.isEnabled }) {
            if let index = profiles.firstIndex(where: { $0.id == 1 }) {
                profiles[index].isEnabled = true
            }
        }

        let enabledIDs = Set(profiles.filter(\.isEnabled).map(\.id))
        let defaultProfileID: Int
        if enabledIDs.contains(preferences.defaultProfileID) {
            defaultProfileID = preferences.defaultProfileID
        } else {
            defaultProfileID = profiles.first(where: \.isEnabled)?.id ?? 1
        }

        return HomeChargingPreferences(
            profiles: profiles.sorted { $0.id < $1.id },
            defaultProfileID: defaultProfileID
        )
    }
}
