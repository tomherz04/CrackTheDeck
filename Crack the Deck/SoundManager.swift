import AVFoundation

enum GameSettings {
    static var soundEnabled: Bool {
        (UserDefaults.standard.object(forKey: DefaultsKey.soundEnabled) as? Bool) ?? true
    }
    static var hapticsEnabled: Bool {
        (UserDefaults.standard.object(forKey: DefaultsKey.hapticsEnabled) as? Bool) ?? true
    }
}

/// Plays short synthesized tones. All engine work happens on a private serial queue, and each
/// tone's buffers are rendered once and then reused, so a tap never pays for audio setup or
/// sample synthesis on the main thread.
final class SoundManager {
    static let shared = SoundManager()

    enum Tone: CaseIterable {
        case select
        case correct
        case wrong
        case win

        var frequencies: [Double] {
            switch self {
            case .select: return [520]
            case .correct: return [660, 990]
            case .wrong: return [220, 150]
            case .win: return [523, 659, 784, 1047]
            }
        }

        var noteDuration: Double {
            self == .win ? 0.11 : 0.09
        }
    }

    private let sampleRate: Double = 44100
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let queue = DispatchQueue(label: "SoundManager", qos: .userInteractive)
    private var buffers: [Tone: [AVAudioPCMBuffer]] = [:]

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Starts the engine and renders every tone ahead of time, so the first tap doesn't hitch.
    func warmUp() {
        queue.async { self.prepare() }
    }

    func play(_ tone: Tone) {
        guard GameSettings.soundEnabled else { return }
        queue.async {
            self.prepare()
            // Starting the player while the engine is stopped (e.g. after an audio interruption
            // it couldn't recover from) raises an exception, so bail instead.
            guard self.engine.isRunning else { return }
            for buffer in self.buffers[tone] ?? [] {
                self.player.scheduleBuffer(buffer, completionHandler: nil)
            }
            if !self.player.isPlaying {
                self.player.play()
            }
        }
    }

    private func prepare() {
        if buffers.isEmpty {
            for tone in Tone.allCases {
                buffers[tone] = tone.frequencies.compactMap { makeBuffer(frequency: $0, duration: tone.noteDuration) }
            }
        }
        guard !engine.isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        try? engine.start()
    }

    private func makeBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }

        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = sin(Double.pi * t / duration)
            let sample = sin(2.0 * Double.pi * frequency * t) * envelope * 0.2
            channelData[frame] = Float(sample)
        }
        return buffer
    }
}
