import Foundation

public enum RetentionPromptType: String, Equatable, Sendable {
    case missingRecentEntry
    case monthlySummaryNeedsData
    case goalFollowUpNeeded
}

public struct RetentionNotificationPayload: Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let categoryIdentifier: String
    public let suggestedDelayHours: Int

    public init(
        id: String,
        title: String,
        body: String,
        categoryIdentifier: String,
        suggestedDelayHours: Int
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.categoryIdentifier = categoryIdentifier
        self.suggestedDelayHours = suggestedDelayHours
    }
}

public struct InAppReminderMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let type: RetentionPromptType
    public let title: String
    public let text: String
    public let priority: Int
    public let lastSessionDate: Date?
    public let daysSinceLastSession: Int?
    public let notificationPayload: RetentionNotificationPayload

    public init(
        id: String,
        type: RetentionPromptType,
        title: String,
        text: String,
        priority: Int,
        lastSessionDate: Date?,
        daysSinceLastSession: Int?,
        notificationPayload: RetentionNotificationPayload
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.text = text
        self.priority = priority
        self.lastSessionDate = lastSessionDate
        self.daysSinceLastSession = daysSinceLastSession
        self.notificationPayload = notificationPayload
    }
}

public struct RetentionPromptService {
    private enum Keys {
        static let lastKnownSessionDate = "retention.last_known_session_date"
        static let lastShownPromptID = "retention.prompt.last_shown.id"
        static let lastShownPromptAt = "retention.prompt.last_shown.at"
    }

    private enum Constants {
        static let suppressionInterval: TimeInterval = 24 * 60 * 60
        static let inactivityThresholdDays = 7
        static let monthlySummaryMinimumEntries = 3
        static let monthlySummaryPromptStartDay = 7
        static let goalFollowUpThresholdDays = 3
        static let missingRecentEntryPriority = 320
        static let goalFollowUpPriority = 260
        static let monthlySummaryPriority = 220
    }

    private let calendar: Calendar
    private let userDefaults: UserDefaults

    public init(
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.calendar = calendar
        self.userDefaults = userDefaults
    }

    public func trackedLastSessionDate() -> Date? {
        userDefaults.object(forKey: Keys.lastKnownSessionDate) as? Date
    }

    public func generatePrompt(
        sessions: [ChargingSession],
        goals: [UserGoal],
        referenceDate: Date = .now
    ) -> InAppReminderMessage? {
        let lastSessionDate = syncTrackedLastSessionDate(with: sessions)
        let daysSinceLastSession = daysBetween(lastSessionDate, and: referenceDate)
        let activeGoals = goals.filter(\.isActive)

        var candidates: [InAppReminderMessage] = []

        if let candidate = makeMissingRecentEntryPrompt(
            lastSessionDate: lastSessionDate,
            daysSinceLastSession: daysSinceLastSession
        ) {
            candidates.append(candidate)
        }

        if let candidate = makeGoalFollowUpPrompt(
            activeGoals: activeGoals,
            sessions: sessions,
            referenceDate: referenceDate,
            daysSinceLastSession: daysSinceLastSession
        ) {
            candidates.append(candidate)
        }

        if let candidate = makeMonthlySummaryPrompt(
            sessions: sessions,
            referenceDate: referenceDate
        ) {
            candidates.append(candidate)
        }

        guard let selected = candidates.max(by: { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.id > rhs.id
            }
            return lhs.priority < rhs.priority
        }) else {
            return nil
        }

        guard !isSuppressed(promptID: selected.id, referenceDate: referenceDate) else {
            return nil
        }

