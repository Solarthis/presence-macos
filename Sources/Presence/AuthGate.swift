import Foundation
import LocalAuthentication

final class AuthGate {
    private let onSuccess: () -> Void
    private let onRejected: () -> Void
    private let onSystemFailureLimit: () -> Void
    private var context: LAContext?
    private var consecutiveSystemFailures = 0
    private var isEvaluating = false

    init(
        onSuccess: @escaping () -> Void,
        onRejected: @escaping () -> Void,
        onSystemFailureLimit: @escaping () -> Void
    ) {
        self.onSuccess = onSuccess
        self.onRejected = onRejected
        self.onSystemFailureLimit = onSystemFailureLimit
    }

    func requestAuthentication() {
        guard !isEvaluating else { return }

        let context = LAContext()
        self.context = context
        isEvaluating = true
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Restore access to your Presence-protected workspace"
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.finish(success: success, error: error)
            }
        }
    }

    func cancel() {
        context?.invalidate()
        context = nil
        isEvaluating = false
    }

    private func finish(success: Bool, error: Error?) {
        isEvaluating = false
        context = nil

        if success {
            consecutiveSystemFailures = 0
            onSuccess()
            return
        }

        onRejected()
        let errorCode = error.map { LAError.Code(rawValue: ($0 as NSError).code) }
        if errorCode == .userCancel || errorCode == .authenticationFailed {
            consecutiveSystemFailures = 0
            return
        }

        consecutiveSystemFailures += 1
        if consecutiveSystemFailures >= 3 {
            onSystemFailureLimit()
        }
    }
}
