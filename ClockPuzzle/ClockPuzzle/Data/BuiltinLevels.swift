//
//  BuiltinLevels.swift
//  Clock
//
//  内置关卡工厂。需求禁止 switch(level) 硬编码逻辑：这里用「章节参数表 +
//  按章分派的布局生成器」按关卡 id 参数化生成 *数据*（LevelData），产出可被 JSON 覆盖。
//
//  设计要点（为什么这样写）：
//   - 每个章节有【本质不同】的核心解法，围绕“调时钟”这个核心动词展开：
//       0 单坡调坡度 / 1 时间门放行 / 2 机械桥补缺 / 3 坡+门双条件 / 4 全机构组合。
//     旧版对每关都吐同一条坡、机构全是碰不到牌的装饰，导致 2~200 关玩法雷同。
//   - 分派靠 chapters 表里的 layout 标签查表，不是 switch(id) 逻辑分支。
//   - 可解性铁律（否则关卡数学上无法通关）：
//       * startMinutes 必须对齐 5 分钟网格：门/桥只在 |分钟-目标|≤4 触发，目标恒为
//         30 的倍数，玩家用 ±5m/±1h 步进，从任意分钟出发永远命中不了 30 的倍数。
//       * 坡要能滑：tan(倾角) 需大于牌+坡摩擦和(≈0.25→14°)，静止坡给 ≥16°。
//       * 断口必须有桥能补上；桥/门若同关出现，共用同一目标时刻，避免要求两个时刻。
//

import Foundation
import CoreGraphics

enum BuiltinLevels {

    /// 章节可用的核心布局（数据标签，供 make 查表分派，非逻辑分支）。
    private enum Layout {
        case workshop      // 第0章：单条时针驱动坡，调坡度
        case pendulumHall  // 第1章：静止坡 + 时间门 + 掠过的钟摆
        case gearCastle    // 第2章：两段坡 + 断口 + 机械桥
        case tower         // 第3章：偏缓的时针驱动坡 + 时间门（双条件）
        case dragonClock   // 第4章：两段坡+桥+门 全组合
    }

    /// 章节配置（数据表，非逻辑分支）。对应需求文档五个章节。
    private struct ChapterSpec {
        let index: Int
        let range: ClosedRange<Int>
        let name: String
        let layout: Layout
    }

    private static let chapters: [ChapterSpec] = [
        ChapterSpec(index: 0, range: 1...20,    name: "Clock Workshop",   layout: .workshop),
        ChapterSpec(index: 1, range: 21...50,   name: "Pendulum Hall",    layout: .pendulumHall),
        ChapterSpec(index: 2, range: 51...90,   name: "Gear Castle",      layout: .gearCastle),
        ChapterSpec(index: 3, range: 91...140,  name: "Mechanical Tower", layout: .tower),
        ChapterSpec(index: 4, range: 141...200, name: "Dragon Clock",     layout: .dragonClock),
    ]

    private static func chapterSpec(for id: Int) -> ChapterSpec {
        chapters.first { $0.range.contains(id) } ?? chapters[0]
    }

    /// 可选花色表（Dragon / White 作为特殊关卡奖励，周期性出现）。
    private static let normalSuits: [Suit] = [.wan, .bamboo, .dot]

    /// 一关的机构集合（各 layout 函数产出，再由 make 组装成 LevelData）。
    fileprivate struct Parts {
        var tracks: [TrackData] = []
        var gears: [GearData] = []
        var pendulums: [PendulumData] = []
        var gates: [TimeGateData] = []
        var bridges: [BridgeData] = []
        var exits: [ExitData] = []
        var tile: TileSpawnData
    }

