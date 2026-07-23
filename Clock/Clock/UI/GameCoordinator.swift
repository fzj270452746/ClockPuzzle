//
//  GameCoordinator.swift
//  Clock
//
//  流程协调器：管理 主菜单 → 关卡选择 → 游戏 → 结算 的界面流转。
//  它持有全局共享服务（SaveStore、EventBus 之外的进程级依赖），
//  并用 UINavigationController 承载各屏。刻意集中在一处做导航，
//  各 VC 不互相 push（避免耦合），只通过回调把「下一步意图」抛给协调器。
//
//  为什么引入它：此前 SceneDelegate 直接 new 一个 GameViewController(levelId:1)，
//  没有菜单、没有关卡选择、通关后自动跳关——玩家无从选择。协调器把这些串成完整产品流程。
//

import UIKit

final class GameCoordinator {

    private let window: UIWindow
    private let nav: UINavigationController
    private let saveStore = SaveStore()

    init(window: UIWindow) {
        self.window = window
        self.nav = UINavigationController()
        nav.setNavigationBarHidden(true, animated: false)
        window.rootViewController = nav
    }

    /// 启动：展示主菜单。
    func start() {
        let menu = MenuViewController(saveStore: saveStore)
        menu.onPlay = { [weak self] in self?.showLevelSelect() }
        menu.onContinue = { [weak self] in
            guard let self else { return }
            self.startLevel(self.saveStore.highestUnlocked)
        }
        nav.setViewControllers([menu], animated: false)
        window.makeKeyAndVisible()
    }

    // MARK: - 关卡选择

    private func showLevelSelect() {
        let select = LevelSelectViewController(saveStore: saveStore)
        select.onPick = { [weak self] id in self?.startLevel(id) }
        select.onBack = { [weak self] in self?.nav.popViewController(animated: true) }
        nav.pushViewController(select, animated: true)
    }

    // MARK: - 进入关卡

    private func startLevel(_ id: Int) {
        let game = GameViewController(levelId: id, saveStore: saveStore)
        game.onExit = { [weak self] in self?.popToMenuOrSelect() }
        game.onAdvance = { [weak self] nextId in
            // 用替换而非 push，避免关卡在导航栈里无限堆叠。
            self?.replaceTop(with: nextId)
        }
        nav.pushViewController(game, animated: true)
    }

    private func replaceTop(with id: Int) {
        let game = GameViewController(levelId: id, saveStore: saveStore)
        game.onExit = { [weak self] in self?.popToMenuOrSelect() }
        game.onAdvance = { [weak self] nextId in self?.replaceTop(with: nextId) }
        var stack = nav.viewControllers
        if !stack.isEmpty { stack.removeLast() }
        stack.append(game)
        nav.setViewControllers(stack, animated: true)
    }

    private func popToMenuOrSelect() {
        // 回退到导航栈里最近的非游戏界面（关卡选择或主菜单）。
        if let target = nav.viewControllers.last(where: { !($0 is GameViewController) }) {
            nav.popToViewController(target, animated: true)
        } else {
            nav.popToRootViewController(animated: true)
        }
    }
}
