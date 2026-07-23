//
//  LevelSelectCells.swift
//  Clock
//
//  关卡选择用的 Cell 与分区头。抽出来单独放，保持 VC 精简。
//

import UIKit

/// 单关格子：显示关号；已通关显示星级；未解锁显示锁并置灰。
final class LevelCell: UICollectionViewCell {
    static let reuseId = "LevelCell"

    private let numberLabel = UILabel()
    private let starsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true

        numberLabel.font = Theme.mono(20)
        numberLabel.textAlignment = .center

        starsLabel.font = .systemFont(ofSize: 9)
        starsLabel.textAlignment = .center
        starsLabel.textColor = Theme.brass

        let stack = UIStackView(arrangedSubviews: [numberLabel, starsLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(id: Int, unlocked: Bool, record: LevelRecord?) {
        if !unlocked {
            numberLabel.text = "🔒"
            starsLabel.text = " "
            contentView.backgroundColor = UIColor(white: 0.14, alpha: 1)
            contentView.layer.borderColor = UIColor(white: 0.22, alpha: 1).cgColor
            numberLabel.textColor = Theme.locked
            return
        }
        numberLabel.text = "\(id)"
        if let rec = record, rec.cleared {
            numberLabel.textColor = Theme.ivory
            starsLabel.text = Theme.starString(rec.stars)
            contentView.backgroundColor = UIColor(white: 0.20, alpha: 1)
            contentView.layer.borderColor = Theme.brass.cgColor
        } else {
            numberLabel.textColor = Theme.ink
            starsLabel.text = " "
            contentView.backgroundColor = UIColor(white: 0.17, alpha: 1)
            contentView.layer.borderColor = Theme.brassDim.cgColor
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        starsLabel.text = " "
    }
}

/// 章节分区头：章节名 + 该章通关进度。
final class ChapterHeader: UICollectionReusableView {
    static let reuseId = "ChapterHeader"

    private let titleLabel = UILabel()
    private let progressLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = Theme.title(16)
        titleLabel.textColor = Theme.brass
        progressLabel.font = Theme.body(13)
        progressLabel.textColor = Theme.inkDim
        progressLabel.textAlignment = .right

        let stack = UIStackView(arrangedSubviews: [titleLabel, progressLabel])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, progress: String) {
        titleLabel.text = title
        progressLabel.text = progress
    }
}
