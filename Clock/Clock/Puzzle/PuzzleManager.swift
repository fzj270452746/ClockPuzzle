//
//  PuzzleManager.swift
//  Clock
//
//  解谜状态机 + 关卡计时。订阅麻将结局事件（到出口/掉落/卡死），
//  维护倒计时（60~180 秒），到点则失败。胜负只发事件，UI 自行响应。
//  它是“裁判”，不碰渲染，也不被其他系统直接引用。
//

import Foundation

final class PuzzleManager: GameSystem {

    enum State { case playing, won, lost }
    private(set) var state: State = .playing

    private let levelId: Int
    private var remaining: TimeInterval
    private unowned let events: EventBus
    private var token: EventBus.Token?
    private var tickAccumulator: TimeInterval = 0

    /// 剩余时间（供结算面板计算星级）。
    var remainingTime: TimeInterval { max(0, remaining) }

    init(levelId: Int, timeLimit: TimeInterval, events: EventBus) {
        self.levelId = levelId
        self.remaining = timeLimit
        self.events = events
    }

    func setup(world: World) {
        token = events.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    func update(deltaTime dt: TimeInterval, world: World) {
        guard state == .playing else { return }
        remaining -= dt
        // 每 ~0.2 秒播报一次剩余时间，避免过密。
        tickAccumulator += dt
        if tickAccumulator >= 0.2 {
            tickAccumulator = 0
            events.publish(.countdownTick(remaining: max(0, remaining)))
        }
        if remaining <= 0 {
            fail(reason: .timeout)
        }
    }

    private func handle(_ event: GameEvent) {
        guard state == .playing else { return }
        switch event {
        case .tileReachedExit:
            state = .won
            events.publish(.levelCompleted(levelId: levelId))
        case .tileFellOff:
            fail(reason: .fell)
        case .tileStuck:
            fail(reason: .stuck)
        default:
            break
        }
    }

    private func fail(reason: FailReason) {
        guard state == .playing else { return }
        state = .lost
        events.publish(.levelFailed(levelId: levelId, reason: reason))
    }
}
