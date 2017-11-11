//
//  RequestModel.swift
//  partners
//
//  Created by Hyungsuk Lee on 5/18/16.
//  Copyright © 2016 classtime. All rights reserved.
//

import Foundation
import UIKit
import ObjectMapper
import PromiseKit
import AwaitKit

protocol JDAPIRequestProtocol: Configurable {
    associatedtype ModelType
    init(model: ModelType?)

    func toDictionary() -> Dictionary<String, AnyObject>?
    func toString() -> String?
}


class RequestModel: JDAPIRequestProtocol {

    //MARK: * Initialize --------------------- 
    /** 리퀘스트 시, 모델객체를 넘겨야 할 경우에 사용함. */
    required init(model: AnyClass? = nil) {
    }

    /** 모델 객체를 딕셔너리 형태로 변환함 for API Request */
    func toDictionary() -> Dictionary<String, AnyObject>? {
        return nil
    }

    func toString() -> String? {
        return nil
    }
}

class RequestTModel<T> : RequestModel {

    var body: T?

    //MARK: * Initialize --------------------- 
    required init(model: T? = nil) {
        super.init()
        body = model
    }

    override func toDictionary() -> Dictionary<String, AnyObject>? {
        var dic = super.toDictionary()!
        if body != nil {
            dic["body"] = self.body as? AnyObject
        }

        return dic
    }

    override func toString() -> String? {
        return nil
    }
}

//CollectionType, DictionaryLiteralConvertible
class RequestVOModel<T: JDAPIRequestProtocol>: RequestTModel<T> {

    //MARK: * Initialize --------------------- 
    required init(model: T? = nil) {
        super.init()
    }

    override func toDictionary() -> Dictionary<String, AnyObject>? {

        var dic = super.toDictionary()!

        if body != nil && body is JDAPIRequestProtocol {
            dic["body"] = body!.toDictionary()
        }

        return dic
    }

    override func toString() -> String? {
        return nil
    }
}


class RequestRPModel<T: JDAPIResponseProtocol>: JDAPIRequestProtocol {
    
    var APIPath = String.empty
    var method = RequestMethod.GET
    var parameters: [String: AnyObject]? = nil
    var representType: T? = nil
    var completion: JDFacadeCompletionBlockWithObject? = nil

    /// 로딩 에니메이션 표시 여부
    var showLoadingView: Bool = true
    
    /// 스플래시 백그라운드 이미지 표시 여부
    var showSplashView: Bool = false
    
    /// 에러발생시 에러 메시지 출력 여부
    var showError: Bool = true
    
    /// 로그인이 필요한 경우,
    var needSession: Bool = false
    private var lock: Bool = false
    
    //MARK: * Initialize ---------------------
    required init(model: T? = nil) {
        
    }
    
    func toDictionary() -> Dictionary<String, AnyObject>? {
        return nil
    }
    
    func toString() -> String? {
        return nil
    }
    
    /** API 요청  */
    func request() {
        if needSession && JDFacade.facade.session == nil {
            JDFacade.ux.loadLoginView()
            return
        }
        
        APIHandler.requestJSONWithRequest(self)
    }
    
    //TODO: 이미지 업로딩을 위한 요청: prameter 설정 변경 필요.
    func requestUpload(to images: [UIImage]?) {
        if let uploadImgs = images {
            APIHandler.requestUploadImages(self, images: uploadImgs)
        } else {
            APIHandler.requestJSONWithRequest(self)
        }
    }


//    func request() -> Promise<RequestRPModel> {
//        APIHandler.requestJSONWithRequest(self)
//        return Promise(self)
//    }
}


