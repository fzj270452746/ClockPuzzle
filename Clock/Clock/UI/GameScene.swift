//
//  GameScene.swift
//  Clock
//
//  场景装配：相机、灯光、地面、重力。把 World 的场景图补全为可渲染场景。
//  节点结构对齐需求文档：CameraNode / LightNode / ClockNode / *Root。
//

import SceneKit
import UIKit

enum GameScene {

    /// 为 world 配好相机、灯光、地面与物理世界参数。
    static func configure(_ world: World) {
        let scene = world.scene

        // 物理：标准重力（麻将下落）。机构 kinematic 不受影响。
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)

        // 背景：轻机械朋克的暗铜灰渐变。
        scene.background.contents = backgroundImage()

        // 相机：竖屏，略微俯视正对 XY 解谜平面。
        let camNode = SCNNode()
        camNode.name = "CameraNode"
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 100
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0, 11)
        camNode.eulerAngles = SCNVector3(0, 0, 0)
        world.rootNode.addChildNode(camNode)

        // 主方向光 + 环境光。
        let keyLight = SCNNode()
        keyLight.name = "LightNode"
        let light = SCNLight()
        light.type = .directional
        light.intensity = 900
        light.castsShadow = true
        light.shadowMode = .deferred
        keyLight.light = light
        keyLight.position = SCNVector3(4, 8, 8)
        keyLight.look(at: SCNVector3Zero)
        world.rootNode.addChildNode(keyLight)

        let ambient = SCNNode()
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 350
        amb.color = UIColor(white: 0.7, alpha: 1)
        ambient.light = amb
        world.rootNode.addChildNode(ambient)

        // 后墙：接住阴影、增加纵深（木纹底板）。
        let wall = SCNNode(geometry: SCNPlane(width: 40, height: 40))
        wall.geometry?.firstMaterial = TextureFactory.material(.wood)
        wall.position = SCNVector3(0, 0, -3)
        wall.name = "BackWall"
        world.rootNode.addChildNode(wall)

        // 不可见边界墙：把麻将约束在可视范围内，避免任何关卡把牌甩出屏幕。
        // 相机 z=11、FOV 55° → 水平可视约 ±2.6，墙放在 ±2.9 刚好在画面外。
        addBoundaryWall(to: world, at: SCNVector3(-2.9, 0, 0))   // 左墙
        addBoundaryWall(to: world, at: SCNVector3( 2.9, 0, 0))   // 右墙
    }

    /// 生成一堵竖直的不可见静态墙（仅参与碰撞，不渲染、不投影）。
    private static func addBoundaryWall(to world: World, at position: SCNVector3) {
        let box = SCNBox(width: 0.4, height: 14, length: 4, chamferRadius: 0)
        let node = SCNNode(geometry: box)
        node.position = position
        node.opacity = 0                 // 不可见
        node.castsShadow = false
        node.name = "BoundaryWall"

        let shape = SCNPhysicsShape(geometry: box, options: nil)
        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = PhysicsCategory.structure   // 麻将 collisionBitMask 含 structure
        body.friction = 0.1
        body.restitution = 0.0
        node.physicsBody = body
        world.rootNode.addChildNode(node)
    }

    private static func backgroundImage() -> UIImage {
        let size = CGSize(width: 8, height: 512)
        return UIGraphicsImageRenderer(size: size).image { rc in
            let ctx = rc.cgContext
            let colors = [UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1).cgColor,
                          UIColor(red: 0.28, green: 0.24, blue: 0.20, alpha: 1).cgColor]
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: .zero,
                                   end: CGPoint(x: 0, y: size.height), options: [])
        }
    }
}
