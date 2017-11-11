//
//  MLBizErrorType.swift
//  mylo2
//
//  Created by Jason Lee on 21/11/2016.
//  Copyright © 2016 Classtime. All rights reserved.
//

import Foundation
import UIKit

protocol MLErrorTypeProtocol {//merge MLErrorProtocol
    func cookError(object: Any?)
}


enum CommonAction: JDActionProtocol {
    case Retry(JDFacadeCompletionBlock?)          //이전 요청을 재요청함.
    case Close                                    //닫기
    case Done(JDFacadeCompletionBlock?)           //닫기 후 호출
}

extension CommonAction {//! Action
    
    var enable: Bool {
        return true
    }
    
    var cancelHidden: Bool  {
        return false
    }
    
    func dispatch() {
        
        switch self {
        case .Close: //from halfPopup, no need to close
            if CommonUtil.currentViewController is HalfPopupViewController {
               CommonUtil.currentViewController?.dismissViewControllerAnimated(true, completion: nil)
            }
            break
        case let .Retry(completion):
            completion?()
            break
        case let .Done(completion):
            completion?()
        default:
            break
        }
    }
}

enum PushAction: JDActionProtocol {//profile-notification, all remote notification actions
    
    case None
    case ProfileActivity        //goto profile, activity main
    case Community(Int)         //communityId
    case CommunityHome(Int)     //communityId
    case CommunityMember(Int)   //communityId
    case CommunityActivity(Int) //communityId
    case CommunityPost(Int, Int)     //communityId, postId
    case SettingBillingInfo
    case Notice(Int)            //notice id, 공지사항 해당 공지 오픈,
}

extension PushAction {
    
    var enable: Bool {
        return true
    }
    
    var cancelHidden: Bool  {
        return false
    }
    
    func dispatch() {
        
        switch self {
        case .ProfileActivity:
            JDFacade.ux.gotoProfileActivity()
            break
        case let .Community(communityId):
            JDFacade.ux.gotoGroupAt(communityId)
            break
        case let .CommunityHome(communityId):
            JDFacade.ux.gotoGroupAt(communityId)
            break
        case let .CommunityMember(communityId):
            JDFacade.ux.gotoGroupMembersAt(communityId)
            break
        case let .CommunityActivity(communityId):
            JDFacade.ux.gotoGroupActivitiesAt(communityId)
            break
        case let .CommunityPost(communityId, postId):
            JDFacade.ux.gotoGrouTimelineAt(communityId, postId: postId)
            break
        case .SettingBillingInfo:
            JDFacade.ux.profile(.profileActivities(.payment)).load()
            break
        case let .Notice(noticeId):
            JDFacade.ux.openPathToWebView(MLConstants.url.customerNotice, parameter: "#\(noticeId)", title: "공지사항")
            break
        default:
            break
        }
    }
}



enum MLBizErrorType: ErrorType, MLErrorTypeProtocol {//! Error
    case activities(APIStatus, ResponseModel?)
    case retryConfirm(String)
    case errorNotification(String)
    case simpleBizError(String)
    case failDeviceCheckConfirm(String)
    case failUserLogin(String)
    case leftActivity(String)
    case showAlert(String)
    
    static func checkAPIResponeCode(response: ResponseModel?) -> MLBizErrorType? {
        if let code = response?.code where APIStatus.succeeds.contains(code) == false {
            
            if code == .RetryConfirm {
                return retryConfirm(response!.message!)
            } else if code == .ErrorNotification {
                return errorNotification(response!.message!)
            } else if code == .SimpleBizError {
                return simpleBizError(response!.message!)
            } else if code == .FailDeviceCheckConfirm {
                return failDeviceCheckConfirm(response!.message!)
            } else if code == .FailUserLogin {
                return failUserLogin(response!.message!)
            } else if code == .LeftActivity {
                return leftActivity(response!.message!)
            } else if code == .ShowAlert {
                return showAlert(response!.message!)
            }
            
            //default
            return activities(code, response ?? nil)
        }
        return nil
    }
    
    var code: APIStatus {
        var status = APIStatus.None
        
        switch self {
        case let .activities(code, _):
            status = code
        case .retryConfirm(_):
            status = .RetryConfirm
        case .errorNotification(_):
            status = .ErrorNotification
        case .simpleBizError(_):
            status = .SimpleBizError
        case .failDeviceCheckConfirm(_):
            status = .FailDeviceCheckConfirm
        case .failUserLogin(_):
            status = .FailUserLogin
        case .leftActivity(_):
            status = .LeftActivity
        case .showAlert(_):
            status = .ShowAlert
        }
        return status
    }
    
