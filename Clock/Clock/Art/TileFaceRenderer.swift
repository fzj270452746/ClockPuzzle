//
//  TileFaceRenderer.swift
//  Clock
//
//  麻将牌牌面绘制。用 CoreGraphics 现绘花色图案（万/条/筒/中/白）+ 数字，
//  返回可直接贴到牌正面的 UIImage。禁止外部图片素材。牌面按 花色+数字 缓存。
//

import UIKit

enum TileFaceRenderer {

    private static let size = CGSize(width: 200, height: 280)
    private static var cache: [String: UIImage] = [:]

    /// 取得牌面图。number 用于 万/条/筒（1...9）；Dragon/White 忽略。
    static func image(suit: Suit, number: Int = 1) -> UIImage {
        let key = "\(suit.rawValue)-\(number)"
        if let c = cache[key] { return c }
        let img = render(suit, number: number)
        cache[key] = img
        return img
    }

    private static func render(_ suit: Suit, number: Int) -> UIImage {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { rc in
            let ctx = rc.cgContext
            let rect = CGRect(origin: .zero, size: size)
            UIColor(red: 0.98, green: 0.97, blue: 0.92, alpha: 1).setFill()
            ctx.fill(rect)
            let inset = rect.insetBy(dx: 12, dy: 12)
            UIColor(white: 0.75, alpha: 0.5).setStroke()
            let border = UIBezierPath(roundedRect: inset, cornerRadius: 14)
            border.lineWidth = 2
            border.stroke()

            switch suit {
            case .wan:    drawWan(inset, number: number)
            case .bamboo: drawBamboo(inset, number: number)
            case .dot:    drawDot(inset, number: number)
            case .dragon: drawDragon(inset)
            case .white:  drawWhite(inset)
            }
        }
    }

    private static let cnNumerals = ["一","二","三","四","五","六","七","八","九"]
    private static func cn(_ n: Int) -> String { cnNumerals[max(1, min(9, n)) - 1] }

    // 万：上数字，下「萬」，红色。
    private static func drawWan(_ rect: CGRect, number: Int) {
        let red = UIColor(red: 0.75, green: 0.12, blue: 0.12, alpha: 1)
        drawText(cn(number), in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.42),
                 color: red, weight: .bold)
        drawText("萬", in: CGRect(x: rect.minX, y: rect.midY - rect.height * 0.02, width: rect.width, height: rect.height * 0.45),
                 color: red, weight: .heavy)
    }

    // 条：绿色竹节，数量 = number（最多画 9，按网格排布）。
    private static func drawBamboo(_ rect: CGRect, number: Int) {
        let green = UIColor(red: 0.10, green: 0.55, blue: 0.28, alpha: 1)
        green.setStroke(); green.setFill()
        let count = max(1, min(9, number))
        let cols = count <= 3 ? 1 : (count <= 6 ? 2 : 3)
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cellW = rect.width / CGFloat(cols)
        let cellH = rect.height / CGFloat(rows)
        var drawn = 0
        for row in 0..<rows {
            let inThisRow = min(cols, count - drawn)
            let offsetX = (rect.width - CGFloat(inThisRow) * cellW) / 2
            for c in 0..<inThisRow {
                let cx = rect.minX + offsetX + (CGFloat(c) + 0.5) * cellW
                let cy = rect.minY + (CGFloat(row) + 0.5) * cellH
                let h = cellH * 0.5
                let stalk = UIBezierPath()
                stalk.move(to: CGPoint(x: cx, y: cy - h/2))
                stalk.addLine(to: CGPoint(x: cx, y: cy + h/2))
                stalk.lineWidth = 6
                stalk.stroke()
                let seg = UIBezierPath(ovalIn: CGRect(x: cx - 6, y: cy - 3, width: 12, height: 6))
                seg.fill()
                drawn += 1
            }
        }
    }

    // 筒：蓝/红同心圆点，数量 = number 的网格。
    private static func drawDot(_ rect: CGRect, number: Int) {
        let count = max(1, min(9, number))
        let cols = count <= 3 ? 1 : (count <= 6 ? 2 : 3)
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cellW = rect.width / CGFloat(cols)
        let cellH = rect.height / CGFloat(rows)
        let dotR = min(cellW, cellH) * 0.32
        var drawn = 0
        for row in 0..<rows {
            let inThisRow = min(cols, count - drawn)
            let offsetX = (rect.width - CGFloat(inThisRow) * cellW) / 2
            for c in 0..<inThisRow {
                let cx = rect.minX + offsetX + (CGFloat(c) + 0.5) * cellW
                let cy = rect.minY + (CGFloat(row) + 0.5) * cellH
                let outer = UIBezierPath(ovalIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR*2, height: dotR*2))
                UIColor(red: 0.13, green: 0.34, blue: 0.66, alpha: 1).setStroke()
                outer.lineWidth = 5; outer.stroke()
                let ir = dotR * 0.45
                let inner = UIBezierPath(ovalIn: CGRect(x: cx - ir, y: cy - ir, width: ir*2, height: ir*2))
                UIColor(red: 0.80, green: 0.20, blue: 0.16, alpha: 1).setFill()
                inner.fill()
                drawn += 1
            }
        }
    }

    // 中（红中）。
    private static func drawDragon(_ rect: CGRect) {
        let red = UIColor(red: 0.78, green: 0.12, blue: 0.12, alpha: 1)
        let box = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.20)
        red.setStroke()
        let p = UIBezierPath(rect: box); p.lineWidth = 6; p.stroke()
        drawText("中", in: rect, color: red, weight: .heavy)
    }

    // 白板。
    private static func drawWhite(_ rect: CGRect) {
        let blue = UIColor(red: 0.30, green: 0.45, blue: 0.70, alpha: 1)
        let box = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
        blue.setStroke()
        let p = UIBezierPath(roundedRect: box, cornerRadius: 8); p.lineWidth = 5; p.stroke()
    }

    private static func drawText(_ s: String, in rect: CGRect, color: UIColor, weight: UIFont.Weight) {
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let fontSize = min(rect.width, rect.height) * 0.7
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        let bounds = str.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, context: nil)
        let y = rect.minY + (rect.height - bounds.height) / 2
        str.draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: bounds.height))
    }
}
