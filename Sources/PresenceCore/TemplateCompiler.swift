import Foundation

public enum TemplateCompilationResult: Equatable {
    case compiled(policy: Policy, json: String)
    case unrecognized(examples: [String])
    case rejected(PolicyValidationError)
}

public enum TemplateCompiler {
    public static func compile(_ input: String) -> TemplateCompilationResult {
        let text = input.lowercased()
        guard let duration = durationSeconds(in: text) else {
            return .unrecognized(examples: ExamplePolicies.phrases)
        }

        let trigger: PolicyTrigger
        if text.contains("someone else") || text.contains("another person") {
            trigger = .additionalViewer
        } else if text.contains("walk away")
                    || text.contains("nobody")
                    || text.contains("no one")
                    || text.contains("absence")
                    || text.contains("leave") {
            trigger = .absence
        } else {
            return .unrecognized(examples: ExamplePolicies.phrases)
        }

        var actions: [PolicyAction] = [.curtain]
        var hiddenBundleIDs: [String]?
        if text.contains("hide apps") || text.contains("hide private apps") {
            actions.append(.hideApps)
            hiddenBundleIDs = ["com.example.PrivateApp"]
        }
        if text.contains("displays off") || text.contains("turn off displays") {
            actions.append(.displaysOff)
        }

        let policy = Policy(
            schemaVersion: 1,
            name: trigger == .absence ? "Walk-away protection" : "Shoulder privacy",
            rules: [
                PolicyRule(
                    trigger: trigger,
                    graceSeconds: duration,
                    minPersons: trigger == .additionalViewer ? 2 : nil,
                    actions: actions,
                    hideAppBundleIds: hiddenBundleIDs
                ),
            ],
            restoration: PolicyRestoration(requireAuth: true)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(policy),
              let json = String(data: data, encoding: .utf8) else {
            return .rejected(.schemaMismatch("Template output could not be encoded."))
        }

        switch PolicyValidator.validate(json) {
        case let .success(validatedPolicy):
            return .compiled(policy: validatedPolicy, json: json)
        case let .failure(error):
            return .rejected(error)
        }
    }

    private static func durationSeconds(in text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(seconds?|minutes?)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: text,
                  range: NSRange(text.startIndex..., in: text)
              ),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else {
            return nil
        }
        return text[unitRange].hasPrefix("minute") ? value * 60 : value
    }
}
