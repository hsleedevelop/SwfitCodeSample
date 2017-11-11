//
//  JDRadioButton.swift
//  radar
//
//  Created by Jason Lee on 16/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

protocol JDRadioButtonDelegate: class {
    func didRadioButtonTouched(sender: JDRadioButton)
}

class JDRadioButton: JDButton {

    //MARK: * properties --------------------
    weak var delegate: JDRadioButtonDelegate?
    
    var imgDefault, imgChecked, imgDisabled: UIImage?
    var imgBgDefault, imgBgChecked, imgBgDisabled: UIImage?
    var textColorDefault, textColorChecked, textColorDisabled: UIColor?
    
    var checked: Bool = false {
        didSet {
            if checked {
                self.setImage(imgChecked, for: .normal)
                self.setImage(imgDefault, for: .selected)
                
                self.setBackgroundImage(imgBgChecked, for: .normal)
                self.setBackgroundImage(imgBgDefault, for: .selected)
                
                self.setTitleColor(textColorChecked, for: .normal)
                self.setTitleColor(textColorDefault, for: .selected)
                
            } else {
                self.setImage(imgDefault, for: .normal)
                self.setImage(imgChecked, for: .selected)
                
                self.setBackgroundImage(imgBgDefault, for: .normal)
                self.setBackgroundImage(imgBgChecked, for: .selected)
                
                self.setTitleColor(textColorDefault, for: .normal)
                self.setTitleColor(textColorChecked, for: .selected)
            }
            
            if value != nil {
                if value is JDBaseModel {
                    (value as! JDBaseModel).radioSelected = checked
                } else if value is JDKeyValue {
                    (value as! JDKeyValue).radioSelected = checked
                } else if value is JDStorageModel {
                    (value as! JDStorageModel).radioSelected = checked
                } else {
                    objc_setAssociatedObject(value, &JDAssociatedKeys.RadioButtonStatus, checked, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                }
            }
        }
    }
    
    var checkedFromValue: Bool {
        get {
            if value != nil {
                if value is JDBaseModel {
                    checked = (value as! JDBaseModel).radioSelected
                } else if value is JDKeyValue {
                    checked = (value as! JDKeyValue).radioSelected
                } else if value is JDStorageModel {
                    checked = (value as! JDStorageModel).radioSelected
                } else {
                    checked = objc_getAssociatedObject(value, &JDAssociatedKeys.RadioButtonStatus) as! Bool
                }
            }
            return checked
        }
    }
    
    
    //MARK: * Initialize ---------------------
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
    }


    //MARK: * Cycle --------------------
    override func awakeFromNib() {
        super.awakeFromNib()
        
        imgDefault = self.image(for: .normal)
        imgChecked = self.image(for: .selected)
        imgDisabled = self.image(for: .disabled)
        
        
        imgBgDefault = self.backgroundImage(for: .normal)
        imgBgChecked = self.backgroundImage(for: .selected)
        imgBgDisabled = self.backgroundImage(for: .disabled)
        
        textColorDefault = self.titleColor(for: .normal)
        textColorChecked = self.titleColor(for: .selected)
        textColorDisabled = self.titleColor(for: .disabled)
        
        self.addTarget(self, action: #selector(self.btnRadioButtonTouched(sender:)), for: .touchUpInside)
    }
    
    func btnRadioButtonTouched(sender: AnyObject? = nil) {
        checked = !checked
        delegate?.didRadioButtonTouched(sender: self)
    }
}

protocol JDRadioGroupDelegate: class {
    func didRadioGroupChanged(sender: JDRadioButton)
}


class JDRadioGroup: JDRadioButtonDelegate, Configurable {
    
    var btns: [JDRadioButton]
    var btnChecked: JDRadioButton?
    var delegate: JDRadioGroupDelegate?
    
    /** value for checked */
    var valueForChecked: AnyObject? {
        get {
            return btns.filter({$0.checked}).first?.value
        }
    }
    
    
    //MARK: * Initialize ---------------------
    
    init?() {
        btns = [JDRadioButton]()
    }
    
    init(radioButtons: [JDRadioButton], checkFirst: Bool = true) {
        
        btns = radioButtons
        
        btns.forEach({
            $0.delegate = self
            $0.addTarget(self, action: #selector(self.dispatchSomeRadioButtonTouched(sender:)), for: .touchUpInside)
        })
        
        btns.firstObject.checked = checkFirst
        if checkFirst {
            btnChecked = btns.firstObject
        }
    }
    
    convenience init(radioBtns: JDRadioButton ..., checkFirst: Bool = true) {
        self.init(radioButtons: radioBtns, checkFirst: checkFirst)
    }
    
    func addRadioButton(radioButton: JDRadioButton, checkFirst: Bool = true) {
        
        if let firstButton = btns.last, checkFirst {
            if btnChecked == nil {
                btnChecked = firstButton
                btnChecked!.checked = true
            }
        }
        //
        radioButton.delegate = self
        radioButton.addTarget(self, action: #selector(self.dispatchSomeRadioButtonTouched(sender:)), for: .touchUpInside)
        btns.append(radioButton)
    }
    
    @objc func dispatchSomeRadioButtonTouched(sender: JDRadioButton) {//특정 라디오버튼이 선택된 경우, 값을 설정함.
        
        guard sender.checked == false || btnChecked != sender else {
            return
        }
        
        btnChecked = sender
        btns.forEach({$0.checked = $0 == sender})
        
        //invalidate ui
        delegate?.didRadioGroupChanged(sender: sender)
    }
    
    func didRadioButtonTouched(sender: JDRadioButton) {
        
        btnChecked = sender
        btns.forEach({$0.checked = $0 == sender})
        
        //invalidate ui
        delegate?.didRadioGroupChanged(sender: sender)
    }
}


class JDReusableRadioGroup: JDRadioButtonDelegate {
    
    var delegate: JDRadioGroupDelegate?
    var tableView: UITableView?
    var collectionView: UICollectionView?
    
    private var values: [AnyObject?]
    
    init() {
        values = [AnyObject]()
    }
    
    var valueForChecked: AnyObject? {
        get {
            return values.filter({
                if $0 is JDBaseModel {
                    return ($0 as! JDBaseModel).radioSelected
                } else if $0 is JDKeyValue {
                    return ($0 as! JDKeyValue).radioSelected
                } else if $0 is JDStorageModel {
                    return ($0 as! JDStorageModel).radioSelected
                } else {
                    return objc_getAssociatedObject($0, &JDAssociatedKeys.RadioButtonStatus) as! Bool
                }
            }).firstObject
        }
    }
    
    func addRadioButton(radioButton: JDRadioButton) {
        
        guard values.count == 0 || values.contains(where: { $0 !== radioButton.value}) else {//?
            return
        }
        
        radioButton.delegate = self
        
        if let value = radioButton.value {
            values.append(value)
        }
    }
    
    func didRadioButtonTouched(sender: JDRadioButton) {
        
        for value in values {
            if value === sender.value {
                sender.checked = true
                continue
            }
            
            if value is JDBaseModel {
                (value as! JDBaseModel).radioSelected = false
            } else if value is JDKeyValue {
                (value as! JDKeyValue).radioSelected = false
            } else if value is JDStorageModel {
                (value as! JDStorageModel).radioSelected = false
            } else {
                objc_setAssociatedObject(value, &JDAssociatedKeys.RadioButtonStatus, false, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
        }
        
        //invalidate ui
        tableView?.reloadData()
        collectionView?.reloadData()
        
        delegate?.didRadioGroupChanged(sender: sender)
    }
}
