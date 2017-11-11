//
//  APIHandler.swift
//  partners
//
//  Created by Hyungsuk Lee on 5/18/16.
//  Copyright © 2016 classtime. All rights reserved.
//

import Foundation
import UIKit
import ReactiveCocoa
import Alamofire
import ObjectMapper
import Kakapo
import SwiftyJSON

enum RequestMethod: String {
    case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
}

/** NSURLSessionConfiguration settings to Alamofire like timeout  */
struct APIManager {
    static let sharedManager: Alamofire.Manager = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = 60
        return Alamofire.Manager(configuration: configuration)
    }()
}

/// Handle for API Requests
class APIHandler {
    static let handler = APIHandler()

//MARK: * properties ------------------------------
    static var needSilent = false
    static var isRequesting: Bool = false
    static var headers: [String : String] = ["Platform": "ios",
                                             "Unique-Id": JDFacade.facade.deviceUUID] //FIXME : real

    private static var alamoFireManager: Alamofire.Manager {
        get {
            return APIManager.sharedManager
        }
    }

    private static var isFakeMode: Bool {
        get {
            var isFake = false
//            #if DEBUG_MODE
//                isFake = true
//            #endif
            return isFake
        }
    }

//MARK: * Main Logic ------------------------------
    class func sendAsyncPostRequest(APIPath APIPath: String, parameters: NSDictionary?, modelClass: AnyClass) -> AnyObject {
        return self.sendAsyncRequest(APIPath: APIPath, method: RequestMethod.POST, parameters: parameters, modelClass: modelClass, showLoadingView: true)
    }


    class func sendAsyncRequest(APIPath APIPath: String, method: RequestMethod, parameters: NSDictionary?, modelClass: AnyClass, showLoadingView: Bool) -> AnyObject {
        return APIHandler.alamoFireManager.request(.POST, APIPath, parameters: parameters as? [String : AnyObject], encoding:.JSON, headers: APIHandler.headers).response { (request, response, data, error) -> Void in
            return data
        }
    }

    /** 현재 요청을 취소함 */
    class func cancelAllRequest() {//FIXME: 테스트 필요
        APIHandler.alamoFireManager.session.invalidateAndCancel()
    }


//    class func requestJSONWithRequest<T: protocol<ResponseModelProtocol, JDModelProtocol>>(request: RequestRPModel<T>) {
//    class func requestJSONWithRequest<T: ResponseModelProtocol where T: RequestType>(request: RequestRPModel<T>) {
    /** API 요청 - 응답에 대한 모델 mapping 처리, convenience */
    class func requestJSONWithRequest<T: JDAPIResponseProtocol>(request: RequestRPModel<T>) {

        APIHandler.requestJSON(APIPath: request.APIPath, method: request.method, parameters: request.parameters, representType: T.self,
                               showLoadingView: request.showLoadingView, showSplashView: request.showSplashView, showError: request.showError, completion: request.completion)
    }

