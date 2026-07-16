import Foundation
import PresenceCore

// Assert-based verification harness. XCTest/Swift Testing do not exist on this
// machine (Command Line Tools only) — this executable IS the automated test suite.
// verify.sh runs it; exit code 0 = green.

var failures = 0
func check(_ condition: Bool, _ name: String) {
    if condition {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

check(PresenceCoreVersion.schemaVersion == 1, "checks-harness-runs")
runStateMachineChecks()
runSafetyConfigChecks()
runPolicyChecks()
runRuntimeIsolationChecks()
runCodexOutputFixtureChecks()
runFixtureVisionChecks()

if failures > 0 {
    print("\(failures) FAILURE(S)")
    exit(1)
}
print("ALL CHECKS PASSED")
