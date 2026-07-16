import AppKit

private final class CurtainWindow: NSWindow {
    var requestAuthentication: (() -> Void)?
    var requestQuit: (() -> Void)?
    private var escapeHoldTimer: Timer?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.charactersIgnoringModifiers?.lowercased() == "q",
           modifiers.contains([.command, .option, .shift]) {
            requestQuit?()
            return
        }

        if event.keyCode == 53 {
            beginEscapeHold()
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelEscapeHold()
            return
        }
        super.keyUp(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
    }

    override func resignKey() {
        cancelEscapeHold()
        super.resignKey()
    }

    private func beginEscapeHold() {
        guard escapeHoldTimer == nil else { return }
        let timer = Timer(timeInterval: 3, repeats: false) { [weak self] _ in
            self?.escapeHoldTimer = nil
            self?.requestAuthentication?()
        }
        escapeHoldTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelEscapeHold() {
        escapeHoldTimer?.invalidate()
        escapeHoldTimer = nil
    }
}

private final class CurtainContentView: NSVisualEffectView {
    private let unlockAction: () -> Void
    private let quitAction: () -> Void
    private let quitButton: NSButton

    init(
        title: String,
        unlockAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.unlockAction = unlockAction
        self.quitAction = quitAction
        quitButton = NSButton(title: "Quit Presence", target: nil, action: nil)
        super.init(frame: .zero)
        buildInterface(title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showQuitButton() {
        quitButton.isHidden = false
    }

    @objc private func unlockPressed() {
        unlockAction()
    }

    @objc private func quitPressed() {
        quitAction()
    }

    private func buildInterface(title titleText: String) {
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Workspace locked")
        icon.contentTintColor = .white
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 46, weight: .medium)

        let title = NSTextField(labelWithString: titleText)
        title.font = .systemFont(ofSize: 25, weight: .semibold)
        title.textColor = .white
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: "Unlock with Touch ID or your password")
        subtitle.font = .systemFont(ofSize: 15)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        let unlockButton = NSButton(title: "Unlock", target: self, action: #selector(unlockPressed))
        unlockButton.bezelStyle = .rounded
        unlockButton.controlSize = .large
        unlockButton.keyEquivalent = "\r"
        unlockButton.bezelColor = .controlAccentColor

        let hint = NSTextField(labelWithString: "Hold Esc to unlock · ⌘⌥⇧Q quits Presence")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center

        quitButton.target = self
        quitButton.action = #selector(quitPressed)
        quitButton.bezelStyle = .rounded
        quitButton.isHidden = true

        let stack = NSStackView(views: [icon, title, subtitle, unlockButton, hint, quitButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(22, after: subtitle)
        stack.setCustomSpacing(22, after: unlockButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            unlockButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }
}

final class CurtainController {
    private(set) var isRaised = false
    private var windows: [CurtainWindow] = []
    private var contentViews: [CurtainContentView] = []
    private let requestAuthentication: () -> Void
    private var title = "Presence protected this workspace"

    init(requestAuthentication: @escaping () -> Void) {
        self.requestAuthentication = requestAuthentication
    }

    func raise(title: String = "Presence protected this workspace") {
        self.title = title
        isRaised = true
        rebuildWindows()
    }

    func dismiss() {
        isRaised = false
        closeWindows()
    }

    func recoverScreens() {
        guard isRaised else { return }
        rebuildWindows()
    }

    func showQuitButton() {
        contentViews.forEach { $0.showQuitButton() }
    }

    private func rebuildWindows() {
        closeWindows()

        for screen in NSScreen.screens {
            let window = CurtainWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.requestAuthentication = { [weak self] in self?.requestAuthentication() }
            window.requestQuit = { NSApp.terminate(nil) }

            let content = CurtainContentView(
                title: title,
                unlockAction: { [weak self] in self?.requestAuthentication() },
                quitAction: { NSApp.terminate(nil) }
            )
            window.contentView = content
            windows.append(window)
            contentViews.append(content)
            window.orderFrontRegardless()
        }

        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func closeWindows() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        contentViews.removeAll()
    }
}
