//
//  SystemInfoViewController.swift
//  radar
//
//  Created by Jason Lee on 11/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

class SystemConnectStatusTableViewCell: JDTableViewCell {
    
//    var signal: Signal<RDStatus, NoError>? {
//        didSet {
//            
//            signal?.take(until: self.reactive.prepareForReuse).observeValues({ [weak self] _ in
//                self?.btnRDStatus.isSelected = RDHandler.handler.isConnectedRDInterface2.value || JDDeviceType.isSimulator
//            })
//        }
//    }
    var status: RDStatus? {
        didSet {
            guard let status = status else {
                return
            }
            
            JDLogger.toast("status.isConnecting \(status.isConnecting) || status.hasRDServerConnected \(status.hasRDServerConnected)")
            btnRDStatus.isSelected = status.isConnecting || status.hasRDServerConnected
        }
    }
    
    @IBOutlet weak var btnRDStatus: JDButton! {
        didSet {
            btnRDStatus.isUserInteractionEnabled = false
        }
    }
    
    @IBOutlet weak var btnGPSStatus: JDButton! {
        didSet {
            btnGPSStatus.isUserInteractionEnabled = false
        }
    }
    
    @IBOutlet weak var btnResetConnect: JDButton! {
        didSet {
            
            btnResetConnect.reactive.controlEvents(.touchUpInside).observeValues { _ in //[weak self] in
                
                guard RDHandler.ux.isConnectedTCPServer else {
                    return
                }
            }
        }
    }
    
    @IBOutlet weak var btnConnect: JDButton! {
        didSet {

            btnConnect.reactive.controlEvents(.touchUpInside).observeValues { _ in //[weak self] in
                //goto hotspot info, if wifi and not rd server,
                guard RDHandler.ux.isConnectedTCPServer else {
                    return
                }
                
                let vc = JDFacade.ux.screens(.system(.rdSetting)).instantiate()
                let nc = JDFacade.ux.generateNavigationController(RDNavigationBar3.self)
                nc.viewControllers = [vc]
                
                if let navBar = nc.navigationBar as? RDNavigationBar3  {
                    navBar.title = "RD Setting"
                    navBar.barView?.btnLeft.setImage(#imageLiteral(resourceName: "head_btn_close"), for: .normal)
                    navBar.barView?.btnLeft.addTarget(navBar, action: #selector(navBar.dismiss), for: .touchUpInside)
//                    navBar.barView?.btnLeft.addTarget(vc, action: #selector(vc.dismiss(animated:completion:)), for: .touchUpInside)
                }
                JDFacade.ux.present(nc, animated: true, completion: nil)
            }
        }
    }
}

class SystemInfoTableViewCell: JDTableViewCell {
    
    var parentViewController: JDViewController?
    var typedSWVersions: [SWVersionsBySWType]? {
        didSet {
            self.updateData()
            
            self.constraintTableHeight.constant = { [weak self] in
                return 28 + ((self?.typedSWVersions?.count ?? 0) *  38)
            } ()
            self.layoutIfNeeded()
            
            self.tableView.reloadData()
        }
    }
    
    private func updateData() {
        lblModelName.text = RDVersionHandler.handler.rdVersion?.modelName
        lblAppVersion.text = JDApplication.shortVersion
    }
    
    @IBOutlet weak var lblModelName: JDLabel!
    @IBOutlet weak var lblAppVersion: JDLabel!
    @IBOutlet weak var tableView: JDTableView! {
        didSet {
            tableView.dataSource = self
            tableView.delegate = self
            
            tableView.separatorStyle = .none
            tableView.isScrollEnabled = false

//            tableView.tableFooterView = UIView() //this call table events
        }
    }
    @IBOutlet weak var constraintTableHeight: NSLayoutConstraint!
    
    
    @IBOutlet weak var btnDownload: JDButton! {
        didSet {
            btnDownload.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                
                if let checkedSWVersions = self?.typedSWVersions?.filter({ $0.swVersions.contains(where: {$0.device == DeviceType.Server.rawValue})}).filter({ $0.checkSelected }), checkedSWVersions.count > 0 {
                    self?.download(swVersions: checkedSWVersions)
                } else {
                    JDFacade.ux.showToastError("choose file first")
                }
            }
        }
    }
    
    @IBOutlet weak var btnUpdate: JDButton! {
        didSet {
            
            btnUpdate.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                
                guard RDHandler.ux.isConnectedTCPServer else {//check TCP
                    return
                }
                
                if let checkedSWVersions = self?.typedSWVersions?.filter({ $0.swVersions.contains(where: {$0.device == DeviceType.App.rawValue})}).filter({ $0.checkSelected }), checkedSWVersions.count > 0 {
                    self?.update(swVersions: checkedSWVersions)
                } else {
                    JDFacade.ux.showToastError("choose file first")
                }
            }
        }
    }
    
