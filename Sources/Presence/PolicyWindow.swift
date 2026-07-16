import PresenceCore
import SwiftUI

enum PolicyCompilerMode: String, CaseIterable, Identifiable {
    case template
    case codexCLI

    var id: String { rawValue }
    var label: String {
        switch self {
        case .template:
            return "Built-in templates"
        case .codexCLI:
            return "Compile with GPT-5.6 (via your Codex plan)"
        }
    }
}

struct PolicyWindow: View {
    @ObservedObject var store: PolicyStore

    @State private var isCreating = false
    @State private var requestText = ""
    @State private var compilerMode = PolicyCompilerMode.template
    @State private var previewPolicy: Policy?
    @State private var previewJSON = ""
    @State private var examples: [String] = []
    @State private var errorText: String?
    @State private var activeCodexCompiler: CodexPolicyCompiler?
    @State private var isCodexCompiling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Policies")
                .font(.title2.bold())

            if store.policies.isEmpty {
                Text("No approved policies yet.")
                    .foregroundStyle(.secondary)
            } else {
                List(store.policies) { stored in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stored.policy.name)
                                .font(.headline)
                            Text(store.activePolicyID == stored.id ? "Active" : "Inactive")
                                .foregroundStyle(store.activePolicyID == stored.id ? .green : .secondary)
                        }
                        Spacer()
                        if store.activePolicyID == stored.id {
                            Button("Deactivate") { store.deactivate() }
                        } else {
                            Button("Activate") { store.activate(stored.id) }
                        }
                        Button("Delete", role: .destructive) {
                            do {
                                try store.delete(stored.id)
                            } catch {
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 140)
            }

            Divider()

            if isCreating {
                creationFlow
            } else {
                Button("New Policy…") {
                    resetCreation()
                    isCreating = true
                }
            }

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 420)
        .sheet(isPresented: $isCodexCompiling) {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Compiling policy…")
                Button("Cancel", role: .cancel) {
                    activeCodexCompiler?.cancel()
                }
            }
            .padding(32)
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var creationFlow: some View {
        if let previewPolicy {
            Text("Preview before approval")
                .font(.headline)
            ForEach(PolicyPreview.lines(for: previewPolicy), id: \.self) { line in
                Text("• \(line)")
            }
            DisclosureGroup("Raw JSON") {
                ScrollView(.horizontal) {
                    Text(previewJSON)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            HStack {
                Button("Approve") { approve(previewPolicy) }
                    .keyboardShortcut(.defaultAction)
                Button("Reject", role: .cancel) {
                    self.previewPolicy = nil
                    previewJSON = ""
                }
            }
        } else {
            Text("Describe the protection you want in plain English.")
                .font(.headline)
            TextField("Protect my screen when I walk away for 30 seconds", text: $requestText)
                .textFieldStyle(.roundedBorder)
            Picker("Compiler", selection: $compilerMode) {
                ForEach(PolicyCompilerMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            HStack {
                Button("Compile") { compile(requestText, mode: compilerMode) }
                    .disabled(requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) { isCreating = false }
            }
            if !examples.isEmpty {
                Text("Try one of these examples:")
                    .font(.subheadline.bold())
                ForEach(examples, id: \.self) { example in
                    Text("• \(example)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func compile(_ text: String, mode: PolicyCompilerMode) {
        errorText = nil
        examples = []
        switch mode {
        case .template:
            switch TemplateCompiler.compile(text) {
            case let .compiled(policy, json):
                previewPolicy = policy
                previewJSON = json
            case let .unrecognized(suggestions):
                examples = suggestions
            case let .rejected(error):
                errorText = error.reason
            }
        case .codexCLI:
            let compiler = CodexPolicyCompiler()
            activeCodexCompiler = compiler
            isCodexCompiling = true
            compiler.compile(text) { result in
                isCodexCompiling = false
                activeCodexCompiler = nil
                switch result {
                case let .compiled(policy, json):
                    previewPolicy = policy
                    previewJSON = json
                case let .fallback(message, templateResult):
                    errorText = message
                    switch templateResult {
                    case let .compiled(policy, json):
                        previewPolicy = policy
                        previewJSON = json
                    case let .unrecognized(suggestions):
                        examples = suggestions
                    case let .rejected(error):
                        errorText = "\(message)\n\(error.reason)"
                    }
                case let .failed(reason):
                    errorText = reason
                case .cancelled:
                    break
                }
            }
        }
    }

    private func approve(_ policy: Policy) {
        do {
            try store.approveAndActivate(policy)
            isCreating = false
            resetCreation()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func resetCreation() {
        requestText = ""
        previewPolicy = nil
        previewJSON = ""
        examples = []
        errorText = nil
    }
}
