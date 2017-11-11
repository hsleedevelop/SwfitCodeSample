//
//  RDCommand.swift
//  radar
//
//  Created by Jason Lee on 16/05/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

protocol EnumCollection : Hashable {}
extension EnumCollection {
    static func cases() -> AnySequence<Self> {
        typealias S = Self
        return AnySequence { () -> AnyIterator<S> in
            var raw = 0
            return AnyIterator {
                let current : Self = withUnsafePointer(to: &raw) { $0.withMemoryRebound(to: S.self, capacity: 1) { $0.pointee } }
                guard current.hashValue == raw else { return nil }
                raw += 1
                return current
            }
        }
    }
}

enum RDCommand: Equatable {
    case none
    case who
    case sendHotspotInfo(String?, String?)
    case getHotspotInfo
    case getSTAInfo(String?)
    case connectRDServer(String?)
    case sendMessage
    case sendFileHeader(String?)
    case sendSWFile(Data?)
    case getSystemInfo
    case getSystemSetup
    case setSystemSetup(String?)
    case clearUserData
    
    //    case who = "who"
    //    case sendHotspotInfo = "send Hotspot info"
    //    case getHotspotInfo = "get HotSpot info"
    //    case getSTAInfo = "get STA Info"
    //    case connectRDServer = "connect RDServer"
    //    case sendMessage = "send Message"
    
    static func connectCases() -> [RDCommand] {
        return [.who, .sendHotspotInfo(nil, nil)]
    }
    
    static func hotspotCases() -> [RDCommand] {
        return [.who, .sendHotspotInfo(nil, nil)]
    }
    
    static func tcpCases() -> [RDCommand] {
        return [.who, .sendHotspotInfo(nil, nil)]
    }
    
    // function for custom operator ==
    static func ==(lhs: RDCommand, rhs: RDCommand) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.who, .who):
            return true
            //        case (let .sendHotspotInfo(a), let .sendHotspotInfo(b)):
        //            return true
        case (.sendHotspotInfo, .sendHotspotInfo):
            return true
        case (.getHotspotInfo, .getHotspotInfo):
            return true
        case (.getSTAInfo, .getSTAInfo):
            return true
        case (.connectRDServer, .connectRDServer):
            return true
        case (.sendMessage, .sendMessage):
            return true
        case (.sendFileHeader, .sendFileHeader):
            return true
        case (.sendSWFile, .sendSWFile):
            return true
        case (.getSystemInfo, .getSystemInfo):
            return true
        case (.getSystemSetup, .getSystemSetup):
            return true
        case (.setSystemSetup, .setSystemSetup):
            return true
        case (.clearUserData, .clearUserData):
            return true
            
        default:
            return false
        }
    }
}
