//
//  FeedbackService.swift
//  Clock
//
//  即时反馈服务：音效（程序合成，不依赖任何音频资源文件，契合「全素材程序生成」原则）
//  + 触感（UIKit haptic）。订阅 EventBus，按游戏事件播放对应反馈。
//
//  为什么这样设计：
//   - 成熟休闲游戏的「手感」很大程度来自即时的听觉/触觉反馈；此前全程静音。
//   - 音效用正弦波实时合成短音（click / open / win 和弦 / fail），无需打包任何 wav/mp3。
//   - 与其它系统一样通过事件解耦，不被直接引用；UI 按钮点击也可主动调用 play(_:)。
//

import Foundation
import AVFoundation
import UIKit

final class FeedbackService {

    /// 反馈类型（语义化，与具体波形解耦）。
    enum Cue {
        case tick          // 时间微调 / 按钮
        case release       // 释放麻将
        case gateOpen      // 门升起
        case bridgeExtend  // 桥展开
        case win           // 通关
        case fail          // 失败
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// 实际使用的采样率：优先跟随硬件输出格式，避免格式不匹配导致的断言崩溃。
    private var sampleRate: Double = 44_100
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var isEngineReady = false

    // 触感发生器（预热以降低首次延迟）。
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notify = UINotificationFeedbackGenerator()

    private var token: EventBus.Token?
    private unowned let events: EventBus

    /// 用户开关（供设置项接入；默认开）。
    var soundEnabled = true
    var hapticsEnabled = true

    init(events: EventBus) {
        self.events = events
        configureAudioSession()
        // 先装配引擎（确定实际采样率），再按该采样率预生成 buffer，保证格式一致。
        startEngine()
        prepareBuffers()
        token = events.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    // MARK: - 事件映射

    private func handle(_ event: GameEvent) {
        switch event {
        case .tileReleased:      play(.release)
        case .levelCompleted:    play(.win)
        case .levelFailed:       play(.fail)
        case let .abilityTriggered(kind):
            play(kind == .dragonActivate ? .gateOpen : .bridgeExtend)
        default: break
        }
    }

    /// 对外主动播放（UI 按钮、机构动画回调用）。
    func play(_ cue: Cue) {
        playSound(cue)
        playHaptic(cue)
    }

    // MARK: - 触感

    private func playHaptic(_ cue: Cue) {
        guard hapticsEnabled else { return }
        switch cue {
        case .tick:                     lightImpact.impactOccurred(intensity: 0.5)
        case .release, .bridgeExtend:   mediumImpact.impactOccurred()
        case .gateOpen:                 lightImpact.impactOccurred()
        case .win:                      notify.notificationOccurred(.success)
        case .fail:                     notify.notificationOccurred(.error)
        }
    }

    // MARK: - 音效

    private func playSound(_ cue: Cue) {
        guard soundEnabled, isEngineReady, let buffer = buffers[key(for: cue)] else { return }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private func key(for cue: Cue) -> String {
        switch cue {
        case .tick:          return "tick"
        case .release:       return "release"
        case .gateOpen:      return "gate"
        case .bridgeExtend:  return "bridge"
        case .win:           return "win"
        case .fail:          return "fail"
        }
    }

    // MARK: - 音频引擎装配

    private func configureAudioSession() {
        // .ambient：与其它 App 音乐共存、随静音键静音——休闲小游戏的礼貌做法。
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func startEngine() {
        // 关键：engine.outputNode 的硬件输出格式在某些路由下 sampleRate/channelCount 为 0，
        // 此时访问 mainMixerNode 触发的隐式连接会抛 ObjC 异常直接崩溃（Swift 的 try? 捕获不到）。
        // 因此先校验输出格式有效，再决定是否装配；无效则静默禁用音频，绝不崩。
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        guard outputFormat.sampleRate > 0, outputFormat.channelCount > 0 else {
            isEngineReady = false
            return
        }

        // 跟随硬件采样率生成 buffer 与连接格式，避免 44100 与实际格式不一致导致 scheduleBuffer 断言。
        sampleRate = outputFormat.sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            isEngineReady = false
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            isEngineReady = true
        } catch {
            isEngineReady = false
        }
    }

    // MARK: - 波形合成（一次性预生成，运行时零分配）

    private func prepareBuffers() {
        // 每个音效由若干正弦分量叠加，套一个指数衰减包络，短促清脆。
        buffers["tick"]    = tone(freqs: [880], duration: 0.05, decay: 40, volume: 0.25)
        buffers["release"] = tone(freqs: [523.25, 659.25], duration: 0.12, decay: 18, volume: 0.3)
        buffers["gate"]    = tone(freqs: [392, 587.33], duration: 0.18, decay: 10, volume: 0.28)
        buffers["bridge"]  = tone(freqs: [329.63, 493.88], duration: 0.22, decay: 8, volume: 0.28)
        // 通关：C-E-G 大三和弦琶音上行，明亮。
        buffers["win"]     = chord(freqs: [523.25, 659.25, 783.99, 1046.5], duration: 0.6, volume: 0.32)
        // 失败：小三度下行，低沉。
        buffers["fail"]    = sequence(freqs: [329.63, 261.63], step: 0.14, duration: 0.34, volume: 0.3)
    }

    /// 叠加正弦分量 + 指数衰减包络。
    private func tone(freqs: [Double], duration: Double, decay: Double, volume: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-decay * t)
            var s = 0.0
            for f in freqs { s += sin(2 * .pi * f * t) }
            s /= Double(freqs.count)
            ptr[i] = Float(s) * Float(env) * volume
        }
        return buffer
    }

    /// 琶音上行（每个音错开进入，套整体衰减），做出「叮咚」通关感。
    private func chord(freqs: [Double], duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let ptr = buffer.floatChannelData![0]
        let stagger = duration / Double(freqs.count + 1)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var s = 0.0
            for (idx, f) in freqs.enumerated() {
                let onset = Double(idx) * stagger
                guard t >= onset else { continue }
                let lt = t - onset
                s += sin(2 * .pi * f * lt) * exp(-5 * lt)
            }
            s /= Double(freqs.count)
            ptr[i] = Float(s) * volume
        }
        return buffer
    }

    /// 顺序两音（下行）做失败提示。
    private func sequence(freqs: [Double], step: Double, duration: Double, volume: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let idx = min(freqs.count - 1, Int(t / step))
            let lt = t - Double(idx) * step
            let s = sin(2 * .pi * freqs[idx] * lt) * exp(-6 * lt)
            ptr[i] = Float(s) * volume
        }
        return buffer
    }
}
