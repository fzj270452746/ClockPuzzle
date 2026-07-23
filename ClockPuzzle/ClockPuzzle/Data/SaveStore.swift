//
//  SaveStore.swift
//  Clock
//
//  本地存档。用 UserDefaults 持久化「解锁进度」与「每关最佳成绩」。
//  刻意做成可注入的轻服务（非全局单例泛滥）：由流程协调器持有一个实例并向下传递。
//
//  存什么、为什么：
//   - highestUnlocked：已解锁的最高关卡 id。通关第 N 关即解锁 N+1，关卡选择据此置灰。
//   - records[id]：每关最佳成绩（星级 + 剩余时间）。只在更好时覆盖，保证「最佳」语义。
//  星级规则（用剩余时间比例，客观且可复现）：通关即 ≥1 星；剩余 ≥1/3 给 2 星；≥2/3 给 3 星。
//

import Foundation

/// 单关最佳成绩。Codable 以便整体序列化进 UserDefaults。
struct LevelRecord: Codable, Equatable {
    var cleared: Bool
    var stars: Int              // 0...3
    var bestRemaining: TimeInterval
}

final class SaveStore {

    /// 关卡总数（与 BuiltinLevels 的章节表一致）。
    static let totalLevels = 200

    private let defaults: UserDefaults
    private let unlockedKey = "clock.highestUnlocked"
    private let recordsKey  = "clock.records"

    /// 内存缓存，避免每次解码。
    private var recordsCache: [Int: LevelRecord]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([Int: LevelRecord].self, from: data) {
            self.recordsCache = decoded
        } else {
            self.recordsCache = [:]
        }
    }

    // MARK: - 解锁进度

    /// 已解锁的最高关卡 id（至少为 1，第一关永远可玩）。
    var highestUnlocked: Int {
        max(1, defaults.integer(forKey: unlockedKey))
    }

    /// 是否已解锁某关。
    func isUnlocked(_ id: Int) -> Bool { id <= highestUnlocked }

    /// 是否还有下一关可进。
    func hasNext(after id: Int) -> Bool { id < Self.totalLevels }

    // MARK: - 成绩读写

    func record(for id: Int) -> LevelRecord? { recordsCache[id] }

    /// 由剩余时间与限时算星级（0...3）。
    static func stars(remaining: TimeInterval, limit: TimeInterval) -> Int {
        guard limit > 0 else { return 1 }
        let ratio = max(0, remaining) / limit
        if ratio >= 2.0 / 3.0 { return 3 }
        if ratio >= 1.0 / 3.0 { return 2 }
        return 1
    }

    /// 记录一次通关：解锁下一关，并在成绩更好时更新最佳。
    /// 返回本次获得的星级（供结算面板显示）。
    @discardableResult
    func recordClear(levelId: Int, remaining: TimeInterval, limit: TimeInterval) -> Int {
        let earned = Self.stars(remaining: remaining, limit: limit)

        // 解锁下一关。
        let nextUnlock = min(levelId + 1, Self.totalLevels)
        if nextUnlock > highestUnlocked {
            defaults.set(nextUnlock, forKey: unlockedKey)
        }

        // 只在更好时覆盖最佳成绩。
        let existing = recordsCache[levelId]
        let bestStars = max(earned, existing?.stars ?? 0)
        let bestRemaining = max(remaining, existing?.bestRemaining ?? 0)
        recordsCache[levelId] = LevelRecord(cleared: true, stars: bestStars, bestRemaining: bestRemaining)
        persistRecords()

        return earned
    }

    // MARK: - 汇总（关卡选择/菜单用）

    /// 已通关关卡数。
    var clearedCount: Int { recordsCache.values.filter { $0.cleared }.count }

    /// 累计星数。
    var totalStars: Int { recordsCache.values.reduce(0) { $0 + $1.stars } }

    // MARK: - 私有

    private func persistRecords() {
        if let data = try? JSONEncoder().encode(recordsCache) {
            defaults.set(data, forKey: recordsKey)
        }
    }

#if DEBUG
    /// 测试/调试用：清空全部进度。
    func resetAll() {
        defaults.removeObject(forKey: unlockedKey)
        defaults.removeObject(forKey: recordsKey)
        recordsCache = [:]
    }
#endif
}
