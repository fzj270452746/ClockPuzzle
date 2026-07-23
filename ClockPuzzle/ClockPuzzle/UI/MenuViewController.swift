//
//  MenuViewController.swift
//  Clock
//
//  主菜单：游戏标题 + 「开始游戏 / 继续」+ 进度概览（已通关数、累计星数）。
//  纯 UI，通过回调把意图交给协调器，不自行导航。
//

import UIKit

final class MenuViewController: UIViewController {

    var onPlay: (() -> Void)?
    var onContinue: (() -> Void)?

    private let saveStore: SaveStore

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.applyBackground(to: view)
        buildUI()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        Theme.resizeBackground(in: view)
    }

    private func buildUI() {
        // 标题
        let title = UILabel()
        title.text = "MAHJONG"
        title.font = Theme.title(44)
        title.textColor = Theme.ivory
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "CLOCK"
        subtitle.font = Theme.title(52)
        subtitle.textColor = Theme.brass
        subtitle.textAlignment = .center

        let tagline = UILabel()
        tagline.text = "Wind the clock. Guide the tile."
        tagline.font = Theme.body(15)
        tagline.textColor = Theme.inkDim
        tagline.textAlignment = .center

        // 进度概览
        let progress = UILabel()
        progress.numberOfLines = 2
        progress.textAlignment = .center
        progress.font = Theme.body(14)
        progress.textColor = Theme.ink
        let cleared = saveStore.clearedCount
        let stars = saveStore.totalStars
        progress.text = "Cleared \(cleared) / \(SaveStore.totalLevels)   ·   ★ \(stars)"

        // 按钮
        let hasProgress = saveStore.highestUnlocked > 1 || cleared > 0
        let playButton = Theme.makeButton(hasProgress ? "Level Select" : "Start Game",
                                          kind: .primary) { [weak self] in self?.onPlay?() }
        let continueButton = Theme.makeButton("Continue  ·  Level \(saveStore.highestUnlocked)",
                                              kind: .secondary) { [weak self] in self?.onContinue?() }
        continueButton.isHidden = !hasProgress

        let titleStack = UIStackView(arrangedSubviews: [title, subtitle, tagline])
        titleStack.axis = .vertical
        titleStack.spacing = 2
        titleStack.setCustomSpacing(14, after: subtitle)

        let buttonStack = UIStackView(arrangedSubviews: [playButton, continueButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 14
        buttonStack.alignment = .fill

        let root = UIStackView(arrangedSubviews: [titleStack, progress, buttonStack])
        root.axis = .vertical
        root.spacing = 40
        root.alignment = .fill
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
        ])
    }
}
