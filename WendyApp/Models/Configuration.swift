import Foundation

enum AgentProfile: String, CaseIterable, Codable {
    case personal, business

    var displayName: String {
        switch self {
        case .personal: "BBUM"
        case .business: "Business"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .personal: "https://prod.wendy-gets-shit-done.today"
        case .business: "https://business.wendy-gets-shit-done.today"
        }
    }

    var bundleAPIKeyKey: String {
        switch self {
        case .personal: "WendyAPIKey"
        case .business: "BusinessAPIKey"
        }
    }

    var bundleAPIKey: String {
        Bundle.main.infoDictionary?[bundleAPIKeyKey] as? String ?? ""
    }
}

struct Configuration {
    private static let defaults = UserDefaults.standard

    // MARK: - Current agent

    static var currentAgent: AgentProfile {
        get {
            defaults.string(forKey: "current_agent")
                .flatMap(AgentProfile.init(rawValue:)) ?? .personal
        }
        set { defaults.set(newValue.rawValue, forKey: "current_agent") }
    }

    // MARK: - Per-agent base URL

    static func apiBaseURL(for agent: AgentProfile) -> String {
        defaults.string(forKey: "base_url_\(agent.rawValue)")
            ?? agent.defaultBaseURL
    }

    static func save(baseURL: String, for agent: AgentProfile) {
        defaults.set(baseURL, forKey: "base_url_\(agent.rawValue)")
    }

    // MARK: - Per-agent API key

    static func apiKey(for agent: AgentProfile) -> String {
        defaults.string(forKey: "api_key_\(agent.rawValue)")
            ?? agent.bundleAPIKey
    }

    static func save(apiKey: String, for agent: AgentProfile) {
        defaults.set(apiKey, forKey: "api_key_\(agent.rawValue)")
    }

    // MARK: - Convenience for current agent

    static var apiBaseURL: String { apiBaseURL(for: currentAgent) }
    static var apiKey: String { apiKey(for: currentAgent) }

    static var isConfigured: Bool {
        let key = apiKey(for: currentAgent)
        let url = apiBaseURL(for: currentAgent)
        return !key.isEmpty && !url.isEmpty
    }

    static func isConfigured(for agent: AgentProfile) -> Bool {
        !apiKey(for: agent).isEmpty && !apiBaseURL(for: agent).isEmpty
    }

    @available(*, deprecated, message: "Use save(apiKey:for:) instead")
    static func save(apiKey: String) {
        save(apiKey: apiKey, for: currentAgent)
    }
}
