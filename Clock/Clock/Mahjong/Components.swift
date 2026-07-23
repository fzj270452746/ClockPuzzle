//
//  Components.swift
//  Clock
//
//  ECS 组件集合。组件是纯数据（+ 极轻的行为），逻辑全在 System。
//  按需求文档：MahjongEntity 由 Physics/Gear/Render 等组件组合而成。
//

import Foundation
import SceneKit

// MARK: - 麻将牌组件

/// 麻将牌：花色、能力、释放状态。对应 struct MahjongTile 的语义。
final class TileComponent: Component {
    let suit: Suit
    let ability: Ability?
    /// 是否已释放（释放前静止在出生点，不参与物理下落）。
    var released = false
    /// White Tile 的“无视一次陷阱”是否已消耗。
    var trapImmunityUsed = false
    /// 停滞计时（秒）。超过阈值判定卡死。
    var stuckTimer: TimeInterval = 0
    /// 释放时的世界坐标（White 牌触发“无视陷阱”时把牌救回这里）。
    var releaseWorldPosition: SCNVector3?

    init(suit: Suit, ability: Ability?) {
        self.suit = suit
        self.ability = ability
    }
}

// MARK: - 物理组件

/// 物理体封装。麻将是全场唯一的 dynamic 刚体（见需求性能约束：
/// 机构一律 kinematic 驱动）。释放前为 kinematic 冻结，释放时切 dynamic。
final class PhysicsComponent: Component {
    unowned let body: SCNPhysicsBody
    let baseMass: CGFloat

    init(body: SCNPhysicsBody, baseMass: CGFloat) {
        self.body = body
        self.baseMass = baseMass
    }

    /// 释放：切换到 dynamic 并施加重力。
    func release() {
        body.type = .dynamic
        body.mass = baseMass
        body.isAffectedByGravity = true
        body.velocity = SCNVector3Zero
        body.angularVelocity = SCNVector4Zero
    }

    /// 冻结（回到释放前状态）。
    func freeze() {
        body.type = .kinematic
        body.velocity = SCNVector3Zero
        body.angularVelocity = SCNVector4Zero
    }
}

// MARK: - 齿轮组件

/// 齿轮：可旋转、可被驱动、可联动。遵循 Rotatable + GearDriven。
final class GearComponent: Component, Rotatable, GearDriven {
    let id: Int
    let teethCount: Int
    let radius: CGFloat
    /// 基础转速（弧度/秒）。驱动齿轮用它自转。
    let baseAngularSpeed: CGFloat
    let isDriver: Bool
    let linkedGearIds: [Int]

    /// GearSystem 每帧写入的当前角速度（弧度/秒）。
    var angularVelocity: CGFloat = 0

    /// 承载旋转的节点（由 RenderComponent/Entity 注入）。
    unowned let spinNode: SCNNode

    init(id: Int, teethCount: Int, radius: CGFloat,
         baseAngularSpeed: CGFloat, isDriver: Bool,
         linkedGearIds: [Int], spinNode: SCNNode) {
        self.id = id
        self.teethCount = teethCount
        self.radius = radius
        self.baseAngularSpeed = baseAngularSpeed
        self.isDriver = isDriver
        self.linkedGearIds = linkedGearIds
        self.spinNode = spinNode
    }
}

// MARK: - 钟摆组件

/// 钟摆：用简谐运动摆动，击飞路径上的麻将。
final class PendulumComponent: Component {
    let amplitude: CGFloat      // 弧度
    let period: TimeInterval    // 秒
    var phase: TimeInterval     // 当前相位（秒）
    unowned let armNode: SCNNode

    init(amplitudeDegrees: Float, period: Float, phase: TimeInterval, armNode: SCNNode) {
        self.amplitude = CGFloat(amplitudeDegrees) * .pi / 180
        self.period = TimeInterval(period)
        self.phase = phase
        self.armNode = armNode
    }
}

// MARK: - 时间门组件

/// 时间门：仅在 openAtMinutes 时刻打开（±容差）。遵循 TimeReactive。
final class TimeGateComponent: Component, TimeReactive {
    let openAtMinutes: Int
    private(set) var isOpen = false
    unowned let gateNode: SCNNode
    private let closedY: Float
    private let openY: Float

