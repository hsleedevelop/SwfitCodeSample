//
//  RDUXHandler.swift
//  radar
//
//  Created by Jason Lee on 27/03/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit
import SwiftMessages


class RDUXHandler: NSObject {

    //MARK: * properties --------------------
    var screens = RDUXCatalogs.screens
    
    //MARK: * properties --------------------
    
    var tc: UITabBarController? //hidden tabbarController
    //MARK: * IBOutlets --------------------


    //MARK: * Initialize --------------------

    override init() {

    }
    
    /** 탭바 설정 */
    func generateNavigationController<T>(_ type: T.Type) -> UINavigationController {
        let nc = UINavigationController(navigationBarClass: type as? AnyClass, toolbarClass: nil)
        //nc.isNavigationBarHidden = true

        return nc
    }
    
    private func configureMainTabBarController() {
        
        let vc0 = JDFacade.ux.screens(.system(.main)).instantiate()
        let vc1 = JDFacade.ux.screens(.driving(.main)).instantiate()
        
        let nc0 = self.generateNavigationController(RDNavigationBar.self)
        nc0.viewControllers = [vc0]
        
        let nc1 = self.generateNavigationController(RDNavigationBar2.self)
        nc1.viewControllers = [vc1]
        
        tc = UITabBarController().then {
            $0.delegate = self
            $0.viewControllers = [nc0, nc1]
            $0.tabBar.isHidden = true
        }
    }
    
    func toggleTabBarViewController() {
        tc?.selectedIndex = tc?.selectedIndex == 0 ? 1 : 0
    }

    
    func gotoSystemViewController() {
        if tc == nil {
            self.configureMainTabBarController()
        }
        
        JDFacade.app.window?.setRootViewController(vc: self.tc!, animated: true)
    }

    //MARK: * Main Logic --------------------
    func showToast(_ title: String, body: String = "") {
        
        let view = MessageView.viewFromNib(layout: .CardView)
        view.configureTheme(.success)
        view.configureDropShadow()
        view.configureContent(title: title, body: body)
        view.bodyLabel?.isHidden = body.isEmpty
        view.button?.isHidden = true
        
        var config = SwiftMessages.defaultConfig
        config.presentationStyle = .bottom
        
        SwiftMessages.show(config: config, view: view)
    }
    
    func showToastError(_ title: String, body: String = "") {
        
        let view = MessageView.viewFromNib(layout: .CardView)
        view.configureTheme(.error)
        view.configureDropShadow()
        view.configureContent(title: title, body: body)
        view.bodyLabel?.isHidden = body.isEmpty
        view.button?.isHidden = true
        
        var config = SwiftMessages.defaultConfig
        config.presentationStyle = .bottom
        
        SwiftMessages.show(config: config, view: view)
    }
    
    func alert(title: String = "", message: String = "", completion: JDAlertCompletion? = nil) {
        JDAlert(title: title, message: message, preferredStyle: .alert)
            .addAction(title: "OK", style: .default, handler: { _ in
                completion?(JDAlertType.OK)
            })
            .show()
    }
    
    func confirm(title: String = "", message: String = "", completion: JDAlertCompletion? = nil) {
        JDAlert(title: title, message: message, preferredStyle: .alert)
            .addAction(title: "cancel", style: .default, handler: { _ in
                completion?(JDAlertType.cancel)
            })
            .addAction(title: "OK", style: .default, handler: { _ in
                completion?(JDAlertType.OK)
            })
            .show()
    }
    