    /// 生成一关。相同 id 永远得到相同结果（种子由 id 派生）。
    static func make(id: Int) -> LevelData {
        let ch = chapterSpec(for: id)
        let seed = UInt64(bitPattern: Int64(id)) &* 0x9E3779B97F4A7C15
        var rng = SeededRandom(seed: seed)

        // 目标时间：对齐到半点（30 的倍数），门/桥的 openAt/extendAt 都用它。
        let targetSlot = rng.int(in: 0...47)          // 每 30 分钟一个槽位
        let targetMinutes = targetSlot * 30

        // 起始时间：必须对齐 5 分钟网格，否则 ±5m 步进永远命中不了 30 倍数的门/桥目标。
        // 再故意与 targetMinutes 错开，让"调时间"成为必要操作。
        let startMinutes = alignedStart(rng: &rng, awayFrom: targetMinutes)

        // 特殊牌：每 25 关给一次 Dragon / White，其余从常规花色里挑。
        let suit: Suit
        if id % 25 == 0 {
            suit = (id / 25) % 2 == 0 ? .dragon : .white
        } else {
            suit = rng.pick(normalSuits) ?? .dot
        }

        // 按章分派布局。每个 layout 在安全范围内用 rng 微调，保证可复现变化且可通。
        let parts: Parts
        switch ch.layout {
        case .workshop:     parts = layoutWorkshop(suit: suit, rng: &rng)
        case .pendulumHall: parts = layoutPendulumHall(suit: suit, targetMinutes: targetMinutes, rng: &rng)
        case .gearCastle:   parts = layoutGearCastle(suit: suit, targetMinutes: targetMinutes, rng: &rng)
        case .tower:        parts = layoutTower(suit: suit, targetMinutes: targetMinutes, rng: &rng)
        case .dragonClock:  parts = layoutDragonClock(suit: suit, targetMinutes: targetMinutes, rng: &rng)
        }

        // 限时：随 id 线性收紧，但给足已知解法时间（下限 70 秒）。
        let timeLimit = TimeInterval(max(70, 180 - min(id, 200) / 2))

        return LevelData(
            id: id,
            title: "\(ch.name) #\(id)",
            chapter: ch.index,
            startMinutes: startMinutes,
            targetMinutes: targetMinutes,
            timeLimit: timeLimit,
            tile: parts.tile,
            tracks: parts.tracks,
            gears: parts.gears,
            pendulums: parts.pendulums,
            timeGates: parts.gates,
            bridges: parts.bridges,
            exits: parts.exits,
            seed: seed
        )
    }
}

// MARK: - 时间/工具

private extension BuiltinLevels {

    /// 生成对齐到 5 分钟网格、且与目标时刻错开的起始时间。
    /// 错开保证"调时间"是通关的必要操作（否则一开局就命中门/桥目标）。
    static func alignedStart(rng: inout SeededRandom, awayFrom target: Int) -> Int {
        let slots = (24 * 60) / 5                 // 288 个 5 分钟槽
        for _ in 0..<8 {                          // 有限次重试，避开目标 ±15 分钟
            let m = rng.int(in: 0...(slots - 1)) * 5
            if abs(m - target) > 15 { return m }
        }
        // 兜底：目标 + 65 分钟并夹回一天内、对齐 5 分钟。
        return (((target + 65) % (24 * 60)) / 5) * 5
    }

    /// 由坡的几何【反推】出生点 x 与出口位置，保证任何坡参数都自洽可通。
    ///
    /// 病因（本次修复的核心）：旧版每关把出生点、出口都写成固定世界坐标，只让倾角
    /// 抖动 ±2°，于是同章 20~50 关看着玩着完全一样。要让每关真的不同，就得让坡的
    /// 中心/长度/倾角按 id 大幅变化——可一旦坡动了，写死的出生点/出口就会脱离坡面，
    /// 关卡变得无解。修法：不再写死，而是从坡几何推导：负倾角 = 左端高，牌落左高端，
    /// 出口置右低端外侧稍下方。这样坡怎么变，路径始终连着，既有可见差异又必然可通。
    ///
    /// 返回：(牌出生点 x，出口位置)。牌的 y 由 LevelBuilder 依坡面重算，这里只定 x。
    static func spawnX(rampCenter c: Vec3, length: Float, tiltDeg: Float) -> Float {
        let a = abs(tiltDeg) * .pi / 180
        let halfRun = (length / 2) * cos(a)
        // 出生点落在坡高端（左端）内侧一点，避免正好悬在坡沿外。
        return c.x - halfRun * 0.82
    }

