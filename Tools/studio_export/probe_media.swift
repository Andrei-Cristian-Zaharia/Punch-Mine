import AVFoundation

// Prints {"<path>": {"width", "height", "durationSec"}} for the videos given on the command line.
//   xcrun swift probe_media.swift a.mp4 b.mp4
var result: [String: [String: Double]] = [:]
for path in CommandLine.arguments.dropFirst() {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        let duration = try await asset.load(.duration)
        let track = try await asset.loadTracks(withMediaType: .video).first!
        let size = try await track.load(.naturalSize)
        let t = try await track.load(.preferredTransform)
        let r = size.applying(t)
        result[path] = ["width": abs(r.width), "height": abs(r.height), "durationSec": (duration.seconds * 10).rounded() / 10]
        semaphore.signal()
    }
    semaphore.wait()
}
print(String(data: try! JSONSerialization.data(withJSONObject: result), encoding: .utf8)!)
