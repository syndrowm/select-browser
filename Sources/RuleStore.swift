import Foundation

/// A remembered browser/profile choice for a specific host.
struct DomainRule: Codable, Equatable {
    var bundleID: String
    var profileDirectory: String?
}

/// Persists per-host browser/profile rules in UserDefaults
/// (~/Library/Preferences/com.evan.select-browser.plist).
enum RuleStore {
    private static let key = "domainRules"
    private static let defaults = UserDefaults.standard

    /// Exact-host match (case-insensitive).
    static func rule(forHost host: String?) -> DomainRule? {
        guard let host = normalize(host) else { return nil }
        return load()[host]
    }

    static func save(_ rule: DomainRule, forHost host: String?) {
        guard let host = normalize(host) else { return }
        var rules = load()
        rules[host] = rule
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: key)
        }
    }

    static func load() -> [String: DomainRule] {
        guard let data = defaults.data(forKey: key),
              let rules = try? JSONDecoder().decode([String: DomainRule].self, from: data)
        else { return [:] }
        return rules
    }

    private static func normalize(_ host: String?) -> String? {
        guard let host, !host.isEmpty else { return nil }
        return host.lowercased()
    }
}
