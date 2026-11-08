import AVFoundation

// Re-encodes simulator recordings to H.264 at 1080 px wide (aspect kept), 30 fps, about 8 Mbit/s.
//   xcrun swift transcode.swift <in.mp4> <out.mp4>
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.removeItem(at: output)

func run() async throws {
    let asset = AVURLAsset(url: input)
    let track = try await asset.loadTracks(withMediaType: .video).first!
    let natural = try await track.load(.naturalSize)
    let width = 1080
    let height = Int((natural.height * CGFloat(width) / natural.width / 2).rounded()) * 2

    let reader = try AVAssetReader(asset: asset)
    let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ])
    reader.add(readerOutput)

    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 8_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: 30,
        ],
    ])
    writerInput.expectsMediaDataInRealTime = false
    writer.add(writerInput)

    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    // The simulator writes variable frame timing from the first frame on; shift everything to start at zero.
    var first: CMTime?
    while let sample = readerOutput.copyNextSampleBuffer() {
        while !writerInput.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        let t = CMSampleBufferGetPresentationTimeStamp(sample)
        if first == nil { first = t }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMTimeSubtract(t, first!), decodeTimeStamp: .invalid)
        var shifted: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: 1,
                                              sampleTimingArray: &timing, sampleBufferOut: &shifted)
        writerInput.append(shifted!)
    }
    writerInput.markAsFinished()
    await writer.finishWriting()
    if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
}

let done = DispatchSemaphore(value: 0)
Task {
    do { try await run() } catch { print("transcode failed: \(error)"); exit(1) }
    done.signal()
}
done.wait()
