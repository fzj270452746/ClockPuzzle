//
//  PendulumSystem.swift
//  Clock
//
//  钟摆系统。用简谐运动 θ(t) = amplitude * sin(2π t / period) 摆动摆臂。
//  摆臂 kinematic：靠节点旋转击飞麻将，不建 dynamic 铰链（性能约束）。
//

import Foundation
import SceneKit

final class PendulumSystem: GameSystem {

    func update(deltaTime dt: TimeInterval, world: World) {
        for e in world.entities(with: PendulumComponent.self) {
            guard let p = e.component(PendulumComponent.self) else { continue }
            p.phase += dt
            let omega = 2 * Double.pi / p.period
            let theta = p.amplitude * CGFloat(sin(omega * p.phase))
            // 绕 z 轴摆动（XY 平面）。
            p.armNode.eulerAngles.z = Float(theta)
        }
    }
}
