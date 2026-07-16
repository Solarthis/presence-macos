import Foundation
import PresenceCore

enum CodexPolicyCompilationResult {
    case compiled(policy: Policy, json: String)
    case fallback(message: String, templateResult: TemplateCompilationResult)
    case failed(reason: String)
    case cancelled
}

private let COMPILER_PROMPT = #"""
    Convert a plain-English Presence privacy request into policy schema v1.

    Output ONLY a single JSON object, no prose, no markdown fences.

    The complete schema is:
    {
      "schemaVersion": 1,
      "name": string,
      "rules": [
        {
          "trigger": "absence" | "additionalViewer",
          "graceSeconds": number from 2 through 600,
          "minPersons": integer at least 2, required only for "additionalViewer",
          "minConfidence": number from 0.3 through 1.0, optional and defaults to 0.6,
          "actions": non-empty array containing only "curtain", "hideApps", or "displaysOff",
          "hideAppBundleIds": array of bundle-ID strings, required only when "hideApps" is present
        }
      ],
      "restoration": {"requireAuth": true}
    }

    Unknown keys are forbidden. There may be at most one rule per trigger. Never put
    minPersons on an absence rule. Never put hideAppBundleIds on a rule without hideApps.
    Never use com.apple.terminal, com.googlecode.iterm2, or com.microsoft.vscode in
    hideAppBundleIds. restoration.requireAuth must always be true.

    Example request: Protect my screen when I walk away for 30 seconds
    Example output: {"schemaVersion":1,"name":"Walk-away protection","rules":[{"trigger":"absence","graceSeconds":30,"minConfidence":0.6,"actions":["curtain"]}],"restoration":{"requireAuth":true}}

    Example request: Raise the curtain when another person is visible for 5 seconds
    Example output: {"schemaVersion":1,"name":"Shoulder privacy","rules":[{"trigger":"additionalViewer","graceSeconds":5,"minPersons":2,"minConfidence":0.6,"actions":["curtain"]}],"restoration":{"requireAuth":true}}
    """#

final class CodexPolicyCompiler {

    private static let timeoutSeconds: TimeInterval = 120
    private static let liveCallLimit = 10
    private static let liveCallCountKey = "codexLiveCalls"
    private static let codexPathKey = "codexPath"
    private static let budgetLock = NSLock()
    private static let logLock = NSLock()

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let workerQueue = DispatchQueue(label: "presence.codex-policy-compiler")
    private let processLock = NSLock()
    private var currentProcess: Process?
    private var cancellationRequested = false

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    func compile(
        _ userText: String,
        completion: @escaping (CodexPolicyCompilationResult) -> Void
    ) {
        workerQueue.async { [self] in
            let result = compileOnWorker(userText)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func cancel() {
        processLock.lock()
        cancellationRequested = true
        let process = currentProcess
        processLock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func compileOnWorker(_ userText: String) -> CodexPolicyCompilationResult {
        guard !isCancellationRequested else { return .cancelled }
        guard let executableURL = discoverCodexBinary() else {
            return templateFallback(
                message: "Codex CLI not found — using built-in templates",
                userText: userText
            )
        }

        switch runCodex(
            executableURL: executableURL,
            userText: userText,
            purpose: "policy-compile"
        ) {
        case let .output(output):
            switch validate(output) {
            case let .success(policy, json):
                return .compiled(policy: policy, json: json)
            case let .failure(firstReason):
                let retryText = userText
                    + "\n\nThe previous output was rejected for this reason: "
                    + firstReason
                    + "\nReturn one corrected JSON object only."
                switch runCodex(
                    executableURL: executableURL,
                    userText: retryText,
                    purpose: "policy-compile-retry"
                ) {
                case let .output(retryOutput):
                    switch validate(retryOutput) {
                    case let .success(policy, json):
                        return .compiled(policy: policy, json: json)
                    case let .failure(secondReason):
                        return .failed(reason: secondReason)
                    }
                case .budgetReached:
                    return templateFallback(
                        message: "live compile budget reached — using built-in templates",
                        userText: userText
                    )
                case .cancelled:
                    return .cancelled
                case let .failed(reason):
                    return .failed(reason: reason)
                }
            }
        case .budgetReached:
            return templateFallback(
                message: "live compile budget reached — using built-in templates",
                userText: userText
            )
        case .cancelled:
            return .cancelled
        case let .failed(reason):
            return .failed(reason: reason)
        }
    }

    private func discoverCodexBinary() -> URL? {
        var paths: [String] = []
        if let override = defaults.string(forKey: Self.codexPathKey), !override.isEmpty {
            paths.append((override as NSString).expandingTildeInPath)
        }
        paths.append(
            ("~/.nvm/versions/node/v24.15.0/bin/codex" as NSString).expandingTildeInPath
        )
        paths.append("/opt/homebrew/bin/codex")
        paths.append("/usr/local/bin/codex")

        for path in paths where fileManager.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private enum InvocationResult {
        case output(String)
        case budgetReached
        case cancelled
        case failed(String)
    }

    private func runCodex(
        executableURL: URL,
        userText: String,
        purpose: String
    ) -> InvocationResult {
        guard !isCancellationRequested else { return .cancelled }
        guard reserveLiveCall() else { return .budgetReached }

        let input = COMPILER_PROMPT + "\n\nUSER REQUEST:\n" + userText
        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        process.executableURL = executableURL
        process.arguments = ["exec", "--sandbox", "read-only", "-"]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = FileHandle.nullDevice

        let timeout = InvocationTimeout()
        var output = ""
        var launchError: Error?
        do {
            try process.run()
            processLock.lock()
            currentProcess = process
            let shouldCancel = cancellationRequested
            processLock.unlock()
            if shouldCancel, process.isRunning {
                process.terminate()
            }

            let timeoutWorkItem = DispatchWorkItem {
                if timeout.markTimedOutIfActive(), process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + Self.timeoutSeconds,
                execute: timeoutWorkItem
            )

            do {
                try standardInput.fileHandleForWriting.write(contentsOf: Data(input.utf8))
                try standardInput.fileHandleForWriting.close()
            } catch {
                if process.isRunning {
                    process.terminate()
                }
                launchError = error
            }

            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeout.cancel()
            timeoutWorkItem.cancel()
            output = String(data: outputData, encoding: .utf8) ?? ""
        } catch {
            launchError = error
        }

        clearCurrentProcess(process)
        appendLiveCallLog(
            purpose: purpose,
            inputCharacters: input.count,
            outputCharacters: output.count
        )

        if isCancellationRequested {
            return .cancelled
        }
        if timeout.didTimeOut {
            return .failed("Codex CLI timed out after 120 seconds.")
        }
        if let launchError {
            return .failed("Codex CLI failed: \(launchError.localizedDescription)")
        }
        guard process.terminationStatus == 0 else {
            return .failed("Codex CLI exited with status \(process.terminationStatus).")
        }
        return .output(output)
    }

    private func validate(_ output: String) -> ValidationResult {
        switch extractLastJSONObject(from: output) {
        case let .success(json):
            switch PolicyValidator.validate(json) {
            case let .success(policy):
                return .success(policy, json)
            case let .failure(error):
                return .failure(error.reason)
            }
        case let .failure(error):
            return .failure(error.reason)
        }
    }

    private enum ValidationResult {
        case success(Policy, String)
        case failure(String)
    }

    private func templateFallback(
        message: String,
        userText: String
    ) -> CodexPolicyCompilationResult {
        .fallback(message: message, templateResult: TemplateCompiler.compile(userText))
    }

    private func reserveLiveCall() -> Bool {
        Self.budgetLock.lock()
        defer { Self.budgetLock.unlock() }
        let count = defaults.integer(forKey: Self.liveCallCountKey)
        guard count < Self.liveCallLimit else { return false }
        defaults.set(count + 1, forKey: Self.liveCallCountKey)
        return true
    }

    private func appendLiveCallLog(
        purpose: String,
        inputCharacters: Int,
        outputCharacters: Int
    ) {
        Self.logLock.lock()
        defer { Self.logLock.unlock() }
        let directory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("logs", isDirectory: true)
        let logURL = directory.appendingPathComponent("live-calls.log")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = "\(ISO8601DateFormatter().string(from: Date()))"
            + "\tpurpose=\(purpose)"
            + "\tcharsIn=\(inputCharacters)"
            + "\tcharsOut=\(outputCharacters)\n"
        let data = Data(line.utf8)
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: data)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            return
        }
    }

    private var isCancellationRequested: Bool {
        processLock.lock()
        defer { processLock.unlock() }
        return cancellationRequested
    }

    private func clearCurrentProcess(_ process: Process) {
        processLock.lock()
        if currentProcess === process {
            currentProcess = nil
        }
        processLock.unlock()
    }
}

private final class InvocationTimeout {
    private let lock = NSLock()
    private var timedOut = false
    private var isActive = true

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOutIfActive() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return false }
        timedOut = true
        isActive = false
        return true
    }

    func cancel() {
        lock.lock()
        isActive = false
        lock.unlock()
    }
}
