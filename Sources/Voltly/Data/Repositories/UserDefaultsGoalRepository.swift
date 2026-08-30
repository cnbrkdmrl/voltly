import Foundation

public final class UserDefaultsGoalRepository: GoalRepository {
    private enum Keys {
        static let goals = "voltly.userGoals"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func fetchGoals() throws -> [UserGoal] {
        guard let data = defaults.data(forKey: Keys.goals) else {
            return []
        }

        return try decoder.decode([UserGoal].self, from: data)
    }

    public func saveGoals(_ goals: [UserGoal]) throws {
        let sortedGoals = goals.sorted { $0.type.rawValue < $1.type.rawValue }
        let data = try encoder.encode(sortedGoals)
        defaults.set(data, forKey: Keys.goals)
    }
}
