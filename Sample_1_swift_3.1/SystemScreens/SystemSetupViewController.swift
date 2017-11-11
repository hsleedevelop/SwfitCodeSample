//
//  SystemSetupViewController.swift
//  radar
//
//  Created by Jason Lee on 16/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit
class SystemSetupTableViewCell: JDTableViewCell {
    
}

enum RDLocale {
    case timezone
    case language
}

class SystemSetupViewController: JDTableViewController {
    enum RDSetupMode: Int {
        case test = 0
        case city = 1
        case autoMute = 2
//        case alert = 3
        case laserDetect = 3
        case voice = 4
        case gps = 5
    }
    
    @IBOutlet var rdosTestMode: [JDRadioButton]!
    @IBOutlet var rdosCityMode: [JDRadioButton]!
    @IBOutlet var rdosAutoMuteMode: [JDRadioButton]!
    @IBOutlet var rdosAlert: [JDCheckBox]!
    @IBOutlet var rdosLaserDetect: [JDRadioButton]!
    @IBOutlet var rdosVoice: [JDRadioButton]!
    @IBOutlet var rdosGPS: [JDRadioButton]!

    @IBOutlet weak var lblTimezone: JDLabel!
    @IBOutlet weak var lblLanguage: JDLabel!
    
    //MARK: * properties --------------------
    lazy var rgroups: [JDRadioGroup]? = {
        
        return [JDRadioGroup(radioButtons: self.rdosTestMode, checkFirst: false),
                JDRadioGroup(radioButtons: self.rdosCityMode, checkFirst: false),
                JDRadioGroup(radioButtons: self.rdosAutoMuteMode, checkFirst: false),
                JDRadioGroup(radioButtons: self.rdosLaserDetect, checkFirst: false),
                JDRadioGroup(radioButtons: self.rdosVoice, checkFirst: false),
                JDRadioGroup(radioButtons: self.rdosGPS, checkFirst: false)]
    }()

