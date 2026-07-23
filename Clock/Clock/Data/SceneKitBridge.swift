//
//  SceneKitBridge.swift
//  Clock
//
//  Data 层的纯值类型（Vec3 等）到 SceneKit 类型的桥接。
//  刻意放在独立文件：让 Data 层保持不依赖 SceneKit，桥接是单向的。
//

import SceneKit

extension Vec3 {
    /// 转成 SceneKit 向量。
    var scnVector: SCNVector3 { SCNVector3(x, y, z) }
}

extension SCNVector3 {
    var vec3: Vec3 { Vec3(Float(x), Float(y), Float(z)) }
}

/// 物理碰撞分类位掩码。集中定义，避免散落魔法数字。
enum PhysicsCategory {
    static let tile: Int      = 1 << 0   // 麻将
    static let structure: Int = 1 << 1   // 轨道 / 平台 / 齿轮 / 桥 / 门
    static let exit: Int      = 1 << 2   // 出口触发区
    static let pendulum: Int  = 1 << 3   // 钟摆锤
}
