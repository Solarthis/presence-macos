import Foundation
import Vision

enum PerceptionConstants {
    static let maximumFramesPerSecond = 5.0 // Five frames per second is responsive without wasting camera work.
    static let minimumFrameInterval = 1.0 / maximumFramesPerSecond // Dropping earlier frames prevents queue buildup.
    static let lowConfidenceUpperBound: VNConfidence = 0.5 // Below 0.5 is too uncertain for absence decisions.
    static let mediumConfidenceUpperBound: VNConfidence = 0.8 // Below 0.8 remains a medium-confidence observation.
    static let cameraQueueLabel = "com.solarthis.presence.camera" // One serial queue keeps capture and Vision ordered.
}
