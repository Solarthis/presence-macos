import PresenceCore
import SwiftUI

struct EventHistoryWindow: View {
    @ObservedObject var store: EventStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Event History")
                    .font(.title2.bold())
                Spacer()
                Button("Delete All", role: .destructive) {
                    store.deleteAll()
                }
                .disabled(store.records.isEmpty)
            }

            if store.records.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Recent Presence events will appear here.")
                )
            } else {
                List {
                    ForEach(Array(store.records.reversed().enumerated()), id: \.offset) { _, record in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(record.eventType)
                                    .font(.headline)
                                Spacer()
                                Text(record.timestamp)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            recordFields(record)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 460)
    }

    @ViewBuilder
    private func recordFields(_ record: EventRecord) -> some View {
        Text("schemaVersion: \(record.schemaVersion)")
        Text("policyId: \(record.policyId ?? "—")")
        Text("confidenceBand: \(record.confidenceBand ?? "—")")
        Text("actionTaken: \(record.actionTaken ?? "—")")
    }
}

struct ExplainRecentEventsButton: View {
    @ObservedObject var eventStore: EventStore
    @ObservedObject var policyStore: PolicyStore

    @State private var showingPreview = false
    @State private var payload = ""
    @State private var localSummary = ""
    @State private var responseText: String?
    @State private var statusText: String?
    @State private var isSending = false
    @State private var activeCompiler: CodexPolicyCompiler?

    var body: some View {
        Button("Explain recent events…") {
            preparePreview()
        }
        .sheet(isPresented: $showingPreview) {
            explanationSheet
        }
    }

    @ViewBuilder
    private var explanationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let responseText {
                Text("Event explanation")
                    .font(.title2.bold())
                if let statusText {
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    Text(responseText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Done") { showingPreview = false }
                    .keyboardShortcut(.defaultAction)
            } else {
                Text("What will be sent")
                    .font(.title2.bold())
                Text("Only these sanitized event fields will be sent after you click Send.")
                    .foregroundStyle(.secondary)
                ScrollView([.horizontal, .vertical]) {
                    Text(payload)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 280)

                if isSending {
                    HStack {
                        ProgressView()
                        Text("Requesting explanation…")
                        Spacer()
                        Button("Cancel", role: .cancel) {
                            activeCompiler?.cancel()
                        }
                    }
                } else {
                    HStack {
                        Button("Send") { send() }
                            .keyboardShortcut(.defaultAction)
                        Button("Cancel", role: .cancel) { showingPreview = false }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 460)
        .interactiveDismissDisabled(isSending)
    }

    private func preparePreview() {
        let records = eventStore.recentRecords()
        payload = EventExplanationPayloadBuilder.makePayload(
            records: records,
            policyNamesByID: policyStore.policyNamesByID
        )
        localSummary = EventExplanationPayloadBuilder.localSummary(records: records)
        responseText = nil
        statusText = nil
        isSending = false
        activeCompiler = nil
        showingPreview = true
    }

    private func send() {
        let compiler = CodexPolicyCompiler()
        activeCompiler = compiler
        isSending = true
        compiler.explainEvents(payload: payload) { result in
            isSending = false
            activeCompiler = nil
            switch result {
            case let .response(response):
                responseText = response
            case let .fallback(message):
                statusText = message
                responseText = localSummary
            case let .failed(reason):
                statusText = reason
                responseText = localSummary
            case .cancelled:
                break
            }
        }
    }
}