    /** API 요청 - 응답에 대한 모델 mapping 처리 */
    class func requestJSON<T: JDAPIResponseProtocol>(APIPath APIPath: String, method: RequestMethod, parameters: [String: AnyObject]?, representType: T.Type?,
                           showLoadingView: Bool, showSplashView: Bool, showError: Bool, completion: JDFacadeCompletionBlockWithObject?) {

        //개발 모드 - API 개발 미완료분에 대한 Mocking
        if isFakeMode, let stub = representType?.init() {
            if let fakeData = stub.fakeData {
                completion?(stub)
                return
            }
        }


        /** 에러 플래그에 따라 얼럿을 호출 후, 완료 컴플리션에 전달함. */
        func nestedShowError(showError: Bool, error: MLError, completion: JDFacadeCompletionBlockWithObject?) {
            if showError {//얼럿 표시, 에러처리
                JDFacade.error.cookError(error, completion: {
                    completion?(error)
                })
            } else {//에러 처리
                JDFacade.error.cookLogErrorSilently(error, completion: {
                    completion?(error)
                })
            }
        }
        
        /** 에러 플래그에 따라 얼럿을 호출 후, 완료 컴플리션에 전달함. */
        func nestedShowToast(error: MLError, completion: JDFacadeCompletionBlockWithObject?) {
            JDFacade.ux.toastError(error.localizedDescription)
            completion?(error)
        }
        
        var JSON: String?
        APIHandler.rac_requestJSON(APIPath: APIPath, method: method, parameters: parameters, showLoadingView: showLoadingView, showSplashView: showSplashView)
            .start(Observer<String, NSError> ( next: { value in
                JSON = value

                }, completed: {
                    
                    if var result = Mapper<T>().map(JSON) {//JSON isArray?
                        result.APIPath = APIPath
                        
                        ///Result Code가 nil이 나올 경우에 대한 방어 코드.
                        if result.code == nil {
                            result.code = APIStatus.None
                        }
                        
                        switch result.code! {
                        case .Succeed, .SucceedOK, .None:  //성공 시,,
                            break
                        case .Unauthorized: //goto login when unauthorized
                            let userInfo = [NSLocalizedDescriptionKey: result.message ?? String.empty]
                            let error = MLError(domain: "MLError", code: result.code!.rawValue, userInfo: userInfo)
                            
                            if let token = self.headers["Mylo_Token_Key"] {//check token
                                JDLogger.debug(token)
                            }
                            
                            nestedShowError(showError, error: error, completion: { result in
                                
                                //로컬 토큰 초기화
                                JDFacade.facade.session = nil
                                JDFacade.biz.storage.removeObjectForKey(MLConstants.session.TokenKey.rawValue)
                                
                                //게스트 랜딩 화면으로 이동
                                JDFacade.ux.gotoLandingForGuest()
                            })
                            return
                        case .BadRequest, .FailDeviceCheck: //show error from server
                            
                            var message = result.message ?? String.empty
                            if result.code == .FailDeviceCheck {
                                let submessage = (result as? ResponseModel)?.subMessage ?? String.empty
                                message = !submessage.isEmpty ? message + "\n\n" + submessage : message
                            }
                            
                            let userInfo = [NSLocalizedDescriptionKey: message]
                            let error = MLError(domain: "MLError", code: result.code!.rawValue, userInfo: userInfo)
                            
                            nestedShowError(showError, error: error, completion: completion)
                            return
//                        case .RetryConfirm, .NonPayment, .NoMembership, .FailDeviceCheckConfirm, .FailPayment, .EmailAlreadyExist: //process on bizHandler level
//                            //send API result
//                            break
                        case .SimpleBizError:
                            let userInfo = [NSLocalizedDescriptionKey: result.message ?? String.empty]
                            let error = MLError(domain: "MLError", code: result.code!.rawValue, userInfo: userInfo)

                            if showError {
                                nestedShowToast(error, completion: { result in
                                    completion?(result)
                                })
                            }
                            return
                        default:
                            
//                            nestedShowError(showError, error: MLErrorType.api(result.code!).error(), completion: completion)
                            break
                        }

                        //send API result
                        completion?(result)

                    } else if let resultArray = Mapper<T>().mapArray(JSON) {
                        //send API result for array
                        completion?(resultArray)

                    } else {//JSON Mapping error
                        nestedShowError(showError, error: MLErrorType.json(.mapping).error(), completion: completion)
                    }
                    

                }, failed: { error in

                    let mError = MLError(error: error)

                    if error.code == NSURLErrorCancelled {//Manual Force Cancelled
                        completion?(nil)
                        //nestedShowError(showError, error: mError, completion: completion)

                    } else if error.code == NSURLErrorTimedOut {//요청 시간 초과 시 재시도 여부,
                        JDFacade.ux.confirm(APIStatus.NSURLErrorTimedOut.localizedDescription, confirmLabel: MLStrings.local.retry(), cancelLabel: MLStrings.local.cancel(), completion: { (alert: JDAlertType) in
                            if alert == .OK {
                                APIHandler.requestJSON(APIPath: APIPath, method: method, parameters: parameters, representType: representType, showLoadingView: showLoadingView, showSplashView: showSplashView, showError: showError, completion: completion)
                                return
                            }

                            nestedShowError(showError, error: mError, completion: completion)
                        })
                    }
            }))
    }

