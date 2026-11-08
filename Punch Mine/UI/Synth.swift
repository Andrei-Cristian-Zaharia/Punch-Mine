import Foundation

/// Offline synthesizer for every Punch Mine sound. Each cue is rendered once at launch into mono samples,
/// so the app ships no audio files. Everything here is pure math and runs off the main thread.
nonisolated enum Synth {
    static let rate = 44_100.0

    enum Cue: String, CaseIterable, Sendable {
        case punch, crit, deflect, titan, minerTick
        case crunch, crunchHard, crunchCrystal
        case coin, lucky, treasure, chain, zap, boom, erupt
        case clear, fever, heart, purchase
        case chestCommon, chestRare, chestEpic, chestLegendary
    }

    /// Pitch variants per cue, so repeated hits don't sound like a machine gun.
    static func variants(_ cue: Cue) -> [Double] {
        switch cue {
        case .punch, .crit, .minerTick, .crunch, .crunchHard, .crunchCrystal, .coin: [0.92, 1.0, 1.08]
        case .deflect, .chain, .zap: [0.95, 1.05]
        default: [1.0]
        }
    }

    static func render(_ cue: Cue, pitch p: Double, seed: UInt64) -> [Float] {
        var rng = Noise(seed: seed)
        var out: [Float]
        switch cue {
        case .punch:
            out = thump(0.11, from: 170 * p, to: 55 * p, decay: 32, gain: 0.9)
            mix(&out, click(0.012, rng: &rng, cutoff: 0.35, gain: 0.45))
        case .crit:
            out = thump(0.16, from: 260 * p, to: 70 * p, decay: 24, gain: 1.0)
            mix(&out, click(0.03, rng: &rng, cutoff: 0.8, gain: 0.5))
            mix(&out, bell([1_400 * p, 2_100 * p], 0.12, decay: 30, gain: 0.12))
        case .deflect:
            out = bell([1_850 * p, 2_770 * p, 4_120 * p], 0.18, decay: 26, gain: 0.22)
            mix(&out, click(0.008, rng: &rng, cutoff: 0.9, gain: 0.2))
        case .titan:
            out = thump(0.5, from: 140, to: 32, decay: 7, gain: 1.0)
            mix(&out, rumble(0.55, rng: &rng, cutoff: 0.05, decay: 6, gain: 0.7))
            mix(&out, click(0.04, rng: &rng, cutoff: 0.6, gain: 0.5))
        case .minerTick:
            out = click(0.02, rng: &rng, cutoff: 0.5, gain: 0.35)
            mix(&out, bell([950 * p, 1_610 * p], 0.05, decay: 70, gain: 0.12))
        case .crunch:
            out = crumble(0.26, rng: &rng, cutoff: 0.12 * p, gain: 0.85)
            mix(&out, thump(0.12, from: 120 * p, to: 50 * p, decay: 28, gain: 0.6))
        case .crunchHard:
            out = crumble(0.3, rng: &rng, cutoff: 0.3 * p, gain: 0.75)
            mix(&out, thump(0.12, from: 150 * p, to: 60 * p, decay: 26, gain: 0.5))
            mix(&out, bell([1_150 * p, 1_730 * p], 0.15, decay: 30, gain: 0.08))
        case .crunchCrystal:
            out = crumble(0.22, rng: &rng, cutoff: 0.45 * p, gain: 0.5)
            mix(&out, bell([2_093 * p, 3_136 * p, 4_186 * p], 0.35, decay: 12, gain: 0.16))
        case .coin:
            out = notes([(988 * p, 0, 0.09), (1_319 * p, 0.055, 0.22)], wave: .chip, decay: 16, gain: 0.16)
        case .lucky:
            out = notes([(1_319, 0, 0.08), (1_568, 0.05, 0.08), (2_093, 0.1, 0.3)], wave: .chip, decay: 12, gain: 0.17)
        case .treasure:
            out = notes([(1_047, 0, 0.12), (1_319, 0.07, 0.12), (1_568, 0.14, 0.12), (2_093, 0.21, 0.45)],
                        wave: .chip, decay: 7, gain: 0.17)
            mix(&out, sparkle(0.6, rng: &rng, gain: 0.05))
        case .chain:
            out = notes([(1_568 * p, 0, 0.2), (2_349 * p, 0.04, 0.3)], wave: .sine, decay: 11, gain: 0.2)
        case .zap:
            out = zap(0.22, rng: &rng, pitch: p)
        case .boom:
            out = thump(0.7, from: 110, to: 28, decay: 5, gain: 1.0)
            mix(&out, rumble(0.9, rng: &rng, cutoff: 0.08, decay: 4, gain: 0.9))
            mix(&out, click(0.05, rng: &rng, cutoff: 0.7, gain: 0.6))
        case .erupt:
            out = rumble(0.8, rng: &rng, cutoff: 0.035, decay: 3.5, gain: 0.9)
            mix(&out, bubbles(0.8, rng: &rng, gain: 0.12))
        case .clear:
            out = notes([(784, 0, 0.1), (1_047, 0.08, 0.1), (1_319, 0.16, 0.42)], wave: .triangle, decay: 6, gain: 0.2)
            mix(&out, notes([(523, 0.16, 0.42), (659, 0.16, 0.42)], wave: .triangle, decay: 6, gain: 0.1))
        case .fever:
            out = riser(0.42, from: 220, to: 880, gain: 0.12)
            mix(&out, notes([(440, 0.4, 0.5), (554, 0.4, 0.5), (659, 0.4, 0.5), (880, 0.4, 0.5)],
                            wave: .chip, decay: 5, gain: 0.08))
        case .heart:
            out = thump(0.8, from: 100, to: 30, decay: 4, gain: 1.0)
            mix(&out, rumble(0.9, rng: &rng, cutoff: 0.06, decay: 3.5, gain: 0.7))
            mix(&out, notes([(523, 0.45, 0.25), (659, 0.6, 0.25), (784, 0.75, 0.25), (1_047, 0.9, 0.9)],
                            wave: .triangle, decay: 3, gain: 0.2))
            mix(&out, sparkle(1.6, rng: &rng, gain: 0.05))
        case .purchase:
            out = click(0.015, rng: &rng, cutoff: 0.6, gain: 0.3)
            mix(&out, notes([(1_175, 0.01, 0.07), (1_760, 0.06, 0.16)], wave: .chip, decay: 20, gain: 0.13))
        case .chestCommon:
            out = chestOpen(rng: &rng, chime: [784, 988, 1_175], gain: 0.16)
        case .chestRare:
            out = chestOpen(rng: &rng, chime: [880, 1_109, 1_319, 1_760], gain: 0.17)
        case .chestEpic:
            out = chestOpen(rng: &rng, chime: [740, 932, 1_109, 1_480, 1_865], gain: 0.18)
            mix(&out, sparkle(0.9, rng: &rng, gain: 0.05))
        case .chestLegendary:
            out = chestOpen(rng: &rng, chime: [784, 988, 1_175, 1_568, 1_976, 2_349], gain: 0.18)
            mix(&out, notes([(392, 0.5, 1.0), (494, 0.5, 1.0), (587, 0.5, 1.0)], wave: .triangle, decay: 2, gain: 0.09))
            mix(&out, sparkle(1.6, rng: &rng, gain: 0.07))
        }
        limit(&out)
        fadeTail(&out)
        return out
    }

    /// Soft limiter: quiet sounds pass almost unchanged, layered impacts round off below 0.9 instead of clipping.
    static func limit(_ a: inout [Float]) {
        for i in a.indices { a[i] = 0.9 * tanh(a[i] / 0.9) }
    }

    // MARK: - Building blocks

    enum Wave { case sine, triangle, chip }

    static func osc(_ wave: Wave, _ phase: Double) -> Double {
        switch wave {
        case .sine: return sin(phase)
        case .triangle:
            let x = (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1)
            return 4 * abs(x - 0.5) - 1
        case .chip: // soft square: odd harmonics only, gentle on the ears
            return sin(phase) + sin(3 * phase) / 3 * 0.6 + sin(5 * phase) / 5 * 0.3
        }
    }

    static func frames(_ seconds: Double) -> Int { Int(seconds * rate) }

    /// Pitch-dropping sine: the body of every hit.
    static func thump(_ seconds: Double, from f0: Double, to f1: Double, decay: Double, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var phase = 0.0
        for i in out.indices {
            let t = Double(i) / rate
            let f = f1 + (f0 - f1) * exp(-t * 30)
            phase += 2 * .pi * f / rate
            out[i] = Float(sin(phase) * exp(-t * decay) * min(1, t * 2_000) * gain)
        }
        return out
    }

    /// A short filtered noise burst: the knuckle on rock.
    static func click(_ seconds: Double, rng: inout Noise, cutoff: Double, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var low = 0.0
        for i in out.indices {
            let t = Double(i) / Double(out.count)
            low += cutoff * (rng.next() - low)
            out[i] = Float(low * (1 - t) * (1 - t) * gain)
        }
        return out
    }

    /// Low noise with a long tail: explosions and lava.
    static func rumble(_ seconds: Double, rng: inout Noise, cutoff: Double, decay: Double, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var a = 0.0, b = 0.0
        for i in out.indices {
            let t = Double(i) / rate
            a += cutoff * (rng.next() - a)
            b += cutoff * (a - b)
            out[i] = Float(b * 6 * exp(-t * decay) * min(1, t * 400) * gain)
        }
        return out
    }

    /// Grainy noise in bursts: rock breaking into chunks.
    static func crumble(_ seconds: Double, rng: inout Noise, cutoff: Double, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var low = 0.0, grain = 1.0, nextGrain = 0
        for i in out.indices {
            if i >= nextGrain {
                grain = 0.35 + 0.65 * abs(rng.next())
                nextGrain = i + frames(0.006 + 0.014 * abs(rng.next()))
            }
            let t = Double(i) / rate
            low += cutoff * (rng.next() - low)
            out[i] = Float(low * grain * exp(-t * 14) * min(1, t * 1_500) * gain * 2.2)
        }
        return out
    }

    /// Inharmonic partials: metal and crystal.
    static func bell(_ partials: [Double], _ seconds: Double, decay: Double, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        for i in out.indices {
            let t = Double(i) / rate
            var v = 0.0
            for (n, f) in partials.enumerated() { v += sin(2 * .pi * f * t) * exp(-t * decay * (1 + 0.4 * Double(n))) }
            out[i] = Float(v / Double(partials.count) * min(1, t * 3_000) * gain * 2)
        }
        return out
    }

    /// Notes as (frequency, start, length) with a plucked envelope.
    static func notes(_ list: [(Double, Double, Double)], wave: Wave, decay: Double, gain: Double) -> [Float] {
        let total = list.map { $0.1 + $0.2 }.max() ?? 0
        var out = [Float](repeating: 0, count: frames(total + 0.02))
        for (f, start, length) in list {
            let s = frames(start), n = frames(length)
            for j in 0..<n where s + j < out.count {
                let t = Double(j) / rate
                let release = min(1, Double(n - j) / (rate * 0.02))
                out[s + j] += Float(osc(wave, 2 * .pi * f * t) * exp(-t * decay) * min(1, t * 1_000) * release * gain)
            }
        }
        return out
    }

    static func sparkle(_ seconds: Double, rng: inout Noise, gain: Double) -> [Float] {
        var list: [(Double, Double, Double)] = []
        var t = 0.05
        while t < seconds - 0.1 {
            list.append((2_000 + 3_000 * abs(rng.next()), t, 0.12))
            t += 0.04 + 0.06 * abs(rng.next())
        }
        return notes(list, wave: .sine, decay: 25, gain: gain)
    }

    static func bubbles(_ seconds: Double, rng: inout Noise, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var t = 0.03
        while t < seconds - 0.08 {
            let f0 = 180 + 260 * abs(rng.next())
            let s = frames(t), n = frames(0.06)
            var phase = 0.0
            for j in 0..<n where s + j < out.count {
                let u = Double(j) / rate
                phase += 2 * .pi * f0 * (1 + u * 12) / rate
                out[s + j] += Float(sin(phase) * sin(.pi * Double(j) / Double(n)) * gain)
            }
            t += 0.05 + 0.1 * abs(rng.next())
        }
        return out
    }

    static func zap(_ seconds: Double, rng: inout Noise, pitch: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var phase = 0.0, jitter = 0.0
        for i in out.indices {
            let t = Double(i) / rate
            if i % 220 == 0 { jitter = rng.next() }
            phase += 2 * .pi * (420 + 380 * jitter) * pitch / rate
            let saw = (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 2 - 1
            out[i] = Float((saw * 0.6 + rng.next() * 0.25) * exp(-t * 14) * min(1, t * 2_000) * 0.22)
        }
        return out
    }

    static func riser(_ seconds: Double, from f0: Double, to f1: Double, gain: Double) -> [Float] {
        var out = [Float](repeating: 0, count: frames(seconds))
        var phase = 0.0
        for i in out.indices {
            let x = Double(i) / Double(out.count)
            phase += 2 * .pi * (f0 * pow(f1 / f0, x)) / rate
            let tremolo = 0.75 + 0.25 * sin(2 * .pi * 18 * x * seconds)
            out[i] = Float(osc(.chip, phase) * x * tremolo * gain)
        }
        return out
    }

    static func chestOpen(rng: inout Noise, chime: [Double], gain: Double) -> [Float] {
        var out = click(0.05, rng: &rng, cutoff: 0.15, gain: 0.5) // the lid
        mix(&out, thump(0.12, from: 200, to: 90, decay: 30, gain: 0.35))
        let list = chime.enumerated().map { (n, f) in (f, 0.08 + 0.07 * Double(n), n == chime.count - 1 ? 0.7 : 0.18) }
        mix(&out, notes(list, wave: .chip, decay: 5, gain: gain))
        return out
    }

    static func mix(_ a: inout [Float], _ b: [Float], at offset: Int = 0) {
        if a.count < b.count + offset { a += [Float](repeating: 0, count: b.count + offset - a.count) }
        for i in b.indices { a[i + offset] += b[i] }
    }

    /// A few ms fade so no cue ends on a click.
    static func fadeTail(_ a: inout [Float]) {
        let n = min(a.count, frames(0.004))
        for j in 0..<n { a[a.count - 1 - j] *= Float(j) / Float(n) }
    }

    // MARK: - Music

    /// A seamless 8-bar loop at 100 BPM in A minor: Am – F – C – G, twice, the second time with a busier arp.
    /// Per-zone flavor of the background loop.
    struct MusicStyle: Sendable {
        let bpm: Double
        /// Four chords (MIDI), played twice over 8 bars.
        let chords: [[Double]]
        let arpWave: Wave
        let arpDecay: Double
        let arpGain: Double
        /// Bass waveform and gain.
        let bassWave: Wave
        let bassGain: Double
        /// Kick beats within a bar.
        let kicks: [Double]
        let shaker: Bool
        let padGain: Double

        /// Pebble Quarry: bouncy A minor chiptune.
        static let quarry = MusicStyle(bpm: 100, chords: [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]],
                                       arpWave: .chip, arpDecay: 9, arpGain: 0.035, bassWave: .triangle, bassGain: 0.16,
                                       kicks: [0, 2], shaker: true, padGain: 0.022)
        /// Crystal Caverns: slow, glassy D major-seventh bells with lots of space.
        static let caverns = MusicStyle(bpm: 84, chords: [[62, 66, 69, 73], [59, 62, 66, 69], [55, 59, 62, 66], [57, 61, 64, 68]],
                                        arpWave: .sine, arpDecay: 3.5, arpGain: 0.05, bassWave: .sine, bassGain: 0.14,
                                        kicks: [0], shaker: false, padGain: 0.03)
        /// Sunken Ruins: slow, watery C# minor with long sine bells and a lazy kick.
        static let ruins = MusicStyle(bpm: 72, chords: [[61, 64, 68], [57, 61, 64], [52, 56, 59], [54, 57, 61]],
                                      arpWave: .sine, arpDecay: 2.6, arpGain: 0.045, bassWave: .sine, bassGain: 0.15,
                                      kicks: [0, 2.5], shaker: false, padGain: 0.034)
        /// Haunted Crypt: slow D minor with soft triangle bells, a heavy pad and a heartbeat kick.
        static let crypt = MusicStyle(bpm: 76, chords: [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]],
                                      arpWave: .triangle, arpDecay: 4.5, arpGain: 0.04, bassWave: .sine, bassGain: 0.16,
                                      kicks: [0, 0.5], shaker: false, padGain: 0.04)
        /// Magma Depths: driving E Phrygian with a heavy four-on-the-floor kick.
        static let magma = MusicStyle(bpm: 112, chords: [[52, 55, 59], [53, 57, 60], [52, 55, 59], [50, 53, 57]],
                                      arpWave: .chip, arpDecay: 14, arpGain: 0.03, bassWave: .chip, bassGain: 0.12,
                                      kicks: [0, 1, 2, 3], shaker: true, padGain: 0.018)
    }

    /// A seamless 8-bar loop.
    static func musicLoop(_ style: MusicStyle = .quarry) -> [Float] {
        let beat = 60.0 / style.bpm
        let total = frames(beat * 32)
        var out = [Float](repeating: 0, count: total)
        var rng = Noise(seed: 7)
        let chords = style.chords
        func hz(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }

        /// Adds a voice into the ring buffer, wrapping the tail past the end back to the start.
        func voice(start: Double, length: Double, _ sample: (Double) -> Double) {
            let s = frames(start), n = frames(length)
            for j in 0..<n {
                out[(s + j) % total] += Float(sample(Double(j) / rate))
            }
        }

        for bar in 0..<8 {
            let chord = chords[bar % 4]
            let barStart = Double(bar) * 4 * beat
            // Bass: root on 1 and 3, fifth on the "and" of 4.
            for (offset, note, len) in [(0.0, chord[0] - 12, 1.6), (2.0, chord[0] - 12, 1.4), (3.5, chord[0] - 5, 0.45)] {
                let f = hz(note)
                voice(start: barStart + offset * beat, length: len * beat) { t in
                    osc(style.bassWave, 2 * .pi * f * t) * exp(-t * 2.2) * min(1, t * 200) * min(1, (len * beat - t) * 30) * style.bassGain
                }
            }
            // Pad: soft sustained chord.
            for note in chord {
                let f = hz(note)
                voice(start: barStart, length: 4 * beat) { t in
                    let env = min(1, t * 2) * min(1, (4 * beat - t) * 2)
                    return (sin(2 * .pi * f * t) + 0.3 * sin(2 * .pi * f * 2.003 * t)) * env * style.padGain
                }
            }
            // Arp: eighths over the chord, an octave up, plucked.
            let top = chord.count - 1
            let pattern = bar < 4 ? [0, 1, 2, 1, 0, 2, 1, 2] : [0, 1, 2, top + 1, 2, 1, 2, top + 1]
            for (step, idx) in pattern.enumerated() {
                let note = idx > top ? chord[0] + 24 : chord[idx] + 12
                let f = hz(note)
                voice(start: barStart + Double(step) * beat / 2, length: min(1.2, 4 / style.arpDecay)) { t in
                    osc(style.arpWave, 2 * .pi * f * t) * exp(-t * style.arpDecay) * min(1, t * 800) * style.arpGain
                }
            }
            // Drums: kick, plus a shaker on the off-beats.
            for k in style.kicks {
                voice(start: barStart + k * beat, length: 0.25) { t in
                    sin(2 * .pi * (50 + 90 * exp(-t * 40)) * t) * exp(-t * 16) * 0.16
                }
            }
            if style.shaker {
                for h in stride(from: 0.5, to: 4.0, by: 1.0) {
                    var low = 0.0
                    let accent = h == 1.5 || h == 3.5 ? 1.0 : 0.6
                    voice(start: barStart + h * beat, length: 0.07) { t in
                        let x = rng.next()
                        low += 0.5 * (x - low)
                        return (x - low) * exp(-t * 60) * 0.05 * accent
                    }
                }
            }
        }
        limit(&out)
        return out
    }
}

/// Deterministic white noise in −1…1.
nonisolated struct Noise {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(Int64(bitPattern: (state >> 11) << 11)) / Double(Int64.max)
    }
}
