import Foundation
import PresenceCore

protocol PresenceSource: AnyObject {
    func start(emit: @escaping (PresenceEvent) -> Void)
    func stop()
}

final class ScriptedSource: PresenceSource {
    enum Scenario: String, CaseIterable {
        case walkAway
        case leanAway
        case secondViewer
        case cameraLoss
    }

    private enum Step {
        case detection(personCount: Int, band: ConfidenceBand)
        case cameraUnavailable

        func event(at time: Double) -> PresenceEvent {
            switch self {
            case let .detection(personCount, band):
                return .detection(t: time, personCount: personCount, band: band)
            case .cameraUnavailable:
                return .cameraUnavailable(t: time)
            }
        }
    }

    let scenario: Scenario
    private let onFinished: (() -> Void)?
    private var workItems: [DispatchWorkItem] = []

    init(scenario: Scenario, onFinished: (() -> Void)? = nil) {
        self.scenario = scenario
        self.onFinished = onFinished
    }

    func start(emit: @escaping (PresenceEvent) -> Void) {
        stop()
        for (delay, step) in steps(for: scenario) {
            let item = DispatchWorkItem {
                emit(step.event(at: ProcessInfo.processInfo.systemUptime))
            }
            workItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
        if let onFinished {
            let item = DispatchWorkItem(block: onFinished)
            workItems.append(item)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + completionDelay(for: scenario),
                execute: item
            )
        }
    }

    func stop() {
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
    }

    private func steps(for scenario: Scenario) -> [(Double, Step)] {
        // The final frame is slightly after five seconds so timer jitter cannot
        // make the core's three-second arming interval one millisecond short.
        let presentPrelude = [0.0, 1.0, 2.0, 3.0, 4.0, 5.1].map {
            ($0, Step.detection(personCount: 1, band: .high))
        }

        switch scenario {
        case .walkAway:
            return presentPrelude + [
                (5.3, .detection(personCount: 0, band: .high)),
            ]

        case .leanAway:
            return presentPrelude + [
                (5.3, .detection(personCount: 0, band: .high)),
                (8.3, .detection(personCount: 1, band: .high)),
                (9.3, .detection(personCount: 1, band: .high)),
            ]

        case .secondViewer:
            return presentPrelude + [
                (5.3, .detection(personCount: 2, band: .high)),
                (10.5, .detection(personCount: 2, band: .high)),
            ]

        case .cameraLoss:
            return presentPrelude + [
                (5.3, .cameraUnavailable),
            ]
        }
    }

    private func completionDelay(for scenario: Scenario) -> Double {
        let lastStep = steps(for: scenario).map(\.0).max() ?? 0
        switch scenario {
        case .walkAway:
            return lastStep + MachineConfig.scriptedDemo.graceSeconds + 1
        case .leanAway, .secondViewer, .cameraLoss:
            return lastStep + 1
        }
    }
}
