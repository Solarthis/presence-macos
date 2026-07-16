import Foundation
import PresenceCore

func runEventRecordChecks() {
    ringBufferChecks()
    sanitizedPayloadChecks()
    localSummaryChecks()
}

private func ringBufferChecks() {
    var buffer = EventRecordRingBuffer(capacity: 1_000)
    for index in 0..<1_002 {
        buffer.append(makeRecord(index: index))
    }
    check(buffer.records.count == 1_000, "event-ring-buffer-caps-at-one-thousand")
    check(buffer.records.first?.timestamp == "time-2", "event-ring-buffer-keeps-most-recent")

    buffer.deleteAll()
    check(buffer.records.isEmpty, "event-delete-all-leaves-store-empty")
}

private func sanitizedPayloadChecks() {
    let hostileJSON = #"{"eventType":"presenceLost","timestamp":"hostile-time","policyId":"policy-1","confidenceBand":"high","actionTaken":"presence-lost","schemaVersion":1,"secretBundleId":"com.example.Secret","rawFileText":"do not leak"}"#
    guard let hostileRecord = try? JSONDecoder().decode(
        EventRecord.self,
        from: Data(hostileJSON.utf8)
    ) else {
        check(false, "event-payload-hostile-record-decodes-to-closed-struct")
        return
    }
    check(true, "event-payload-hostile-record-decodes-to-closed-struct")

    let records = (0..<21).map { makeRecord(index: $0) } + [hostileRecord]
    let payload = EventExplanationPayloadBuilder.makePayload(
        records: records,
        policyNamesByID: ["policy-1": "Office policy"]
    )
    guard let data = payload.data(using: String.Encoding.utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let payloadRecords = root["records"] as? [[String: Any]] else {
        check(false, "event-payload-is-json")
        return
    }
    check(true, "event-payload-is-json")
    check(Set(root.keys) == ["records"], "event-payload-root-is-allow-listed")
    check(payloadRecords.count == 20, "event-payload-limits-to-last-twenty")

    let allowedFields: Set<String> = [
        "eventType",
        "timestamp",
        "policyName",
        "confidenceBand",
        "actionTaken",
        "schemaVersion",
    ]
    check(
        payloadRecords.allSatisfy { Set($0.keys).isSubset(of: allowedFields) },
        "event-payload-record-fields-are-allow-listed"
    )
    check(!payload.contains("secretBundleId"), "event-payload-drops-hostile-extra-field")
    check(!payload.contains("rawFileText"), "event-payload-never-includes-raw-file-field")
    check(!payload.contains("policy-1"), "event-payload-removes-policy-id")
    check(payload.contains("Office policy"), "event-payload-substitutes-policy-name")
}

private func localSummaryChecks() {
    let records = [
        makeRecord(index: 1, eventType: "presenceLost"),
        makeRecord(index: 2, eventType: "curtainRaised"),
        makeRecord(index: 3, eventType: "presenceLost"),
    ]
    let summary = EventExplanationPayloadBuilder.localSummary(records: records)
    check(summary.contains("curtainRaised=1"), "event-local-summary-counts-curtain-events")
    check(summary.contains("presenceLost=2"), "event-local-summary-counts-presence-events")
    check(summary.contains("First timestamp: time-1"), "event-local-summary-has-first-timestamp")
    check(summary.contains("Last timestamp: time-3"), "event-local-summary-has-last-timestamp")
}

private func makeRecord(index: Int, eventType: String = "presenceLost") -> EventRecord {
    EventRecord(
        eventType: eventType,
        timestamp: "time-\(index)",
        policyId: "policy-1",
        confidenceBand: "high",
        actionTaken: "presence-lost"
    )
}
