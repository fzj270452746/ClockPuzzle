//
//  LevelLoader.swift
//  Clock
//
//  关卡加载器。优先从 bundle 里的 JSON 读取；找不到时回退到
//  内置的程序化关卡工厂（仍然是数据，不是 switch 逻辑分支）。
//

import Foundation

struct LevelLoader {

    enum LoadError: Error { case notFound, decodeFailed(Error) }

    /// 从 bundle 加载 "level_<id>.json"。
    static func loadJSON(id: Int, bundle: Bundle = .main) -> LevelData? {
        guard let url = bundle.url(forResource: "level_\(id)", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(LevelData.self, from: data)
        } catch {
            assertionFailure("level_\(id).json decode failed: \(error)")
            return nil
        }
    }

    /// 对外统一入口：先 JSON，再回退到内置工厂。
    static func load(id: Int) -> LevelData {
        if let json = loadJSON(id: id) { return json }
        return BuiltinLevels.make(id: id)
    }
}
