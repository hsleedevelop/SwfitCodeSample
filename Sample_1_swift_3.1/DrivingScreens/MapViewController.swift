//
//  MapViewController.swift
//  radar
//
//  Created by Jason Lee on 30/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit
import GoogleMaps


class RDMapMarker: GMSMarker {
    var value: AnyObject?
}


class MapViewController: UIViewController {

    //MARK: * properties --------------------
    /// change view of parentViewController
    var funcToggleOfParentViewController: ((Int)->()?)?
    
    var mapMarkers: [RDMapMarker] = []
    
    lazy var poiData: JDKeyValueList = {
        
        var dataSource = JDKeyValueList()
        dataSource.list = [JDKeyValue("Shape Curve", #imageLiteral(resourceName: "map_popup_icon_h")),
                           JDKeyValue("Tunnel", #imageLiteral(resourceName: "map_popup_icon_t")),
                           JDKeyValue("Rest Area", #imageLiteral(resourceName: "map_popup_icon_e")),
                           JDKeyValue("Falling Rock", #imageLiteral(resourceName: "map_popup_icon_f")),
                           JDKeyValue("Bus line is under\nvideo surveillance", #imageLiteral(resourceName: "map_popup_icon_b")),
                           JDKeyValue("User Area", #imageLiteral(resourceName: "map_popup_icon_u")),
                           JDKeyValue("Video mobile\nsurveillance", #imageLiteral(resourceName: "map_popup_icon_v")),
                           JDKeyValue("Obey Regulation Speed", #imageLiteral(resourceName: "map_popup_icon_o")),
                           
                           JDKeyValue("Red Light Camera", #imageLiteral(resourceName: "map_popup_icon_r")),
                           JDKeyValue("Speed Camera", #imageLiteral(resourceName: "map_popup_icon_s")),
                           JDKeyValue("Warning, possible\nmobile speed camera", #imageLiteral(resourceName: "map_popup_icon_m")),
                           JDKeyValue("Warning, possible\npolice trap", #imageLiteral(resourceName: "map_popup_icon_w")),
                           JDKeyValue("Police trap", #imageLiteral(resourceName: "map_popup_icon_p")),
                           JDKeyValue("Accident Area", #imageLiteral(resourceName: "map_popup_icon_a"))
        ]
        
        dataSource.listType = .image
        dataSource.title = "Point Icon"
        
        return dataSource
    } ()
    
    lazy var alertView: POIAlertView = {
        return POIAlertView.instantiateFromNib(name: "POIAlertView")
    } ()

    //MARK: * IBOutlets --------------------

    @IBOutlet weak var lblMeter: JDLabel!
    @IBOutlet weak var lblMeterUnit: JDLabel!
    
    
    @IBOutlet weak var btnCompass: JDButton!
    @IBOutlet weak var btnHelp: JDButton! {
        didSet {
            btnHelp.reactive.controlEvents(.touchUpInside).observeValues { _ in
                JDFacade.ux.showTableAlertPopup(dataSource: self.poiData, type: RDImageTableViewCell.self, completion: nil)
            }
        }
    }
    
    @IBOutlet weak var mapView: GMSMapView! {
        didSet {
            self.initMapView()
        }
    }
    
    
    @IBOutlet weak var btnModeToggle: JDButton! {
        didSet {
            btnModeToggle.reactive.controlEvents(.touchUpInside).observeValues { _ in
                self.funcToggleOfParentViewController?(1)
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


    private func initProperties() {
        RDHandler.handler.driving.signal.observeValues { [weak self] (driving) in
            self?.updateMapDriving(driving: driving)
        }
        
        RDHandler.handler.alert.signal.observeValues { [weak self] (alert) in
            self?.updateMapAlert(alert: alert)
        }
        
        if let driving = RDHandler.handler.drivings?.last {
            self.updateMapDriving(driving: driving)
        }
        
        if let alert = RDHandler.handler.alerts?.last {
            self.updateMapAlert(alert: alert)
        }
    }


    private func initUI() {

    }

    private func initMapView() {
        
        let coord = JDFacade.permission.defaultLocation.coordinate
        let camera = GMSCameraPosition.camera(withLatitude: coord.latitude, longitude:coord.longitude, zoom:16) //FIXME : delete?
        
        mapView.camera = camera
        mapView.delegate = self
        
        mapView.settings.rotateGestures = false
        mapView.settings.tiltGestures = false
        
        mapView.isMyLocationEnabled = false
        
        self.startGPSTracking()
    }
    
    /// startGPSTracking
    private var recursiveCount: Int = 0
    private func startGPSTracking() {
        
        let pstatus = JDFacade.permission.statusOfLocation(completion: { (type, status) in //권한 변경 체크
            if status == .authorized {//
                self.startGPSTracking()
            }
        })
        
        guard pstatus == .authorized else {//권한 설정이 안된 경우, 리턴 -> completion처리
            return
        }

        if JDFacade.permission.userLocation == nil && recursiveCount < 25 {
            JDFacade.permission.startUpdatingLocation()
            
            recursiveCount += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                self.startGPSTracking() //recursive
            })
            
            return
        }
        
        recursiveCount = 0
        
        JDFacade.permission.locationSignal.observeResult { (result) in //for Debug: it doesn't work if location simulated,
            guard result.error == nil else {
                //show error popup
                return
            }
            
            if let location = result.value {
                //You can change viewingAngle from 0 to 45
                let camera = GMSCameraPosition.camera(withTarget: location.coordinate, zoom: 16, bearing: location.course, viewingAngle: 0)
                
                self.mapView.animate(to: camera)
                self.userMarker.position = location.coordinate
            }
        }
    }
    
    lazy var userMarker: RDMapMarker = { [weak self] in
  
        func nested(_ umarker: RDMapMarker) {
            umarker.icon = umarker.icon == #imageLiteral(resourceName: "icon_location") ? #imageLiteral(resourceName: "icon_location_press") : #imageLiteral(resourceName: "icon_location")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                nested(umarker)
            }
        }
        
        let umarker = RDMapMarker()
        umarker.icon = #imageLiteral(resourceName: "icon_location_press")
        umarker.map = self?.mapView
        
        nested(umarker)
        
        return umarker
    } ()

    func prepareViewDidLoad() {

    }

    //MARK: * Main Logic --------------------
    func updateMapDriving(driving: RDDriving) {
        
        //stop updateLocation if get driving info
        JDFacade.permission.stopUpdatingLocation()
        
        //You can change viewingAngle from 0 to 45
        let camera = GMSCameraPosition.camera(withTarget: driving.coordinate, zoom: 16, bearing: driving.direction, viewingAngle: 0)
        
        self.mapView.animate(to: camera)
        self.userMarker.position = driving.coordinate
        
        lblMeter.text = "\(driving.speed.i)"
        
        btnCompass.setTitle(driving.compass, for: .normal)
        
        if let alert = RDHandler.handler.alerts?.last, alertView.superview != nil {//distance
            alertView.distance = driving.distanceFrom(to: alert.coordinate)
            alertView.lblSpeed.text = self.lblMeter.text
        }
    }
    
    func generatePOI(alert: RDAlert) -> UIView {
        let poiView = POIView.instantiateFromNib(name: "POIView")
        poiView.alert = alert
        return poiView
    }
    
    func showWarning(alert: RDAlert) {
        
        //set alert info
        alertView.alert = alert
        
        if alertView.superview == nil {
            self.navigationController?.view.addSubview(alertView)
            alertView.snp.makeConstraints { (make) in
                make.edges.equalToSuperview()
            }
        }
        
        if let driving = RDHandler.handler.drivings?.last {//distance
            alertView.distance = alert.distanceFrom(to: driving.coordinate)
            alertView.lblSpeed.text = self.lblMeter.text
        }
        alertView.startWarning()
    }
    
    func updateMapAlert(alert: RDAlert) {

        let marker = RDMapMarker()
        marker.position = alert.coordinate
        marker.map = mapView
        if alert.isWarning && self === (JDFacade.ux.currentViewController?.childViewControllers[0] as! UIPageViewController).viewControllers?[0] {
            marker.iconView = self.generatePOI(alert: alert) //MLUX.images.locationIcon()
            if alert == RDHandler.handler.alerts?.filter({$0.isWarning}).last {
                self.showWarning(alert: alert)
            }
        } else {
            marker.icon = alert.typeImage
        }
        
        //show alert2 when over speed and first time? last?
//        if RDHandler.handler.alerts?.last == alert {
//            
//        }
        
        //distance = last driving coord - last alert coord.
        if let driving = RDHandler.handler.drivings?.last {//distance
            //alertContainer.lblDistance.text = "\(alert.distanceFrom(to: driving.coordinate))"
        }
    }

    //MARK: * UI Events --------------------


    //MARK: * Memory Manage --------------------

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


extension MapViewController: GMSMapViewDelegate {
    
//    func mapView(mapView: GMSMapView, didTapMarker marker: GMSMarker) -> Bool {
//        
//        //1. change marker icon as selected
//        currentMarker = marker as? MLMapMarker
//        
//        guard currentMarker?.value != nil else {
//            return true
//        }
//        
//        //2. get info of Studio
//        cardView.studio = currentMarker!.value as? StudioModel
//        
//        //3. move cardview
//        constraintBottomStudioCard.constant = 0
//        UIView.animateWithDuration(JDAnimation.duration) {
//            self.cardContainer.layoutIfNeeded()
//        }
//        
//        return true
//    }
//    
//    func mapView(mapView: GMSMapView, didTapAtCoordinate coordinate: CLLocationCoordinate2D) {
//        
//        //1. change marker set nil
//        currentMarker = nil
//        
//        //2. move cardview
//        constraintBottomStudioCard.constant = -cardContainer.height
//        UIView.animateWithDuration(JDAnimation.duration) {
//            self.cardContainer.layoutIfNeeded()
//        }
//    }

	
}
