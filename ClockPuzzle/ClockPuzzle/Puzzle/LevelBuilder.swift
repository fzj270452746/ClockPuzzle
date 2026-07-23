//
//  LevelBuilder.swift
//  Clock
//
//  关卡装配器。把 LevelData（纯数据）翻译成 World 里的实体与节点：
//  轨道/平台、齿轮、钟摆、时间门、桥梁、出口、麻将。
//  它是 Data 层与运行时 ECS 之间的桥，逻辑仍在各 System 里。
//

import Foundation
import SceneKit

struct LevelBuilder {

    /// 依据关卡数据填充 world。返回麻将实体（供 UI 聚焦）。
    @discardableResult
    static func build(_ level: LevelData, into world: World) -> Entity {
        var rng = SeededRandom(seed: level.seed)

        buildTracks(level, world)
        buildGears(level, world)
        buildPendulums(level, world)
        buildGates(level, world)
        buildBridges(level, world)
        buildExits(level, world)

        // 麻将：万/条/筒才有数字，取 1...9 里的一个（可复现）。
        let number = rng.int(in: 1...9)
        let tile = MahjongFactory.make(id: 10_000, data: level.tile, number: number, into: world)
        world.add(tile)
        anchorTileOnStartTrack(tile, level: level, world: world)
        return tile
    }

    /// 把麻将吸附到它出生所在的那段坡面上（成为坡节点的子节点）。
    ///
    /// 病因：牌出生点若是写死的绝对世界坐标，一旦坡是 hourDriven（绕自身中心旋转），
    /// 玩家调时间 → 坡转动 → 坡从牌底下转走 → 牌悬空 → Release 后垂直坠落判负。
    /// 修法：让牌成为坡节点的子节点，用坡的【局部坐标】表达位置。这样坡怎么转，
    /// 牌都始终贴在坡面上；释放时再摘回世界坐标系（见 MahjongController）。
    ///
    /// 选坡规则：优先选 hourDriven 坡（它会转，必须绑定）；否则选牌出生 x 落在其
    /// 水平范围内的那段静止坡（第 1/2 章用静止坡，牌同样要贴在坡面而非悬空世界坐标）。
    private static func anchorTileOnStartTrack(_ tile: Entity, level: LevelData, world: World) {
        let track = pickStartTrack(level)
        guard let track,
              let trackNode = world.trackRoot.childNode(withName: "track_\(track.id)", recursively: false)
        else { return }

        // 坡面顶面在局部 +y = 厚度一半处；牌底再抬起牌高一半 + 一点点间隙。
        let surfaceY = track.size.y / 2 + MahjongFactory.tileSize.y / 2 + 0.02
        // 牌沿坡长方向的落点：把出生点世界 x 换算成坡的局部 x（减去坡中心 x），
        // 并夹到坡内 ±42% 半长，确保稳落在坡面内而非坡沿外。
        let localXRaw = level.tile.position.x - track.position.x
        let halfSpan = track.size.x * 0.42
        let localX = max(-halfSpan, min(halfSpan, localXRaw))

        let node = tile.node
        node.removeFromParentNode()
        node.position = SCNVector3(localX, surfaceY, 0)
        node.eulerAngles = SCNVector3Zero    // 让牌与坡面局部系对齐，随坡一起转
        trackNode.addChildNode(node)
    }

    /// 选择牌的吸附坡：先 hourDriven，再按出生 x 落在水平范围内的坡，兜底取第一段。
    private static func pickStartTrack(_ level: LevelData) -> TrackData? {
        if let driven = level.tracks.first(where: { $0.hourDriven }) { return driven }
        let x = level.tile.position.x
        if let hit = level.tracks.first(where: { abs(x - $0.position.x) <= $0.size.x / 2 }) {
            return hit
        }
        return level.tracks.first
    }

    // MARK: - 各部分装配

    private static func buildTracks(_ level: LevelData, _ world: World) {
        for t in level.tracks {
            let geo = GeometryFactory.platform(size: t.size)
            let node = SCNNode(geometry: geo)
            node.position = t.position.scnVector
            node.name = "track_\(t.id)"
            // 受时针驱动的斜坡会在运行时旋转 eulerAngles.z：必须用 kinematic 刚体，
            // 否则 static 刚体的碰撞面只在初始化读一次 transform，之后永远固定不动，
            // 导致“调时间改坡度”在物理层完全失效（视觉在转、碰撞面没转）。
            // 固定不动的轨道才用 static。
            // 注意摩擦：滑坡必须用低摩擦（≈0.25），否则 tan(倾角) < 摩擦系数，牌卡住不滑。
            // makeKinematicBody 默认 0.7 太高（那是给挡块/齿轮用的），这里单独建低摩擦体。
            if t.hourDriven {
                makeRampBody(node, kinematic: true)
            } else {
                makeRampBody(node, kinematic: false)
            }

            let entity = Entity(id: 20_000 + t.id, name: "track_\(t.id)", node: node)
            entity.attach(TiltPlatformComponent(baseTiltDegrees: t.tiltDegrees,
                                                 hourDriven: t.hourDriven,
                                                 platformNode: node))
            world.trackRoot.addChildNode(node)
            world.add(entity)
        }
    }

