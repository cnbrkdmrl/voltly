import Foundation

public protocol GoalRepository {
    func fetchGoals() throws -> [UserGoal]
    func saveGoals(_ goals: [UserGoal]) throws
}
