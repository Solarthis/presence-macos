import PresenceCore

private func expectPolicyRejection(
    _ json: String,
    name: String,
    matches: (PolicyValidationError) -> Bool
) {
    switch PolicyValidator.validate(json) {
    case .success:
        check(false, name)
    case let .failure(error):
        check(matches(error), name)
    }
}

private func hostilePolicyFixturesAreRejected() {
    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Hostile","rules":[],"restoration":{"requireAuth":true},"rootCommand":"run"}"#,
        name: "policy-rejects-unknown-root-key"
    ) {
        $0 == .unknownKey(path: "root", key: "rootCommand")
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Hostile","rules":[{"trigger":"absence","graceSeconds":30,"minConfidence":0.6,"actions":["curtain"],"command":"run"}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-unknown-rule-key"
    ) {
        $0 == .unknownKey(path: "rules[0]", key: "command")
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Hostile","rules":[],"restoration":{"requireAuth":true,"fallback":"none"}}"#,
        name: "policy-rejects-unknown-restoration-key"
    ) {
        $0 == .unknownKey(path: "restoration", key: "fallback")
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Too fast","rules":[{"trigger":"absence","graceSeconds":1,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-grace-below-two"
    ) {
        $0 == .graceSecondsOutOfBounds(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Too slow","rules":[{"trigger":"absence","graceSeconds":9999,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-grace-above-six-hundred"
    ) {
        $0 == .graceSecondsOutOfBounds(rule: 0)
    }

    for action in ["runShell", "lockScreen"] {
        expectPolicyRejection(
            #"{"schemaVersion":1,"name":"Unsupported action","rules":[{"trigger":"absence","graceSeconds":30,"actions":["\#(action)"]}],"restoration":{"requireAuth":true}}"#,
            name: "policy-rejects-unsupported-action-\(action)"
        ) {
            $0 == .unsupportedAction(action)
        }
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"No auth","rules":[],"restoration":{"requireAuth":false}}"#,
        name: "policy-rejects-require-auth-false"
    ) {
        $0 == .restorationAuthenticationRequired
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Missing auth","rules":[],"restoration":{}}"#,
        name: "policy-rejects-require-auth-absent"
    ) {
        $0 == .restorationAuthenticationRequired
    }

    expectPolicyRejection(
        #"{"schemaVersion":2,"name":"Future schema","rules":[],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-schema-version-two"
    ) {
        $0 == .unsupportedSchemaVersion(2)
    }

    expectPolicyRejection(
        #"Sure! Here is your policy: {"schemaVersion":1,"name":"Wrapped","rules":[],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-prose-wrapped-json"
    ) {
        $0 == .notSingleJSONObject
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Duplicate","rules":[{"trigger":"absence","graceSeconds":30,"actions":["curtain"]},{"trigger":"absence","graceSeconds":60,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-duplicate-absence-trigger"
    ) {
        $0 == .duplicateTrigger(.absence)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Missing apps","rules":[{"trigger":"absence","graceSeconds":30,"actions":["hideApps"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-hide-apps-without-bundle-ids"
    ) {
        $0 == .hideAppBundleIdsRequired(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Empty actions","rules":[{"trigger":"absence","graceSeconds":30,"actions":[]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-empty-actions"
    ) {
        $0 == .emptyActions(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Hide Terminal","rules":[{"trigger":"absence","graceSeconds":30,"actions":["hideApps"],"hideAppBundleIds":["com.apple.Terminal"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-never-hide-terminal"
    ) {
        $0 == .protectedAppBundleId("com.apple.Terminal")
    }
}

private func remainingSemanticBoundsAreRejected() {
    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Low confidence","rules":[{"trigger":"absence","graceSeconds":30,"minConfidence":0.2,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-confidence-below-bound"
    ) {
        $0 == .minConfidenceOutOfBounds(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Missing people","rules":[{"trigger":"additionalViewer","graceSeconds":5,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-missing-additional-viewer-min-persons"
    ) {
        $0 == .minPersonsRequired(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"One person","rules":[{"trigger":"additionalViewer","graceSeconds":5,"minPersons":1,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-min-persons-below-two"
    ) {
        $0 == .minPersonsOutOfBounds(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Wrong trigger field","rules":[{"trigger":"absence","graceSeconds":30,"minPersons":2,"actions":["curtain"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-min-persons-on-absence"
    ) {
        $0 == .minPersonsNotAllowed(rule: 0)
    }

    expectPolicyRejection(
        #"{"schemaVersion":1,"name":"Unexpected apps","rules":[{"trigger":"absence","graceSeconds":30,"actions":["curtain"],"hideAppBundleIds":["com.example.App"]}],"restoration":{"requireAuth":true}}"#,
        name: "policy-rejects-bundle-ids-without-hide-apps"
    ) {
        $0 == .hideAppBundleIdsNotAllowed(rule: 0)
    }
}

private func examplesCompilerAndPreviewAreValid() {
    for (index, json) in ExamplePolicies.jsonStrings.enumerated() {
        switch PolicyValidator.validate(json) {
        case .success:
            check(true, "bundled-example-\(index + 1)-validates")
        case .failure:
            check(false, "bundled-example-\(index + 1)-validates")
        }
    }

    switch TemplateCompiler.compile("protect my screen when I walk away for 30 seconds") {
    case let .compiled(policy, json):
        check(policy.rules.first?.trigger == .absence, "template-compiler-produces-absence-policy")
        if case .success = PolicyValidator.validate(json) {
            check(true, "template-compiler-output-passes-validator")
        } else {
            check(false, "template-compiler-output-passes-validator")
        }
        check(!PolicyPreview.lines(for: policy).isEmpty, "policy-preview-lines-non-empty")
        check(
            PolicyPreview.lines(for: policy).first
                == "When nobody is visible for 30 seconds → raise the privacy curtain",
            "policy-preview-describes-absence-curtain"
        )
    case .unrecognized, .rejected:
        check(false, "template-compiler-produces-absence-policy")
        check(false, "template-compiler-output-passes-validator")
        check(false, "policy-preview-lines-non-empty")
        check(false, "policy-preview-describes-absence-curtain")
    }

    switch TemplateCompiler.compile("protect my screen when I leave for 2 minutes") {
    case let .compiled(policy, _):
        check(policy.rules.first?.graceSeconds == 120, "template-compiler-recognizes-minutes")
    case .unrecognized, .rejected:
        check(false, "template-compiler-recognizes-minutes")
    }

    switch TemplateCompiler.compile(
        "protect my screen and hide private apps when I walk away for 60 seconds"
    ) {
    case let .compiled(policy, _):
        check(
            policy.rules.first?.actions == [.curtain, .hideApps]
                && policy.rules.first?.hideAppBundleIds == ["com.example.PrivateApp"],
            "template-compiler-preserves-inert-hide-apps-action"
        )
        check(
            PolicyPreview.lines(for: policy).contains(where: {
                $0.hasSuffix("hide selected apps (not active in this build yet)")
            }),
            "policy-preview-labels-hide-apps-inert"
        )
    case .unrecognized, .rejected:
        check(false, "template-compiler-preserves-inert-hide-apps-action")
        check(false, "policy-preview-labels-hide-apps-inert")
    }

    switch TemplateCompiler.compile("do something surprising") {
    case let .unrecognized(examples):
        check(examples.count == 3, "template-compiler-unrecognized-lists-three-examples")
    case .compiled, .rejected:
        check(false, "template-compiler-unrecognized-lists-three-examples")
    }
}

private func policyConfigPreservesProductionIsolation() {
    let policy = Policy(
        schemaVersion: 1,
        name: "Configuration check",
        rules: [
            PolicyRule(trigger: .absence, graceSeconds: 42, actions: [.curtain]),
            PolicyRule(
                trigger: .additionalViewer,
                graceSeconds: 7,
                minPersons: 3,
                actions: [.curtain]
            ),
        ],
        restoration: PolicyRestoration(requireAuth: true)
    )
    let config = MachineConfig.production(applying: policy)

    check(config.graceSeconds == 42, "policy-config-overrides-absence-grace")
    check(
        config.additionalViewerEnabled
            && config.additionalViewerMinPersons == 3
            && config.additionalViewerSustainSeconds == 7,
        "policy-config-overrides-additional-viewer-fields"
    )
    check(
        config.launchGuardSeconds == PresenceDefaults.launchGuardSeconds
            && config.presenceConfirmSeconds == PresenceDefaults.presenceConfirmSeconds
            && config.armAfterPresenceSeconds == PresenceDefaults.armAfterPresenceSeconds
            && config.cooldownSeconds == PresenceDefaults.cooldownSeconds,
        "policy-config-preserves-production-safety-timing"
    )
}

func runPolicyChecks() {
    hostilePolicyFixturesAreRejected()
    remainingSemanticBoundsAreRejected()
    examplesCompilerAndPreviewAreValid()
    policyConfigPreservesProductionIsolation()
}
