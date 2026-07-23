//
//  WinEffect.swift
//  Clock
//
//  通关特效：在出口位置放一束程序生成的粒子（金色火花上扬 + 扩散），
//  契合「全素材程序生成」原则，不引入任何贴图资源。由 GameViewController 在胜利时调用。
//

import SceneKit
import UIKit

enum WinEffect {

    /// 在指定世界坐标处爆发一束庆祝粒子，自动在数秒后清理。
    static func burst(at position: SCNVector3, in world: World) {
        let system = SCNParticleSystem()
        system.birthRate = 600
        system.emissionDuration = 0.4
        system.loops = false
        system.particleLifeSpan = 1.2
        system.particleLifeSpanVariation = 0.4
        system.particleVelocity = 3.2
        system.particleVelocityVariation = 1.6
        system.spreadingAngle = 180
        system.emitterShape = SCNSphere(radius: 0.15)
        system.particleSize = 0.06
        system.particleSizeVariation = 0.03
        system.particleColor = Theme.brass
        system.particleColorVariation = SCNVector4(0.1, 0.15, 0.05, 0)
        system.particleImage = sparkImage()
        system.blendMode = .additive
        system.acceleration = SCNVector3(0, -2.4, 0)   // 火花上抛后回落
        system.isAffectedByGravity = false

        let emitter = SCNNode()
        emitter.position = position
        emitter.addParticleSystem(system)
        world.effectRoot.addChildNode(emitter)

        // 播完自动移除，避免节点堆积。
        emitter.runAction(.sequence([.wait(duration: 2.0), .removeFromParentNode()]))
    }

    /// 程序绘制一个柔边圆点作为火花贴图。
    private static func sparkImage() -> UIImage {
        let size = CGSize(width: 32, height: 32)
        return UIGraphicsImageRenderer(size: size).image { rc in
            let ctx = rc.cgContext
            let center = CGPoint(x: 16, y: 16)
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor]
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: 16, options: [])
        }
    }
}
