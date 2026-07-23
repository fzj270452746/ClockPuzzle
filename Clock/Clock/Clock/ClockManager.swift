//
//  ClockManager.swift
//  Clock
//
//  时间控制系统——整个游戏最核心的系统。
//  持有“当日分钟数”状态，提供 UI 可调用的调整接口，
//  并在时间变化时通过 EventBus 广播 timeChanged（模块间不直接引用）。
//
//  设计要点：
//   - 它既是状态持有者，又是 GameSystem（驱动自动播放）。
//   - 逻辑刻意收敛在“时间”这一件事上，不承担机构反应（那是 MechanismSystem 的事）。
//

import Foundation
import CoreGraphics

/// 时间控制系统。
final class ClockManager: GameSystem {

    // MARK: - 常量
    static let minutesPerDay = 24 * 60
    /// 自动播放速率：需求文档「1 秒 = 10 分钟」。
    static let autoPlayMinutesPerSecond: Double = 10

    // MARK: - 状态
    private(set) var totalMinutes: Int
    private(set) var isAutoPlaying = false

    /// 自动播放的分钟累加器（避免整数丢精度）。
    private var minuteAccumulator: Double = 0

    private unowned let events: EventBus

    init(startMinutes: Int, events: EventBus) {
        self.totalMinutes = ((startMinutes % Self.minutesPerDay) + Self.minutesPerDay) % Self.minutesPerDay
        self.events = events
    }

    // MARK: - GameSystem
    func setup(world: World) {
        // 挂载即广播一次初始时间，让机构对齐初始状态。
        broadcast()
    }

    func update(deltaTime: TimeInterval, world: World) {
        guard isAutoPlaying else { return }
        minuteAccumulator += deltaTime * Self.autoPlayMinutesPerSecond
        guard minuteAccumulator >= 1 else { return }
        let whole = Int(minuteAccumulator)
        minuteAccumulator -= Double(whole)
        setMinutes(totalMinutes + whole)
    }

    // MARK: - UI 操作接口（对应“微调 / 快速调整 / 自动播放”）

    func nudge(by minutes: Int) { setMinutes(totalMinutes + minutes) }
    func addFiveMinutes()  { nudge(by: 5) }
    func subFiveMinutes()  { nudge(by: -5) }
    func addHour()         { nudge(by: 60) }
    func subHour()         { nudge(by: -60) }

    /// 拖动时间轮：把一段角度（弧度）换算成分钟增量。整圈 = 12 小时。
    func drag(byRadians radians: CGFloat) {
        let minutesPerRadian = CGFloat(12 * 60) / (2 * .pi)
        nudge(by: Int((radians * minutesPerRadian).rounded()))
    }

    func toggleAutoPlay() { isAutoPlaying.toggle() }
    func setAutoPlay(_ on: Bool) { isAutoPlaying = on }

    /// 直接设定（用于重置关卡到起始时间）。
    func reset(to startMinutes: Int) {
        isAutoPlaying = false
        minuteAccumulator = 0
        setMinutes(startMinutes)
    }

    // MARK: - 派生量（供 UI 与机构使用）

    /// 时针角度（弧度）。12 点为 0，顺时针为正。一天走两圈。
    var hourHandAngle: CGFloat {
        let hourFraction = CGFloat(totalMinutes % (12 * 60)) / CGFloat(12 * 60)
        return hourFraction * 2 * .pi
    }

    /// 分针角度（弧度）。
    var minuteHandAngle: CGFloat {
        let minuteFraction = CGFloat(totalMinutes % 60) / 60
        return minuteFraction * 2 * .pi
    }

    var isOnHour: Bool { totalMinutes % 60 == 0 }
    var isOnHalfHour: Bool { totalMinutes % 60 == 30 }

    /// "HH:MM" 24 小时制。
    var displayString: String {
        String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    // MARK: - 私有

    private func setMinutes(_ raw: Int) {
        let wrapped = ((raw % Self.minutesPerDay) + Self.minutesPerDay) % Self.minutesPerDay
        guard wrapped != totalMinutes else { return }
        totalMinutes = wrapped
        broadcast()
    }

    private func broadcast() {
        events.publish(.timeChanged(totalMinutes: totalMinutes,
                                    isHour: isOnHour,
                                    isHalfHour: isOnHalfHour))
    }
}
