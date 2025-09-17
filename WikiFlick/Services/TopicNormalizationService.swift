import Foundation

/// Service responsible for normalizing topic selections from different sources (onboarding vs settings)
/// to ensure consistent behavior across the app
class TopicNormalizationService {
    static let shared = TopicNormalizationService()

    private init() {}

    /// Mapping from localization keys (used in settings) to canonical English labels (used by ArticleRepository)
    private let canonicalMap: [String: String] = [
        "all_topics": "All Topics",
        "general_reference": "General Reference",
        "culture_and_arts": "Culture and the Arts",
        "geography_and_places": "Geography and Places",
        "health_and_fitness": "Health and Fitness",
        "history_and_events": "History and Events",
        "human_activities": "Human Activities",
        "mathematics_and_logic": "Mathematics and Logic",
        "natural_and_physical_sciences": "Natural and Physical Sciences",
        "people_and_self": "People and Self",
        "philosophy_and_thinking": "Philosophy and Thinking",
        "religion_and_belief_systems": "Religion and Belief Systems",
        "society_and_social_sciences": "Society and Social Sciences",
        "technology_and_applied_sciences": "Technology and Applied Sciences"
    ]

    /// Normalizes topic selections to canonical English labels that ArticleRepository understands
    /// - Parameter rawTopics: Array of topics from UserDefaults (may contain mix of English labels and localization keys)
    /// - Returns: Array of canonical English topic labels
    func normalizeTopics(_ rawTopics: [String]) -> [String] {
        guard !rawTopics.isEmpty else {
            return ["All Topics"]
        }

        // Step 1: Convert each topic to its canonical English label
        let canonicalTopics = rawTopics.compactMap { topic -> String? in
            // If it's a localization key, convert it
            if let canonical = canonicalMap[topic] {
                return canonical
            }
            // If it's already a canonical English label, keep it
            if canonicalMap.values.contains(topic) {
                return topic
            }
            // Unknown topic, log and skip
            print("⚠️ Unknown topic encountered during normalization: \(topic)")
            return nil
        }

        // Step 2: Handle "All Topics" special case
        if canonicalTopics.contains("All Topics") {
            return ["All Topics"]
        }

        // Step 3: Remove duplicates while preserving order
        let uniqueTopics = canonicalTopics.reduce(into: [String]()) { result, topic in
            if !result.contains(topic) {
                result.append(topic)
            }
        }

        // Step 4: Return default if empty
        return uniqueTopics.isEmpty ? ["All Topics"] : uniqueTopics
    }

    /// Gets normalized topics from UserDefaults
    /// - Returns: Array of canonical English topic labels
    func getNormalizedTopicsFromUserDefaults() -> [String] {
        let rawTopics = UserDefaults.standard.array(forKey: "selectedTopics") as? [String] ?? []
        return normalizeTopics(rawTopics)
    }

    /// Validates if a topic is supported by the ArticleRepository
    /// - Parameter topic: The topic to validate
    /// - Returns: True if the topic is supported
    func isTopicSupported(_ topic: String) -> Bool {
        return canonicalMap.values.contains(topic)
    }

    /// Gets all supported canonical topic labels
    /// - Returns: Array of all canonical English topic labels
    func getAllSupportedTopics() -> [String] {
        return Array(canonicalMap.values).sorted()
    }

    /// Converts a canonical English label back to its localization key
    /// - Parameter canonicalTopic: The canonical English topic label
    /// - Returns: The localization key if found, otherwise the input topic
    func getLocalizationKey(for canonicalTopic: String) -> String {
        for (key, value) in canonicalMap {
            if value == canonicalTopic {
                return key
            }
        }
        return canonicalTopic
    }
}