    init(openAtMinutes: Int, gateNode: SCNNode) {
        self.openAtMinutes = openAtMinutes
        self.gateNode = gateNode
        self.closedY = gateNode.position.y
        // 升程必须由门自身高度决定：整扇门要完全升到关闭时的顶沿之上，门底才彻底
        // 离开路径。旧代码把升程写死 1.4，对 height>1.92 的门（如 level_1 的 2.4）升起后
        // 门底仍低于牌顶，物理上继续挡牌——那是“门开了还挡住麻将”的真正原因（代码 bug，非参数）。
        // 用门高作升程：门底开启后升到原门顶位置，再加一点余量，任何高度的门都必然放行。
        let gateHeight = (gateNode.geometry as? SCNBox).map { Float($0.height) } ?? 1.4
        self.openY = gateNode.position.y + gateHeight + 0.1
    }

    func react(minutes: Int, hourAngle: CGFloat, minuteAngle: CGFloat) {
        // 容差 4 分钟（自动播放 1 秒=10 分钟，粒度较粗）。
        let shouldOpen = abs(minutes - openAtMinutes) <= 4
        // 被 Dragon 牌强制开启后，即使时间不满足也保持开（forceOpen 语义）。
        setOpen(shouldOpen || forcedOpen)
    }

    /// Dragon 牌「激活机关」：强制开启一次，不受时钟约束。
    func forceOpen() {
        guard !forcedOpen else { return }
        forcedOpen = true
        setOpen(true)
    }

    private var forcedOpen = false

    private func setOpen(_ open: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        let targetY = isOpen ? openY : closedY
        let move = SCNAction.move(to: SCNVector3(gateNode.position.x, targetY, gateNode.position.z),
                                  duration: 0.35)
        move.timingMode = .easeInEaseOut
        gateNode.runAction(move)
    }
}

// MARK: - 机械桥组件

/// 机械桥：到达指定分钟（半点）时展开，补齐轨道缺口。遵循 TimeReactive。
final class BridgeComponent: Component, TimeReactive {
    let extendAtMinutes: Int
    private(set) var isExtended = false
    unowned let deckNode: SCNNode
    private let retractedScale: Float = 0.02
    private let extendedScale: Float = 1.0

    init(extendAtMinutes: Int, deckNode: SCNNode) {
        self.extendAtMinutes = extendAtMinutes
        self.deckNode = deckNode
        deckNode.scale.x = retractedScale   // 初始收回
    }

    func react(minutes: Int, hourAngle: CGFloat, minuteAngle: CGFloat) {
        let shouldExtend = abs(minutes - extendAtMinutes) <= 4
        setExtended(shouldExtend || forcedExtend)
    }

    /// Dragon 牌「激活机关」：强制展开一次，不受时钟约束。
    func forceExtend() {
        guard !forcedExtend else { return }
        forcedExtend = true
        setExtended(true)
    }

    private var forcedExtend = false

    private func setExtended(_ extend: Bool) {
        guard extend != isExtended else { return }
        isExtended = extend
        let target = isExtended ? extendedScale : retractedScale
        // 只在 x 方向伸缩（桥面沿 x 展开），保持 y/z 不变。
        let scaleAct = SCNAction.customAction(duration: 0.4) { node, elapsed in
            let p = Float(elapsed / 0.4)
            let from = node.scale.x
            node.scale = SCNVector3(from + (target - from) * p, node.scale.y, node.scale.z)
        }
        scaleAct.timingMode = .easeInEaseOut
        deckNode.runAction(scaleAct)
    }
}

// MARK: - 受时针驱动的平台

/// 平台：其倾角随时针角度变化。遵循 TimeReactive。
final class TiltPlatformComponent: Component, TimeReactive {
    let baseTiltRadians: Float
    let hourDriven: Bool
    unowned let platformNode: SCNNode

    init(baseTiltDegrees: Float, hourDriven: Bool, platformNode: SCNNode) {
        self.baseTiltRadians = baseTiltDegrees * .pi / 180
        self.hourDriven = hourDriven
        self.platformNode = platformNode
        platformNode.eulerAngles.z = self.baseTiltRadians
    }

    func react(minutes: Int, hourAngle: CGFloat, minuteAngle: CGFloat) {
        guard hourDriven else { return }
        // 时针角度映射到 ±15° 的额外倾角，制造“调时间改坡度”的解谜手感。
        let extra = Float(sin(hourAngle)) * (15 * .pi / 180)
        platformNode.eulerAngles.z = baseTiltRadians + extra
    }
}

// MARK: - 出口组件

/// 出口：检测麻将是否进入半径范围。
final class ExitComponent: Component {
    let id: Int
    let radius: CGFloat
    init(id: Int, radius: CGFloat) {
        self.id = id
        self.radius = radius
    }
}
