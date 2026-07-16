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
        // DEBUG builds only: both simulator and live-test flags are required, and
        // a live-test session can never enter camera monitoring.
#if DEBUG
        let liveTestEnabled = options.liveTestEnabled
#else
        let liveTestEnabled = false
#endif

        let runtime = RuntimeCoordinator(
            menuBarState: menuBarState,
            liveTestEnabled: liveTestEnabled,
            policyStore: .shared,
            fixtureCaptureEnabled: CommandLine.arguments.contains("--fixture-capture")
        )
        coordinator = runtime

        if let scenarioName = options.scenarioName,
           let scenario = ScriptedSource.Scenario(rawValue: scenarioName) {
            runtime.startScripted(scenario: scenario)
        } else {
            runtime.startForCurrentCameraAuthorization()
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
    @StateObject private var eventStore = EventStore.shared

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
                if !menuBarState.isSimulatorRunning {
                    CameraPermissionControls(coordinator: appDelegate.coordinator)
                }
                if menuBarState.cameraAuthorizationState == .authorized
                    || menuBarState.isSimulatorRunning {
                    Button(menuBarState.isPaused ? "Resume monitoring" : "Pause monitoring") {
                        appDelegate.coordinator?.togglePause()
                    }
                }
                Button("Protect Now") {
                    appDelegate.coordinator?.protectNow()
                }
                Menu("Simulator") {
                    ForEach(ScriptedSource.Scenario.allCases, id: \.rawValue) { scenario in
                        Button(scenario.rawValue) {
                            appDelegate.coordinator?.simulate(scenario)
                        }
                    }
                    if menuBarState.isSimulatorRunning {
                        Divider()
                        Button("Stop Simulator") {
                            appDelegate.coordinator?.stopSimulator()
                        }
                    }
                }
                Button(menuBarState.isHUDVisible ? "Hide Status HUD" : "Show Status HUD") {
                    appDelegate.coordinator?.toggleHUD()
                }
                .disabled(menuBarState.isSimulatorRunning)
                if menuBarState.fixtureCaptureAvailable {
                    Menu("DEBUG") {
                        Button("Capture fixture frame") {
                            appDelegate.coordinator?.captureFixtureFrame()
                        }
                    }
                }
                PolicyMenuButton()
                EventHistoryMenuButton()
                ExplainRecentEventsButton(
                    eventStore: eventStore,
                    policyStore: policyStore
                )
                Divider()
                Button("Quit Presence") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        } label: {
            Label(menuBarState.menuBarText, systemImage: menuBarState.symbolName)
        }

        Settings {
            PresenceSettingsView()
        }

        Window("Policies", id: "policies") {
            PolicyWindow(store: policyStore)
        }

        Window("Event History", id: "event-history") {
            EventHistoryWindow(store: eventStore)
        }
    }
}

private struct CameraPermissionControls: View {
    let coordinator: RuntimeCoordinator?
    @ObservedObject private var menuBarState = MenuBarState.shared
    @State private var showingPrePrompt = false

    var body: some View {
        Group {
            switch menuBarState.cameraAuthorizationState {
            case .notDetermined:
                Button("Start Monitoring") {
                    showingPrePrompt = true
                }
            case .unavailable:
                Button("Open System Settings…") {
                    guard let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
                    ) else { return }
                    NSWorkspace.shared.open(url)
                }
            case .authorized:
                EmptyView()
            }
        }
        .sheet(isPresented: $showingPrePrompt) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Presence uses the camera locally to notice when you step away. No images ever leave this Mac.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Enable camera") {
                        showingPrePrompt = false
                        coordinator?.requestCameraAccess()
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("Not now", role: .cancel) {
                        showingPrePrompt = false
                    }
                }
            }
            .padding(24)
            .frame(width: 430)
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

private struct EventHistoryMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Event History…") {
            openWindow(id: "event-history")
        }
    }
}

private struct PresenceSettingsView: View {
    @AppStorage(DisplaySleepSettings.allowDisplaysOffKey) private var allowDisplaysOff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presence Settings")
                .font(.headline)
            Text("Monitoring controls are available from the menu bar.")
                .foregroundStyle(.secondary)
            Divider()
            Toggle("Allow turning displays off", isOn: $allowDisplaysOff)
            Text("Turns off displays. Your Mac locks only if 'Require password immediately' is enabled — Presence cannot verify this setting.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 460)
    }
}
