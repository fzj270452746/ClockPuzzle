//
//  LevelData.swift
//  Clock
//
//  关卡数据模型。需求文档强制：所有关卡必须 JSON 化，禁止 switch(level)。
//  这里全部用 Codable + 语义化枚举，让关卡成为纯数据。
//

import Foundation
import CoreGraphics

// MARK: - 花色 / 特殊能力（对应“麻将属性”）

enum Suit: String, Codable {
    case wan       // 万：重、惯性大、速度慢
    case bamboo    // 条：轻、快
    case dot       // 筒：平衡
    case dragon    // Dragon Tile：激活机关
    case white     // White Tile：无视一次陷阱

    /// 质量（影响物理惯性）。数值取自需求文档的相对权重。
    var mass: CGFloat {
        switch self {
        case .wan:    return 4.0
        case .bamboo: return 1.6
        case .dot:    return 2.6
        case .dragon: return 3.0
        case .white:  return 2.2
        }
    }

    var ability: Ability? {
        switch self {
        case .dragon: return .activateMechanism
        case .white:  return .ignoreOneTrap
        default:      return nil
        }
    }
}

enum Ability: String, Codable {
    case activateMechanism
    case ignoreOneTrap
}

// MARK: - 三维向量（Codable，桥接 SceneKit 时再转 SCNVector3）

struct Vec3: Codable {
    var x: Float
    var y: Float
    var z: Float
    init(_ x: Float, _ y: Float, _ z: Float) { self.x = x; self.y = y; self.z = z }
}

// MARK: - 机械组件数据

struct GearData: Codable {
    let id: Int
    let radius: CGFloat
    let teethCount: Int
    let thickness: CGFloat
    /// 联动的其他齿轮 id（对应“联动齿轮”）。
    let linkedGearIds: [Int]
    /// 基础转速（度/秒），正为顺时针。
    let rotationSpeed: Float
    let position: Vec3
    /// 是否为“动力齿轮”（大齿轮提供动力）。
    let isDriver: Bool
}

struct PendulumData: Codable {
    let id: Int
    /// 摆幅（度）。
    let amplitude: Float
    /// 周期（秒）。
    let period: Float
    let armLength: CGFloat
    let bobRadius: CGFloat
    let position: Vec3
}

/// 时间门：仅在指定时刻打开（对应 08:00 / 12:30 / 18:45）。
struct TimeGateData: Codable {
    let id: Int
    /// 打开所需的“当日分钟数”（0...1439）。
    let openAtMinutes: Int
    let position: Vec3
    let size: Vec3
}

/// 机械桥：随时间展开/收回。
struct BridgeData: Codable {
    let id: Int
    /// 展开所需最小分钟数（到达半点等条件由 targetTime 驱动的角度决定）。
    let extendAtMinutes: Int
    let position: Vec3
    let length: CGFloat
}

/// 轨道段（program 生成的管道 / 平台）。
struct TrackData: Codable {
    let id: Int
    let position: Vec3
    let size: Vec3
    /// 绕 z 轴的倾角（度）。时针旋转会改变平台角度——这里给初始角。
    let tiltDegrees: Float
    /// 该平台角度是否受“时针”驱动。
    let hourDriven: Bool
}

struct ExitData: Codable {
    let id: Int
    let position: Vec3
    let radius: CGFloat
}

struct TileSpawnData: Codable {
    let suit: Suit
    let position: Vec3
}

// MARK: - 关卡

struct LevelData: Codable {
    let id: Int
    let title: String
    let chapter: Int
    /// 起始时间（当日分钟数）。
    let startMinutes: Int
    /// 目标时间（提示：把时钟调到这里通常能解）。
    let targetMinutes: Int
    /// 关卡限时（秒），需求文档 60~180。
    let timeLimit: TimeInterval

    let tile: TileSpawnData
    let tracks: [TrackData]
    let gears: [GearData]
    let pendulums: [PendulumData]
    let timeGates: [TimeGateData]
    let bridges: [BridgeData]
    let exits: [ExitData]

    /// 用于 SeededRandom 的种子，保证同一关卡表现可复现。
    let seed: UInt64
}