    func showTableAlertPopup<T: JDTableViewCell>(dataSource: JDKeyValueList?, type: T.Type, completion: JDFacadeCompletionBlock?) {
        
        if let vc = self.screens(.common(.tableAlert)).instantiate() as? RDTableAlertViewController {
            vc.dataSource = dataSource
            vc.tableCellType = type
            
            let _ = vc.show { (alert: JDAlertType) in
                if alert == .OK {
                    completion?()
                }
            }
        }
    }
    
    
    @discardableResult func showProgressPopup(title: String, message: String?, progress: Double, completion: JDFacadeCompletionBlock?) -> RDProgressPopViewController {
        var tvc: RDProgressPopViewController?
        
        if let vc = self.currentViewController as? RDProgressPopViewController {
            JDFacade.runOnMainThread {
                vc.setProperties(title: title, message: message, progress: progress)
            }
            tvc = vc
            
        } else if let vc = self.screens(.common(.progress)).instantiate() as? RDProgressPopViewController {
            
            JDFacade.runOnMainThread {
                vc.show { (alert: JDAlertType) in
                    if alert == .OK {
                        completion?()
                    }
                    }.setProperties(title: title, message: nil, progress: progress)
            }
            
            tvc = vc
        }
        return tvc!
    }
}

extension RDUXHandler {

}

extension RDUXHandler {// UIViewController
    
    var currentViewController: UIViewController? {
        return ViewControllerUtil.currentViewController
    }
    
    func present(_ viewController: UIViewController, animated: Bool, completion: JDFacadeCompletionBlock?) {
        self.currentViewController?.present(viewController, animated: animated, completion: completion)
    }
    
    func push(_ viewController: UIViewController, animated: Bool) {
        
        if let nc = self.currentViewController?.navigationController, let navBar = nc.navigationBar as? RDNavigationBar3  {
//            navBar.barView?.btnLeft.removeTarget(navBar, action: #selector(navBar.dismiss), for: .touchUpInside)
//            navBar.barView?.btnLeft.addTarget(navBar, action: #selector(navBar.pop), for: .touchUpInside)
        }
        
        self.currentViewController?.navigationController?.pushViewController(viewController, animated: animated)
    }
    
    func refreshCurrentViewController<T: JDViewController>(vcType: T.Type) {
        if let vc = self.getViewController(vcType: T.self) {
            JDFacade.runOnMainThread {
                vc.refreshViewController()
            }
        }
    }
    
    func getViewController<T>(vcType: T.Type) -> T? {
        
        var targetVC: UIViewController?
        
        guard var vc = self.currentViewController else {
            return nil
        }
        
        if vc.presentingViewController != nil {
            vc = vc.presentingViewController ?? vc
        }
        
        if vc is T {
            return vc as? T
        }
        
//        if vc is SlideMenuController {
//            vc = (vc as! SlideMenuController).mainViewController!
//        }
        
        
        if vc is UITabBarController {
            vc = (vc as! UITabBarController).selectedViewController!
        }
        
        if vc is UINavigationController {
            if let nc = vc as? UINavigationController {
                for subvc in nc.viewControllers.reversed() {
                    if subvc is T {
                        targetVC = subvc
                        break;
                    }
                }
            }
        }
        
        if let nc = vc.navigationController {
            for subvc in nc.viewControllers.reversed() {
                if subvc is T {
                    targetVC = subvc
                    break;
                }
            }
        }
        
        if vc.presentedViewController != nil {
            if vc.presentedViewController is T {
                return vc.presentedViewController as? T
            }
        }
        
        if vc.childViewControllers.count > 0 {
            for subvc in vc.childViewControllers.reversed() {
                if subvc is T {
                    targetVC = subvc
                    break;
                } else if let pvc = subvc as? UIPageViewController, subvc is UIPageViewController {
                    for childvc in pvc.viewControllers!.reversed() {
                        if childvc is T {
                            targetVC = childvc
                            break;
                        }
                    }
                }
            }
        }
        
        if targetVC == nil {
            targetVC = vc
        }
        
        return targetVC as? T
    }
}

extension RDUXHandler: UITabBarControllerDelegate {
    
    @objc func tabBarController(tabBarController: UITabBarController, didSelectViewController viewController: UIViewController) {
        
    }
    
    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        return viewController != tabBarController.selectedViewController
    }
}
