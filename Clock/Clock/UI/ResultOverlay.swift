//
//  ResultOverlay.swift
//  Clock
//
//  结算浮层（胜/负）与暂停浮层。取代此前「弹个横幅 + 1.8 秒自动跳关」的做法，
//  把控制权交回玩家：胜利可下一关/重试/回菜单，失败可重试/回菜单，随时可暂停。
//

import UIKit

/// 半透明卡片式浮层基类：铺满父视图、居中一张面板。
class OverlayView: UIView {
    let panel = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.62)
        panel.backgroundColor = Theme.panel
        panel.layer.cornerRadius = 20
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 300),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(in parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
        alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.22) {
            self.alpha = 1
            self.panel.transform = .identity
        }
    }

    func dismiss() { removeFromSuperview() }
}

/// 结算浮层：胜利显示星级 + 用时；失败显示原因。
final class ResultOverlay: OverlayView {

    /// 胜利结算。
    init(won: Bool, title: String, stars: Int, detail: String,
         hasNext: Bool,
         onNext: @escaping () -> Void,
         onRetry: @escaping () -> Void,
         onMenu: @escaping () -> Void) {
        super.init(frame: .zero)

        let heading = UILabel()
        heading.text = won ? "LEVEL CLEAR" : "TRY AGAIN"
        heading.font = Theme.title(28)
        heading.textColor = won ? Theme.success : Theme.danger
        heading.textAlignment = .center

        let sub = UILabel()
        sub.text = title
        sub.font = Theme.body(14)
        sub.textColor = Theme.inkDim
        sub.textAlignment = .center

        // 星级（仅胜利）。
        let starLabel = UILabel()
        starLabel.text = Theme.starString(stars)
        starLabel.font = .systemFont(ofSize: 40)
        starLabel.textColor = Theme.brass
        starLabel.textAlignment = .center
        starLabel.isHidden = !won

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = Theme.body(15)
        detailLabel.textColor = Theme.ink
        detailLabel.textAlignment = .center

        var buttons: [UIView] = []
        if won && hasNext {
            buttons.append(Theme.makeButton("Next Level", kind: .primary, action: onNext))
        }
        buttons.append(Theme.makeButton("Retry", kind: .secondary, action: onRetry))
        buttons.append(Theme.makeButton("Menu", kind: .ghost, action: onMenu))

        let buttonStack = UIStackView(arrangedSubviews: buttons)
        buttonStack.axis = .vertical
        buttonStack.spacing = 10

        let stack = UIStackView(arrangedSubviews: [heading, sub, starLabel, detailLabel, buttonStack])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(20, after: detailLabel)
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 暂停浮层：继续 / 重试 / 回菜单。
final class PauseOverlay: OverlayView {
    init(onResume: @escaping () -> Void,
         onRetry: @escaping () -> Void,
         onMenu: @escaping () -> Void) {
        super.init(frame: .zero)

        let heading = UILabel()
        heading.text = "PAUSED"
        heading.font = Theme.title(28)
        heading.textColor = Theme.ivory
        heading.textAlignment = .center

        let buttonStack = UIStackView(arrangedSubviews: [
            Theme.makeButton("Resume", kind: .primary, action: onResume),
            Theme.makeButton("Retry", kind: .secondary, action: onRetry),
            Theme.makeButton("Menu", kind: .ghost, action: onMenu),
        ])
        buttonStack.axis = .vertical
        buttonStack.spacing = 10

        let stack = UIStackView(arrangedSubviews: [heading, buttonStack])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
