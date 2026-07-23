//
//  Theme.swift
//  Clock
//
//  统一视觉主题：配色、字体、按钮样式。集中一处定义，让菜单/关卡选择/HUD/结算
//  风格一致（成熟产品的基本要求）。配色取「轻机械朋克 + 铜色 + 象牙白」基调，呼应美术方向。
//

import UIKit

enum Theme {

    // MARK: - 配色
    static let bgTop     = UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1)   // 深石板
    static let bgBottom  = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
    static let brass     = UIColor(red: 0.80, green: 0.62, blue: 0.32, alpha: 1)   // 铜
    static let brassDim  = UIColor(red: 0.55, green: 0.43, blue: 0.24, alpha: 1)
    static let ivory     = UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)   // 象牙白
    static let ink       = UIColor(white: 0.92, alpha: 1)
    static let inkDim    = UIColor(white: 0.55, alpha: 1)
    static let danger    = UIColor(red: 0.86, green: 0.30, blue: 0.24, alpha: 1)
    static let success   = UIColor(red: 0.30, green: 0.72, blue: 0.40, alpha: 1)
    static let panel     = UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 0.96)
    static let locked    = UIColor(white: 0.30, alpha: 1)

    // MARK: - 字体
    static func title(_ size: CGFloat) -> UIFont { .systemFont(ofSize: size, weight: .black) }
    static func body(_ size: CGFloat) -> UIFont  { .systemFont(ofSize: size, weight: .semibold) }
    static func mono(_ size: CGFloat) -> UIFont   { .monospacedDigitSystemFont(ofSize: size, weight: .bold) }

    // MARK: - 背景渐变
    static func applyBackground(to view: UIView) {
        view.backgroundColor = bgBottom
        let grad = CAGradientLayer()
        grad.colors = [bgTop.cgColor, bgBottom.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        grad.frame = view.bounds
        grad.name = "themeBackground"
        view.layer.insertSublayer(grad, at: 0)
    }

    /// 在 layoutSubviews 时调用，保持渐变铺满。
    static func resizeBackground(in view: UIView) {
        view.layer.sublayers?.first { $0.name == "themeBackground" }?.frame = view.bounds
    }

    // MARK: - 按钮
    enum ButtonKind { case primary, secondary, ghost }

    static func makeButton(_ title: String, kind: ButtonKind = .secondary,
                           action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 22)
        switch kind {
        case .primary:
            config.baseBackgroundColor = brass
            config.baseForegroundColor = UIColor(white: 0.1, alpha: 1)
        case .secondary:
            config.baseBackgroundColor = UIColor(white: 0.22, alpha: 1)
            config.baseForegroundColor = ivory
        case .ghost:
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = brass
        }
        let b = UIButton(configuration: config)
        b.titleLabel?.font = body(17)
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    /// 星级串（★★☆）。
    static func starString(_ n: Int) -> String {
        String(repeating: "★", count: max(0, n)) + String(repeating: "☆", count: max(0, 3 - n))
    }

    // MARK: - 游戏内控制按钮

    /// 时间调节键（-1h/-5m/+5m/+1h）。紧凑、等宽数字字体、深色底象牙字。
    static func makeTimeButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .medium
        config.baseBackgroundColor = UIColor(white: 0.20, alpha: 0.95)
        config.baseForegroundColor = ivory
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        let b = UIButton(configuration: config)
        b.titleLabel?.font = mono(17)
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor(white: 1, alpha: 0.06).cgColor
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    /// 核心动作按钮（Release）。铜色主按钮，字号更大更醒目。
    static func makeReleaseButton(_ text: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = text
        config.cornerStyle = .large
        config.baseBackgroundColor = UIColor(red: 0.78, green: 0.36, blue: 0.16, alpha: 1)
        config.baseForegroundColor = ivory
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        let b = UIButton(configuration: config)
        b.titleLabel?.font = title(18)
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    /// 次级切换按钮（Auto）。带开/关两态配色。
    static func makeAutoButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .large
        config.baseBackgroundColor = UIColor(white: 0.22, alpha: 1)
        config.baseForegroundColor = ivory
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14)
        let b = UIButton(configuration: config)
        b.titleLabel?.font = body(16)
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }
}
