import Foundation
import PresenceCore

final class EventStore {
    struct Record: Codable {
        let eventType: String
        let timestamp: String
        let policyId: String?
        let confidenceBand: String?
        let actionTaken: String?
        let schemaVersion: Int

        enum CodingKeys: String, CodingKey {
            case eventType
            case timestamp
            case policyId
            case confidenceBand
            case actionTaken
            case schemaVersion
        }

        init(
            eventType: EventKind,
            timestamp: Date,
            policyId: String?,
            confidenceBand: ConfidenceBand?,
            actionTaken: String?
        ) {
            self.eventType = eventType.rawValue
            self.timestamp = EventStore.timestampFormatter.string(from: timestamp)
            self.policyId = policyId
            self.confidenceBand = confidenceBand?.rawValue
            self.actionTaken = actionTaken
            self.schemaVersion = 1
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            eventType = try container.decode(String.self, forKey: .eventType)
            timestamp = try container.decode(String.self, forKey: .timestamp)
            policyId = try container.decodeIfPresent(String.self, forKey: .policyId)
            confidenceBand = try container.decodeIfPresent(String.self, forKey: .confidenceBand)
            actionTaken = try container.decodeIfPresent(String.self, forKey: .actionTaken)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(eventType, forKey: .eventType)
            try container.encode(timestamp, forKey: .timestamp)
            if let policyId {
                try container.encode(policyId, forKey: .policyId)
            } else {
                try container.encodeNil(forKey: .policyId)
            }
            if let confidenceBand {
                try container.encode(confidenceBand, forKey: .confidenceBand)
            } else {
                try container.encodeNil(forKey: .confidenceBand)
            }
            if let actionTaken {
                try container.encode(actionTaken, forKey: .actionTaken)
            } else {
                try container.encodeNil(forKey: .actionTaken)
            }
            try container.encode(schemaVersion, forKey: .schemaVersion)
        }
    }

    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let lock = NSLock()

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        let directory = directoryURL ?? Self.applicationSupportDirectory(fileManager: fileManager)
        fileURL = directory.appendingPathComponent("events.jsonl")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: Data())
        }
        pruneOnLaunch()
    }

    func append(
        _ eventType: EventKind,
        policyId: String? = nil,
        confidenceBand: ConfidenceBand? = nil,
        actionTaken: String? = nil,
        at date: Date = Date()
    ) {
        let record = Record(
            eventType: eventType,
            timestamp: date,
            policyId: policyId,
            confidenceBand: confidenceBand,
            actionTaken: actionTaken
        )
        guard let encoded = try? encoder.encode(record) else { return }

        lock.lock()
        defer { lock.unlock() }

        var data = (try? Data(contentsOf: fileURL)) ?? Data()
        data.append(encoded)
        data.append(0x0A)
        try? data.write(to: fileURL, options: .atomic)
        trimIfNeeded(data: data)
    }

    func deleteAll() {
        lock.lock()
        defer { lock.unlock() }
        try? Data().write(to: fileURL, options: .atomic)
    }

    private func pruneOnLaunch(now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        let records = loadRecords()
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let retained = records.filter { record in
            guard record.schemaVersion == 1,
                  let date = Self.timestampFormatter.date(from: record.timestamp) else {
                return false
            }
            return date >= cutoff
        }.suffix(1_000)
        rewrite(records: Array(retained))
    }

    private func trimIfNeeded(data: Data) {
        let lineCount = data.reduce(into: 0) { count, byte in
            if byte == 0x0A { count += 1 }
        }
        guard lineCount > 1_000 else { return }
        rewrite(records: Array(loadRecords().suffix(1_000)))
    }

    private func loadRecords() -> [Record] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return [] }
        return data.split(separator: 0x0A).compactMap { line in
            try? decoder.decode(Record.self, from: Data(line))
        }
    }

    private func rewrite(records: [Record]) {
        var data = Data()
        for record in records {
            guard let encoded = try? encoder.encode(record) else { continue }
            data.append(encoded)
            data.append(0x0A)
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        if let fixedHome = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"],
           !fixedHome.isEmpty {
            return URL(fileURLWithPath: fixedHome, isDirectory: true)
                .appendingPathComponent("Library/Application Support/Presence", isDirectory: true)
        }
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Presence", isDirectory: true)
    }
}