    static func exitPos(rampCenter c: Vec3, length: Float, tiltDeg: Float) -> Vec3 {
        let a = abs(tiltDeg) * .pi / 180
        let halfRun = (length / 2) * cos(a)
        let halfRise = (length / 2) * sin(a)
        // 出口置于坡低端（右端）外侧、再往下一截：牌滑出坡沿后自然落入。
        return Vec3(c.x + halfRun + 0.35, c.y - halfRise - 0.55, 0)
    }
}

// MARK: - 第0章 Clock Workshop：单条时针驱动坡（教学，保持已验证可通的布局）

private extension BuiltinLevels {

    static func layoutWorkshop(suit: Suit, rng: inout SeededRandom) -> Parts {
        // 一条【连续不断】的时针驱动斜坡：调时间加大坡度把牌导向出口。
        // 每关让坡的中心高度、长度、基础倾角都在安全范围内实质变化（不再是写死一条坡），
        // 出生点与出口由坡几何反推，保证怎么变都自洽可通——这才是同章每关“看着玩着都不同”。
        let tilt = -13 - rng.float(in: 0..<3.0)              // -13 ~ -16°，sin 加成后必滑
        let length = 4.2 + rng.float(in: 0..<1.2)            // 坡长 4.2 ~ 5.4
        let cx = -0.3 + rng.float(in: 0..<0.6)               // 坡中心左右浮动
        let cy = -0.2 + rng.float(in: 0..<0.5)               // 坡中心高低浮动
        let center = Vec3(cx, cy, 0)
        let ramp = TrackData(id: 0,
                             position: center,
                             size: Vec3(length, 0.16, 1.0),
                             tiltDegrees: tilt,
                             hourDriven: true)
        let exit = ExitData(id: 0,
                            position: exitPos(rampCenter: center, length: length, tiltDeg: tilt),
                            radius: 0.8)
        // 装饰齿轮藏在后景(z=-0.9)，纯章节主题，碰不到牌。
        let gears = decorGears(count: rng.int(in: 1...2), rng: &rng)
        // 出生点由坡几何反推（负倾角时左端最高）。
        let tile = TileSpawnData(suit: suit,
                                 position: Vec3(spawnX(rampCenter: center, length: length, tiltDeg: tilt),
                                                center.y + 1.0, 0))
        return Parts(tracks: [ramp], gears: gears, exits: [exit], tile: tile)
    }
}

// MARK: - 第1章 Pendulum Hall：静止坡 + 时间门 + 掠过的钟摆

private extension BuiltinLevels {

    static func layoutPendulumHall(suit: Suit, targetMinutes: Int, rng: inout SeededRandom) -> Parts {
        // 静止坡：倾角 ≥16° 保证牌一放就滑（tan16°≈0.29 > 摩擦和 0.25）。
        // 坡长/中心每关变化，门与钟摆的 x 都跟着坡走，出生点/出口由几何反推。
        let tilt = -17 - rng.float(in: 0..<2.0)              // -17 ~ -19°
        let length = 4.6 + rng.float(in: 0..<1.0)            // 4.6 ~ 5.6
        let cx = -0.1 + rng.float(in: 0..<0.4)
        let cy = -0.2 + rng.float(in: 0..<0.3)
        let center = Vec3(cx, cy, 0)
        let ramp = TrackData(id: 0,
                             position: center,
                             size: Vec3(length, 0.16, 1.0),
                             tiltDegrees: tilt,
                             hourDriven: false)

        // 时间门横在坡中段：关闭时门体探入坡面上方挡住牌；到 targetMinutes 升起让路。
        // 门 x 取坡中心偏低端一点（牌先滑一段再遇门），随坡浮动而非写死。
        let gateX = center.x + Float(rng.float(in: 0.0..<0.5))
        let gateY = center.y + 0.45
        let gate = TimeGateData(id: 0,
                                openAtMinutes: targetMinutes,
                                position: Vec3(gateX, gateY, 0),
                                size: Vec3(0.25, 1.0, 0.8))

        // 钟摆：bob 在坡面【上方 ≥0.86】掠过，只做视觉威慑不阻断路径（不受时钟控）。
        // pivot 置于门前上方，x 随门走，制造“趁摆锤荡开的空档 Release”的手感。
        let pend = PendulumData(id: 0,
                                amplitude: 28 + rng.float(in: 0..<10),
                                period: 1.6 + rng.float(in: 0..<0.5),
                                armLength: 1.2,
                                bobRadius: 0.22,
                                position: Vec3(gateX - 0.6, center.y + 2.5, 0))

        let exit = ExitData(id: 0,
                            position: exitPos(rampCenter: center, length: length, tiltDeg: tilt),
                            radius: 0.8)
        let tile = TileSpawnData(suit: suit,
                                 position: Vec3(spawnX(rampCenter: center, length: length, tiltDeg: tilt),
                                                center.y + 1.1, 0))
        return Parts(tracks: [ramp], pendulums: [pend], gates: [gate], exits: [exit], tile: tile)
    }
}