    //MARK: * IBOutlets --------------------
//    @IBOutlet weak var tableView: JDTableView! {
//        didSet {
//            tableView.dataSource = self
//            tableView.delegate = self
//            
//            tableView.tableFooterView = UIView() //this call table events
//            
//            tableView.separatorStyle = .none
//            tableView.isScrollEnabled = false
//            
//        }
//    }
    @IBOutlet weak var btnTimeZone: JDButton! {
        didSet {
            btnTimeZone.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                self?.lblTimezone.text = TimeZone.current.abbreviation()
            }
        }
    }
    @IBOutlet weak var btnLanguage: JDButton! {
        didSet {
            btnLanguage.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                self?.loadTableView(locale: .language)
            }
        }
    }

    @IBOutlet weak var btnSave: JDButton! {
        didSet {
            btnSave.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                self?.saveSettings()
            }
        }
    }
    
    //MARK: * Initialize --------------------

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initProperties()
        self.initUI()
        self.prepareViewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }


    private func initProperties() {

        rdosTestMode[0].value = "on" as AnyObject
        rdosTestMode[1].value = "off" as AnyObject
        
        rdosCityMode[0].value = "Highway" as AnyObject
        rdosCityMode[1].value = "City" as AnyObject
        rdosCityMode[2].value = "AutoCity" as AnyObject
        
        rdosAutoMuteMode[0].value = "on" as AnyObject
        rdosAutoMuteMode[1].value = "off" as AnyObject
        
        rdosAlert[0].value = "K" as AnyObject
        rdosAlert[1].value = "X" as AnyObject
        rdosAlert[2].value = "Ka338" as AnyObject
        rdosAlert[3].value = "Ka343" as AnyObject
        rdosAlert[4].value = "Ka347" as AnyObject
        rdosAlert[5].value = "Ka355" as AnyObject

        
        rdosLaserDetect[0].value = "on" as AnyObject
        rdosLaserDetect[1].value = "off" as AnyObject
        
        rdosVoice[0].value = "on" as AnyObject
        rdosVoice[1].value = "off" as AnyObject
        
        rdosGPS[0].value = "on" as AnyObject
        rdosGPS[1].value = "off" as AnyObject
        
        
        //1. get settings
        RDHandler.handler.status.signal.observeValues({ [weak self] (status) in
            JDFacade.runOnMainThread {
                self?.updateSettings(setting: status.rdSetting)
            }
        })
        
        self.updateSettings(setting: RDHandler.handler.rdSetting)
    }


    private func initUI() {
        tableView.tableFooterView = UIView() //this call table events
        
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
    }


    func prepareViewDidLoad() {
        self.getSystemSettings()
    }
    
    override func refreshViewController() {
        self.prepareViewDidLoad()
    }

    //MARK: * Main Logic --------------------
    private func getSystemSettings() {
        
        if RDHandler.handler.status.rdSetting == nil {
            RDHandler.handler.getSystemSetup(completion: nil)
        }
    }
    
    func updateSettings(setting: DCSettingModel?) {
        
        guard let setting = setting else {
            return
        }
        
        func nested(bool: Bool?, rgroup: JDRadioGroup?) {
            guard let bool = bool, let rgroup = rgroup else {
                return
            }
            
            if let radio = bool ? rgroup.btns.first : rgroup.btns.last {
                rgroup.didRadioButtonTouched(sender: radio)
            }
        }
        
        nested(bool: setting.test, rgroup: self.rgroups?[RDSetupMode.test.rawValue])
        nested(bool: setting.autoMute, rgroup: self.rgroups?[RDSetupMode.autoMute.rawValue])
        nested(bool: setting.laserDetect, rgroup: self.rgroups?[RDSetupMode.laserDetect.rawValue])
        nested(bool: setting.voice, rgroup: self.rgroups?[RDSetupMode.voice.rawValue])
        nested(bool: setting.gps, rgroup: self.rgroups?[RDSetupMode.gps.rawValue])
        
        if let mode = setting.cityMode, let rgroup = self.rgroups?[RDSetupMode.city.rawValue] {
            if mode == "Highway" {
                rgroup.didRadioButtonTouched(sender: rgroup.btns[0])
            } else if mode == "City" {
                rgroup.didRadioButtonTouched(sender: rgroup.btns[1])
            } else if mode == "AutoCity" {
                rgroup.didRadioButtonTouched(sender: rgroup.btns[2])
            }
        }
        
        self.rdosAlert.forEach({ (chk) in
            chk.checked = false
        })
        
        setting.alert?.components(separatedBy: "|").forEach({ (alert) in // (K, X, Ka, Ka338,Ka343,Ka347,Ka355)
            if alert == "K" {
                self.rdosAlert[0].checked = true
            } else if alert == "X" {
                self.rdosAlert[1].checked = true
            } else if alert == "Ka338" {
                self.rdosAlert[2].checked = true
            } else if alert == "Ka343" {
                self.rdosAlert[3].checked = true
            } else if alert == "Ka347" {
                self.rdosAlert[4].checked = true
            } else if alert == "Ka355" {
                self.rdosAlert[5].checked = true
            }
        })
        
        self.lblTimezone.text = "GMT+\(setting.timezone ?? "")"
        self.lblLanguage.text = setting.language
        
        self.tableView.reloadData()
    }
    
    func saveSettings() {

        let newSetting = DCSettingModel()

        newSetting.test = rgroups?[RDSetupMode.test.rawValue].valueForChecked as? String == "on"
        newSetting.cityMode = rgroups?[RDSetupMode.city.rawValue].valueForChecked as? String
        
        newSetting.autoMute = rgroups?[RDSetupMode.autoMute.rawValue].valueForChecked as? String == "on"
        
        newSetting.laserDetect = rgroups?[RDSetupMode.laserDetect.rawValue].valueForChecked as? String == "on"
        newSetting.alert = rdosAlert.filter({ return $0.checked }).map({ (chk: JDCheckBox) -> String in
            return chk.value as? String ?? ""
        }).joined(separator: "|")
        
        newSetting.voice = rgroups?[RDSetupMode.voice.rawValue].valueForChecked as? String == "on"
        newSetting.gps = rgroups?[RDSetupMode.gps.rawValue].valueForChecked as? String == "on"
        
        newSetting.timezone = self.lblTimezone.text?.digits()
        newSetting.language = self.lblLanguage.text
        
        RDHandler.handler.setSystemSetup(settings: newSetting.convertToStream()) { _ in
            JDFacade.ux.showToast("Settings saved.")
        }
    }
    
    
    func loadTableView(locale: RDLocale) {
        
        var dataSource = JDKeyValueList()
        if locale == .language {
            
            dataSource.list = [JDKeyValue("Bulgarian", "Bulgarian"),
                               JDKeyValue("Czech", "Czech"),
                               JDKeyValue("German", "German"),
                               JDKeyValue("Hungarian", "Hungarian"),
                               JDKeyValue("English", "English"),
                               JDKeyValue("Russian", "Russian")]
            dataSource.listType = .radio
            dataSource.title = "Language Select"
        }
        
        JDFacade.ux.showTableAlertPopup(dataSource: dataSource, type: RDRadioTableViewCell.self) {
            if let keyValue = dataSource.selectedKeyValue {
                //set somewhere
                self.lblLanguage.text = keyValue.key;
            }
        }
    }

    //MARK: * UI Events --------------------


    //MARK: * Memory Manage --------------------

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


//extension SystemSetupViewController : UITableViewDataSource, UITableViewDelegate {
//    
//    func numberOfSections(in tableView: UITableView) -> Int {
//        return 2
//    }
//    
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 1
//    }
//    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        
//        var height = 0.c
//        if indexPath.section == 0 {
//            height = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemConnectStatusTableViewCell.self)?.height ?? 0
//        } else if indexPath.section == 1 {
//            height = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoTableViewCell.self)?.height ?? 0
//        }
//        return height
//    }
//    
//    /** cellForRowAtIndexPath */
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        var cell: UITableViewCell!
//        
//        if indexPath.section == 0 {
//            cell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemConnectStatusTableViewCell.self)
//            
//        } else if indexPath.section == 1 {
//            cell = (tableView as? JDTableView)?.dequeueReusableCell(type: SystemInfoTableViewCell.self)
//            
//        }
//        return cell
//    }
//    
//    /** didSelectRow */
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        
//    }
//}

