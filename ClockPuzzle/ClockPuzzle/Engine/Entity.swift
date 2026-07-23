//
//  Entity.swift
//  Clock
//
//  ECS 核心：Entity 是组件与 SceneKit 节点的容器。
//  故意不做任何游戏逻辑，逻辑全部下沉到 System。
//

import Foundation
import SceneKit

/// 组件标记协议。所有组件都是纯数据 / 轻行为，不持有全局引用。
protocol Component: AnyObject {
    /// 组件被挂载到实体时回调（可选）。
    func didAttach(to entity: Entity)
}

extension Component {
    func didAttach(to entity: Entity) {}
}

/// 实体：拥有一个 SceneKit 节点与若干组件。
/// 使用组合而非继承——不同实体的差异体现在“挂了哪些组件”。
final class Entity {

    /// 全局唯一 id（由 World 分配，非随机，保证可复现）。
    let id: Int

    /// 语义名，便于调试与按名查找。
    let name: String

    /// 该实体在场景图中的根节点。
    let node: SCNNode

    private(set) var components: [ObjectIdentifier: Component] = [:]

    init(id: Int, name: String, node: SCNNode = SCNNode()) {
        self.id = id
        self.name = name
        self.node = node
        self.node.name = name
    }

    // MARK: - 组件管理

    @discardableResult
    func attach<C: Component>(_ component: C) -> C {
        components[ObjectIdentifier(C.self)] = component
        component.didAttach(to: self)
        return component
    }

    func component<C: Component>(_ type: C.Type) -> C? {
        components[ObjectIdentifier(C.self)] as? C
    }

    func has<C: Component>(_ type: C.Type) -> Bool {
        components[ObjectIdentifier(C.self)] != nil
    }

    func detach<C: Component>(_ type: C.Type) {
        components.removeValue(forKey: ObjectIdentifier(C.self))
    }
}