// MARK: - 第2章 Gear Castle：两段坡 + 断口 + 机械桥

private extension BuiltinLevels {

    static func layoutGearCastle(suit: Suit, targetMinutes: Int, rng: inout SeededRandom) -> Parts {
        // 两段坡 + 断口 + 桥。整条链按 id 平移/缩放，桥始终锚在上段右端对准断口，
        // 下段接桥末端——用几何串联而非写死坐标，保证每关不同且断口必有桥补。
        let tiltA = -16 - rng.float(in: 0..<2.0)
        let lenA = 2.2 + rng.float(in: 0..<0.8)              // 上段 2.2 ~ 3.0
        let upperCx = -1.5 + rng.float(in: 0..<0.4)
        let upperCy = 0.3 + rng.float(in: 0..<0.3)
        let upperCenter = Vec3(upperCx, upperCy, 0)
        let upper = TrackData(id: 0,
                              position: upperCenter,
                              size: Vec3(lenA, 0.16, 1.0),
                              tiltDegrees: tiltA,
                              hourDriven: false)

        // 上段右端（低端）坐标：断口从这里开始。
        let aRun = (lenA / 2) * cosf(abs(tiltA) * .pi / 180)
        let aRise = (lenA / 2) * sinf(abs(tiltA) * .pi / 180)
        let upperRightX = upperCx + aRun
        let upperRightY = upperCy - aRise

        // 断口宽度（桥长），按关变化；桥 pivot 在左端向右展开补上缺口。
        let bridgeLen: Float = 1.2 + rng.float(in: 0..<0.5)
        let bridge = BridgeData(id: 0,
                                extendAtMinutes: targetMinutes,
                                position: Vec3(upperRightX + 0.05, upperRightY - 0.1, 0),
                                length: CGFloat(bridgeLen))

        // 下段坡：左端接桥末端，继续向右下导向出口。
        let tiltB = -16 - rng.float(in: 0..<2.0)
        let lenB = 2.0 + rng.float(in: 0..<0.8)
        let bRun = (lenB / 2) * cosf(abs(tiltB) * .pi / 180)
        let bRise = (lenB / 2) * sinf(abs(tiltB) * .pi / 180)
        let lowerLeftX = upperRightX + bridgeLen + 0.05
        let lowerCx = lowerLeftX + bRun
        let lowerCy = upperRightY - 0.1 - bRise
        let lowerCenter = Vec3(lowerCx, lowerCy, 0)
        let lower = TrackData(id: 1,
                              position: lowerCenter,
                              size: Vec3(lenB, 0.16, 1.0),
                              tiltDegrees: tiltB,
                              hourDriven: false)

        let exit = ExitData(id: 0,
                            position: exitPos(rampCenter: lowerCenter, length: lenB, tiltDeg: tiltB),
                            radius: 0.8)
        let gears = decorGears(count: rng.int(in: 2...3), rng: &rng)
        // 出生点落在上段坡高端（由几何反推）。
        let tile = TileSpawnData(suit: suit,
                                 position: Vec3(spawnX(rampCenter: upperCenter, length: lenA, tiltDeg: tiltA),
                                                upperCy + 1.1, 0))
        return Parts(tracks: [upper, lower], gears: gears, bridges: [bridge], exits: [exit], tile: tile)
    }
}

