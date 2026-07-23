//
//  SeededRandom.swift
//  Clock
//
//  可复现随机数发生器。需求文档明确禁止 Int.random()，
//  统一走带种子的生成器，保证关卡可复现、易测试。
//
//  算法：SplitMix64。质量足够，速度快，实现简单。
//

import Foundation

/// 带种子的伪随机发生器。遵循 RandomNumberGenerator，
/// 因此可直接喂给标准库的 `Int.random(in:using:)` 等接口。
struct SeededRandom: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // 避免全 0 种子退化。
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    // MARK: - 便捷方法（刻意包装，业务层不直接调用标准库随机）

    /// [0, upperBound) 的整数。
    mutating func int(below upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound 必须为正")
        return Int(next() % UInt64(upperBound))
    }

    /// [lower, upper] 闭区间整数。
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + int(below: span)
    }

    /// [0, 1) 浮点。
    mutating func unit() -> Double {
        // 取高 53 位映射到 [0,1)。
        return Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// [lower, upper) 浮点。
    mutating func float(in range: Range<Float>) -> Float {
        return range.lowerBound + Float(unit()) * (range.upperBound - range.lowerBound)
    }

    /// 从数组里挑一个（可复现）。
    mutating func pick<T>(_ array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        return array[int(below: array.count)]
    }
}
