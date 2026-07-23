//
//  TextureFactory.swift
//  Clock
//
//  程序化材质工厂。需求文档强制：不使用外部素材 / AI 图片，
//  全部用 CoreGraphics 现绘纹理，再包成 SCNMaterial。
//  纹理带缓存，避免每个实体重复生成（减少 Draw Call 前的 CPU 开销）。
//

import UIKit
import SceneKit

enum MaterialStyle: Hashable {
    case ivory      // 象牙白（麻将牌身）
    case metalGrey  // 金属灰（齿轮 / 结构）
    case copper     // 铜色（发条 / 传送）
    case wood       // 木纹（底座 / 轨道）
}

enum TextureFactory {

    // 纹理缓存：同一风格只生成一次。
    private static var imageCache: [MaterialStyle: UIImage] = [:]

    /// 取得某风格的材质（每次返回新的 SCNMaterial，但共享底层贴图）。
    static func material(_ style: MaterialStyle) -> SCNMaterial {
        let m = SCNMaterial()
        let img = image(for: style)
        m.diffuse.contents = img
        switch style {
        case .ivory:
            m.roughness.contents = 0.35 as NSNumber
            m.metalness.contents = 0.0 as NSNumber
            m.lightingModel = .physicallyBased
        case .metalGrey:
            m.roughness.contents = 0.4 as NSNumber
            m.metalness.contents = 0.9 as NSNumber
            m.lightingModel = .physicallyBased
        case .copper:
            m.roughness.contents = 0.3 as NSNumber
            m.metalness.contents = 1.0 as NSNumber
            m.lightingModel = .physicallyBased
        case .wood:
            m.roughness.contents = 0.6 as NSNumber
            m.metalness.contents = 0.0 as NSNumber
            m.lightingModel = .physicallyBased
        }
        return m
    }

    private static func image(for style: MaterialStyle) -> UIImage {
        if let cached = imageCache[style] { return cached }
        let img: UIImage
        switch style {
        case .ivory:     img = drawIvory()
        case .metalGrey: img = drawMetal()
        case .copper:    img = drawCopper()
        case .wood:      img = drawWood()
        }
        imageCache[style] = img
        return img
    }

    // MARK: - 各风格绘制

    private static let size = CGSize(width: 256, height: 256)

    private static func render(_ draw: (CGContext, CGRect) -> Void) -> UIImage {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            draw(ctx.cgContext, rect)
        }
    }

    /// 象牙白：暖白底 + 极细噪点，模拟骨质。
    private static func drawIvory() -> UIImage {
        render { ctx, rect in
            let colors = [UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1).cgColor,
                          UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1).cgColor]
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: .zero,
                                   end: CGPoint(x: rect.width, y: rect.height), options: [])
            // 细噪点（用可复现的种子，避免每次不同）
            var rng = SeededRandom(seed: 0x49564F5259)
            ctx.setFillColor(UIColor(white: 0.85, alpha: 0.15).cgColor)
            for _ in 0..<600 {
                let x = rng.float(in: 0..<Float(rect.width))
                let y = rng.float(in: 0..<Float(rect.height))
                ctx.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1))
            }
        }
    }

    /// 金属灰：冷灰底 + 横向拉丝高光。
    private static func drawMetal() -> UIImage {
        render { ctx, rect in
            ctx.setFillColor(UIColor(white: 0.42, alpha: 1).cgColor)
            ctx.fill(rect)
            var rng = SeededRandom(seed: 0x4D4554414C0000)
            for _ in 0..<220 {
                let y = CGFloat(rng.float(in: 0..<Float(rect.height)))
                let w = CGFloat(rng.float(in: 40..<Float(rect.width)))
                let x = CGFloat(rng.float(in: 0..<Float(rect.width)))
                let bright = CGFloat(rng.float(in: 0..<0.25))
                ctx.setStrokeColor(UIColor(white: 0.5 + bright, alpha: 0.5).cgColor)
                ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x + w, y: y))
                ctx.strokePath()
            }
        }
    }

    /// 铜色：暖橙金属 + 斜向光泽。
    private static func drawCopper() -> UIImage {
        render { ctx, rect in
            let colors = [UIColor(red: 0.80, green: 0.50, blue: 0.24, alpha: 1).cgColor,
                          UIColor(red: 0.55, green: 0.32, blue: 0.14, alpha: 1).cgColor]
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: .zero,
                                   end: CGPoint(x: rect.width, y: rect.height), options: [])
        }
    }

    /// 木纹：棕底 + 波纹年轮。
    private static func drawWood() -> UIImage {
        render { ctx, rect in
            ctx.setFillColor(UIColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 1).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(UIColor(red: 0.30, green: 0.19, blue: 0.10, alpha: 0.6).cgColor)
            ctx.setLineWidth(2)
            var y: CGFloat = 0
            var rng = SeededRandom(seed: 0x574F4F44)
            while y < rect.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                let mid = CGFloat(rng.float(in: 4..<14))
                ctx.addQuadCurve(to: CGPoint(x: rect.width, y: y),
                                 control: CGPoint(x: rect.width / 2, y: y + mid))
                ctx.strokePath()
                y += CGFloat(rng.float(in: 12..<26))
            }
        }
    }
}
