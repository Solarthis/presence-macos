import Foundation

func runSliceSevenStructuralChecks() {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let presence = root.appendingPathComponent("Sources/Presence", isDirectory: true)
    let runtime = read(presence.appendingPathComponent("RuntimeCoordinator.swift"))
    let hud = read(presence.appendingPathComponent("HUDPanel.swift"))
    let displays = read(presence.appendingPathComponent("DisplaysOffExecutor.swift"))
    let history = read(presence.appendingPathComponent("EventHistoryWindow.swift"))
    let compiler = read(presence.appendingPathComponent("CodexPolicyCompiler.swift"))

    check(
        runtime.contains("Another person may be able to view your screen"),
        "additional-viewer-uses-curtain-title-swap"
    )
    check(
        hud.contains(">= 2 ? .controlAccentColor : .labelColor"),
        "hud-accents-two-or-more-people"
    )
    check(
        displays.contains("/usr/bin/pmset")
            && displays.contains("[\"displaysleepnow\"]")
            && displays.contains("allowDisplaysOffKey")
            && displays.contains("$0.actions.contains(.displaysOff)"),
        "displays-off-is-policy-and-settings-gated"
    )
    check(
        history.contains("EventExplanationPayloadBuilder.makePayload(")
            && history.contains("records: records")
            && !history.contains("Data(contentsOf:"),
        "flow-f-builds-payload-from-record-structs"
    )
    check(
        history.contains("Text(\"What will be sent\")")
            && history.contains("Button(\"Send\")"),
        "flow-f-requires-explicit-preview-send"
    )
    check(
        compiler.contains("purpose: \"event-explanation\"")
            && compiler.contains("private static let liveCallCountKey = \"codexLiveCalls\"")
            && compiler.contains("guard reserveLiveCall() else { return .budgetReached }"),
        "flow-f-shares-codex-live-call-budget"
    )

    let sourceFiles = (try? FileManager.default.contentsOfDirectory(
        at: presence,
        includingPropertiesForKeys: nil
    )) ?? []
    let allSource = sourceFiles
        .filter { $0.pathExtension == "swift" }
        .map(read)
        .joined(separator: "\n")
    check(
        !allSource.contains("NSRunningApplication"),
        "app-hiding-remains-cut"
    )
}

private func read(_ url: URL) -> String {
    (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}