    /** API 요청 - ReactiveCocoa를 이용한 응답 리턴  */
    class func rac_requestJSON(APIPath APIPath: String, method: RequestMethod, parameters: [String: AnyObject]?, showLoadingView: Bool, showSplashView: Bool) -> SignalProducer<String, NSError> {

        return SignalProducer<String, NSError> { observer, disposable in
            
            if let _ = JDFacade.ux.APITracer.indexOf(APIPath.hashValue) {//동일한 요청에 대해서는 캔슬
                return
            }
            
            if showLoadingView {
                JDFacade.ux.showLoading("Loading", showSplashView: showSplashView, hash: APIPath.hashValue)
            }

//            JDLogger.log(APIPath)
//            if parameters != nil {
//                JDLogger.log(parameters!.prettyJSON)
//            }

            var request: Alamofire.Request!
            if method == .GET || parameters == nil {
                request = APIHandler.alamoFireManager.request(Method(rawValue: method.rawValue)!, APIPath, parameters: parameters, headers: APIHandler.headers)
            } else {
                request = APIHandler.alamoFireManager.request(Method(rawValue: method.rawValue)!, APIPath, parameters: parameters, encoding:.JSON, headers: APIHandler.headers)
                JDLogger.debug("encoding:.JSON")
            }

            request.responseString(completionHandler: { (response) -> Void in
                JDLogger.log(response.request!.URL!)  // original URL request
                if parameters != nil {
                    JDLogger.log(parameters!.prettyJSON!)
                }
                
                switch response.result {
                case .Success(let value):
                    if !needSilent {
                        JDLogger.log(value)
                    }
                    
                    if showLoadingView {
                        JDFacade.ux.hideLoading(showLoadingView ? APIPath.hashValue : 0, completion: {
                            observer.sendNext(value)
                            observer.sendCompleted()
                        })
                    } else {
                        observer.sendNext(value)
                        observer.sendCompleted()
                    }
                    
                case .Failure(let error):
                    JDLogger.log(error)
                    
                    if showLoadingView {
                        JDFacade.ux.hideLoading(showLoadingView ? APIPath.hashValue : 0, completion: {
                            observer.sendFailed(error)
                        })
                    } else {
                        observer.sendFailed(error)
                    }
                }
            })
        }
    }
    
    
    /** 응답 결과를 리턴하지 않는 리퀘스트 */
    class func requestJSONWithoutReponse(APIPath APIPath: String, method: RequestMethod, parameters: [String: AnyObject]?) {
        
//        JDLogger.debug(APIPath)
//        if parameters != nil {
//            JDLogger.debug(parameters!.prettyJSON)
//        }
        
        var request: Alamofire.Request!
        if method == .GET || parameters == nil {
            request = APIHandler.alamoFireManager.request(Method(rawValue: method.rawValue)!, APIPath, parameters: parameters, headers: APIHandler.headers)
        } else {
            request = APIHandler.alamoFireManager.request(Method(rawValue: method.rawValue)!, APIPath, parameters: parameters, encoding:.JSON, headers: APIHandler.headers)
//            JDLogger.debug("encoding:.JSON")
        }
        
        request.responseData { (response) in
            if response.result.error != nil {
                //TODO: response 로 NSURLError 가 오기 때문에, 변경 필요.
                if let error = response.result.error as? NSURLError {
                    print("\(error) is NSURLError Type")
                    //change MLError
                    //Domain은 custom 정의, code는 NSUrlError(enum type)의 raw value
                    let customError = MLError(domain: "NSURLError", code: error.rawValue, userInfo: nil)
                    JDFacade.error.cookLogErrorSilently(customError)
                }
                else {
                    JDFacade.error.cookLogErrorSilently(response.result.error as! MLError)
                }
            }
        }
    }

