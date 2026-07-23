//
//  EventBus.swift
//  Clock
//
//  模块间通信总线。需求文档强制：模块之间不得直接引用，
//  统一走事件（这里用 NotificationCenter 封装成类型安全的总线）。
//

import Foundation

/// 游戏事件。用枚举承载 payload，避免字符串 userInfo 到处飞。
enum GameEvent {
    /// 时间被改变（分钟数、是否整点、是否半点）。
    case timeChanged(totalMinutes: Int, isHour: Bool, isHalfHour: Bool)
    /// 时间到达某个“时间门”要求的时刻。
    case timeGateReached(minutes: Int)
    /// 麻将被释放。
    case tileReleased(entityId: Int)
    /// 麻将进入出口。
    case tileReachedExit(entityId: Int, exitId: Int)
    /// 麻将掉落（跌出轨道）。
    case tileFellOff(entityId: Int)
    /// 麻将卡死超时。
    case tileStuck(entityId: Int)
    /// 关卡胜利。
    case levelCompleted(levelId: Int)
    /// 关卡失败。
    case levelFailed(levelId: Int, reason: FailReason)
    /// 剩余时间更新（秒）。
    case countdownTick(remaining: TimeInterval)
    /// 特殊牌能力触发（Dragon 激活机关 / White 免疫陷阱），供反馈与提示。
    case abilityTriggered(kind: AbilityKind)
}

/// 能力触发种类（用于反馈/提示，与 Ability 语义对应）。
enum AbilityKind {
    case dragonActivate
    case whiteRescue
}

enum FailReason {
    case fell
    case stuck
    case timeout
}

/// 事件总线：对 NotificationCenter 的薄封装，提供类型安全的发布/订阅。
final class EventBus {

    private let center = NotificationCenter()
    private static let name = Notification.Name("Clock.GameEvent")

    /// 订阅令牌。持有它以保持订阅；释放即自动退订。
    final class Token {
        fileprivate let observer: NSObjectProtocol
        fileprivate let center: NotificationCenter
        fileprivate init(observer: NSObjectProtocol, center: NotificationCenter) {
            self.observer = observer
            self.center = center
        }
        deinit { center.removeObserver(observer) }
    }

    func publish(_ event: GameEvent) {
        center.post(name: EventBus.name, object: nil, userInfo: ["e": Box(event)])
    }

    /// 订阅事件。回调在主线程执行（游戏循环即主线程）。
    @discardableResult
    func subscribe(_ handler: @escaping (GameEvent) -> Void) -> Token {
        let obs = center.addObserver(forName: EventBus.name, object: nil, queue: .main) { note in
            guard let box = note.userInfo?["e"] as? Box else { return }
            handler(box.value)
        }
        return Token(observer: obs, center: center)
    }

    /// 因为 GameEvent 是枚举值类型，用引用盒子塞进 userInfo。
    private final class Box {
        let value: GameEvent
        init(_ value: GameEvent) { self.value = value }
    }
}