    private func download(swVersions: [SWVersionsBySWType]) {
        
        JDFacade.ux.confirm(title: "Download", message: "Do you want to download?", completion: { (alert: JDAlertType) in
            if alert == .OK {
                RDVersionHandler.handler.downloadSWVersionsFromServer(typedSWVersions: swVersions, completion: { [weak self] _ in
                    self?.parentViewController?.refreshViewController()
                })
            }
        })
    }
    
    private func update(swVersions: [SWVersionsBySWType]) {
        
        JDFacade.ux.confirm(title: "Update", message: "Do you want to update?", completion: { (alert: JDAlertType) in
            if alert == .OK {
                RDVersionHandler.handler.updateSWVersionsToRD(typedSWVersions: swVersions, completion: { [weak self] _ in
                    self?.parentViewController?.refreshViewController()
                })
            }
        })
    }

}

extension SystemInfoTableViewCell: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : (typedSWVersions?.count ?? 0)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        var height = 0.c
        if indexPath.section == 0 {
            height = SystemInfoSubTitleTableViewCell.height
            
        } else if indexPath.section == 1 {
            height = SystemInfoSubContentTableViewCell.height
        }
        
        return height
    }
    
    /** cellForRowAtIndexPath */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        if indexPath.section == 0 {
            cell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoSubTitleTableViewCell.self)
            
        } else if indexPath.section == 1 {
            if let tcell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoSubContentTableViewCell.self) {

                tcell.swVersionByType = self.typedSWVersions?[indexPath.row]
                cell = tcell
            }
        }

        return cell
    }
    
    /** willDisplayCell */
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
    }
    
    /** didSelectRow */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}

class SystemInfoSubTitleTableViewCell: JDTableViewCell {
    override class var height: CGFloat { get { return 28 } }
}

class SystemInfoSubContentTableViewCell: JDTableViewCell {
    override class var height: CGFloat { get { return 38 } }
    
    var swVersionByType: SWVersionsBySWType? {
        didSet {
            chkSelect.setTitle(swVersionByType?.swType.title, for: .normal)
            chkSelect.value = swVersionByType
            
            lblServer.text  = swVersionByType?.server?.version
            lblApp.text     = swVersionByType?.app?.version
            lblRD.text      = swVersionByType?.rd?.version
        }
    }

    
    @IBOutlet weak var chkSelect: JDCheckBox!
    @IBOutlet weak var lblServer: JDLabel!
    @IBOutlet weak var lblApp: JDLabel!
    @IBOutlet weak var lblRD: JDLabel!
}

class SystemConnectFTPTableViewCell: JDTableViewCell {
    override class var height: CGFloat { get { return 55 } }
    