    /** make httpbody for upload */
    class func getURLRequestWithComponents(urlString: String, parameters: [String: AnyObject]?, imageData: NSData) -> (URLRequestConvertible, NSData) {

        // create url request to send
        let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: urlString)!)
        mutableURLRequest.HTTPMethod = Alamofire.Method.POST.rawValue
        let boundaryConstant = "myRandomBoundary12345"
        let contentType = "multipart/form-data;boundary="+boundaryConstant
        mutableURLRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")

        mutableURLRequest.setValue("ios", forHTTPHeaderField: "platform")
        mutableURLRequest.setValue(APIHandler.headers["Mylo-Token-Key"], forHTTPHeaderField: "Mylo-Token-Key")
        //get token key
        let tokenKey = APIHandler.headers["Mylo-Token-Key"]
        debugPrint("tokenKey : \(tokenKey)")

        // create upload data to send
        let uploadData = NSMutableData()

        // add image
        uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        uploadData.appendData("Content-Disposition: form-data; name=\"files[]\"; filename=\"file.jpg\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        uploadData.appendData("Content-Type: image/jpeg\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
        uploadData.appendData(imageData)

        // add parameters
        if parameters != nil {
            for (key, value) in parameters! {
                uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
                uploadData.appendData("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)".dataUsingEncoding(NSUTF8StringEncoding)!)
            }
        }
        uploadData.appendData("\r\n--\(boundaryConstant)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)



        // return URLRequestConvertible and NSData
        return (Alamofire.ParameterEncoding.URL.encode(mutableURLRequest, parameters: nil).0, uploadData)
    }

    /** API 요청 - 업로드를 요청함. */
    class func rac_requestUpload(APIPath APIPath: String, method: RequestMethod, parameters: [String: AnyObject]?, data: NSData, showLoadingView: Bool) -> SignalProducer<String, NSError> {
        JDLogger.log(parameters)

        return SignalProducer<String, NSError> { observer, disposable in
            
            let request = self.getURLRequestWithComponents(APIPath, parameters: parameters, imageData: data)

            Alamofire.upload(request.0, data: request.1)
            .progress({ (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
                    debugPrint("Total bytes written on main queue: \(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)")
                    dispatch_async(dispatch_get_main_queue()) {
                        JDFacade.ux.loading(progress: totalBytesWritten/totalBytesExpectedToWrite, message: "Upload")
                    }
                })
                .responseString(completionHandler: { (response) -> Void in
                    switch response.result {
                    case .Success(let value):
                        if !needSilent {
                            JDLogger.log(value)
                        }
                        
                        JDFacade.ux.hideLoading(completion: {
                            observer.sendNext(value)
                            observer.sendCompleted()
                        })

                    case .Failure(let error):
                        JDLogger.log(error)
                        JDFacade.ux.hideLoading(completion: {
                            observer.sendFailed(error)
                        })
                    }
                })
        }
    }
    
    /******************************************************/
    
    /** API 요청 -  다중 업로드를 요청함. */
    //TODO: 수정 필요.
    class func rac_requestUploads(APIPath APIPath: String, method: RequestMethod, parameters: [String: AnyObject]?, imgData: [UIImage]?, showLoadingView: Bool) -> SignalProducer<String, NSError> {
        JDLogger.log(parameters)
        
        return SignalProducer<String, NSError> { observer, disposable in
            
            Alamofire.upload(.POST, APIPath, headers: self.headers, multipartFormData: { multipartFormData in
                
                //multipart encoding start
                if let param = parameters {
                    for (key, value) in param {
                        debugPrint(value)
                        // whkim - value에 int값이 들어오는 경우 datausingEncoding crash 이슈 수정
                        multipartFormData.appendBodyPart(data: "\(value)".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, name: key)
                        
                    }
                }
                let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
                if let pictures = imgData {
                    for (index, image) in pictures.enumerate() {
                        if let imageData = UIImageJPEGRepresentation(image, 1) {
                            let filename = "file_\(index).jpg"
                            let filePath = "\(paths[0])/\(filename)"
                            
                            imageData.writeToFile(filePath, atomically: true)
                            
//                            multipartFormData.appendBodyPart(data: imgU, name: "files[]", fileName: "file_\(index).jpg", mimeType: "image/jpeg")
                            multipartFormData.appendBodyPart(fileURL: NSURL(fileURLWithPath: filePath), name: "files[]", fileName: "file_\(index).jpg", mimeType: "image/jpeg")
                        }
                    }
                }
                //encoding end
                
                }, encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .Success(let upload, _, _):
                        upload.progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                            JDFacade.ux.loading(progress: totalBytesWritten/totalBytesExpectedToWrite, message: "Upload")
                            debugPrint("Uploading images for status post \(totalBytesWritten) / \(totalBytesExpectedToWrite)")
                        }
                        
                        /*
                         response 의 raw data 에 PHP Exception Html 코드가 포함되어, responseJson을 얻을 수 없음.
                         우선 responseStrinㅎ 을 통해 json String 얻고, SwiftJson 을 통해 json 객체로 변경.(필요시)
                        */
                        upload.responseString(completionHandler: { (response) in
                            switch response.result {
                            case .Success(let value):
                                if !needSilent {
                                    JDLogger.log(value)
                                }
                                
                                JDFacade.ux.hideLoading(completion: {
                                    observer.sendNext(value)
                                    observer.sendCompleted()
                                })
                                
                            case .Failure(let error):
                                JDLogger.log(error)
                                JDFacade.ux.hideLoading(completion: {
                                    observer.sendFailed(error)
                                })
                            }
                        })
                        
                    case .Failure(let encodingError):
                        JDLogger.log(encodingError)
                    }
                }
            ) //end almofire call
 
        }
 
    }//end func


    
    /** API 요청 - 응답에 대한 모델 mapping 처리, convenience */
    class func requestUploadImages<T: JDAPIResponseProtocol>(request: RequestRPModel<T>, images: [UIImage]? = nil) {
        
        APIHandler.requestUploadsJson(APIPath: request.APIPath,
                                       method: request.method,
                                       parameters: request.parameters,
                                       images: images,
                                       representType: T.self,
                                       showLoadingView: request.showLoadingView,
                                       showSplashView: request.showSplashView,
                                       showError: request.showError,
                                       completion: request.completion)
    }

    
    /** API 요청 - 다중 이미지 업로드 */
    class func requestUploadsJson<T: JDAPIResponseProtocol>(APIPath APIPath: String,
                                   method: RequestMethod,
                                   parameters: [String: AnyObject]?,
                                   images:[UIImage]? = nil,
                                   representType: T.Type?,
                                   showLoadingView: Bool,
                                   showSplashView: Bool,
                                   showError: Bool,
                                   completion: JDFacadeCompletionBlockWithObject?) {
        
        var imageUploadCount = 0
        
        /** 에러 플래그에 따라 얼럿을 호출 후, 완료 컴플리션에 전달함. */
        func nestedShowError(showError: Bool, error: MLError, completion: JDFacadeCompletionBlockWithObject?) {
            if showError {//얼럿 표시, 에러처리
                JDFacade.error.cookError(error, completion: {
                    completion?(error)
                })
            } else {//에러 처리
                JDFacade.error.cookLogErrorSilently(error, completion: {
                    completion?(error)
                })
            }
        }
        
        /** 에러 플래그에 따라 얼럿을 호출 후, 완료 컴플리션에 전달함. */
        func nestedShowToast(error: MLError, completion: JDFacadeCompletionBlockWithObject?) {
            JDFacade.ux.toastError(error.localizedDescription)
            completion?(error)
        }
        
        
        guard let imageArray = images else { return }
        
        var JSON: String?
        
        APIHandler.rac_requestUploads(APIPath: APIPath, method: RequestMethod.POST, parameters: parameters, imgData: imageArray, showLoadingView: true)
            .start(Observer<String, NSError> ( next: { value in
                JSON = value
                
                }, completed: {
                    
                    if var result = Mapper<T>().map(JSON) {//JSON isArray?
                        result.APIPath = APIPath
                        
                        switch result.code! {
                        case .Succeed, .SucceedOK, .None:  //성공 시,,
                            break
                        case .Unauthorized: //goto login when unauthorized
                            let userInfo = [NSLocalizedDescriptionKey: result.message ?? String.empty]
                            let error = MLError(domain: "MLError", code: result.code!.rawValue, userInfo: userInfo)
                            
                            nestedShowError(showError, error: error, completion: { result in
                                JDFacade.ux.loadLoginView()
                            })
                            return
                        case .BadRequest, .FailDeviceCheck: //show error from server
                            
                            var message = result.message ?? String.empty
                            if result.code == .FailDeviceCheck {
                                let submessage = (result as? ResponseModel)?.subMessage ?? String.empty
                                message = !submessage.isEmpty ? message + "\n\n" + submessage : message
                            }
                            
                            let userInfo = [NSLocalizedDescriptionKey: message]
                            let error = MLError(domain: "MLError", code: result.code!.rawValue, userInfo: userInfo)
                            
                            nestedShowError(showError, error: error, completion: completion)
                            return
                      //case .RetryConfirm, .NonPayment, .NoMembership, .FailDeviceCheckConfirm, .FailPayment, .EmailAlreadyExist: //process on bizHandler level
                            //                            //send API result
                        //                            break
                        case .SimpleBizError:
                            let userInfo = [NSLocalizedDescriptionKey: result.message ?? String.empty]
                            let error = MLError(domain: "MLError", code: result.code!.rawValue, userInfo: userInfo)
                            
                            if showError {
                                nestedShowToast(error, completion: { result in
                                    completion?(result)
                                })
                            }
                            return
                        default:
                            //nestedShowError(showError, error: MLErrorType.api(result.code!).error(), completion: completion)
                            break
                        }
                        
                        //send API result
                        completion?(result)
                        
                    } else if let resultArray = Mapper<T>().mapArray(JSON) {
                        
                        //send API result for array
                        completion?(resultArray)
                        
                    } else {//JSON Mapping error
                        nestedShowError(showError, error: MLErrorType.json(.mapping).error(), completion: completion)
                    }
                    
                    
                }, failed: { error in
                    
                    let mError = MLError(error: error)
                    
                    if error.code == NSURLErrorCancelled {//Manual Force Cancelled
                        completion?(nil)
                        //nestedShowError(showError, error: mError, completion: completion)
                        
                    } else if error.code == NSURLErrorTimedOut {//요청 시간 초과 시 재시도 여부,
                        JDFacade.ux.confirm(APIStatus.NSURLErrorTimedOut.localizedDescription, confirmLabel: MLStrings.local.retry(), cancelLabel: MLStrings.local.cancel(), completion: { (alert: JDAlertType) in
                            if alert == .OK {
                                //TODO
                                
                                return
                            }
                            
                            nestedShowError(showError, error: mError, completion: completion)
                        })
                    }
            }))
    } //end func
    
 
}

extension String {
    func deleteHTMLTag(tag:String) -> String {
        return self.stringByReplacingOccurrencesOfString("(?i)</?\(tag)\\b[^<]*>", withString: "", options: .RegularExpressionSearch, range: nil)
    }
    
    func deleteHTMLTags(tags:[String]) -> String {
        var mutableString = self
        for tag in tags {
            mutableString = mutableString.deleteHTMLTag(tag)
        }
        return mutableString
    }
}