// MARK: - 第3章 Mechanical Tower：偏缓的时针驱动坡 + 时间门（双条件）

private extension BuiltinLevels {

    static func layoutTower(suit: Suit, targetMinutes: Int, rng: inout SeededRandom) -> Parts {
        // 坡故意偏缓（-7~-9°，tan≈0.12~0.16 < 摩擦和 0.25）：静止时牌卡住不滑。
        // 必须调时钟让 sin(hourAngle)*15° 把坡压陡（sin<0 的 6:00-12:00 段）才滑。
        // 基础倾角只能在这个窄窗口内变（守住“静止卡死”语义），但坡中心/长度、门位置
        // 按 id 变化，出生点/出口由几何反推，让每关布局仍有可见差异。
        let tilt = -7 - rng.float(in: 0..<2.0)               // -7 ~ -9°
        let length = 4.6 + rng.float(in: 0..<1.0)
        let cx = -0.1 + rng.float(in: 0..<0.4)
        let cy = -0.1 + rng.float(in: 0..<0.3)
        let center = Vec3(cx, cy, 0)
        let ramp = TrackData(id: 0,
                             position: center,
                             size: Vec3(length, 0.16, 1.0),
                             tiltDegrees: tilt,
                             hourDriven: true)

        // 门的开启时刻取 towerGateMinutes：落在 sin(hourAngle)<0 的时段（坡此时够陡），
        // 于是"门开"与"坡陡"在同一时刻成立，双条件有解。
        let gateOpen = towerGateMinutes(near: targetMinutes)
        let gate = TimeGateData(id: 0,
                                openAtMinutes: gateOpen,
                                position: Vec3(center.x + Float(rng.float(in: 0.0..<0.5)), center.y + 0.4, 0),
                                size: Vec3(0.25, 1.0, 0.8))

        let exit = ExitData(id: 0,
                            position: exitPos(rampCenter: center, length: length, tiltDeg: tilt),
                            radius: 0.8)
        let gears = decorGears(count: rng.int(in: 3...4), rng: &rng)
        let tile = TileSpawnData(suit: suit,
                                 position: Vec3(spawnX(rampCenter: center, length: length, tiltDeg: tilt),
                                                center.y + 1.0, 0))
        return Parts(tracks: [ramp], gears: gears, gates: [gate], exits: [exit], tile: tile)
    }

    /// 把门开启时刻规整到 sin(hourAngle)<0 的时段（6:00-12:00，即 minutes∈(360,720)）的
    /// 30 倍数。该时段时针驱动坡被压陡到能滑，保证"门开=坡陡"同刻成立。
    static func towerGateMinutes(near target: Int) -> Int {
        // 映射到 12 小时制里的分钟(0...719)，落在 (360,720) 段。
        let base = target % 720
        // 取 07:30-10:30 之间的 30 倍数槽。收窄到这段是因为端点(06:30/11:30)
        // 处 sin 幅度不足，坡只压到 -11.9°(tan≈0.21<0.25 牌卡死，无解)。
        // 07:30~10:30 段 sin 幅度足够，坡角 ≤-18°，tan>0.32，牌必滑。
        let slotsStart = 450 / 30      // 07:30 → 槽 15
        let slotsEnd = 630 / 30        // 10:30 → 槽 21
        let span = slotsEnd - slotsStart + 1
        let slot = slotsStart + (abs(base) / 30) % span
        return slot * 30
    }
}

// MARK: - 第4章 Dragon Clock：两段坡 + 桥 + 门 全组合

private extension BuiltinLevels {

