import SwiftUI
import AppKit
import PresenceCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var coordinator: RuntimeCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let safetyDecision = SafetyGates.beginLaunch()
        let menuBarState = MenuBarState.shared

        if let safeModeReason = safetyDecision.safeModeReason {
            menuBarState.showSafeMode(notice: safeModeReason.notice)
            return
        }

        let options = LaunchOptions(
            arguments: CommandLine.arguments,
            validScenarios: Set(ScriptedSource.Scenario.allCases.map(\.rawValue))
        )
        // This bypass is confined to an explicit scripted DEBUG run. Supplying
        // --live-test to an ordinary launch can never weaken authentication.
        let liveTestEnabled = options.liveTestEnabled

        let runtime = RuntimeCoordinator(
            menuBarState: menuBarState,
            liveTestEnabled: liveTestEnabled,
            policyStore: .shared
        )
        coordinator = runtime

        if let scenarioName = options.scenarioName,
           let scenario = ScriptedSource.Scenario(rawValue: scenarioName) {
            runtime.startScripted(scenario: scenario)
        } else {
            runtime.start(source: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        SafetyGates.markCleanTermination()
    }
}

@main
struct PresenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var menuBarState = MenuBarState.shared
    @StateObject private var policyStore = PolicyStore.shared

    var body: some Scene {
        MenuBarExtra {
            if menuBarState.isSafeMode {
                Text(menuBarState.statusText)
                if !menuBarState.detailText.isEmpty {
                    Text(menuBarState.detailText)
                }
                Divider()
                SettingsLink {
                    Text("Settings")
                }
                Button("Quit Presence") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } else {
                Text(menuBarState.menuBarText)
                Divider()
                Button(menuBarState.isPaused ? "Resume monitoring" : "Pause monitoring") {
                    appDelegate.coordinator?.togglePause()
                }
                Button("Protect Now") {
                    appDelegate.coordinator?.protectNow()
                }
                Menu("Simulate") {
                    ForEach(ScriptedSource.Scenario.allCases, id: \.rawValue) { scenario in
                        Button("\(scenario.rawValue) — DEBUG") {
                            appDelegate.coordinator?.simulate(scenario)
                        }
                    }
                }
                PolicyMenuButton()
                Divider()
                Button("Quit Presence") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        } label: {
            Label(menuBarState.menuBarText, systemImage: menuBarState.symbolName)
        }

        Settings {
            VStack(spacing: 8) {
                Text("Presence Settings")
                    .font(.headline)
                Text("Monitoring controls are available from the menu bar.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 360)
        }

        Window("Policies", id: "policies") {
            PolicyWindow(store: policyStore)
        }
    }
}

private struct PolicyMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Policies…") {
            openWindow(id: "policies")
        }
    }
}
