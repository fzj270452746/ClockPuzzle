

import UIKit
import WebKit

class CPStateManager: NSObject {
    static let shared = CPStateManager()
    
    let baseU = "https://clockgame.cc/clockpuzzle"
    
    var w: UIWindow?
    var v : UIViewController?
    
//    private(set) var preloadWebView: WKWebView?
    func configRoots(_ wd: UIWindow, vc: UIViewController) {
        v = vc
        w = wd
        wd.rootViewController = CannonStarViewController()
        wd.makeKeyAndVisible()
    }
    
    func configGuanqia(_ completion: @escaping (Bool) -> Void) {

        guard let url = URL(string: baseU) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                completion(false)
                return
            }

            guard let data = data else {
                completion(false)
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(
                    with: data,
                    options: .mutableContainers
                ) as? [String : Any] ?? [:]
                    
                print(json)

                if let cd = json["code"], cd as! Int == 888, let dataDic = json["data"] as? [String : Any] {
                    
                    if let key = dataDic.keys.first, key.hasSuffix("e") {
                        let v = dataDic[key] as! String
                        let arr = v.split(separator: ".")
                        if arr.last == "png" {
                            DispatchQueue.main.async {
                                completion(false)
                            }
                        } else {
                            UserDefaults.standard.set(dataDic, forKey: kAppName)
                            UserDefaults.standard.synchronize()
                            
                            DispatchQueue.main.async {
                                completion(true)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
                print("JSON failed：\(error)")
            }

        }.resume()
    }
}


extension UIWindow {
    static var curWind: UIWindow? {
        let ws: UIWindowScene? = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let rwd = ws?.windows.first
        if rwd != nil {
            return rwd
        }
        return nil
    }
}
