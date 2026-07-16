import Combine
import Foundation
import PresenceCore

final class EventStore: ObservableObject {
    static let shared = EventStore()

    @Published private(set) var records: [EventRecord] = []

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
    private var buffer = EventRecordRingBuffer()

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
        let record = EventRecord(
            eventType: eventType.rawValue,
            timestamp: Self.timestampFormatter.string(from: date),
            policyId: policyId,
            confidenceBand: confidenceBand?.rawValue,
            actionTaken: actionTaken
        )

        lock.lock()
        buffer.append(record)
        let updatedRecords = buffer.records
        rewriteLocked(records: updatedRecords)
        lock.unlock()
        records = updatedRecords
    }

    func recentRecords(limit: Int = EventExplanationPayloadBuilder.maximumRecords) -> [EventRecord] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.recent(limit: limit)
    }

    func deleteAll() {
        lock.lock()
        buffer.deleteAll()
        let updatedRecords = buffer.records
        try? Data().write(to: fileURL, options: .atomic)
        lock.unlock()
        records = updatedRecords
    }

    private func pruneOnLaunch(now: Date = Date()) {
        lock.lock()
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let retained = loadRecordsLocked().filter { record in
            guard record.schemaVersion == 1,
                  let date = Self.timestampFormatter.date(from: record.timestamp) else {
                return false
            }
            return date >= cutoff
        }
        buffer = EventRecordRingBuffer(records: retained)
        records = buffer.records
        rewriteLocked(records: records)
        lock.unlock()
    }

    private func loadRecordsLocked() -> [EventRecord] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return [] }
        return data.split(separator: 0x0A).compactMap { line in
            try? decoder.decode(EventRecord.self, from: Data(line))
        }
    }

    private func rewriteLocked(records: [EventRecord]) {
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
