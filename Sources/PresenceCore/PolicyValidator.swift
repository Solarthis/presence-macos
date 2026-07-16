import Foundation

public enum PolicyValidationError: Error, Equatable {
    case notSingleJSONObject
    case invalidJSON(String)
    case unknownKey(path: String, key: String)
    case schemaMismatch(String)
    case unsupportedSchemaVersion(Int)
    case unsupportedAction(String)
    case graceSecondsOutOfBounds(rule: Int)
    case minConfidenceOutOfBounds(rule: Int)
    case minPersonsRequired(rule: Int)
    case minPersonsNotAllowed(rule: Int)
    case minPersonsOutOfBounds(rule: Int)
    case emptyActions(rule: Int)
    case hideAppBundleIdsRequired(rule: Int)
    case hideAppBundleIdsNotAllowed(rule: Int)
    case protectedAppBundleId(String)
    case duplicateTrigger(PolicyTrigger)
    case restorationAuthenticationRequired

    public var reason: String {
        switch self {
        case .notSingleJSONObject:
            return "Input must be exactly one JSON object with no surrounding prose."
        case let .invalidJSON(message):
            return "Input is not valid JSON: \(message)"
        case let .unknownKey(path, key):
            return "Unknown key '\(key)' at \(path)."
        case let .schemaMismatch(message):
            return "Policy does not match schema v1: \(message)"
        case let .unsupportedSchemaVersion(version):
            return "schemaVersion must be exactly 1; received \(version)."
        case let .unsupportedAction(action):
            return "Action '\(action)' is not in the v1 capability allow-list."
        case let .graceSecondsOutOfBounds(rule):
            return "rules[\(rule)].graceSeconds must be between 2 and 600 seconds."
        case let .minConfidenceOutOfBounds(rule):
            return "rules[\(rule)].minConfidence must be between 0.3 and 1.0."
        case let .minPersonsRequired(rule):
            return "rules[\(rule)].minPersons is required for additionalViewer."
        case let .minPersonsNotAllowed(rule):
            return "rules[\(rule)].minPersons is allowed only for additionalViewer."
        case let .minPersonsOutOfBounds(rule):
            return "rules[\(rule)].minPersons must be at least 2."
        case let .emptyActions(rule):
            return "rules[\(rule)].actions must not be empty."
        case let .hideAppBundleIdsRequired(rule):
            return "rules[\(rule)].hideAppBundleIds is required when hideApps is requested."
        case let .hideAppBundleIdsNotAllowed(rule):
            return "rules[\(rule)].hideAppBundleIds is allowed only when hideApps is requested."
        case let .protectedAppBundleId(bundleID):
            return "The protected app '\(bundleID)' can never be hidden by a policy."
        case let .duplicateTrigger(trigger):
            return "Only one '\(trigger.rawValue)' rule is allowed."
        case .restorationAuthenticationRequired:
            return "restoration.requireAuth must be present and literally true."
        }
    }
}

public enum PolicyValidator {
    private static let rootKeys: Set<String> = ["schemaVersion", "name", "rules", "restoration"]
    private static let ruleKeys: Set<String> = [
        "trigger",
        "graceSeconds",
        "minPersons",
        "minConfidence",
        "actions",
        "hideAppBundleIds",
    ]
    private static let restorationKeys: Set<String> = ["requireAuth"]
    private static let allowedActions: Set<String> = ["curtain", "hideApps", "displaysOff"]
    private static let neverHideBundleIDs: Set<String> = [
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "com.microsoft.vscode",
    ]

