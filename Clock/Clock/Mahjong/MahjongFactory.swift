//
//  MahjongFactory.swift
//  Clock
//
//  麻将实体工厂。用 SCNBox + chamferRadius 生成圆角牌身（对应需求 SCNBox+Chamfer），
//  牌面贴 TileFaceRenderer 现绘的花色纹理，挂 PhysicsComponent / TileComponent。
//  麻将是全场唯一的 dynamic 刚体；释放前用 kinematic 冻结（见需求性能约束）。
//

import Foundation
import SceneKit

enum MahjongFactory {

    /// 牌身尺寸（米）。竖屏解谜场景里适中即可。
    static let tileSize = SCNVector3(0.42, 0.56, 0.28)

    /// 用关卡里的出生数据造一颗麻将实体，并挂入 world.mahjongRoot。
    /// - Parameter number: 牌面数字 1...9（Dragon/White 忽略）。
    static func make(id: Int, data: TileSpawnData, number: Int, into world: World) -> Entity {
        let suit = data.suit

        // MARK: 几何：圆角长方体
        let box = SCNBox(
            width: CGFloat(tileSize.x),
            height: CGFloat(tileSize.y),
            length: CGFloat(tileSize.z),
            chamferRadius: 0.06
        )

        // 六面材质：正面贴牌面，其余象牙白（牌背 / 侧面）。
        // SCNBox 材质顺序：前、右、后、左、上、下。
        let face = SCNMaterial()
        face.diffuse.contents = TileFaceRenderer.image(suit: suit, number: number)
        face.lightingModel = .physicallyBased
        face.roughness.contents = 0.4 as NSNumber
        let ivory = TextureFactory.material(.ivory)
        box.materials = [face, ivory,
                         ivory.copy() as! SCNMaterial,
                         ivory.copy() as! SCNMaterial,
                         ivory.copy() as! SCNMaterial,
                         ivory.copy() as! SCNMaterial]

        let node = SCNNode(geometry: box)
        node.position = data.position.scnVector
        node.name = "tile_\(id)"

        let entity = Entity(id: id, name: "tile_\(id)", node: node)

        // MARK: 物理体（释放前 kinematic 冻结在原地）
        let shape = SCNPhysicsShape(geometry: box, options: [
            .type: SCNPhysicsShape.ShapeType.boundingBox.rawValue
        ])
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.mass = suit.mass
        body.friction = 0.2
        body.rollingFriction = 0.02
        body.restitution = 0.02      // 几乎不反弹，避免落到斜坡上弹飞出轨道
        body.damping = 0.05
        body.angularDamping = 0.2
        body.categoryBitMask = PhysicsCategory.tile
        body.collisionBitMask = PhysicsCategory.structure | PhysicsCategory.pendulum
        body.contactTestBitMask = PhysicsCategory.structure | PhysicsCategory.exit
        node.physicsBody = body

        entity.attach(TileComponent(suit: suit, ability: suit.ability))
        entity.attach(PhysicsComponent(body: body, baseMass: suit.mass))

        world.mahjongRoot.addChildNode(node)
        return entity
    }
}
