import Foundation
import PresenceCore

enum DisplaySleepSettings {
    static let allowDisplaysOffKey = "allowDisplaysOff"
}

final class DisplaysOffExecutor {
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "presence.displays-off-executor", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func executeIfAllowed(policy: Policy?, trigger: PolicyTrigger) {
        guard defaults.bool(forKey: DisplaySleepSettings.allowDisplaysOffKey),
              policy?.rules.contains(where: {
                  $0.trigger == trigger && $0.actions.contains(.displaysOff)
              }) == true else {
            return
        }

        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return
            }
        }
    }
}