    public static func validate(_ input: String) -> Result<Policy, PolicyValidationError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{", trimmed.last == "}" else {
            return .failure(.notSingleJSONObject)
        }

        let data = Data(trimmed.utf8)
        let rawObject: Any
        do {
            rawObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
        guard let root = rawObject as? [String: Any] else {
            return .failure(.notSingleJSONObject)
        }

        if let error = unknownKey(in: root, allowed: rootKeys, path: "root") {
            return .failure(error)
        }
        if let rules = root["rules"] as? [Any] {
            for (index, value) in rules.enumerated() {
                guard let rule = value as? [String: Any] else { continue }
                if let error = unknownKey(in: rule, allowed: ruleKeys, path: "rules[\(index)]") {
                    return .failure(error)
                }
            }
        }
        if let restoration = root["restoration"] as? [String: Any],
           let error = unknownKey(in: restoration, allowed: restorationKeys, path: "restoration") {
            return .failure(error)
        }
        for key in ["schemaVersion", "name"] {
            if let error = unknownNestedObjectKey(in: root[key], path: key) {
                return .failure(error)
            }
        }
        if let rules = root["rules"] as? [[String: Any]] {
            for (index, rule) in rules.enumerated() {
                for key in ruleKeys {
                    if let error = unknownNestedObjectKey(
                        in: rule[key],
                        path: "rules[\(index)].\(key)"
                    ) {
                        return .failure(error)
                    }
                }
            }
        }
        if let restoration = root["restoration"] as? [String: Any],
           let error = unknownNestedObjectKey(
               in: restoration["requireAuth"],
               path: "restoration.requireAuth"
           ) {
            return .failure(error)
        }

        if let rules = root["rules"] as? [[String: Any]] {
            for rule in rules {
                guard let actions = rule["actions"] as? [Any] else { continue }
                for action in actions {
                    if let actionName = action as? String, !allowedActions.contains(actionName) {
                        return .failure(.unsupportedAction(actionName))
                    }
                }
            }
        }

        let policy: Policy
        do {
            policy = try JSONDecoder().decode(Policy.self, from: data)
        } catch let DecodingError.keyNotFound(key, context)
            where key.stringValue == "requireAuth" && context.codingPath.last?.stringValue == "restoration" {
            return .failure(.restorationAuthenticationRequired)
        } catch {
            return .failure(.schemaMismatch(decodingReason(error)))
        }

        guard policy.schemaVersion == 1 else {
            return .failure(.unsupportedSchemaVersion(policy.schemaVersion))
        }

        for rule in policy.rules {
            for action in rule.actions where !allowedActions.contains(action.rawValue) {
                return .failure(.unsupportedAction(action.rawValue))
            }
        }

        var seenTriggers: Set<PolicyTrigger> = []
        for (index, rule) in policy.rules.enumerated() {
            guard (2...600).contains(rule.graceSeconds) else {
                return .failure(.graceSecondsOutOfBounds(rule: index))
            }
            guard (0.3...1.0).contains(rule.minConfidence) else {
                return .failure(.minConfidenceOutOfBounds(rule: index))
            }
            guard !rule.actions.isEmpty else {
                return .failure(.emptyActions(rule: index))
            }

            switch rule.trigger {
            case .absence:
                if rule.minPersons != nil {
                    return .failure(.minPersonsNotAllowed(rule: index))
                }
            case .additionalViewer:
                guard let minPersons = rule.minPersons else {
                    return .failure(.minPersonsRequired(rule: index))
                }
                guard minPersons >= 2 else {
                    return .failure(.minPersonsOutOfBounds(rule: index))
                }
            }

            let hidesApps = rule.actions.contains(.hideApps)
            if hidesApps && rule.hideAppBundleIds == nil {
                return .failure(.hideAppBundleIdsRequired(rule: index))
            }
            if !hidesApps && rule.hideAppBundleIds != nil {
                return .failure(.hideAppBundleIdsNotAllowed(rule: index))
            }
            for bundleID in rule.hideAppBundleIds ?? [] {
                if neverHideBundleIDs.contains(bundleID.lowercased()) {
                    return .failure(.protectedAppBundleId(bundleID))
                }
            }

            guard seenTriggers.insert(rule.trigger).inserted else {
                return .failure(.duplicateTrigger(rule.trigger))
            }
        }

        guard policy.restoration.requireAuth == true else {
            return .failure(.restorationAuthenticationRequired)
        }
        return .success(policy)
    }

    private static func unknownKey(
        in object: [String: Any],
        allowed: Set<String>,
        path: String
    ) -> PolicyValidationError? {
        guard let key = object.keys.sorted().first(where: { !allowed.contains($0) }) else {
            return nil
        }
        return .unknownKey(path: path, key: key)
    }

    private static func unknownNestedObjectKey(
        in value: Any?,
        path: String
    ) -> PolicyValidationError? {
        if let object = value as? [String: Any], let key = object.keys.sorted().first {
            return .unknownKey(path: path, key: key)
        }
        if let values = value as? [Any] {
            for (index, nested) in values.enumerated() {
                if let error = unknownNestedObjectKey(in: nested, path: "\(path)[\(index)]") {
                    return error
                }
            }
        }
        return nil
    }

    private static func decodingReason(_ error: Error) -> String {
        switch error {
        case let DecodingError.typeMismatch(_, context),
             let DecodingError.valueNotFound(_, context),
             let DecodingError.dataCorrupted(context):
            return context.debugDescription
        case let DecodingError.keyNotFound(key, _):
            return "Missing required key '\(key.stringValue)'."
        default:
            return error.localizedDescription
        }
    }
}
