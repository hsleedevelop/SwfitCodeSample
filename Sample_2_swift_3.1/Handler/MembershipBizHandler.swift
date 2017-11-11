//
//  MembershipBizHandler.swift
//  mylo2
//
//  Created by Jason Lee on 13/11/2016.
//  Copyright © 2016 Classtime. All rights reserved.
//

import Foundation
import ReactiveCocoa
import PromiseKit
import AwaitKit
import DispatchFramework

class MembershipBizHandler {

    /** 일반 멤버십 리스트 조회 */
    class func awaitToGetMembershipBasicList(groupId: Int) -> [MembershipModel]? {
        return try! await(self.getMembershipBasicList(groupId))
    }
    
    class func getMembershipBasicList(groupId: Int) -> Promise<[MembershipModel]?> {
        
        return Promise(resolver: { (resolve) in
            RequestRPModel<ResponseVOModel<MembershipModel>>().configure {
                $0.APIPath = API.Profile.getMembershipBasicList
                $0.parameters = ["group_id": groupId]
                
                $0.completion = { response in
                    var membershipList: [MembershipModel]? = nil
                    if let stubs = response as? [ResponseVOModel<MembershipModel>] {
                        membershipList = []
                        stubs.forEach({ stub in
                            membershipList?.append(stub.data!)
                        })
                    }
                    resolve(membershipList, nil)
                }
                }.request()
        })
    }
    
    /** 일반 멤버십 리스트 조회 */
    class func awaitToGetMembershipPaymentInfo() -> MembershipPaymentModel? {
        return try! await(self.getMembershipPaymentInfo())
    }
    
    class func getMembershipPaymentInfo() -> Promise<MembershipPaymentModel?> {
        
        return Promise(resolver: { (resolve) in
            RequestRPModel<ResponseVOModel<MembershipPaymentModel>>().configure {
                $0.APIPath = API.Profile.getMembershipInfo
                
                $0.completion = { response in
                    var paymentInfo: MembershipPaymentModel? = nil
                    if let result = response as? ResponseVOModel<MembershipPaymentModel>, let stub = result.data {
                        //for Succeed
                        paymentInfo = stub
                    }
                    resolve(paymentInfo, nil)
                }
                }.request()
        })
    }

    
    /** 멤버십 일시정지 시작/해제 */
    class func awaitToPutMembershipHold(parameters: [String: AnyObject]) throws -> ResponseModel?  {
        return try await(self.putMembershipHold(parameters))
    }
    
    class func putMembershipHold(parameters: [String: AnyObject]) -> Promise<ResponseModel?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            RequestRPModel<ResponseModel>().configure {
                $0.APIPath = API.Profile.putMembershipHold
                $0.method = .PUT
                $0.parameters = parameters
                
                $0.completion = { response in
                    
                    guard let result = response as? ResponseModel else { return } //if no result return
                    
                    //check biz error
                    if let error = MLBizErrorType.checkAPIResponeCode(result) {
                        reject(error)
                        return
                    }
                    
                    JDFacade.ux.toast(result.message)
                    fulfill(result)
                }
                }.request()
        })
    }
    
    
    /** 멤버십 해지 시작/해제 */
    class func awaitToPutMembershipStop(parameters: [String: AnyObject]) throws -> ResponseModel?  {
        return try await(self.putMembershipStop(parameters))
    }
    
    class func putMembershipStop(parameters: [String: AnyObject]) -> Promise<ResponseModel?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            RequestRPModel<ResponseModel>().configure {
                $0.APIPath = API.Profile.putMembershipStop
                $0.method = .PUT
                $0.parameters = parameters
                
                $0.completion = { response in
                    
                    guard let result = response as? ResponseModel else { return } //if no result return
                    
                    //check biz error
                    if let error = MLBizErrorType.checkAPIResponeCode(result) {
                        reject(error)
                        return
                    }
                    
//                    var isPossible: Bool? = true
//                    if let stubs = response as? ResponseTModel<Bool> {
//                        isPossible = stubs.data
//                    }
//                    
//                    if result.message != nil && (parameters["action"] as! String) != "start" {
//                        JDFacade.ux.toast(result.message)
//                    }
                    fulfill(result)
                }
                }.request()
        })
    }
    
    
    /** 환경설정 정보 설정 */
    class func awaitToPutChangeMembership(parameters: [String: AnyObject]) throws -> ResponseModel? {
        return try await(self.putChangeMembership(parameters))
    }
    
    class func putChangeMembership(parameters: [String: AnyObject]) -> Promise<ResponseModel?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            RequestRPModel<ResponseModel>().configure {
                $0.APIPath = API.Profile.putMembershipChange
                $0.method = .PUT
                $0.parameters = parameters
                
                $0.completion = { response in
                    
                    guard let result = response as? ResponseModel else { return } //if no result return
                    
                    //check biz error
                    if let error = MLBizErrorType.checkAPIResponeCode(result) {
                        reject(error)
                        return
                    }
                    
                    JDFacade.ux.toast(result.message)
                    fulfill(result)
                }
                }.request()
        })
    }
    
    
    /** 빌키 존재여부 */
    class func awaitToGetMembershipHasBillkey() -> Bool? {
        return try! await(self.getMembershipHasBillkey())
    }
    
    class func getMembershipHasBillkey() -> Promise<Bool?> {
        
        return Promise(resolver: { (resolve) in
            RequestRPModel<ResponseTModel<Bool>>().configure {
                $0.APIPath = API.Profile.getBillInfo
                
                $0.completion = { response in
                    if let result = response as? ResponseTModel<Bool> {
                        resolve(result.data, nil)
                        return
                    }
                    
                    resolve(nil, nil)
                }
                }.request()
        })
    }
}

extension MembershipBizHandler {

}
