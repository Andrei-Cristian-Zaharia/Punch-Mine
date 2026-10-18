import AVFoundation

/// Plays the synthesized cues and the music loop. Sounds render in the background at launch;
/// anything played before they are ready is skipped.
final class SoundEngine {
    typealias Cue = Synth.Cue

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.rate, channels: 1)!
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private let musicNode = AVAudioPlayerNode()
    private var buffers: [Cue: [AVAudioPCMBuffer]] = [:]
    /// Zone id → its loop.
    private var musicBuffers: [String: AVAudioPCMBuffer] = [:]
    private var playingMusic: String?
    /// The zone whose loop should play.
    var musicZone = "quarry" { didSet { if musicZone != oldValue { switchMusic() } } }
    private var lastPlayed: [Cue: TimeInterval] = [:]
    private var configObserver: NSObjectProtocol?

    var effectsOn = true
    /// 0…1, from Settings.
    var effectsVolume: Float = 1
    var musicVolume: Float = 1 { didSet { musicNode.volume = Self.musicLevel * musicVolume; updateMusic() } }
    private static let musicLevel: Float = 0.55
    var musicOn = true { didSet { updateMusic() } }
    /// Music pauses while an ad plays or the app is in the background.
    var musicSuspended = false { didSet { updateMusic() } }

    init() {
        for _ in 0..<10 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            voices.append(node)
        }
        engine.attach(musicNode)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)
        musicNode.volume = Self.musicLevel
        // Headroom for several cues at once (punch + crunch + coin).
        engine.mainMixerNode.outputVolume = 0.7

        #if os(iOS)
        // Ambient: mixes with the player's own music and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        #endif
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restart() }
        }
        load()
    }

    private func load() {
        Task.detached(priority: .userInitiated) {
            var rendered: [Cue: [[Float]]] = [:]
            for (n, cue) in Cue.allCases.enumerated() {
                rendered[cue] = Synth.variants(cue).enumerated().map { v, pitch in
                    Synth.render(cue, pitch: pitch, seed: UInt64(n * 31 + v))
                }
            }
            // One loop per zone.
            let styles: [(String, Synth.MusicStyle)] = [("quarry", .quarry), ("caverns", .caverns), ("magma", .magma), ("ruins", .ruins)]
            var music: [String: [Float]] = [:]
            for (zone, style) in styles { music[zone] = Synth.musicLoop(style) }
            await MainActor.run { [rendered, music] in
                self.buffers = rendered.mapValues { $0.compactMap(self.buffer) }
                self.musicBuffers = music.compactMapValues(self.buffer)
                self.updateMusic()
            }
        }
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = b.floatChannelData?[0] else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return b
    }

    /// Starts the engine if it isn't running. Returns false if audio is unavailable.
    @discardableResult
    func ensureRunning() -> Bool {
        if engine.isRunning { return true }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        do { try engine.start() } catch { return false }
        return true
    }

    private func restart() {
        voices.forEach { $0.stop() }
        musicNode.stop()
        playingMusic = nil
        if !engine.isRunning { ensureRunning() }
        updateMusic()
    }

    /// Minimum seconds between two plays of the same cue, so hold-punching and splash breaks don't pile up.
    private func spacing(_ cue: Cue) -> TimeInterval {
        switch cue {
        case .punch, .crit, .crunch, .crunchHard, .crunchCrystal: 0.035
        case .coin: 0.05
        case .minerTick: 0.09
        case .deflect, .chain, .zap: 0.08
        default: 0.15
        }
    }

    func play(_ cue: Cue, volume: Float = 1) {
        guard effectsOn, effectsVolume > 0, let variants = buffers[cue], let buffer = variants.randomElement() else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlayed[cue], now - last < spacing(cue) { return }
        lastPlayed[cue] = now
        guard ensureRunning() else { return }
        let node = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        node.volume = volume * effectsVolume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    private func updateMusic() {
        let wanted = musicOn && musicVolume > 0 && !musicSuspended && !otherAudioPlaying
        if wanted, let musicBuffer = musicBuffers[musicZone] {
            guard !musicNode.isPlaying, ensureRunning() else { return }
            musicNode.scheduleBuffer(musicBuffer, at: nil, options: .loops)
            musicNode.play()
            playingMusic = musicZone
        } else if musicNode.isPlaying {
            musicNode.stop()
            playingMusic = nil
        }
    }

    private func switchMusic() {
        guard musicNode.isPlaying, playingMusic != musicZone else { return updateMusic() }
        musicNode.stop()
        playingMusic = nil
        updateMusic()
    }

    /// The player's own music wins over ours.
    private var otherAudioPlaying: Bool {
        #if os(iOS)
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        #else
        false
        #endif
    }

    func appBecameActive() {
        ensureRunning()
        musicSuspended = false
    }

    func appWentInactive() {
        musicSuspended = true
    }
}
