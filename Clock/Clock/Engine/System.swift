//
//  System.swift
//  Clock
//
//  ECS 核心：GameSystem 承载逻辑。刻意拆成多个 System，
//  避免把所有逻辑堆进单个 update(deltaTime:)。
//  （命名为 GameSystem 而非 System，规避与 Swift `System` 模块冲突。）
//

import Foundation

/// 系统协议。每个系统只关心自己的一类组件。
protocol GameSystem: AnyObject {
    /// 系统挂载到 World 时调用一次。
    func setup(world: World)
    /// 每帧推进。deltaTime 单位秒。
    func update(deltaTime: TimeInterval, world: World)
}

extension GameSystem {
    func setup(world: World) {}
}
