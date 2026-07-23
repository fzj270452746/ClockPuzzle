//
//  MechanismSystem.swift
//  Clock
//
//  机构反应系统。订阅 timeChanged，把当前时间/指针角度派发给所有
//  TimeReactive 组件（时间门、桥梁、受时针驱动的平台）。
//  它不每帧轮询——纯事件驱动，符合“模块间用事件通信”的约束。
//

import Foundation
import CoreGraphics
import SceneKit

final class MechanismSystem: GameSystem {

    private var token: EventBus.Token?
    private weak var world: World?

    func setup(world: World) {
        self.world = world
        token = world.events.subscribe { [weak self] event in
            guard case let .timeChanged(minutes, _, _) = event else { return }
            self?.dispatch(minutes: minutes)
        }
    }

    // 纯事件驱动，无需每帧逻辑。
    func update(deltaTime: TimeInterval, world: World) {}

    private func dispatch(minutes: Int) {
        guard let world else { return }
        let hourAngle = CGFloat(minutes % 720) / 720 * 2 * .pi
        let minuteAngle = CGFloat(minutes % 60) / 60 * 2 * .pi

        // 遍历所有实体，凡是 TimeReactive 的组件都通知。
        for entity in world.entities {
            for component in entity.components.values {
                if let reactive = component as? TimeReactive {
                    reactive.react(minutes: minutes, hourAngle: hourAngle, minuteAngle: minuteAngle)
                }
            }
        }

        // 唤醒已释放的牌：牌滑到关闭的门/桥断口前停住后，dynamic 刚体会进入 resting
        // 休眠；门升起或桥展开移走障碍后，休眠的牌不会被重力自动唤醒，视觉上就是
        // “机构已放行但牌不动”。时间变化必然伴随机构状态可能改变，这里统一把已释放的
        // 牌唤醒（施加零冲量即可让 SceneKit 重新激活刚体），保证放行后牌继续下滑。
        for entity in world.entities {
            guard let tile = entity.component(TileComponent.self), tile.released,
                  let body = entity.node.physicsBody, body.type == .dynamic else { continue }
            body.applyForce(SCNVector3Zero, asImpulse: true)
        }
    }
}
