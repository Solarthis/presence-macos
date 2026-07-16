import Foundation

public enum PolicyPreview {
    public static func lines(for policy: Policy) -> [String] {
        var lines: [String] = []
        for rule in policy.rules {
            let condition: String
            switch rule.trigger {
            case .absence:
                condition = "When nobody is visible for \(format(rule.graceSeconds)) seconds"
            case .additionalViewer:
                condition = "When another person is visible for \(format(rule.graceSeconds)) seconds"
            }

            for action in rule.actions {
                switch action {
                case .curtain:
                    lines.append("\(condition) → raise the privacy curtain")
                case .hideApps:
                    lines.append("\(condition) → hide selected apps (not active in this build yet)")
                case .displaysOff:
                    lines.append("\(condition) → turn displays off (not active in this build yet)")
                }
            }
        }
        lines.append("Unlocking always requires Touch ID or your password")
        return lines
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }
}
