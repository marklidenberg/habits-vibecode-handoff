import AVFoundation

/// Tu-du: two notes, each sound synthesized once
enum Chime: String, CaseIterable {
    case off, marimba, xylophone, kalimba, musicBox, vibraphone, glockenspiel, triangle, singingBowl

    static let engine = AVAudioEngine()
    static let player = AVAudioPlayerNode()
    static let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    static var buffers: [Chime: AVAudioPCMBuffer] = [:]

    var name: String {
        switch self {
        case .musicBox: "Music Box"
        case .singingBowl: "Singing Bowl"
        default: rawValue.capitalized
        }
    }

    /// Hz, semitones, seconds, `(multiple, amplitude, fade)` each, Hz
    var voice: (pitch: Double, interval: Double, pause: Double, partials: [(Double, Double, Double)], tremolo: Double) {
        switch self {
        case .off: (0, 0, 0, [], 0)
        case .marimba: (784, 7, 0.09, [(1, 1, 1), (4, 0.35, 0.15), (10, 0.08, 0.05)], 0)
        case .xylophone: (1193, 5, 0.085, [(1, 1, 1), (3, 0.4, 0.25), (6, 0.15, 0.1)], 0)
        case .kalimba: (587, 5, 0.11, [(1, 1, 1), (5.4, 0.25, 0.08), (2, 0.12, 0.4)], 0)
        case .musicBox: (2093, 4, 0.12, [(1, 1, 1), (3.9, 0.3, 0.3), (9.2, 0.1, 0.1)], 0)
        case .vibraphone: (698, 4, 0.14, [(1, 1, 1), (4, 0.2, 0.3)], 6)
        case .glockenspiel: (1568, 5, 0.1, [(1, 1, 1), (2.76, 0.45, 0.4), (5.4, 0.2, 0.2)], 0)
        case .triangle: (1303, 3, 0.12, [(1, 1, 1), (2.43, 0.5, 0.8), (3.79, 0.3, 0.6), (5.9, 0.2, 0.5)], 0)
        case .singingBowl: (523, 7, 0.16, [(1, 1, 1), (1.006, 0.8, 1), (2.71, 0.35, 0.6), (5.1, 0.12, 0.3)], 0)
        }
    }

    var buffer: AVAudioPCMBuffer {
        if let buffer = Self.buffers[self] { return buffer }
        let voice = voice, rate = Self.format.sampleRate, decay = 0.3
        let frames = AVAudioFrameCount((voice.pause + decay) * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: Self.format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for (start, pitch) in [(0.0, voice.pitch), (voice.pause, voice.pitch * pow(2, voice.interval / 12))] {
            for frame in Int(start * rate)..<Int(frames) {
                let t = Double(frame) / rate - start
                let envelope = 0.25 * min(t / 0.004, 1) * pow(0.0004, t / decay) * (voice.tremolo > 0 ? 0.65 + 0.35 * sin(2 * .pi * voice.tremolo * t) : 1)
                let partials = voice.partials.map { multiple, amplitude, fade in
                    amplitude * pow(0.001, min(t / (decay * fade), 1)) * sin(2 * .pi * pitch * multiple * t)
                }
                samples[frame] += Float(envelope * partials.reduce(0, +))
            }
        }
        Self.buffers[self] = buffer
        return buffer
    }

    /// The player wired once; the ring switch mutes it, music plays on
    static let wired: Void = {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }()

    func play() {
        guard self != .off else { return }
        _ = Self.wired
        if !Self.engine.isRunning { try? Self.engine.start() }
        Self.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        Self.player.play()
    }
}
