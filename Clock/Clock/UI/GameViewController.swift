//
//  GameViewController.swift
//  Clock
//
//  游戏主控制器。它是“组装者”：创建 World、注入各 System、装配关卡、
//  搭建 UI（SCNView + 时间轮 + 控制条 + HUD + 暂停/结算浮层），并订阅事件更新界面。
//  刻意保持“薄”——不写玩法逻辑，逻辑都在各 System 里。
//
//  流程职责：本 VC 只负责“玩一关”。通关/退出的去向通过回调交给 GameCoordinator：
//   - onAdvance(nextId)：玩家在结算面板点“下一关”。
//   - onExit()：玩家点“菜单”返回。
//

import UIKit
import SceneKit

final class GameViewController: UIViewController {

    // 协调器回调
    var onAdvance: ((Int) -> Void)?
    var onExit: (() -> Void)?

    // 依赖（构造注入，不用全局单例）
    private let events = EventBus()
    private let saveStore: SaveStore
    private var feedback: FeedbackService!
    private var world: World!
    private var clock: ClockManager!
    private var mahjong: MahjongController!
    private var puzzle: PuzzleManager!

    private var currentLevelId: Int
    private var currentLevel: LevelData!
    private var eventTokens: [EventBus.Token] = []
    private var isResolved = false      // 本关是否已出结果（避免重复结算）

    // UI
    private let scnView = SCNView()
    private let clockFace = ClockFaceView()
    private let hud = HUDView()
    private let pauseButton = UIButton(configuration: .plain())
    private var autoButton: UIButton?
    private var tutorialLabel: UILabel?

