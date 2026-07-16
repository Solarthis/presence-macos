import Foundation
import PresenceCore

func runCodexOutputFixtureChecks() {
    runExtractorEdgeCaseChecks()

    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("fixtures-codex", isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        print("SKIP codex-output-fixtures (fixtures-codex absent)")
        return
    }

    let fixtureURLs: [URL]
    do {
        fixtureURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "txt" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
        check(false, "codex-output-fixtures-readable")
        return
    }

    check(!fixtureURLs.isEmpty, "codex-output-fixtures-present")
    for fixtureURL in fixtureURLs {
        let fixtureName = fixtureURL.deletingPathExtension().lastPathComponent
        guard let transcript = try? String(contentsOf: fixtureURL, encoding: .utf8) else {
            check(false, "codex-output-\(fixtureName)-readable")
            continue
        }
        switch extractLastJSONObject(from: transcript) {
        case let .success(json):
            check(true, "codex-output-\(fixtureName)-extracts-last-json")
            if case .success = PolicyValidator.validate(json) {
                check(true, "codex-output-\(fixtureName)-validates")
            } else {
                check(false, "codex-output-\(fixtureName)-validates")
            }
        case .failure:
            check(false, "codex-output-\(fixtureName)-extracts-last-json")
            check(false, "codex-output-\(fixtureName)-validates")
        }
    }
}

private func runExtractorEdgeCaseChecks() {
    let validJSON = ExamplePolicies.simpleAbsenceJSON
    let wrapped = """
    Codex banner
    ```json
    \(validJSON)
    ```
    trailing prose
    """
    switch extractLastJSONObject(from: wrapped) {
    case let .success(json):
        check(json == validJSON, "codex-extractor-handles-fences-and-trailing-prose")
        if case .success = PolicyValidator.validate(json) {
            check(true, "codex-extracted-valid-json-passes-validator")
        } else {
            check(false, "codex-extracted-valid-json-passes-validator")
        }
    case .failure:
        check(false, "codex-extractor-handles-fences-and-trailing-prose")
        check(false, "codex-extracted-valid-json-passes-validator")
    }

    let twoObjects = #"banner {"ignored":{"brace":"}"}} final {"schemaVersion":1,"name":"No auth","rules":[],"restoration":{"requireAuth":false}} done"#
    switch extractLastJSONObject(from: twoObjects) {
    case let .success(json):
        check(json.contains("No auth"), "codex-extractor-selects-last-balanced-object")
        if case .failure(.restorationAuthenticationRequired) = PolicyValidator.validate(json) {
            check(true, "codex-extracted-hostile-json-fails-validator")
        } else {
            check(false, "codex-extracted-hostile-json-fails-validator")
        }
    case .failure:
        check(false, "codex-extractor-selects-last-balanced-object")
        check(false, "codex-extracted-hostile-json-fails-validator")
    }

    switch extractLastJSONObject(from: "Codex returned no structured output.") {
    case .success:
        check(false, "codex-extractor-no-json-is-typed-failure")
    case .failure(.noJSONObject):
        check(true, "codex-extractor-no-json-is-typed-failure")
    case .failure(.unbalancedJSONObject):
        check(false, "codex-extractor-no-json-is-typed-failure")
    }

    switch extractLastJSONObject(from: "banner {\"schemaVersion\": 1") {
    case .success:
        check(false, "codex-extractor-unbalanced-json-is-typed-failure")
    case .failure(.unbalancedJSONObject):
        check(true, "codex-extractor-unbalanced-json-is-typed-failure")
    case .failure(.noJSONObject):
        check(false, "codex-extractor-unbalanced-json-is-typed-failure")
    }
}
