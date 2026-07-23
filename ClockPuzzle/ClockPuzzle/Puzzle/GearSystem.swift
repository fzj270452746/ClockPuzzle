//
//  GearSystem.swift
//  Clock
//
//  齿轮系统。负责：驱动齿轮自转、把动力沿 linkedGearIds 传播到联动齿轮
//  （角速度按齿数比反向），并把角速度积分成每帧旋转（Rotatable.spin）。
//  齿轮全部 kinematic：靠节点旋转带动麻将，不用 dynamic 刚体（性能约束）。
//

import Foundation
import SceneKit

final class GearSystem: GameSystem {

    func update(deltaTime dt: TimeInterval, world: World) {
        let gearEntities = world.entities(with: GearComponent.self)
        guard !gearEntities.isEmpty else { return }

        // 建立 id -> 组件 映射，便于联动查找。
        var byId: [Int: GearComponent] = [:]
        for e in gearEntities {
            if let g = e.component(GearComponent.self) { byId[g.id] = g }
        }

        // 1) 驱动齿轮：角速度 = 基础转速。
        for (_, g) in byId where g.isDriver {
            g.angularVelocity = g.baseAngularSpeed
        }

        // 2) 联动传播：被驱动齿轮跟随其 linked 源，按齿数比反向。
        //    多级联动做有限次迭代传播（避免建图，关卡齿轮数很小）。
        for _ in 0..<byId.count {
            for (_, g) in byId where !g.isDriver {
                guard let sourceId = g.linkedGearIds.first,
                      let source = byId[sourceId] else { continue }
                let ratio = CGFloat(source.teethCount) / CGFloat(max(1, g.teethCount))
                g.angularVelocity = -source.angularVelocity * ratio
            }
        }

        // 3) 积分成旋转。
        for (_, g) in byId {
            g.spin(by: g.angularVelocity * CGFloat(dt))
        }
    }
}