    @IBOutlet weak var btnFTP: JDButton! {
        didSet {
            btnFTP.reactive.controlEvents(.touchUpInside).observeValues {_ in
                
                let vc = FTPInfoViewController()
                let nc = JDFacade.ux.generateNavigationController(RDNavigationBar3.self)
                nc.viewControllers = [vc]
                
                if let navBar = nc.navigationBar as? RDNavigationBar3  {
                    navBar.title = "FTP Info"
                    navBar.barView?.btnLeft.setImage(#imageLiteral(resourceName: "head_btn_close"), for: .normal)
                    navBar.barView?.btnLeft.addTarget(navBar, action: #selector(navBar.dismiss), for: .touchUpInside)
                }
                
                JDFacade.ux.present(nc, animated: true, completion: nil)
            }
        }
    }
}

class SystemInfoViewController: JDViewController {

    //MARK: * properties --------------------

    
    var versionInf: ResourceItem? {
        didSet {
            
        }
    }
    
//    lazy var refreshControl: UIRefreshControl = { [unowned self] in
//        let refreshControl = UIRefreshControl()
//        refreshControl.addTarget(self, action: #selector(SystemInfoViewController.handleRefresh(refreshControl:)), for: .valueChanged)
//        return refreshControl
//    }()

    //MARK: * IBOutlets --------------------
    @IBOutlet weak var tableView: JDTableView! {
        didSet {
            tableView.dataSource = self
            tableView.delegate = self
            
            tableView.tableFooterView = UIView() //this call table events
            
            tableView.separatorStyle = .none
            tableView.isScrollEnabled = false
        }
    }

    //MARK: * Initialize --------------------

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initProperties()
        self.initUI()
        self.prepareViewDidLoad()
    }


    private func initProperties() {

    }


    private func initUI() {
        RDHandler.handler.status.signal.observeValues { [weak self] (status) in
            self?.tableView.reloadData()
        }
    }


    func prepareViewDidLoad() {
        self.getVersionsOfAll()
    }

    override func refreshViewController() {
        self.prepareViewDidLoad()
    }
   
    
    //MARK: * Main Logic --------------------
    private func getVersionsOfAll() {
        
        //1. check RD status
//        RDHandler.handler.checkHotspot()
        
        //2. get all
        RDVersionHandler.handler.getVersionsOfAllDevices { [weak self] _ in
            JDFacade.runOnMainThread {
                self?.tableView.reloadData()
            }
        }
    }

    //MARK: * UI Events --------------------
    var typedSWVersions: [SWVersionsBySWType]? {
        return RDVersionHandler.handler.getVersionsBySWType()
    }

    //MARK: * Memory Manage --------------------

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

//    var statusCell: SystemConnectStatusTableViewCell? {
//        didSet {
//            guard let tcell = statusCell else {
//                return
//            }
//            
//            tcell.btnRDStatus.value = RDHandler.handler.isConnectedRDInterface2
//            
//            RDHandler.handler.isConnectedRDInterface2.signal.observeValues { result in
//                tcell.btnRDStatus.isSelected = result
//            }
//            
//            RDHandler.handler.interfaceSignal?.take(until: tcell.reactive.prepareForReuse).observeValues({ _ in
//                tcell.btnRDStatus.isSelected = RDHandler.handler.isConnectedRDInterface2.value || JDDeviceType.isSimulator
//            })
//        }
//    }
}


extension SystemInfoViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        var height = 0.c
        if indexPath.section == 0 {
            height = 120 //(tableView as? JDTableView)?.dequeueReusableCell(type: SystemConnectStatusTableViewCell.self)?.height ?? 0
        } else if indexPath.section == 1 {
            height = 521 //(tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoTableViewCell.self)?.height ?? 0
        } else if indexPath.section == 2 {
            height = 55 //(tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoTableViewCell.self)?.height ?? 0
        }
        return height
    }
    
    /** cellForRowAtIndexPath */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: JDTableViewCell!
        
        if indexPath.section == 0 {//status
            if let tcell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemConnectStatusTableViewCell.self) {
                tcell.status = RDHandler.handler.status;
                cell = tcell
            }
            
        } else if indexPath.section == 1 {//versions
            if let tcell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoTableViewCell.self) {
                tcell.typedSWVersions = self.typedSWVersions
                tcell.parentViewController = self
                
                cell = tcell
            }
        } else if indexPath.section == 2 {//versions
            if let tcell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemConnectFTPTableViewCell.self) {
                cell = tcell
            }
        }
        return cell
    }
    
    /** didSelectRow */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}
