import Foundation

func runRuntimeIsolationChecks() {
    let runtimeURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/Presence/RuntimeCoordinator.swift")
    guard let source = try? String(contentsOf: runtimeURL, encoding: .utf8) else {
        check(false, "runtime-isolation-source-is-readable")
        return
    }
    check(true, "runtime-isolation-source-is-readable")

    let cameraConstructionCount = source.components(
        separatedBy: "CameraSource(fixtureCaptureEnabled:"
    ).count - 1
    check(
        cameraConstructionCount == 1
            && source.contains("start(source: CameraSource(fixtureCaptureEnabled:"),
        "camera-construction-routes-through-production-start"
    )

    let restoreBlock = functionBlock(
        named: "restoreProductionAfterSimulator",
        in: source
    )
    check(
        restoreBlock?.contains("startCameraMonitoring()") == true
            && restoreBlock?.contains("begin(source:") == false,
        "simulator-restoration-routes-through-production-entrypoint"
    )

    let productionStartBlock = functionBlock(named: "start(source:", in: source)
    check(
        productionStartBlock?.contains(".production(applying: policyStore.activePolicy)") == true,
        "camera-production-entrypoint-applies-active-policy"
    )
}

private func functionBlock(named name: String, in source: String) -> String? {
    guard let start = source.range(of: "func \(name)")?.lowerBound else { return nil }
    let suffix = source[start...]
    guard let next = suffix.dropFirst().range(of: "\n    private func ")?.lowerBound else {
        return String(suffix)
    }
    return String(suffix[..<next])
}