    var result: ResponseModel? {//FIXME : need to refactor
        var result: ResponseModel?
        
        switch self {
        case let .activities(_, response):
            result = response
            break
        default:
            break
        }
        return result
    }
    
    var message: String {
        var message = ""
        
        switch self {
        case let .leftActivity(string):
            message = string
        case let .retryConfirm(string):
            message = string
        case let .errorNotification(string):
            message = string
        case let .simpleBizError(string):
            message = string
        case let .failDeviceCheckConfirm(string):
            message = string
        case let .failUserLogin(string):
            message = string
        case let .showAlert(string):
            message = string
        default:
            break
        }
        return message
    }
    
    func cookError(object: Any? = nil) {
        
        if !NSThread.isMainThread() {//if not main thread
            dispatch_async(dispatch_get_main_queue(), {//run in mainThread
                self.cookError(object)
            })
            return
        }
        
        
        switch self {
        case let .activities(code, result):
            
            switch code {
            case .DataAlreadyExist:
                break
            case .FailCoupon:
                break
            case .FailUserLogin: 
                break
            case .FailPayment: 
                //PG사 신용카드 - 결제 실패
                JDFacade.ux.auth(.sub(.paymentError)).presentOnCurrentContext() //결제 에러 페이지 호출
                break
            case .FailDeviceCheckConfirm: 
                break
            case .FailDeviceCheck: 
                break
            case .OnceInMonth: 
                JDFacade.ux.toast("일시정지는 한달에 한번만 가능합니다.")
                break
             case .LeftActivity:
                break
            case .NonPayment:
                if let vc = JDFacade.ux.auth(.sub(.nonPayment)).instantiate() {
                    JDFacade.ux.loadViewController(vc)
                }
                break
            case .NoMembership: 
                //ReserveAction.MembershipBuy.dispatch()
                if let vc = JDFacade.ux.profile(.membership(.select)).instantiate() as? MembershipViewController {
                    JDFacade.ux.membershipSeleceMode = .Register
                    JDFacade.ux.loadViewController(vc)
                }
                break
            default:
                break
            }
            break
        case .leftActivity(message):
            cookErrorLeftActivity(message, completion: nil)
            break
        case let .retryConfirm(message):
            cookErrorOnHalfPopup(message, completion: object as? JDFacadeCompletionBlock)
            break
        case let .errorNotification(message):
            JDFacade.ux.toastError(message)
            break
        case let .simpleBizError(message):
            JDFacade.ux.toastError(message)
        case let .failDeviceCheckConfirm(message):
            JDLogger.log(message)
            break
        case let .failUserLogin(message):
            JDFacade.ux.toastError(message)
            break
        case let .showAlert(message):
            JDFacade.ux.alert(message)
            break
        default:
            break
        }
    }
    
    func cookErrorOnHalfPopup(message: String, completion: JDFacadeCompletionBlock?) {
        let popupMessage = PopupMessage().configure {
            
            $0.title    = message
            
            //cancel
            $0.cancelTitle  = "취소"
            $0.cancel       = CommonAction.Close
            
            //action
            $0.actionTitle  = "확인"
            $0.action       = CommonAction.Retry(completion)
        }
        
        JDFacade.ux.showHalfPopup(popupMessage)
    }
    
    func cookErrorLeftActivity(message: String, completion: JDFacadeCompletionBlock?) {
        let popupMessage = PopupMessage().configure {
            
            $0.title    = message
            
            //action
            $0.actionTitle  = "나의 일정으로 바로가기"
            $0.action       = CommonAction.Done({
                
                if JDFacade.ux.tc?.selectedIndex == 3 {//from pspayment
                    if let vc = CommonUtil.currentNavigationController?.viewControllers[1] {
                        CommonUtil.currentNavigationController?.popToViewController(vc, animated: true)
                    }
                } else {
                    CommonUtil.currentViewController?.dismissViewControllerAnimated(true, completion: {
                        JDFacade.ux.gotoProfileActivity()
                    })
                }
            })
        }
        
        JDFacade.ux.showHalfPopup(popupMessage)
    }
}

