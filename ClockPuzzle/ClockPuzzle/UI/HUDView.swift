//
//  HUDView.swift
//  Clock
//
//  抬头显示：关卡标题、当前时间、目标时间、剩余倒计时，以及结算横幅。
//  纯展示控件，被 GameViewController 调用，不含玩法逻辑。
//

import UIKit

final class HUDView: UIView {

    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let targetLabel = UILabel()
    private let remainingLabel = UILabel()
    private let bannerLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor(white: 0.95, alpha: 1)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 30, weight: .heavy)
        timeLabel.textColor = .white

        targetLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        targetLabel.textColor = UIColor(red: 0.85, green: 0.7, blue: 0.4, alpha: 1)

        remainingLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        remainingLabel.textColor = UIColor(white: 0.9, alpha: 1)
        remainingLabel.textAlignment = .right

        let topRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), remainingLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let midRow = UIStackView(arrangedSubviews: [timeLabel, targetLabel])
        midRow.axis = .horizontal
        midRow.alignment = .lastBaseline
        midRow.spacing = 12

        let col = UIStackView(arrangedSubviews: [topRow, midRow])
        col.axis = .vertical
        col.spacing = 2
        col.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col)

        // 结算横幅（默认隐藏）
        bannerLabel.font = .systemFont(ofSize: 34, weight: .black)
        bannerLabel.textAlignment = .center
        bannerLabel.textColor = .white
        bannerLabel.alpha = 0
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        bannerLabel.layer.cornerRadius = 12
        bannerLabel.clipsToBounds = true
        addSubview(bannerLabel)

        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: topAnchor),
            col.leadingAnchor.constraint(equalTo: leadingAnchor),
            col.trailingAnchor.constraint(equalTo: trailingAnchor),
            col.bottomAnchor.constraint(equalTo: bottomAnchor),

            bannerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            bannerLabel.topAnchor.constraint(equalTo: bottomAnchor, constant: 180),
            bannerLabel.widthAnchor.constraint(equalToConstant: 260),
            bannerLabel.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    // MARK: - 更新接口

    func configure(title: String, time: String, target: String, remaining: TimeInterval) {
        titleLabel.text = title
        timeLabel.text = time
        targetLabel.text = "→ \(target)"
        updateRemaining(remaining)
        bannerLabel.alpha = 0
    }

    func updateTime(_ s: String) { timeLabel.text = s }

    func updateRemaining(_ seconds: TimeInterval) {
        let s = max(0, Int(seconds.rounded()))
        remainingLabel.text = String(format: "%02d:%02d", s / 60, s % 60)
        remainingLabel.textColor = s <= 10
            ? UIColor(red: 0.9, green: 0.3, blue: 0.25, alpha: 1)
            : UIColor(white: 0.9, alpha: 1)
    }

    func showBanner(_ text: String, color: UIColor) {
        bannerLabel.text = text
        bannerLabel.backgroundColor = color.withAlphaComponent(0.9)
        UIView.animate(withDuration: 0.25) { self.bannerLabel.alpha = 1 }
    }
}
