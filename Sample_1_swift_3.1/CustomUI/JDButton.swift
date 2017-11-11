//
//  JDButton.swift
//  radar
//
//  Created by Jason Lee on 11/04/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class JDButton: UIButton {
    
    //MARK: * Properties --------------------
    var value: AnyObject?
    var value2: AnyObject?
    
    var fontNormal: UIFont?
    var fontSelected: UIFont?
    
    fileprivate var _insets, _bgInsets: UIEdgeInsets?

    //MARK: * IBInspectable --------------------
    @IBInspectable var borderColor: UIColor? = UIColor.clear {
        didSet {
            layer.borderColor = self.borderColor?.cgColor
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = self.borderWidth
        }
    }
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = self.cornerRadius
            layer.masksToBounds = self.cornerRadius > 0
        }
    }
    @IBInspectable var minimumFontScaleFactor: CGFloat = 0 {
        didSet {
            self.titleLabel?.minimumScaleFactor = self.minimumFontScaleFactor
            self.titleLabel?.adjustsFontSizeToFitWidth = true
            self.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        }
    }
    
    @IBInspectable var rectForCap: CGRect = CGRect.zero
    @IBInspectable var rectForCapBackground: CGRect = CGRect.zero
    
    //MARK: * Initialize --------------------
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
}

extension JDButton {
    
    override func draw(_ rect: CGRect) {
        
        if !rectForCap.equalTo(CGRect.zero) {//rectForCap이 설정된 경우, 이미지를 리사이즈함.
            
        }
        
        if !rectForCapBackground.equalTo(CGRect.zero) {//rectForCapBackground이 설정된 경우, 이미지를 리사이즈함.
            
            let top = rectForCapBackground.minY, left = rectForCapBackground.minX,
            bottom = rectForCapBackground.height, right = rectForCapBackground.width
            
            _bgInsets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            
            self.setBackgroundImageStretch(for: .normal, capInsets: _bgInsets!)
            self.setBackgroundImageStretch(for: .highlighted, capInsets: _bgInsets!)
            self.setBackgroundImageStretch(for: .selected, capInsets: _bgInsets!)
            self.setBackgroundImageStretch(for: .disabled, capInsets: _bgInsets!)
        }
        
        self.layer.cornerRadius = self.cornerRadius
        self.layer.borderWidth = self.borderWidth
        self.layer.borderColor = self.borderColor?.cgColor
    }
    
    func setBackgroundImageStretch(for state: UIControlState, capInsets: UIEdgeInsets) {
        
        if var image = self.backgroundImage(for: state), !UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsets.zero)  {
            image = ImageUtil.resizeImageWithCapInsets(image: image, capInsets: capInsets, resizingMode: .stretch)
            super.setBackgroundImage(image, for: state)
        }
    }
    
    override func setBackgroundImage(_ image: UIImage?, for state: UIControlState) {
        super.setBackgroundImage(image, for: state)
        self.setBackgroundImageStretch(for: state, capInsets: _bgInsets ?? UIEdgeInsets.zero)
    }
}

extension UIButton {
    /// show background as rounded rect, like mail addressees
    var rounded: Bool {
        get { return layer.cornerRadius > 0 }
        set { roundWithTitleSize(size: newValue ? titleSize : 0) }
    }
    
    /// removes other title attributes
    var titleSize: CGFloat {
        get {
            let titleFont = attributedTitle(for: .normal)?.attribute(NSFontAttributeName, at: 0, effectiveRange: nil) as? UIFont
            return titleFont?.pointSize ?? UIFont.buttonFontSize
        }
        set {
            // TODO: use current attributedTitleForState(.Normal) if defined
            if UIFont.buttonFontSize == newValue || 0 == newValue {
                setTitle(currentTitle, for: .normal)
            }
            else {
                let attrTitle = NSAttributedString(string: currentTitle ?? "", attributes:
                    [NSFontAttributeName: UIFont.systemFont(ofSize: newValue), NSForegroundColorAttributeName: currentTitleColor]
                )
                setAttributedTitle(attrTitle, for: .normal)
            }
            
            if rounded {
                roundWithTitleSize(size: newValue)
            }
        }
    }
    
    func roundWithTitleSize(size: CGFloat) {
        let padding = size / 4
        layer.cornerRadius = padding + size * 1.2 / 2
        let sidePadding = padding * 1.5
        contentEdgeInsets = UIEdgeInsets(top: padding, left: sidePadding, bottom: padding, right: sidePadding)
        
        if size.isZero {
            backgroundColor = UIColor.clear
            setTitleColor(tintColor, for: .normal)
        }
        else {
            backgroundColor = tintColor
            let currentTitleColor = titleColor(for: .normal)
            if currentTitleColor == nil || currentTitleColor == tintColor {
                setTitleColor(UIColor.white, for: .normal)
            }
        }
    }
    
    override open func tintColorDidChange() {
        super.tintColorDidChange()
        if rounded {
            backgroundColor = tintColor
        }
    }
}
