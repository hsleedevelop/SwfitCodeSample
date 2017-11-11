//
//  ResponseModel.swift
//  partners
//
//  Created by Hyungsuk Lee on 5/18/16.
//  Copyright © 2016 classtime. All rights reserved.
//

import Foundation
import UIKit
import ObjectMapper
import SwiftDate

public class JDDateTransform: TransformType {
    public typealias Object = NSDate
    public typealias JSON = Double

    public init() {}

    public func transformFromJSON(value: AnyObject?) -> NSDate? {
        if let timeInt = value as? Double {
            return NSDate(timeIntervalSince1970: NSTimeInterval(timeInt))
        }

        if let dateStr = value as? String {

            var date: NSDate!
            if dateStr.characters.count == 10 {
                date = dateStr.toDate(DateFormat.Custom("yyyy-MM-dd"))
            } else if dateStr.characters.count > 10 {
                date = dateStr.toDate(DateFormat.Custom("yyyy-MM-dd HH:mm:ss"))
            }

            return date
        }

        return nil
    }

    public func transformToJSON(value: NSDate?) -> Double? {
        if let date = value {
            return Double(date.timeIntervalSince1970)
        }
        return nil
    }
}


protocol JDAPIResponseProtocol: Mappable, Configurable {
    //local variable
    
    /** 현재 요청에 대한 API path */
    var APIPath: String? {get set}
    
    /** API-Status 값을 가지고 있으며, Error핸들링 처리 */
    var code: APIStatus? {get set}
    
    /** 오류메시지 - Error핸들링 처리 */
    var message: String? {get set}
    
    /** 페이크 응답 데이터를 리턴. */
    var fakeData: AnyObject? {get}
    
    init?()
}

extension JDAPIResponseProtocol {

}

/// 리스폰스 모델
class ResponseModel: JDAPIResponseProtocol {

    //MARK: * properties ---------------------
    private var _apiPath: String?
    private var _code: APIStatus? = .Succeed
    
    var message: String?
    var subMessage: String?
    var dictionary: [String: AnyObject]?
    
    var code: APIStatus? {
        get {
            return _code
        }
        set(v) {
            _code = v
        }
    }

    var APIPath: String? {
        get {
            return _apiPath
        }
        set(v) {
            _apiPath = v
        }
    }
    
    var fakeData: AnyObject? {
        get {
            return nil
        }
    }

    required init() {
    }

    required init?(_ map: Map) {
    }

    func mapping(map: Map) {
        code        <- (map["code"], EnumTransform<APIStatus>())
        message     <- map["message"]
        subMessage  <- map["sub_message"]
        
        dictionary = map.JSONDictionary
//        code = APIStatus(raw: map["code"].value() ?? -1)
    }
    
    func initFakeData() {
        
    }
}


/// 순수 데이터 형을 제너릭으로 사용할 경우의 클래스
class ResponseTModel<T>: ResponseModel {

    //MARK: * properties ---------------------
    var data: T?
    
    //MARK: * Initialize ---------------------
    required init?(_ map: Map) {
        super.init(map)
    }


    override func mapping(map: Map) {
        super.mapping(map)
        
        map.JSONDictionary.keys.forEach { //should change to array,
            if $0 != "message" && $0 != "sub_message" && $0 != "code" {
                data <- map[$0]
                return
            }
        }
//        
//        if let key = map.JSONDictionary.keys.first {
//            data <- map[key]
//        }
    }
}

/// 모델링 매핑을 위한 제너릭 클래스
class ResponseVOModel<T: JDModelProtocol> : ResponseModel {

    //MARK: * properties ---------------------
    private var _data: T?
    var data: T? {
        get {
            if _fake != nil {
                return _fake
            }
            return _data
        }
        set (v) {
            _data = v
        }
    }
    
    
    //MARK: * Initialize ---------------------
    private var _fake: T?
    override var fakeData: AnyObject? {
        get {
            _fake = T.initFake()
            return _fake as? AnyObject
        }
    }

    required init() {
        super.init()
    }

    
    required init?(_ map: Map) {
        super.init(map)
    }

    //MARK: * Main Logic ---------------------
    override func mapping(map: Map) {
        super.mapping(map)
        
        _data = T(map)
        _data?.mapping(map)
    }
}

/// 컬렉션 타입 모델링 매핑을 위한 제너릭 클래스
class ResponseVOCModel<T: JDModelProtocol> : ResponseModel {
    
    //MARK: * properties ---------------------
    private var _data: [T]?
    var data: [T]? {
        get {
            if _fake != nil {
                return _fake
            }
            return _data
        }
        set (v) {
            _data = v
        }
    }
    
    //MARK: * Initialize ---------------------
    private var _fake: [T]?
    override var fakeData: AnyObject? {
        get {
            _fake = []
            
            for _ in 1...10 {
                _fake?.append(T.initFake()!)
            }
            return _fake as? AnyObject
        }
    }
    
    required init() {
        super.init()
    }
    
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    //MARK: * Main Logic ---------------------
    override func mapping(map: Map) {
        super.mapping(map)
        
//        _data = Array(map)
//        _data = map(
    }
}



