import AVFoundation

enum GameSettings {
    static var soundEnabled: Bool {
        (UserDefaults.standard.object(forKey: DefaultsKey.soundEnabled) as? Bool) ?? true
    }
    static var hapticsEnabled: Bool {
        (UserDefaults.standard.object(forKey: DefaultsKey.hapticsEnabled) as? Bool) ?? true
    }
}

final class SoundManager {
    static let shared = SoundManager()

    enum Tone {
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
    private var started = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ tone: Tone) {
        guard GameSettings.soundEnabled else { return }
        ensureStarted()

        for frequency in tone.frequencies {
            guard let buffer = makeBuffer(frequency: frequency, duration: tone.noteDuration) else { continue }
            player.scheduleBuffer(buffer, completionHandler: nil)
        }
        if !player.isPlaying {
            player.play()
        }
    }

    private func ensureStarted() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
        started = true
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
