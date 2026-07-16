import Foundation

public struct EventRecord: Codable, Equatable {
    public let eventType: String
    public let timestamp: String
    public let policyId: String?
    public let confidenceBand: String?
    public let actionTaken: String?
    public let schemaVersion: Int

    public init(
        eventType: String,
        timestamp: String,
        policyId: String?,
        confidenceBand: String?,
        actionTaken: String?,
        schemaVersion: Int = 1
    ) {
        self.eventType = eventType
        self.timestamp = timestamp
        self.policyId = policyId
        self.confidenceBand = confidenceBand
        self.actionTaken = actionTaken
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case eventType
        case timestamp
        case policyId
        case confidenceBand
        case actionTaken
        case schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(String.self, forKey: .eventType)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        policyId = try container.decodeIfPresent(String.self, forKey: .policyId)
        confidenceBand = try container.decodeIfPresent(String.self, forKey: .confidenceBand)
        actionTaken = try container.decodeIfPresent(String.self, forKey: .actionTaken)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(policyId, forKey: .policyId)
        try container.encode(confidenceBand, forKey: .confidenceBand)
        try container.encode(actionTaken, forKey: .actionTaken)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }
}

public struct EventRecordRingBuffer: Equatable {
    public private(set) var records: [EventRecord]
    public let capacity: Int

    public init(records: [EventRecord] = [], capacity: Int = 1_000) {
        self.capacity = max(0, capacity)
        self.records = Array(records.suffix(self.capacity))
    }

    public mutating func append(_ record: EventRecord) {
        guard capacity > 0 else { return }
        records.append(record)
        if records.count > capacity {
            records.removeFirst(records.count - capacity)
        }
    }

    public mutating func deleteAll() {
        records.removeAll(keepingCapacity: false)
    }

    public func recent(limit: Int) -> [EventRecord] {
        Array(records.suffix(max(0, limit)))
    }
}

public enum EventExplanationPayloadBuilder {
    public static let maximumRecords = 20

    public static func makePayload(
        records: [EventRecord],
        policyNamesByID: [String: String]
    ) -> String {
        let sanitized = records
            .filter { $0.schemaVersion == 1 }
            .suffix(maximumRecords)
            .map { record in
                SanitizedRecord(
                    eventType: record.eventType,
                    timestamp: record.timestamp,
                    policyName: record.policyId.flatMap { policyNamesByID[$0] },
                    confidenceBand: record.confidenceBand,
                    actionTaken: record.actionTaken,
                    schemaVersion: record.schemaVersion
                )
            }
        let payload = Payload(records: Array(sanitized))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return #"{"records":[]}"# }
        return String(data: data, encoding: .utf8) ?? #"{"records":[]}"#
    }

    public static func localSummary(records: [EventRecord]) -> String {
        let recent = records.filter { $0.schemaVersion == 1 }.suffix(maximumRecords)
        guard let first = recent.first, let last = recent.last else {
            return "No recent events. Counts by event type: none. First timestamp: none. Last timestamp: none."
        }

        var counts: [String: Int] = [:]
        for record in recent {
            counts[record.eventType, default: 0] += 1
        }
        let countText = counts.keys.sorted().map { key in
            "\(key)=\(counts[key] ?? 0)"
        }.joined(separator: ", ")
        return "Counts by event type: \(countText). First timestamp: \(first.timestamp). Last timestamp: \(last.timestamp)."
    }

    private struct Payload: Encodable {
        let records: [SanitizedRecord]
    }

    private struct SanitizedRecord: Encodable {
        let eventType: String
        let timestamp: String
        let policyName: String?
        let confidenceBand: String?
        let actionTaken: String?
        let schemaVersion: Int
    }
}
