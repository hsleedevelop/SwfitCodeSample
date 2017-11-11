//
//  DashboardViewController.swift
//  radar
//
//  Created by Jason Lee on 30/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

class DashboardViewController: UIViewController {

    //MARK: * properties --------------------
    var funcToggleOfParentViewController: ((Int)->()?)?

    //MARK: * IBOutlets --------------------
    @IBOutlet weak var btnModeToggle: JDButton! {
        didSet {
            btnModeToggle.reactive.controlEvents(.touchUpInside).observeValues { _ in
                self.funcToggleOfParentViewController?(0)
            }
        }
    }

    @IBOutlet weak var gaugeView: SpeedoGuageView!
    @IBOutlet weak var lblSpeed: JDLabel!
    @IBOutlet weak var lblSpeedUnit: JDLabel!
    @IBOutlet weak var btnCompass: JDButton! {
        didSet {
            btnCompass.isUserInteractionEnabled = false
        }
    }
    @IBOutlet weak var lblCityMode: JDLabel! {
        didSet {
            lblCityMode.text = RDHandler.handler.status.rdSetting?.cityMode ?? "CityMode"
            RDHandler.handler.status.signal.observeValues { [weak self] (status) in
                self?.lblCityMode.text = RDHandler.handler.status.rdSetting?.cityMode ?? "CityMode"
            }
        }
    }
    @IBOutlet weak var btnUserAreaDelete: JDButton! {
        didSet {
            btnUserAreaDelete.reactive.controlEvents(.touchUpInside).observeValues { _ in
                RDHandler.handler.clearUserArea(completion: { _ in
                    
                })
            }
        }
    }
    
    @IBOutlet weak var alertContainer: DashboardAlertView!
    @IBOutlet weak var constraintAlertContainerHeight: NSLayoutConstraint!
    //MARK: * Initialize --------------------

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initProperties()
        self.initUI()
        self.prepareViewDidLoad()
    }


    private func initProperties() {
        
        RDHandler.handler.driving.signal.observeValues { [weak self] (driving) in
            self?.updateDashboard(driving: driving)
        }
        
        RDHandler.handler.alert.signal.observeValues { [weak self] (alert) in
            self?.updateAlert(alert: alert)
        }
        
        if let driving = RDHandler.handler.drivings?.last {
            self.updateDashboard(driving: driving)
        }
        
        if let alert = RDHandler.handler.alerts?.last {
            self.updateAlert(alert: alert)
        }
    }


    private func initUI() {
        
        alertContainer.isHidden = true
        constraintAlertContainerHeight.constant = 0
        self.view.layoutIfNeeded()
    }
    
    func updateDashboard(driving: RDDriving) {
        lblSpeed.text = "\(driving.speed.i)"
        btnCompass.setTitle(driving.compass, for: .normal)
        
        //if alert or drive?
        self.gaugeView.updateGuage(speed: driving.speed)
        
        if let alert = RDHandler.handler.alerts?.last {//distance
            alertContainer.distance = driving.distanceFrom(to: alert.coordinate)
        }
    }
    
    func updateAlert(alert: RDAlert) {
        
        alertContainer.alert = alert
        if let driving = RDHandler.handler.drivings?.last {//distance
            alertContainer.distance = alert.distanceFrom(to: driving.coordinate)
        }

        //if alert or drive?
        alertContainer.isHidden = false
        constraintAlertContainerHeight.constant = 112
        
        UIView.animate(withDuration: JDAnimation.duration, animations: { 
            self.view.layoutIfNeeded()
        }) { [weak self] (finished) in
            
            JDFacade.dispatchAfter(duration: 5.0, fn: {
                self?.constraintAlertContainerHeight.constant = 0
                
                UIView.animate(withDuration: JDAnimation.duration, animations: {
                    self?.view.layoutIfNeeded()
                }) { [weak self] (finished) in
                    self?.alertContainer.isHidden = true
                }
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.gaugeView.setNeedsDisplay()
    }


    func prepareViewDidLoad() {

    }

    //MARK: * Main Logic --------------------


    //MARK: * UI Events --------------------


    //MARK: * Memory Manage --------------------

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


extension DashboardViewController {

}
