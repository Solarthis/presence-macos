import AppKit
import PresenceCore

final class HUDPanel {
    private let panel: NSPanel
    private let stateLabel = NSTextField(labelWithString: "PAUSED")
    private let peopleLabel = NSTextField(labelWithString: "People: —")
    private let confidenceLabel = NSTextField(labelWithString: "Confidence: —")
    private let scenarioLabel = NSTextField(labelWithString: "")
    private let simulatorBadge = NSTextField(labelWithString: "SIMULATOR — scripted events, real state machine")

    var isVisible: Bool { panel.isVisible }

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        buildContent()
        reposition()
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.maxX - size.width - 20,
            y: frame.maxY - size.height - 20
        ))
    }

    func update(
        state: PresenceState,
        config: MachineConfig,
        now: Double,
        personCount: Int?,
        confidenceBand: ConfidenceBand?,
        scenarioName: String?
    ) {
        stateLabel.stringValue = stateText(for: state, config: config, now: now)
        peopleLabel.stringValue = "People: \(personCount.map(String.init) ?? "—")"
        peopleLabel.textColor = (personCount ?? 0) >= 2 ? .controlAccentColor : .labelColor
        confidenceLabel.stringValue = "Confidence: \(confidenceBand?.rawValue.uppercased() ?? "—")"
        if let scenarioName {
            scenarioLabel.stringValue = "Scenario: \(scenarioName)"
            scenarioLabel.isHidden = false
            simulatorBadge.isHidden = false
        } else {
            scenarioLabel.stringValue = ""
            scenarioLabel.isHidden = true
            simulatorBadge.isHidden = true
        }
    }

    private func stateText(for state: PresenceState, config: MachineConfig, now: Double) -> String {
        switch state {
        case .launchGuard, .awaitingPresence, .cooldown:
            return "MONITORING"
        case .present:
            return "PRESENT"
        case let .grace(since):
            let remaining = max(0, Int(ceil(config.graceSeconds - (now - since))))
            return String(format: "GRACE %02d:%02d", remaining / 60, remaining % 60)
        case .protected:
            return "PROTECTED"
        case .paused:
            return "PAUSED"
        case .unknownWarning:
            return "UNKNOWN"
        }
    }

    private func buildContent() {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active

        stateLabel.font = .monospacedSystemFont(ofSize: 34, weight: .bold)
        stateLabel.textColor = .labelColor
        peopleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        confidenceLabel.font = .systemFont(ofSize: 19, weight: .medium)
        scenarioLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        simulatorBadge.font = .systemFont(ofSize: 13, weight: .bold)
        simulatorBadge.textColor = .white
        simulatorBadge.backgroundColor = .systemOrange
        simulatorBadge.drawsBackground = true
        simulatorBadge.alignment = .center
        simulatorBadge.isBezeled = false
        simulatorBadge.isEditable = false
        simulatorBadge.isSelectable = false
        simulatorBadge.isHidden = true
        scenarioLabel.isHidden = true

        let stack = NSStackView(views: [
            simulatorBadge,
            stateLabel,
            peopleLabel,
            confidenceLabel,
            scenarioLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: background.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -22),
            simulatorBadge.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        panel.contentView = background
    }
}
