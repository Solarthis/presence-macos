import Foundation

enum SafeModeReason {
    case emergencyDisabled
    case repeatedCrashes

    var notice: String? {
        switch self {
        case .emergencyDisabled:
            return nil
        case .repeatedCrashes:
            return "Presence started in safe mode after repeated crashes"
        }
    }
}

struct SafetyLaunchDecision {
    let safeModeReason: SafeModeReason?

    var isSafeMode: Bool { safeModeReason != nil }
}

enum SafetyGates {
    private static let markerName = "launch.marker"
    private static let historyName = "unclean-exits.json"
    private static let disableFileName = ".presence-disable"
    private static let crashWindow: TimeInterval = 5 * 60

    static func beginLaunch(
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> SafetyLaunchDecision {
        let emergencyDisabled = defaults.bool(forKey: "emergencyDisabled")
            || fileManager.fileExists(
                atPath: fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent(disableFileName).path
            )

        let directory = EventStore.applicationSupportDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let markerURL = directory.appendingPathComponent(markerName)
        let historyURL = directory.appendingPathComponent(historyName)

        var uncleanTimestamps = loadHistory(from: historyURL)
        if let markerData = try? Data(contentsOf: markerURL),
           let markerText = String(data: markerData, encoding: .utf8),
           let markerTimestamp = TimeInterval(markerText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            uncleanTimestamps.append(markerTimestamp)
        }
        uncleanTimestamps = Array(uncleanTimestamps.suffix(3))
        if let data = try? JSONEncoder().encode(uncleanTimestamps) {
            try? data.write(to: historyURL, options: .atomic)
        }
        try? Data(String(now.timeIntervalSince1970).utf8).write(to: markerURL, options: .atomic)

        let recentUncleanCount = uncleanTimestamps.filter {
            now.timeIntervalSince1970 - $0 <= crashWindow && now.timeIntervalSince1970 >= $0
        }.count

        if emergencyDisabled {
            return SafetyLaunchDecision(safeModeReason: .emergencyDisabled)
        }
        if recentUncleanCount >= 3 {
            return SafetyLaunchDecision(safeModeReason: .repeatedCrashes)
        }
        return SafetyLaunchDecision(safeModeReason: nil)
    }

    static func markCleanTermination(fileManager: FileManager = .default) {
        let markerURL = EventStore.applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent(markerName)
        try? fileManager.removeItem(at: markerURL)
    }

    private static func loadHistory(from url: URL) -> [TimeInterval] {
        guard let data = try? Data(contentsOf: url),
              let timestamps = try? JSONDecoder().decode([TimeInterval].self, from: data) else {
            return []
        }
        return timestamps
    }
}