    static func layoutDragonClock(suit: Suit, targetMinutes: Int, rng: inout SeededRandom) -> Parts {
        // 复用第2章"两段坡+桥"几何串联骨架，路径更长，再在下段坡上加一道门。
        // 桥与门共用 targetMinutes：一次调时同时展开桥、升起门，避免要求两个不同时刻（无解）。
        let tiltA = -16 - rng.float(in: 0..<2.0)
        let lenA = 2.2 + rng.float(in: 0..<0.8)
        let upperCx = -1.6 + rng.float(in: 0..<0.4)
        let upperCy = 0.5 + rng.float(in: 0..<0.3)
        let upperCenter = Vec3(upperCx, upperCy, 0)
        let upper = TrackData(id: 0,
                              position: upperCenter,
                              size: Vec3(lenA, 0.16, 1.0),
                              tiltDegrees: tiltA,
                              hourDriven: false)

        let aRun = (lenA / 2) * cosf(abs(tiltA) * .pi / 180)
        let aRise = (lenA / 2) * sinf(abs(tiltA) * .pi / 180)
        let upperRightX = upperCx + aRun
        let upperRightY = upperCy - aRise

        let bridgeLen: Float = 1.2 + rng.float(in: 0..<0.5)
        let bridge = BridgeData(id: 0,
                                extendAtMinutes: targetMinutes,
                                position: Vec3(upperRightX + 0.05, upperRightY - 0.1, 0),
                                length: CGFloat(bridgeLen))

        let tiltB = -16 - rng.float(in: 0..<2.0)
        let lenB = 2.2 + rng.float(in: 0..<0.8)
        let bRun = (lenB / 2) * cosf(abs(tiltB) * .pi / 180)
        let bRise = (lenB / 2) * sinf(abs(tiltB) * .pi / 180)
        let lowerLeftX = upperRightX + bridgeLen + 0.05
        let lowerCx = lowerLeftX + bRun
        let lowerCy = upperRightY - 0.1 - bRise
        let lowerCenter = Vec3(lowerCx, lowerCy, 0)
        let lower = TrackData(id: 1,
                              position: lowerCenter,
                              size: Vec3(lenB, 0.16, 1.0),
                              tiltDegrees: tiltB,
                              hourDriven: false)

        // 门横在下段坡中段（x 由下段几何定），与桥共用 targetMinutes（同刻放行）。
        let gate = TimeGateData(id: 0,
                                openAtMinutes: targetMinutes,
                                position: Vec3(lowerCx, lowerCy + 0.45, 0),
                                size: Vec3(0.25, 1.0, 0.8))

        let exit = ExitData(id: 0,
                            position: exitPos(rampCenter: lowerCenter, length: lenB, tiltDeg: tiltB),
                            radius: 0.8)
        let gears = decorGears(count: rng.int(in: 3...5), rng: &rng)
        let tile = TileSpawnData(suit: suit,
                                 position: Vec3(spawnX(rampCenter: upperCenter, length: lenA, tiltDeg: tiltA),
                                                upperCy + 1.1, 0))
        return Parts(tracks: [upper, lower], gears: gears,
                     gates: [gate], bridges: [bridge], exits: [exit], tile: tile)
    }
}

// MARK: - 装饰齿轮（章节主题，放在后景 z=-0.9，物理上碰不到牌）

private extension BuiltinLevels {

    static func decorGears(count: Int, rng: inout SeededRandom) -> [GearData] {
        guard count > 0 else { return [] }
        var result: [GearData] = []
        for g in 0..<count {
            let teeth = rng.int(in: 8...20)
            let radius = CGFloat(0.5 + Double(teeth) * 0.03)
            let baseSpeed = 24.0 + rng.float(in: 0..<24.0)      // 度/秒
            let dir: Float = g % 2 == 0 ? 1 : -1
            result.append(GearData(
                id: g,
                radius: radius,
                teethCount: teeth,
                thickness: 0.18,
                linkedGearIds: g > 0 ? [g - 1] : [],
                rotationSpeed: dir * baseSpeed,
                // z=-0.9：装饰齿轮必须放在牌/坡平面(z=0)之后，否则旋转的齿轮(structure 刚体)
                // 会撞飞正在滑坡的牌。牌 z∈[-0.14,0.14] 够不到 z∈[-0.99,-0.81] 的齿轮。
                position: Vec3(Float(-1.3 + Double(g) * 1.15), 1.6, -0.9),
                isDriver: g == 0
            ))
        }
        return result
    }
}



