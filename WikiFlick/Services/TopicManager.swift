import Foundation

class TopicManager {
    static let shared = TopicManager()

    private init() {}

    // Topic display names (used in UI)
    static let topicDisplayNames = [
        "General Reference",
        "Culture and the Arts",
        "Geography and Places",
        "Health and Fitness",
        "History and Events",
        "Human Activities",
        "Mathematics and Logic",
        "Natural and Physical Sciences",
        "People and Self",
        "Philosophy and Thinking",
        "Religion and Belief Systems",
        "Society and Social Sciences",
        "Technology and Applied Sciences"
    ]

    // Topic keys (used for storage and localization)
    static let topicKeys = [
        "general_reference",
        "culture_and_arts",
        "geography_and_places",
        "health_and_fitness",
        "history_and_events",
        "human_activities",
        "mathematics_and_logic",
        "natural_and_physical_sciences",
        "people_and_self",
        "philosophy_and_thinking",
        "religion_and_belief_systems",
        "society_and_social_sciences",
        "technology_and_applied_sciences"
    ]

    // Mapping between display names and keys
    static let displayToKeyMap: [String: String] = Dictionary(
        uniqueKeysWithValues: zip(topicDisplayNames, topicKeys)
    )

    static let keyToDisplayMap: [String: String] = Dictionary(
        uniqueKeysWithValues: zip(topicKeys, topicDisplayNames)
    )

    // Maximum number of topics that can be selected
    static let maxTopicSelection = 5

    // Convert display names to keys
    static func convertDisplayNamesToKeys(_ displayNames: Set<String>) -> Set<String> {
        return Set(displayNames.compactMap { displayToKeyMap[$0] })
    }

    // Convert keys to display names
    static func convertKeysToDisplayNames(_ keys: Set<String>) -> Set<String> {
        return Set(keys.compactMap { keyToDisplayMap[$0] })
    }

    // Get saved topics from UserDefaults as display names
    static func getSavedTopicsAsDisplayNames() -> Set<String> {
        if let savedKeys = UserDefaults.standard.array(forKey: "selectedTopics") as? [String] {
            // Convert keys to display names
            let displayNames = convertKeysToDisplayNames(Set(savedKeys))
            return displayNames
        }
        return ["General Reference", "Culture and the Arts", "History and Events"]
    }

    // Get saved topics from UserDefaults as keys
    static func getSavedTopicsAsKeys() -> Set<String> {
        if let savedKeys = UserDefaults.standard.array(forKey: "selectedTopics") as? [String] {
            return Set(savedKeys)
        }
        return ["general_reference", "culture_and_arts", "history_and_events"]
    }

    // Save topics to UserDefaults (always saves as keys)
    static func saveTopics(displayNames: Set<String>) {
        let keys = convertDisplayNamesToKeys(displayNames)
        UserDefaults.standard.set(Array(keys), forKey: "selectedTopics")
        NotificationCenter.default.post(name: .topicsChanged, object: nil)
    }

    // Save topics to UserDefaults (when we already have keys)
    static func saveTopicsFromKeys(_ keys: Set<String>) {
        UserDefaults.standard.set(Array(keys), forKey: "selectedTopics")
        NotificationCenter.default.post(name: .topicsChanged, object: nil)
    }
}

extension Notification.Name {
    static let topicsChanged = Notification.Name("topicsChanged")
}