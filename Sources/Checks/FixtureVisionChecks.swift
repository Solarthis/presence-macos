import AppKit
import Foundation
import Vision

private struct FixtureSidecar: Decodable {
    let faces: Int
    let humans: Int
    let band: String
}

func runFixtureVisionChecks() {
    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("fixtures", isDirectory: true)
    let fixtures = [
        (name: "empty-room", passes: { (count: Int) in count == 0 }),
        (name: "one-person", passes: { (count: Int) in count == 1 }),
        (name: "two-people", passes: { (count: Int) in count >= 2 }),
    ]

    let allFixturesExist = fixtures.allSatisfy { fixture in
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(fixture.name).appendingPathExtension("png").path
        ) && FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(fixture.name).appendingPathExtension("json").path
        )
    }
    guard allFixturesExist else {
        print("SKIP fixture-vision (no fixtures captured yet)")
        return
    }

    for fixture in fixtures {
        let imageURL = directory.appendingPathComponent(fixture.name).appendingPathExtension("png")
        let sidecarURL = directory.appendingPathComponent(fixture.name).appendingPathExtension("json")
        let sidecarValid = (try? Data(contentsOf: sidecarURL))
            .flatMap { try? JSONDecoder().decode(FixtureSidecar.self, from: $0) }
            .map { $0.faces >= 0 && $0.humans >= 0 && ["low", "medium", "high"].contains($0.band) }
            ?? false
        check(sidecarValid, "fixture-vision-\(fixture.name)-sidecar-valid")

        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            check(false, "fixture-vision-\(fixture.name)-person-count")
            continue
        }

        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([faceRequest, humanRequest])
            let personCount = max(faceRequest.results?.count ?? 0, humanRequest.results?.count ?? 0)
            check(
                fixture.passes(personCount),
                "fixture-vision-\(fixture.name)-person-count"
            )
        } catch {
            check(false, "fixture-vision-\(fixture.name)-person-count")
        }
    }
}