    init(levelId: Int, saveStore: SaveStore) {
        self.currentLevelId = levelId
        self.saveStore = saveStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.currentLevelId = 1
        self.saveStore = SaveStore()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        feedback = FeedbackService(events: events)
        setupSceneView()
        setupControls()
        subscribeEvents()
        loadLevel(id: currentLevelId)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // MARK: - 组装场景与系统

    private func loadLevel(id: Int) {
        world?.stop()
        isResolved = false

        let level = LevelLoader.load(id: id)
        currentLevelId = level.id
        currentLevel = level

        let newWorld = World(events: events, random: SeededRandom(seed: level.seed))
        GameScene.configure(newWorld)

        // 系统注册顺序 = 每帧执行顺序：
        // 时间 → 齿轮 → 钟摆 → 机构反应 → 麻将监视 → 裁判
        let clockManager = ClockManager(startMinutes: level.startMinutes, events: events)
        let mahjongController = MahjongController(events: events)
        let puzzleManager = PuzzleManager(levelId: level.id, timeLimit: level.timeLimit, events: events)

        newWorld.addSystem(clockManager)
        newWorld.addSystem(GearSystem())
        newWorld.addSystem(PendulumSystem())
        newWorld.addSystem(MechanismSystem())
        newWorld.addSystem(mahjongController)
        newWorld.addSystem(puzzleManager)

        LevelBuilder.build(level, into: newWorld)

        self.world = newWorld
        self.clock = clockManager
        self.mahjong = mahjongController
        self.puzzle = puzzleManager

        scnView.scene = newWorld.scene
        scnView.isPlaying = true
        clockFace.setTime(minutes: level.startMinutes)
        hud.configure(title: level.title, time: clock.displayString,
                      target: minutesString(level.targetMinutes),
                      remaining: level.timeLimit)

        newWorld.start()
        showTutorialIfNeeded(for: level.id)

        // 新世界的时钟从暂停开始，同步 Auto 按钮回默认态。
        autoButton?.configuration?.baseBackgroundColor = UIColor(white: 0.22, alpha: 1)
        autoButton?.configuration?.baseForegroundColor = Theme.ivory
    }

    // MARK: - SCNView

    private func setupSceneView() {
        scnView.translatesAutoresizingMaskIntoConstraints = false
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 60
        scnView.isUserInteractionEnabled = true
        scnView.backgroundColor = .black
        // 关键：驱动 SceneKit 的时间轴与物理引擎。isPlaying=false 时物理不推进。
        scnView.isPlaying = true
        scnView.rendersContinuously = true
        view.addSubview(scnView)
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: view.topAnchor),
            scnView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scnView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 控制 UI

    private func setupControls() {
        // HUD 顶部
        hud.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hud.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -64),
        ])

        // 暂停按钮（右上角）
        var pconf = UIButton.Configuration.plain()
        pconf.image = UIImage(systemName: "pause.circle.fill")
        pconf.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 30)
        pconf.baseForegroundColor = Theme.ivory
        pauseButton.configuration = pconf
        pauseButton.addAction(UIAction { [weak self] _ in self?.pauseGame() }, for: .touchUpInside)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pauseButton)
        NSLayoutConstraint.activate([
            pauseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            pauseButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
        ])

        // 时间轮（底部中央，位于控制区上方）
        clockFace.translatesAutoresizingMaskIntoConstraints = false
        clockFace.onScrub = { [weak self] minutes in
            self?.clock.nudge(by: minutes)
        }
        view.addSubview(clockFace)

        // 两段式控制条：上排时间调节（粗调|微调分组），下排 Release + Auto。
        let controls = makeControlBar()
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            clockFace.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clockFace.widthAnchor.constraint(equalToConstant: 108),
            clockFace.heightAnchor.constraint(equalToConstant: 108),
            clockFace.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -10),

            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func makeControlBar() -> UIStackView {
        // 上排：[-1h][-5m]  (间隙)  [+5m][+1h]，粗调与微调左右分组。
        let minusH = Theme.makeTimeButton("-1h") { [weak self] in self?.tickTime { $0.subHour() } }
        let minus5 = Theme.makeTimeButton("-5m") { [weak self] in self?.tickTime { $0.subFiveMinutes() } }
        let plus5  = Theme.makeTimeButton("+5m") { [weak self] in self?.tickTime { $0.addFiveMinutes() } }
        let plusH  = Theme.makeTimeButton("+1h") { [weak self] in self?.tickTime { $0.addHour() } }

        let leftPair = UIStackView(arrangedSubviews: [minusH, minus5])
        leftPair.axis = .horizontal
        leftPair.spacing = 6
        leftPair.distribution = .fillEqually

        let rightPair = UIStackView(arrangedSubviews: [plus5, plusH])
        rightPair.axis = .horizontal
        rightPair.spacing = 6
        rightPair.distribution = .fillEqually

        let timeRow = UIStackView(arrangedSubviews: [leftPair, rightPair])
        timeRow.axis = .horizontal
        timeRow.spacing = 28          // 中央留空隙，把「往回拨」和「往前拨」分开
        timeRow.distribution = .fillEqually

        // 下排：RELEASE（主）+ Auto（次）。
        let release = Theme.makeReleaseButton("RELEASE") { [weak self] in
            guard let self else { return }
            self.mahjong.releaseTiles(in: self.world)
            self.dismissTutorial()
        }
        let auto = Theme.makeAutoButton("⟳ Auto") { [weak self] in self?.toggleAuto() }
        autoButton = auto

        let actionRow = UIStackView(arrangedSubviews: [release, auto])
        actionRow.axis = .horizontal
        actionRow.spacing = 10
        // Release 占约 2/3，Auto 占 1/3。
        release.setContentHuggingPriority(.defaultLow, for: .horizontal)
        auto.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        auto.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let stack = UIStackView(arrangedSubviews: [timeRow, actionRow])
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }

    /// 切换 Auto 走时，并同步按钮视觉态。
    private func toggleAuto() {
        clock.toggleAutoPlay()
        let on = clock.isAutoPlaying
        autoButton?.configuration?.baseBackgroundColor = on
            ? Theme.brass
            : UIColor(white: 0.22, alpha: 1)
        autoButton?.configuration?.baseForegroundColor = on
            ? UIColor(white: 0.1, alpha: 1)
            : Theme.ivory
        feedback.play(.tick)
    }

    /// 调时间 + 反馈（点击的即时听觉/触觉反馈）。
    private func tickTime(_ op: (ClockManager) -> Void) {
        op(clock)
        feedback.play(.tick)
    }

    // MARK: - 事件

    private func subscribeEvents() {
        eventTokens.removeAll()
        let token = events.subscribe { [weak self] event in
            self?.handle(event)
        }
        eventTokens.append(token)
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case let .timeChanged(minutes, _, _):
            clockFace.setTime(minutes: minutes)
            hud.updateTime(clock?.displayString ?? "")
        case let .countdownTick(remaining):
            hud.updateRemaining(remaining)
        case let .abilityTriggered(kind):
            showAbilityToast(kind)
        case .levelCompleted:
            handleWin()
        case let .levelFailed(_, reason):
            handleFail(reason)
        default:
            break
        }
    }

    // MARK: - 胜负结算

    private func handleWin() {
        guard !isResolved else { return }
        isResolved = true

        // 通关粒子特效（在第一个出口处爆发），随后停世界。
        if let exitEntity = world.entities(with: ExitComponent.self).first {
            WinEffect.burst(at: exitEntity.node.presentation.worldPosition, in: world)
        }
        world.stop()

        let limit = currentLevel.timeLimit
        let remaining = puzzle.remainingTime
        let stars = saveStore.recordClear(levelId: currentLevelId, remaining: remaining, limit: limit)

        let detail = "Time left  \(minutesToClock(remaining))"
        let hasNext = saveStore.hasNext(after: currentLevelId)
        let overlay = ResultOverlay(
            won: true,
            title: currentLevel.title,
            stars: stars,
            detail: detail,
            hasNext: hasNext,
            onNext: { [weak self] in
                guard let self else { return }
                self.onAdvance?(min(self.currentLevelId + 1, SaveStore.totalLevels))
            },
            onRetry: { [weak self] in self?.retryLevel() },
            onMenu: { [weak self] in self?.onExit?() })
        overlay.present(in: view)
    }

    private func handleFail(_ reason: FailReason) {
        guard !isResolved else { return }
        isResolved = true
        world.stop()

        let overlay = ResultOverlay(
            won: false,
            title: currentLevel.title,
            stars: 0,
            detail: failText(reason),
            hasNext: false,
            onNext: {},
            onRetry: { [weak self] in self?.retryLevel() },
            onMenu: { [weak self] in self?.onExit?() })
        overlay.present(in: view)
    }

    private func failText(_ r: FailReason) -> String {
        switch r {
        case .fell:    return "The tile fell off the track."
        case .stuck:   return "The tile got stuck."
        case .timeout: return "Time ran out."
        }
    }

    private func retryLevel() {
        view.subviews.compactMap { $0 as? OverlayView }.forEach { $0.dismiss() }
        loadLevel(id: currentLevelId)
    }

    // MARK: - 暂停

    private func pauseGame() {
        guard !isResolved, world.isRunning else { return }
        world.stop()
        scnView.isPlaying = false

        let overlay = PauseOverlay(
            onResume: { [weak self] in self?.resumeGame() },
            onRetry: { [weak self] in
                self?.dismissOverlays()
                self?.retryLevel()
            },
            onMenu: { [weak self] in self?.onExit?() })
        overlay.present(in: view)
    }

    /// 继续：关闭暂停浮层并恢复世界。
    private func resumeGame() {
        dismissOverlays()
        scnView.isPlaying = true
        world.start()
    }

    private func dismissOverlays() {
        view.subviews.compactMap { $0 as? OverlayView }.forEach { $0.dismiss() }
    }

    // MARK: - 能力提示浮字

    private func showAbilityToast(_ kind: AbilityKind) {
        let text = kind == .dragonActivate ? "Dragon activates the mechanism!"
                                            : "White Tile shrugs off the trap!"
        let toast = PaddingLabel()
        toast.text = text
        toast.font = Theme.body(14)
        toast.textColor = UIColor(white: 0.1, alpha: 1)
        toast.backgroundColor = Theme.brass
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
        ])
        UIView.animate(withDuration: 0.2, animations: { toast.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.1, options: []) {
                toast.alpha = 0
            } completion: { _ in toast.removeFromSuperview() }
        }
    }

    // MARK: - 新手引导

    private func showTutorialIfNeeded(for id: Int) {
        dismissTutorial()
        guard id <= 3 else { return }
        let text: String
        switch id {
        case 1:  text = "Tap +5m / +1h to wind the clock to the target time, then Release the tile."
        case 2:  text = "The tile needs a steep ramp or an open gate. Change the time, then Release."
        default: text = "Watch how the mechanisms react to time, then time your Release."
        }
        let label = PaddingLabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = Theme.body(14)
        label.textColor = Theme.ink
        label.backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 84),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
        tutorialLabel = label
    }

    private func dismissTutorial() {
        guard let label = tutorialLabel else { return }
        tutorialLabel = nil
        UIView.animate(withDuration: 0.3, animations: { label.alpha = 0 }) { _ in
            label.removeFromParentIfPossible()
        }
    }

    // MARK: - 工具

    private func minutesString(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// 剩余秒数格式化为 M:SS。
    private func minutesToClock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private extension UIView {
    func removeFromParentIfPossible() { removeFromSuperview() }
}

/// 带内边距的 label（新手引导气泡用）。
final class PaddingLabel: UILabel {
    var inset = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right,
                      height: s.height + inset.top + inset.bottom)
    }
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines n: Int) -> CGRect {
        let r = super.textRect(forBounds: bounds.inset(by: inset), limitedToNumberOfLines: n)
        return r.inset(by: UIEdgeInsets(top: -inset.top, left: -inset.left,
                                        bottom: -inset.bottom, right: -inset.right))
    }
}
