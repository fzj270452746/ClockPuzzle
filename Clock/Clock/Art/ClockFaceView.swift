//
//  ClockFaceView.swift
//  Clock
//
//  时钟盘控件。需求文档指定：用 CAShapeLayer + CoreGraphics 绘制
//  刻度、罗马数字、指针。既是可视化，也是“时间轮”交互控件——
//  拖动盘面即拖动时间（拖 1 圈分针 = 1 小时）。
//
//  它不直接引用游戏逻辑：只通过闭包 onScrub 把“分钟增量”抛出去，
//  由外部（GameViewController）转交 ClockManager。
//

import UIKit

final class ClockFaceView: UIView {

    /// 拖动盘面产生的时间增量（分钟）。正为顺时针。
    var onScrub: ((Int) -> Void)?

    // 当前指针角度（弧度，12 点为 0，顺时针为正）。
    private var hourAngle: CGFloat = 0
    private var minuteAngle: CGFloat = 0

    private let romanNumerals = ["XII", "I", "II", "III", "IV", "V",
                                 "VI", "VII", "VIII", "IX", "X", "XI"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    /// 由外部驱动：传入当日分钟数，刷新指针角度。
    func setTime(minutes: Int) {
        let m = CGFloat(minutes % 60)
        let h = CGFloat(minutes % 720) / 60.0     // 12 小时制
        minuteAngle = m / 60.0 * .pi * 2
        hourAngle = h / 12.0 * .pi * 2
        setNeedsDisplay()
    }

    // MARK: - 绘制

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 6

        drawDialBackground(ctx, center: center, radius: radius)
        drawTicks(ctx, center: center, radius: radius)
        drawNumerals(center: center, radius: radius)
        drawHand(ctx, center: center, angle: hourAngle,
                 length: radius * 0.52, width: 6,
                 color: UIColor(white: 0.15, alpha: 1))
        drawHand(ctx, center: center, angle: minuteAngle,
                 length: radius * 0.78, width: 4,
                 color: UIColor(white: 0.15, alpha: 1))
        // 中心铆钉
        ctx.setFillColor(UIColor(red: 0.72, green: 0.45, blue: 0.20, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12))
    }

    private func drawDialBackground(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        // 象牙白盘面 + 铜色外圈
        ctx.setFillColor(UIColor(red: 0.96, green: 0.94, blue: 0.87, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2))
        ctx.setStrokeColor(UIColor(red: 0.66, green: 0.42, blue: 0.18, alpha: 1).cgColor)
        ctx.setLineWidth(5)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2))
    }

    private func drawTicks(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        for i in 0..<60 {
            let angle = CGFloat(i) / 60.0 * .pi * 2
            let isMajor = i % 5 == 0
            let inner = radius - (isMajor ? 14 : 7)
            ctx.setLineWidth(isMajor ? 3 : 1)
            ctx.setStrokeColor(UIColor(white: 0.2, alpha: isMajor ? 1 : 0.5).cgColor)
            let outerP = point(center: center, angle: angle, dist: radius - 2)
            let innerP = point(center: center, angle: angle, dist: inner)
            ctx.move(to: innerP)
            ctx.addLine(to: outerP)
            ctx.strokePath()
        }
    }

    private func drawNumerals(center: CGPoint, radius: CGFloat) {
        let font = UIFont.systemFont(ofSize: radius * 0.13, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(white: 0.15, alpha: 1)
        ]
        for (i, roman) in romanNumerals.enumerated() {
            let angle = CGFloat(i) / 12.0 * .pi * 2
            let p = point(center: center, angle: angle, dist: radius * 0.76)
            let str = NSAttributedString(string: roman, attributes: attrs)
            let sz = str.size()
            str.draw(at: CGPoint(x: p.x - sz.width / 2, y: p.y - sz.height / 2))
        }
    }

    private func drawHand(_ ctx: CGContext, center: CGPoint, angle: CGFloat,
                          length: CGFloat, width: CGFloat, color: UIColor) {
        let tip = point(center: center, angle: angle, dist: length)
        let tail = point(center: center, angle: angle + .pi, dist: length * 0.18)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: tail)
        ctx.addLine(to: tip)
        ctx.strokePath()
    }

    /// 12 点为 0、顺时针为正的极坐标 → 屏幕坐标。
    private func point(center: CGPoint, angle: CGFloat, dist: CGFloat) -> CGPoint {
        // 屏幕 y 向下：12 点方向为 -y。
        CGPoint(x: center.x + dist * sin(angle),
                y: center.y - dist * cos(angle))
    }

    // MARK: - 拖动 = 时间轮

    private var lastAngle: CGFloat?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        lastAngle = angleOf(point: t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let prev = lastAngle else { return }
        let now = angleOf(point: t.location(in: self))
        var delta = now - prev
        // 处理跨 0/2π 的跳变
        if delta > .pi { delta -= .pi * 2 }
        if delta < -.pi { delta += .pi * 2 }
        lastAngle = now
        // 分针转 1 圈 = 60 分钟；这里把弧度增量折算成分钟。
        let minutes = Int((delta / (.pi * 2) * 60).rounded())
        if minutes != 0 { onScrub?(minutes) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastAngle = nil
    }

    private func angleOf(point p: CGPoint) -> CGFloat {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return atan2(p.x - center.x, center.y - p.y)   // 12 点为 0、顺时针为正
    }
}
