import Foundation

public enum PolicyTrigger: String, Codable, CaseIterable {
    case absence
    case additionalViewer
}

public enum PolicyAction: String, Codable, CaseIterable {
    case curtain
    case hideApps
    case displaysOff
}

public struct PolicyRule: Codable, Equatable {
    public let trigger: PolicyTrigger
    public let graceSeconds: Double
    public let minPersons: Int?
    public let minConfidence: Double
    public let actions: [PolicyAction]
    public let hideAppBundleIds: [String]?

    public init(
        trigger: PolicyTrigger,
        graceSeconds: Double,
        minPersons: Int? = nil,
        minConfidence: Double = 0.6,
        actions: [PolicyAction],
        hideAppBundleIds: [String]? = nil
    ) {
        self.trigger = trigger
        self.graceSeconds = graceSeconds
        self.minPersons = minPersons
        self.minConfidence = minConfidence
        self.actions = actions
        self.hideAppBundleIds = hideAppBundleIds
    }

    private enum CodingKeys: String, CodingKey {
        case trigger
        case graceSeconds
        case minPersons
        case minConfidence
        case actions
        case hideAppBundleIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trigger = try container.decode(PolicyTrigger.self, forKey: .trigger)
        graceSeconds = try container.decode(Double.self, forKey: .graceSeconds)
        minPersons = try container.decodeIfPresent(Int.self, forKey: .minPersons)
        minConfidence = try container.decodeIfPresent(Double.self, forKey: .minConfidence) ?? 0.6
        actions = try container.decode([PolicyAction].self, forKey: .actions)
        hideAppBundleIds = try container.decodeIfPresent([String].self, forKey: .hideAppBundleIds)
    }
}

public struct PolicyRestoration: Codable, Equatable {
    public let requireAuth: Bool

    public init(requireAuth: Bool) {
        self.requireAuth = requireAuth
    }
}

public struct Policy: Codable, Equatable {
    public let schemaVersion: Int
    public let name: String
    public let rules: [PolicyRule]
    public let restoration: PolicyRestoration

    public init(
        schemaVersion: Int,
        name: String,
        rules: [PolicyRule],
        restoration: PolicyRestoration
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.rules = rules
        self.restoration = restoration
    }
}
