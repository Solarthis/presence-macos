import SwiftUI
import AppKit
import PresenceCore

@main
struct PresenceApp: App {
    var body: some Scene {
        MenuBarExtra("Presence", systemImage: "eye") {
            Text("Presence — scaffold build (slice 1)")
            Divider()
            Button("Quit Presence") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
