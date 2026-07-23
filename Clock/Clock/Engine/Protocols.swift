//
//  Protocols.swift
//  Clock
//
//  行为协议。需求文档强制：用协议组合替代巨大继承树。
//  组件按需遵循这些协议，System 面向协议工作，互不依赖具体类型。
//

import Foundation
import SceneKit

/// 可绕某轴旋转的东西（齿轮、指针）。
protocol Rotatable: AnyObject {
    /// 承载旋转的节点。
    var spinNode: SCNNode { get }
    /// 施加一个增量旋转（弧度），绕 z 轴（本游戏在 XY 平面解谜）。
    func spin(by radians: CGFloat)
}

extension Rotatable {
    func spin(by radians: CGFloat) {
        spinNode.eulerAngles.z += Float(radians)
    }
}

/// 对时间变化做出反应的东西（平台角度、时间门、桥梁）。
protocol TimeReactive: AnyObject {
    /// - Parameters:
    ///   - minutes: 当日总分钟数（0...1439）。
    ///   - hourAngle: 时针角度（弧度，12 点为 0，顺时针为正）。
    ///   - minuteAngle: 分针角度（弧度）。
    func react(minutes: Int, hourAngle: CGFloat, minuteAngle: CGFloat)
}

/// 被齿轮驱动的东西（联动齿轮、被时针带动的机构）。
protocol GearDriven: AnyObject {
    /// 当前角速度（弧度/秒），由 GearSystem 写入。
    var angularVelocity: CGFloat { get set }
}