    private static func buildGears(_ level: LevelData, _ world: World) {
        for g in level.gears {
            let geo = GeometryFactory.gear(radius: g.radius, teeth: g.teethCount, thickness: g.thickness)
            let node = SCNNode(geometry: geo)
            node.position = g.position.scnVector
            node.name = "gear_\(g.id)"
            makeKinematicBody(node)

            let entity = Entity(id: 30_000 + g.id, name: "gear_\(g.id)", node: node)
            let speedRad = CGFloat(g.rotationSpeed) * .pi / 180   // 度/秒 → 弧度/秒
            entity.attach(GearComponent(
                id: g.id,
                teethCount: g.teethCount,
                radius: g.radius,
                baseAngularSpeed: speedRad,
                isDriver: g.isDriver,
                linkedGearIds: g.linkedGearIds,
                spinNode: node
            ))
            world.gearRoot.addChildNode(node)
            world.add(entity)
        }
    }

    private static func buildPendulums(_ level: LevelData, _ world: World) {
        for p in level.pendulums {
            let pivot = GeometryFactory.pendulum(armLength: p.armLength, bobRadius: p.bobRadius)
            pivot.position = p.position.scnVector
            pivot.name = "pendulum_\(p.id)"
            // 摆锤给 kinematic 体，用于击打麻将。
            if let bob = pivot.childNode(withName: "bob", recursively: true) {
                makeKinematicBody(bob)
            }
            let entity = Entity(id: 40_000 + p.id, name: "pendulum_\(p.id)", node: pivot)
            entity.attach(PendulumComponent(amplitudeDegrees: p.amplitude,
                                            period: p.period,
                                            phase: 0,
                                            armNode: pivot))
            world.pendulumRoot.addChildNode(pivot)
            world.add(entity)
        }
    }

    private static func buildGates(_ level: LevelData, _ world: World) {
        for gate in level.timeGates {
            let box = SCNBox(width: CGFloat(gate.size.x), height: CGFloat(gate.size.y),
                             length: CGFloat(gate.size.z), chamferRadius: 0.02)
            box.firstMaterial = TextureFactory.material(.copper)
            let node = SCNNode(geometry: box)
            node.position = gate.position.scnVector
            node.name = "gate_\(gate.id)"
            makeKinematicBody(node)

            let entity = Entity(id: 50_000 + gate.id, name: "gate_\(gate.id)", node: node)
            entity.attach(TimeGateComponent(openAtMinutes: gate.openAtMinutes, gateNode: node))
            world.trackRoot.addChildNode(node)
            world.add(entity)
        }
    }

    private static func buildBridges(_ level: LevelData, _ world: World) {
        for b in level.bridges {
            let box = SCNBox(width: CGFloat(b.length), height: 0.12, length: 0.8, chamferRadius: 0.02)
            box.firstMaterial = TextureFactory.material(.wood)
            let node = SCNNode(geometry: box)
            node.position = b.position.scnVector
            node.name = "bridge_\(b.id)"
            // 让锚点在左端，向右展开。
            node.pivot = SCNMatrix4MakeTranslation(Float(-b.length / 2), 0, 0)
            makeKinematicBody(node)

            let entity = Entity(id: 60_000 + b.id, name: "bridge_\(b.id)", node: node)
            entity.attach(BridgeComponent(extendAtMinutes: b.extendAtMinutes, deckNode: node))
            world.trackRoot.addChildNode(node)
            world.add(entity)
        }
    }

    private static func buildExits(_ level: LevelData, _ world: World) {
        for ex in level.exits {
            // 出口用铜色圆环表示（发条盒观感）。
            let ring = SCNTorus(ringRadius: ex.radius, pipeRadius: ex.radius * 0.14)
            ring.firstMaterial = TextureFactory.material(.copper)
            let node = SCNNode(geometry: ring)
            node.position = ex.position.scnVector
            node.eulerAngles.x = .pi / 2    // 立起来朝向玩家
            node.name = "exit_\(ex.id)"

            let entity = Entity(id: 70_000 + ex.id, name: "exit_\(ex.id)", node: node)
            entity.attach(ExitComponent(id: ex.id, radius: ex.radius))
            world.trackRoot.addChildNode(node)
            world.add(entity)
        }
    }

    // MARK: - 物理体辅助

    private static func makeStaticBody(_ node: SCNNode) {
        guard let geo = node.geometry else { return }
        let shape = SCNPhysicsShape(geometry: geo, options: nil)
        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = PhysicsCategory.structure
        body.friction = 0.25
        node.physicsBody = body
    }

    /// 滑坡专用刚体：低摩擦（0.25），保证牌能沿倾角下滑。
    /// hourDriven 坡会旋转，必须 kinematic（碰撞面随节点 transform 更新）；
    /// 固定坡用 static。二者摩擦一致，滑动手感不受“是否随时间转”影响。
    private static func makeRampBody(_ node: SCNNode, kinematic: Bool) {
        guard let geo = node.geometry else { return }
        let shape = SCNPhysicsShape(geometry: geo, options: nil)
        let body = SCNPhysicsBody(type: kinematic ? .kinematic : .static, shape: shape)
        body.categoryBitMask = PhysicsCategory.structure
        body.friction = 0.25
        node.physicsBody = body
    }

    private static func makeKinematicBody(_ node: SCNNode) {
        guard let geo = node.geometry else { return }
        let shape = SCNPhysicsShape(geometry: geo, options: nil)
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.categoryBitMask = PhysicsCategory.structure
        body.friction = 0.7
        node.physicsBody = body
    }
}