        markShown(promptID: selected.id, referenceDate: referenceDate)
        return selected
    }

    private func syncTrackedLastSessionDate(with sessions: [ChargingSession]) -> Date? {
        let latestSessionDate = sessions.map(\.sessionDate).max()
        let currentlyTracked = trackedLastSessionDate()

        if let latestSessionDate {
            if let currentlyTracked {
                if latestSessionDate > currentlyTracked {
                    userDefaults.set(latestSessionDate, forKey: Keys.lastKnownSessionDate)
                }
            } else {
                userDefaults.set(latestSessionDate, forKey: Keys.lastKnownSessionDate)
            }
            return max(currentlyTracked ?? latestSessionDate, latestSessionDate)
        }

        return currentlyTracked
    }

    private func makeMissingRecentEntryPrompt(
        lastSessionDate: Date?,
        daysSinceLastSession: Int?
    ) -> InAppReminderMessage? {
        guard let daysSinceLastSession,
              daysSinceLastSession >= Constants.inactivityThresholdDays else {
            return nil
        }

        let title = "Kayıt güncellemesi zamanı"
        let text = "Son şarj kaydının üzerinden \(daysSinceLastSession) gün geçti. Yeni bir kayıt ekleyip maliyet trendini güncel tut."
        let id = "retention.missing_recent_entry.\(daysSinceLastSession / Constants.inactivityThresholdDays)"

        return InAppReminderMessage(
            id: id,
            type: .missingRecentEntry,
            title: title,
            text: text,
            priority: Constants.missingRecentEntryPriority,
            lastSessionDate: lastSessionDate,
            daysSinceLastSession: daysSinceLastSession,
            notificationPayload: RetentionNotificationPayload(
                id: id,
                title: title,
                body: text,
                categoryIdentifier: "retention.missing_recent_entry",
                suggestedDelayHours: 24
            )
        )
    }

    private func makeMonthlySummaryPrompt(
        sessions: [ChargingSession],
        referenceDate: Date
    ) -> InAppReminderMessage? {
        let dayOfMonth = calendar.component(.day, from: referenceDate)
        guard dayOfMonth >= Constants.monthlySummaryPromptStartDay else {
            return nil
        }

        let monthSessions = sessions.filter {
            $0.sessionDate >= referenceDate.startOfMonth && $0.sessionDate <= referenceDate.endOfMonth
        }
        let missingCount = Constants.monthlySummaryMinimumEntries - monthSessions.count
        guard missingCount > 0 else { return nil }

        let year = calendar.component(.year, from: referenceDate)
        let month = calendar.component(.month, from: referenceDate)
        let title = "Aylık özetini güçlendir"
        let text = "Bu ay özetinin netleşmesi için en az \(missingCount) yeni şarj kaydı daha ekle."
        let id = "retention.monthly_summary.\(year)-\(month)"

        return InAppReminderMessage(
            id: id,
            type: .monthlySummaryNeedsData,
            title: title,
            text: text,
            priority: Constants.monthlySummaryPriority,
            lastSessionDate: monthSessions.map(\.sessionDate).max(),
            daysSinceLastSession: nil,
            notificationPayload: RetentionNotificationPayload(
                id: id,
                title: title,
                body: text,
                categoryIdentifier: "retention.monthly_summary",
                suggestedDelayHours: 48
            )
        )
    }

    private func makeGoalFollowUpPrompt(
        activeGoals: [UserGoal],
        sessions: [ChargingSession],
        referenceDate: Date,
        daysSinceLastSession: Int?
    ) -> InAppReminderMessage? {
        guard !activeGoals.isEmpty,
              let daysSinceLastSession,
              daysSinceLastSession >= Constants.goalFollowUpThresholdDays else {
            return nil
        }

        let dayOfMonth = calendar.component(.day, from: referenceDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: referenceDate)?.count ?? 30
        let monthlySessions = sessions.filter {
            $0.sessionDate >= referenceDate.startOfMonth && $0.sessionDate <= referenceDate.endOfMonth
        }

        if let entryGoal = activeGoals.first(where: { $0.type == .monthlyChargeEntries }) {
            let expectedCount = Int(ceil(entryGoal.targetValue * Double(dayOfMonth) / Double(daysInMonth)))
            if monthlySessions.count < max(1, expectedCount) {
                let missingCount = max(1, expectedCount - monthlySessions.count)
                let id = "retention.goal_follow_up.entry.\(calendar.component(.month, from: referenceDate))"
                let title = "Hedef takibini canlı tut"
                let text = "Kayıt düzeni hedefine yaklaşmak için bugün \(missingCount) yeni kayıt eklemek iyi olur."
                return InAppReminderMessage(
                    id: id,
                    type: .goalFollowUpNeeded,
                    title: title,
                    text: text,
                    priority: Constants.goalFollowUpPriority,
                    lastSessionDate: trackedLastSessionDate(),
                    daysSinceLastSession: daysSinceLastSession,
                    notificationPayload: RetentionNotificationPayload(
                        id: id,
                        title: title,
                        body: text,
                        categoryIdentifier: "retention.goal_follow_up.entry",
                        suggestedDelayHours: 24
                    )
                )
            }
        }

        let id = "retention.goal_follow_up.general.\(calendar.component(.month, from: referenceDate))"
        let title = "Hedeflerin için yeni veri ekle"
        let text = "Hedef takibinin güncel kalması için yeni bir şarj kaydı eklemen faydalı olur."
        return InAppReminderMessage(
            id: id,
            type: .goalFollowUpNeeded,
            title: title,
            text: text,
            priority: Constants.goalFollowUpPriority,
            lastSessionDate: trackedLastSessionDate(),
            daysSinceLastSession: daysSinceLastSession,
            notificationPayload: RetentionNotificationPayload(
                id: id,
                title: title,
                body: text,
                categoryIdentifier: "retention.goal_follow_up.general",
                suggestedDelayHours: 24
            )
        )
    }

    private func daysBetween(_ startDate: Date?, and endDate: Date) -> Int? {
        guard let startDate else { return nil }
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day
    }

    private func isSuppressed(promptID: String, referenceDate: Date) -> Bool {
        guard let shownID = userDefaults.string(forKey: Keys.lastShownPromptID),
              let shownAt = userDefaults.object(forKey: Keys.lastShownPromptAt) as? Date else {
            return false
        }

        guard shownID == promptID else { return false }
        return referenceDate.timeIntervalSince(shownAt) < Constants.suppressionInterval
    }

    private func markShown(promptID: String, referenceDate: Date) {
        userDefaults.set(promptID, forKey: Keys.lastShownPromptID)
        userDefaults.set(referenceDate, forKey: Keys.lastShownPromptAt)
    }
}
