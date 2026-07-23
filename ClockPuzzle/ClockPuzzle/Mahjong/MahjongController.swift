//
//  MahjongController.swift
//  Clock
//
//  麻将控制器系统。负责：释放麻将、监视其运动状态，并在以下情况发事件：
//   - 进入某出口半径          → tileReachedExit
//   - 掉出世界下边界          → tileFellOff
//   - 速度长时间接近 0（卡死）→ tileStuck
//  判定结果只发事件，不直接下判决（胜负交给 PuzzleManager）。
//

import Foundation
import SceneKit

final class MahjongController: GameSystem {

    /// 掉落判定：低于该 Y 视为跌出轨道。
    private let fallY: Float = -6.0
    /// 卡死判定：速度平方低于该阈值累计超过 stuckLimit 秒。
    private let stuckSpeedSq: Float = 0.004
    private let stuckLimit: TimeInterval = 15.0

    private unowned let events: EventBus
    /// 已判定结束的麻将 id，避免重复发事件。
    private var settled: Set<Int> = []

    init(events: EventBus) {
        self.events = events
    }

    /// 释放麻将：切 dynamic 并广播。UI 的“释放”按钮调用它。
    func releaseTiles(in world: World) {
        for e in world.entities(with: TileComponent.self) {
            guard let tile = e.component(TileComponent.self),
                  let phys = e.component(PhysicsComponent.self),
                  !tile.released else { continue }

            // 牌在释放前是坡节点的子节点（随坡旋转、贴在坡面上）。
            // 释放要变成独立 dynamic 体，必须摘回 mahjongRoot，并【保留当前世界变换】，
            // 否则 addChildNode 会保留局部坐标导致瞬移。
            let node = e.node
            if node.parent !== world.mahjongRoot {
                let worldTransform = node.worldTransform
                world.mahjongRoot.addChildNode(node)
                node.transform = world.mahjongRoot.convertTransform(worldTransform, from: nil)
            }

            tile.released = true
            tile.releaseWorldPosition = e.node.presentation.worldPosition
            phys.release()
            events.publish(.tileReleased(entityId: e.id))
        }
    }

    func update(deltaTime dt: TimeInterval, world: World) {
        let exits = world.entities(with: ExitComponent.self)

        for e in world.entities(with: TileComponent.self) {
            guard let tile = e.component(TileComponent.self),
                  tile.released,
                  !settled.contains(e.id) else { continue }

            let pos = e.node.presentation.position

            // 0) Dragon 牌「激活机关」：靠近门/桥时强制其开启（不受时钟约束）。
            if tile.ability == .activateMechanism {
                activateNearbyMechanisms(around: e.node.presentation.worldPosition, world: world)
            }

            // 1) 出口检测
            for exitEntity in exits {
                guard let exit = exitEntity.component(ExitComponent.self) else { continue }
                let ep = exitEntity.node.position
                let dx = pos.x - ep.x, dy = pos.y - ep.y, dz = pos.z - ep.z
                let distSq = dx*dx + dy*dy + dz*dz
                if distSq <= Float(exit.radius * exit.radius) {
                    settled.insert(e.id)
                    events.publish(.tileReachedExit(entityId: e.id, exitId: exit.id))
                    break
                }
            }
            if settled.contains(e.id) { continue }

            // 2) 掉落检测（White 牌可无视一次）
            if pos.y < fallY {
                if rescueIfPossible(tile: tile, entity: e, world: world) { continue }
                settled.insert(e.id)
                events.publish(.tileFellOff(entityId: e.id))
                continue
            }

            // 3) 卡死检测（速度长时间接近 0；White 牌可无视一次）
            if let v = e.node.physicsBody?.velocity {
                let speedSq = v.x*v.x + v.y*v.y + v.z*v.z
                if speedSq < stuckSpeedSq {
                    tile.stuckTimer += dt
                    if tile.stuckTimer >= stuckLimit {
                        if rescueIfPossible(tile: tile, entity: e, world: world) { continue }
                        settled.insert(e.id)
                        events.publish(.tileStuck(entityId: e.id))
                    }
                } else {
                    tile.stuckTimer = 0
                }
            }
        }
    }

    /// White 牌「无视一次陷阱」：首次将要掉落/卡死时，把牌救回释放点并清零速度，
    /// 消耗免疫。返回是否成功营救（true 表示本次不判负）。
    private func rescueIfPossible(tile: TileComponent, entity: Entity, world: World) -> Bool {
        guard tile.ability == .ignoreOneTrap,
              !tile.trapImmunityUsed,
              let anchor = tile.releaseWorldPosition else { return false }
        tile.trapImmunityUsed = true
        tile.stuckTimer = 0
        let node = entity.node
        node.worldPosition = anchor
        node.physicsBody?.velocity = SCNVector3Zero
        node.physicsBody?.angularVelocity = SCNVector4Zero
        events.publish(.abilityTriggered(kind: .whiteRescue))
        return true
    }

    /// Dragon 牌靠近时强制开启门/桥。半径内即触发，一次性（组件内部幂等）。
    private func activateNearbyMechanisms(around p: SCNVector3, world: World) {
        let reachSq: Float = 1.2 * 1.2
        for entity in world.entities {
            for component in entity.components.values {
                if let gate = component as? TimeGateComponent {
                    if !gate.isOpen, distanceSq(entity.node.presentation.worldPosition, p) <= reachSq {
                        gate.forceOpen()
                        events.publish(.abilityTriggered(kind: .dragonActivate))
                    }
                } else if let bridge = component as? BridgeComponent {
                    if !bridge.isExtended, distanceSq(entity.node.presentation.worldPosition, p) <= reachSq {
                        bridge.forceExtend()
                        events.publish(.abilityTriggered(kind: .dragonActivate))
                    }
                }
            }
        }
    }

    private func distanceSq(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
        return dx*dx + dy*dy + dz*dz
    }

    /// 关卡重置时清空判定缓存。
    func reset() { settled.removeAll() }
}
