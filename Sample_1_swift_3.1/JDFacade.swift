//
//  JDFacade.swift
//  JasonDevelop
//
//  Created by Hyungsuk Lee on 12/15/15.
//  Copyright © 2015 JasonMakesApp. All rights reserved.
//

import Foundation
import Swift
import SnapKit

#if DEBUG
    import FLEX
#endif

typealias JDFacadeCompletionBlock = () -> Void
typealias JDFacadeCompletionBlockWithObject = (Any?) -> Void

        
class JDFacade: NSObject {
    static let facade = JDFacade()
    
    static let ux = RDUXHandler()
    static let permission = PermissionHandler()
//
//    typealias biz = MLBizHandler
//    typealias error = MLErrorHandler

    
    //MARK: * Instance Properties ---------------------
    
    //MARK: * AppDelegate ---------------------
    static var app: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    var appDelegate: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }

//    var deviceUUID: String {
//        get {
//            return JDUUID.createUUIDForApplication()
//        }
//    }

    var APNSToken = String.empty

    var pushInfo: [NSObject: AnyObject]?
//    var deepLinkAction: DeepLinkAction? {
//        didSet {
//            if JDFacade.ux.tc != nil {
//                JDFacade.ux.dispatchQueryAction(deepLinkAction)
//            }
//        }
//    }

    //MARK: * Session ---------------------
    /// 로그인, 회원가입 시 임시 세션으로 사용
//    var tmpSession: UserModel?
//    
//    var hasSessionIfNotLoadAuthView: Bool {
//        get {
//            let hasSession = self.session != nil
//            if !hasSession {
//                JDFacade.ux.loadLoginView()
//            }
//            
//            return hasSession
//        }
//    }
//    
//    /// 로그인 후, 사용자 정보
//    var session: UserModel? {
//        didSet {
//            guard session != nil else { return }
//            
//            if !self.APNSToken.isEmpty && self.APNSToken != MLConstants.session.TokenError.rawValue {
//                //request update push token
//                async {
//                    JDFacade.biz.auth.awaitToPutPushToken(self.APNSToken)
//                }
//                
//            } else {
//
//                if self.APNSToken != MLConstants.session.TokenError.rawValue {//if no error, but retry get token
//                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(3.0 * Double(NSEC_PER_SEC))),
//                                   dispatch_get_main_queue()) { () -> Void in
//                                    self.session = self.session
//                    }
//                }
//            }
//        }
//    }


    var isFirstLoadingOnLaunch = true
    
    var funcRunOnMainThread: (() -> Void)? {
        didSet {
            DispatchQueue.main.async {//run in mainThread
                self.funcRunOnMainThread?()
                self.funcRunOnMainThread = nil
                
            }
        }
    }
    
    //MARK: * UI Events --------------------
    class func runOnMainThread(fn: @escaping () -> Void) {
        DispatchQueue.main.async {//run in mainThread
            fn()
        }
    }
    
    /** convenience for dispatch_after  */
    class func dispatchAfter(duration: Double, fn: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            fn()
        }
    }
    
    
    class func getRadioButtonStatus(object: AnyObject) -> Bool {
        return (objc_getAssociatedObject(object, &JDAssociatedKeys.RadioButtonStatus) as? Bool ?? false)
    }
    
    class func setRadioButtonStatus(object: AnyObject, status: AnyObject) {//for radio box
        objc_setAssociatedObject(object, &JDAssociatedKeys.RadioButtonStatus, status, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }
    
    class func getCheckBoxStatus(object: AnyObject) -> Bool {
        return (objc_getAssociatedObject(object, &JDAssociatedKeys.CheckBoxStatus) as? Bool ?? false)
    }
    
    class func setCheckBoxStatus(object: AnyObject, status: AnyObject) {//for radio box
        objc_setAssociatedObject(object, &JDAssociatedKeys.CheckBoxStatus, status, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }
    
    func didChangeNetworkReachability(notification: Notification) {
        
        if let reachability = notification.object as? RealReachability {
            let status = reachability.currentReachabilityStatus()
            JDLogger.debug(status.rawValue)
            JDLogger.toast(status.rawValue)
        }
    }

    //MARK: * Init --------------------- 
    override init() {
        super.init()

    }
    
    func initialize() {
        
        RealReachability.sharedInstance().autoCheckInterval = 0.3
        RealReachability.sharedInstance().startNotifier()

        NotificationCenter.default.addObserver(self, selector: #selector(didChangeNetworkReachability(notification:)),
                                               name: NSNotification.Name.realReachabilityChanged, object: nil)
    }
}

///TODO : 임시로 로그인 유저와 Guest를 구별하기 위해 만듬. 나중에 수정.
extension JDFacade {
    
    ///Seesion Token을 확인하여, User와 Guest를 구분한다.
    func isLogInUser() -> Bool {
        return true //JDFacade.facade.session != nil
    }
}


