//
//  GeometryFactory.swift
//  Clock
//
//  程序化几何工厂。需求文档要求：齿轮用 UIBezierPath + SCNShape 生成，
//  麻将用 SCNBox + chamfer 做圆角，全部参数化，禁止外部模型资源。
//

import UIKit
import SceneKit

enum GeometryFactory {

    // MARK: - 齿轮（UIBezierPath 生成齿廓，再 SCNShape 挤出）

    /// 生成一个齿轮几何。
    /// - Parameters:
    ///   - radius: 节圆半径。
    ///   - teeth: 齿数。
    ///   - thickness: 挤出厚度。
    static func gear(radius: CGFloat, teeth: Int, thickness: CGFloat) -> SCNGeometry {
        let path = gearPath(radius: radius, teeth: max(6, teeth))
        let shape = SCNShape(path: path, extrusionDepth: thickness)
        shape.chamferRadius = thickness * 0.12
        // 面：正面 / 侧面 / 背面，给金属材质。
        let side = TextureFactory.material(.metalGrey)
        let face = TextureFactory.material(.metalGrey)
        shape.materials = [face, side, face]
        return shape
    }

    /// 齿轮齿廓：外圈交替的“齿顶/齿根”折线 + 中心轴孔。
    private static func gearPath(radius: CGFloat, teeth: Int) -> UIBezierPath {
        let path = UIBezierPath()
        let addendum = radius * 0.14          // 齿顶高
        let outer = radius + addendum
        let inner = radius - addendum
        let stepsPerTooth = 4                  // 齿顶2 + 齿根2
        let total = teeth * stepsPerTooth
        for i in 0...total {
            let frac = CGFloat(i) / CGFloat(total)
            let angle = frac * 2 * .pi
            // 在 outer / inner 之间按齿相位切换，形成梯形齿。
            let phase = i % stepsPerTooth
            let r: CGFloat
            switch phase {
            case 0, 1: r = outer
            default:   r = inner
            }
            let p = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()

        // 中心轴孔（逆向子路径，SCNShape 会挖空）。
        let hole = UIBezierPath(ovalIn: CGRect(x: -radius * 0.18, y: -radius * 0.18,
                                               width: radius * 0.36, height: radius * 0.36))
        hole.usesEvenOddFillRule = true
        path.append(hole.reversing())
        return path
    }

    // MARK: - 麻将牌（SCNBox + chamfer 圆角）

    /// 标准麻将牌尺寸（宽:高:厚 ≈ 0.5:0.7:0.3 的缩放）。
    static func mahjong() -> SCNBox {
        let box = SCNBox(width: 0.5, height: 0.7, length: 0.32, chamferRadius: 0.06)
        return box
    }

    // MARK: - 钟摆（SCNCylinder 摆杆 + SCNSphere 摆锤）

    /// 返回一个已组装好的钟摆节点：pivot 在原点，摆杆向 -Y 垂下。
    static func pendulum(armLength: CGFloat, bobRadius: CGFloat) -> SCNNode {
        let pivot = SCNNode()

        let arm = SCNCylinder(radius: 0.04, height: armLength)
        arm.firstMaterial = TextureFactory.material(.copper)
        let armNode = SCNNode(geometry: arm)
        // 圆柱默认中心在原点、沿 Y。下移半个长度，使顶端在 pivot。
        armNode.position = SCNVector3(0, Float(-armLength / 2), 0)
        pivot.addChildNode(armNode)

        let bob = SCNSphere(radius: bobRadius)
        bob.firstMaterial = TextureFactory.material(.metalGrey)
        let bobNode = SCNNode(geometry: bob)
        bobNode.position = SCNVector3(0, Float(-armLength), 0)
        bobNode.name = "bob"
        pivot.addChildNode(bobNode)

        return pivot
    }

    // MARK: - 轨道 / 平台（圆角盒）

    static func platform(size: Vec3) -> SCNGeometry {
        let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y),
                         length: CGFloat(size.z), chamferRadius: 0.02)
        box.firstMaterial = TextureFactory.material(.wood)
        return box
    }
}
