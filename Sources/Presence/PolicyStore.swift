import Combine
import Foundation
import PresenceCore

struct StoredPolicy: Codable, Equatable, Identifiable {
    let id: UUID
    let policy: Policy
}

enum PolicyStoreError: LocalizedError {
    case invalidPolicy(String)
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidPolicy(reason):
            return reason
        case let .persistenceFailed(reason):
            return "Could not save policies: \(reason)"
        }
    }
}

final class PolicyStore: ObservableObject {
    static let shared = PolicyStore()

    @Published private(set) var policies: [StoredPolicy] = []
    @Published private(set) var activePolicyID: UUID?

    var onActivePolicyChanged: ((Policy?) -> Void)?

    var activePolicy: Policy? {
        guard let activePolicyID else { return nil }
        return policies.first(where: { $0.id == activePolicyID })?.policy
    }

    var policyNamesByID: [String: String] {
        Dictionary(uniqueKeysWithValues: policies.map { ($0.id.uuidString, $0.policy.name) })
    }

    private static let activePolicyDefaultsKey = "activePolicyID"
    private let fileURL: URL
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        let directory = directoryURL ?? EventStore.applicationSupportDirectory(fileManager: fileManager)
        fileURL = directory.appendingPathComponent("policies.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    @discardableResult
    func approveAndActivate(_ policy: Policy) throws -> StoredPolicy {
        let validatedPolicy = try validate(policy)
        let stored = StoredPolicy(id: UUID(), policy: validatedPolicy)
        let updatedPolicies = policies + [stored]
        try persist(updatedPolicies)
        policies = updatedPolicies
        setActivePolicyID(stored.id)
        return stored
    }

    func activate(_ id: UUID) {
        guard policies.contains(where: { $0.id == id }) else { return }
        setActivePolicyID(id)
    }

    func deactivate() {
        setActivePolicyID(nil)
    }

    func delete(_ id: UUID) throws {
        let updatedPolicies = policies.filter { $0.id != id }
        try persist(updatedPolicies)
        policies = updatedPolicies
        if activePolicyID == id {
            setActivePolicyID(nil)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            clearInvalidActivePolicyID()
            return
        }

        guard let rawEntries = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            rejectStoredFile()
            return
        }

        var validated: [StoredPolicy] = []
        for rawEntry in rawEntries {
            guard let entry = rawEntry as? [String: Any],
                  Set(entry.keys) == Set(["id", "policy"]),
                  let idValue = entry["id"] as? String,
                  let id = UUID(uuidString: idValue),
                  let rawPolicy = entry["policy"] as? [String: Any],
                  let policyData = try? JSONSerialization.data(withJSONObject: rawPolicy),
                  let policyJSON = String(data: policyData, encoding: .utf8) else {
                rejectStoredFile()
                return
            }
            switch PolicyValidator.validate(policyJSON) {
            case let .success(policy):
                validated.append(StoredPolicy(id: id, policy: policy))
            case .failure:
                rejectStoredFile()
                return
            }
        }
        policies = validated

        if let value = defaults.string(forKey: Self.activePolicyDefaultsKey),
           let id = UUID(uuidString: value),
           policies.contains(where: { $0.id == id }) {
            activePolicyID = id
        } else {
            clearInvalidActivePolicyID()
        }
    }

    private func validate(_ policy: Policy) throws -> Policy {
        let data: Data
        do {
            data = try encoder.encode(policy)
        } catch {
            throw PolicyStoreError.invalidPolicy("Policy could not be encoded for validation.")
        }
        guard let json = String(data: data, encoding: .utf8) else {
            throw PolicyStoreError.invalidPolicy("Policy could not be encoded as UTF-8 JSON.")
        }
        switch PolicyValidator.validate(json) {
        case let .success(validatedPolicy):
            return validatedPolicy
        case let .failure(error):
            throw PolicyStoreError.invalidPolicy(error.reason)
        }
    }

    private func persist(_ policies: [StoredPolicy]) throws {
        do {
            let data = try encoder.encode(policies)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PolicyStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    private func setActivePolicyID(_ id: UUID?) {
        activePolicyID = id
        if let id {
            defaults.set(id.uuidString, forKey: Self.activePolicyDefaultsKey)
        } else {
            defaults.removeObject(forKey: Self.activePolicyDefaultsKey)
        }
        onActivePolicyChanged?(activePolicy)
    }

    private func clearInvalidActivePolicyID() {
        activePolicyID = nil
        defaults.removeObject(forKey: Self.activePolicyDefaultsKey)
    }

    private func rejectStoredFile() {
        policies = []
        clearInvalidActivePolicyID()
    }
}
