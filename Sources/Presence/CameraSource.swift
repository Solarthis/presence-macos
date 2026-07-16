import AVFoundation
import CoreImage
import Foundation
import ImageIO
import PresenceCore
import UniformTypeIdentifiers
import Vision

enum CameraAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case unavailable
}

final class CameraSource: NSObject, PresenceSource {
    struct FixtureSidecar: Codable {
        let faces: Int
        let humans: Int
        let band: String
    }

    static var authorizationState: CameraAuthorizationState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    static func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let cameraQueue = DispatchQueue(label: PerceptionConstants.cameraQueueLabel)
    private let fixtureCaptureEnabled: Bool
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var emit: ((PresenceEvent) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var selectedDevice: AVCaptureDevice?
    private var isConfigured = false
    private var isStarted = false
    private var lastProcessedFrameTime: Double?

#if DEBUG
    private var fixtureImage: CGImage?
    private var fixtureSidecar: FixtureSidecar?
#endif

    init(fixtureCaptureEnabled: Bool) {
#if DEBUG
        self.fixtureCaptureEnabled = fixtureCaptureEnabled
#else
        self.fixtureCaptureEnabled = false
#endif
        super.init()
    }

    func start(emit: @escaping (PresenceEvent) -> Void) {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            self.emit = emit
            self.isStarted = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    self?.cameraQueue.async {
                        guard let self, self.isStarted else { return }
                        if granted {
                            self.configureAndStart()
                        } else {
                            self.emitCameraUnavailable()
                        }
                    }
                }
            case .denied, .restricted:
                self.emitCameraUnavailable()
            @unknown default:
                self.emitCameraUnavailable()
            }
        }
    }

    func stop() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            self.isStarted = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.removeObservers()
            self.emit = nil
            self.lastProcessedFrameTime = nil
#if DEBUG
            self.fixtureImage = nil
            self.fixtureSidecar = nil
#endif
        }
    }

    func captureFixtureFrame(completion: @escaping (Result<URL, Error>) -> Void) {
#if DEBUG
        cameraQueue.async { [weak self] in
            guard let self, self.fixtureCaptureEnabled,
                  let image = self.fixtureImage,
                  let sidecar = self.fixtureSidecar else {
                completion(.failure(CameraSourceError.fixtureCaptureUnavailable))
                return
            }

            do {
                let workingDirectory = URL(
                    fileURLWithPath: FileManager.default.currentDirectoryPath,
                    isDirectory: true
                )
                guard FileManager.default.fileExists(
                    atPath: workingDirectory.appendingPathComponent("Package.swift").path
                ) else {
                    throw CameraSourceError.fixtureCaptureUnavailable
                }
                let directory = workingDirectory
                    .appendingPathComponent("fixtures", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                let stem = "fixture-\(UUID().uuidString.lowercased())"
                let imageURL = directory.appendingPathComponent(stem).appendingPathExtension("png")
                let sidecarURL = directory.appendingPathComponent(stem).appendingPathExtension("json")

                guard let destination = CGImageDestinationCreateWithURL(
                    imageURL as CFURL,
                    UTType.png.identifier as CFString,
                    1,
                    nil
                ) else {
                    throw CameraSourceError.fixtureEncodingFailed
                }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else {
                    throw CameraSourceError.fixtureEncodingFailed
                }

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(sidecar).write(to: sidecarURL, options: .atomic)
                completion(.success(imageURL))
            } catch {
                completion(.failure(error))
            }
        }
#else
        completion(.failure(CameraSourceError.fixtureCaptureUnavailable))
#endif
    }

    private func configureAndStart() {
        guard isStarted else { return }
        if !isConfigured {
            guard configureSession() else {
                emitCameraUnavailable()
                return
            }
        }
        installObservers()
        guard !session.isRunning else { return }
        session.startRunning()
        emit?(.cameraRestored(t: ProcessInfo.processInfo.systemUptime))
    }

    private func configureSession() -> Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first else { return false }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            session.sessionPreset = .vga640x480
            guard session.canAddInput(input), session.canAddOutput(videoOutput) else {
                return false
            }
            session.addInput(input)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
            session.addOutput(videoOutput)
            selectedDevice = device
            isConfigured = true
            return true
        } catch {
            return false
        }
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.cameraQueue.async { self?.emitCameraUnavailable() }
        })
        observers.append(center.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.cameraQueue.async {
                guard let self, self.isStarted else { return }
                self.emit?(.cameraRestored(t: ProcessInfo.processInfo.systemUptime))
            }
        })
        observers.append(center.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: session,
            queue: nil
        ) { [weak self] _ in
            self?.cameraQueue.async { self?.emitCameraUnavailable() }
        })
        if let selectedDevice {
            observers.append(center.addObserver(
                forName: .AVCaptureDeviceWasDisconnected,
                object: selectedDevice,
                queue: nil
            ) { [weak self] _ in
                self?.cameraQueue.async { self?.emitCameraUnavailable() }
            })
        }
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func emitCameraUnavailable() {
        guard isStarted else { return }
        emit?(.cameraUnavailable(t: ProcessInfo.processInfo.systemUptime))
    }

    private func process(_ sampleBuffer: CMSampleBuffer) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameTime = presentationTime.isValid
            ? CMTimeGetSeconds(presentationTime)
            : ProcessInfo.processInfo.systemUptime
        if let lastProcessedFrameTime,
           frameTime - lastProcessedFrameTime < PerceptionConstants.minimumFrameInterval {
            return
        }
        lastProcessedFrameTime = frameTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            emitCameraUnavailable()
            return
        }

        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([faceRequest, humanRequest])
            let faces = faceRequest.results ?? []
            let humans = humanRequest.results ?? []
            let personCount = max(faces.count, humans.count)
            let confidences = faces.map(\.confidence) + humans.map(\.confidence)
            // A successfully processed empty frame is a confident zero-person observation.
            let maximumConfidence = confidences.max() ?? 1
            let band = confidenceBand(for: maximumConfidence)

#if DEBUG
            if fixtureCaptureEnabled,
               let image = imageContext.createCGImage(
                   CIImage(cvPixelBuffer: pixelBuffer),
                   from: CGRect(
                       origin: .zero,
                       size: CGSize(
                           width: CVPixelBufferGetWidth(pixelBuffer),
                           height: CVPixelBufferGetHeight(pixelBuffer)
                       )
                   )
               ) {
                fixtureImage = image
                fixtureSidecar = FixtureSidecar(
                    faces: faces.count,
                    humans: humans.count,
                    band: band.rawValue
                )
            }
#endif

            emit?(.detection(
                t: ProcessInfo.processInfo.systemUptime,
                personCount: personCount,
                band: band
            ))
        } catch {
            emitCameraUnavailable()
        }
    }

    private func confidenceBand(for confidence: VNConfidence) -> ConfidenceBand {
        if confidence < PerceptionConstants.lowConfidenceUpperBound {
            return .low
        }
        if confidence < PerceptionConstants.mediumConfidenceUpperBound {
            return .medium
        }
        return .high
    }
}

extension CameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isStarted else { return }
        process(sampleBuffer)
    }
}

private enum CameraSourceError: LocalizedError {
    case fixtureCaptureUnavailable
    case fixtureEncodingFailed

    var errorDescription: String? {
        switch self {
        case .fixtureCaptureUnavailable:
            return "Fixture capture is unavailable or no processed frame is ready."
        case .fixtureEncodingFailed:
            return "The fixture PNG could not be encoded."
        }
    }
}
