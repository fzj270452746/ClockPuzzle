//
//  World.swift
//  Clock
//
//  ECS 容器。持有实体与系统，并用 CADisplayLink 驱动帧循环。
//  刻意不做成单例——由 GameViewController 创建并持有。
//

import Foundation
import SceneKit
import QuartzCore

final class World {

    // MARK: - Scene graph roots（对应需求文档的节点结构）
    let scene = SCNScene()
    let rootNode: SCNNode
    let clockNode = SCNNode()
    let gearRoot = SCNNode()
    let pendulumRoot = SCNNode()
    let trackRoot = SCNNode()
    let mahjongRoot = SCNNode()
    let effectRoot = SCNNode()

    // MARK: - ECS storage
    private(set) var entities: [Entity] = []
    private var systems: [GameSystem] = []

    // MARK: - Shared services（通过构造注入，不用全局单例）
    let events: EventBus
    let random: SeededRandom

    // MARK: - Loop
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private(set) var isRunning = false

    init(events: EventBus, random: SeededRandom) {
        self.events = events
        self.random = random
        self.rootNode = scene.rootNode

        clockNode.name = "ClockNode"
        gearRoot.name = "GearRoot"
        pendulumRoot.name = "PendulumRoot"
        trackRoot.name = "TrackRoot"
        mahjongRoot.name = "MahjongRoot"
        effectRoot.name = "EffectRoot"

        rootNode.addChildNode(clockNode)
        rootNode.addChildNode(gearRoot)
        rootNode.addChildNode(pendulumRoot)
        rootNode.addChildNode(trackRoot)
        rootNode.addChildNode(mahjongRoot)
        rootNode.addChildNode(effectRoot)
    }

    // MARK: - Entity management
    @discardableResult
    func add(_ entity: Entity) -> Entity {
        entities.append(entity)
        return entity
    }

    func remove(_ entity: Entity) {
        entity.node.removeFromParentNode()
        entities.removeAll { $0 === entity }
    }

    /// 拉取拥有指定组件的实体。System 用它做筛选。
    func entities<C: Component>(with type: C.Type) -> [Entity] {
        entities.filter { $0.has(type) }
    }

    func firstEntity<C: Component>(with type: C.Type) -> Entity? {
        entities.first { $0.has(type) }
    }

    // MARK: - System management
    func addSystem(_ system: GameSystem) {
        systems.append(system)
        system.setup(world: self)
    }

    func system<S: GameSystem>(ofType type: S.Type) -> S? {
        for s in systems { if let hit = s as? S { return hit } }
        return nil
    }

    // MARK: - Loop control
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        var dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        // 掉帧保护：单帧最大步进 1/20 秒，避免物理穿透。
        if dt > 0.05 { dt = 0.05 }
        for system in systems {
            system.update(deltaTime: dt, world: self)
        }
    }

    deinit { stop() }
}
