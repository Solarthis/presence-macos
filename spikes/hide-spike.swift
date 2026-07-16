// Spike S3 (final): NSRunningApplication.hide() on macOS 26 — verify via OBSERVED isHidden
// state, not return values (which return false spuriously here). Throwaway code.
import AppKit

func poll(_ app: NSRunningApplication, until want: Bool, timeout: Double) -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if app.isHidden == want { return true }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return app.isHidden == want
}

let bundleId = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "com.apple.TextEdit"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
    print("SPIKE: \(bundleId) not running"); exit(2)
}
_ = app.hide()
let didHide = poll(app, until: true, timeout: 3)
_ = app.unhide()
let didShow = poll(app, until: false, timeout: 3)
print("SPIKE observed: hidden=\(didHide) then visible-again=\(didShow) target=\(bundleId)")
print(didHide && didShow ? "SPIKE RESULT: PASS — hide()/unhide() work without TCC (verify via isHidden, ignore return values)"
                         : "SPIKE RESULT: FAIL — cut app hiding per fallback")
