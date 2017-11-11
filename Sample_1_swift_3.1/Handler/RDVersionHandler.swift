//
//  RDVersionHandler
//  radar
//
//  Created by Jason Lee on 03/05/2017.
//  Copyright © 2017 JasonDevelop. All rights reserved.
//

import Foundation
import UIKit

class RDVersionHandler {
    static let handler: RDVersionHandler = RDVersionHandler()
    
    //MARK: * properties --------------------
    lazy var ftpConfiguration: SessionConfiguration = {
        var configuration = SessionConfiguration()
        configuration.host = RDConstants.server.domain
        configuration.username = RDConstants.server.uid
        configuration.password = RDConstants.server.pwd
        
        configuration.encoding = String.Encoding.utf8
        
        return configuration
    } ()
    
    lazy var ftpSession: Session = { [unowned self] in
        return Session(configuration: self.ftpConfiguration)
        } ()
    
    //FIXME: keep public?
    var versions: [DCVersionModel] = []
    
    fileprivate var documentDirectory: URL? {
        get {
            guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
                return nil
            }
            
            return URL(fileURLWithPath: path)
        }
    }
    
    fileprivate var versionInfPath: URL? {
        get {
            guard let destURL = self.documentDirectory?.appendingPathComponent("version.inf") else {
                return nil
            }
            return destURL
        }
    }
    
    var isReqFinishedAll = (false, false, false) {
        didSet {
            finishedObsever.send(value: isReqFinishedAll == (true, true, true))
        }
    }
    let (finishedSignal, finishedObsever) = Signal<Bool, NoError>.pipe()

    //MARK: * IBOutlets --------------------


    //MARK: * Initialize --------------------

    init() {
        
    }
    
    func configureFTPSession(conf: SessionConfiguration) {
        self.ftpConfiguration = conf
        ftpSession = Session(configuration: self.ftpConfiguration)
    }
    
    //MARK: * Main Logic --------------------
    
    //get versios info by SWType as (ftp, app, rd)
    func getVersionsBySWType() -> [SWVersionsBySWType] {
        
        var swVersionsByType: [SWVersionsBySWType] = []
        let swVersions = RDDBHandler.get(item: SWVersion.self)
        SWType.cases().forEach { (type: SWType) in
            
            let filteredSWVersions = swVersions.filter(NSPredicate(format: "swType='\(type.rawValue)'"))
            if filteredSWVersions.count > 0 {
                swVersionsByType.append(SWVersionsBySWType(swType: type, swVersions: Array(filteredSWVersions)))
            }
        }
        
        return swVersionsByType
    }
    
    var serverVersion: DCVersionModel? {
        return RDDBHandler.get(item: DCVersionModel.self).filter(NSPredicate(format: "device = %@", DeviceType.Server.rawValue)).first
    }
    
    var appVersion: DCVersionModel? {
        return RDDBHandler.get(item: DCVersionModel.self).filter(NSPredicate(format: "device = %@", DeviceType.App.rawValue)).first
    }
    
    var rdVersion: DCVersionModel? {
        return RDDBHandler.get(item: DCVersionModel.self).filter(NSPredicate(format: "device = %@", DeviceType.RD.rawValue)).first
    }
    
    
    func updateSWVersionsToRD(typedSWVersions: [SWVersionsBySWType], completion: JDFacadeCompletionBlockWithObject? = nil) {
        
        //reset thread safe object
        typedSWVersions.forEach({ $0.swVersions.first?.generateThreadSafeReference() })
        
        async { [unowned self] in
            autoreleasepool {
                do {
                    
                    defer {//return
                        completion?(nil)
                    }
                    
                    guard let appVersion = self.appVersion else {
                        return
                    }
                    
                    //1. for, file header > udpate > progress > notifty result
                    //2. has file
                    //prepare app version
                    let rdVersion = DCVersionModel(device: DeviceType.RD) //new
                    rdVersion.updateNumber = appVersion.updateNumber
                    
                    var prvc: RDProgressPopViewController?
                    var upindex = 0
                    
                    for typedSWVersion in typedSWVersions {//update
                        //precondition(typedSwVersion.swVersions.first != nil)
                        
                        if let swVersionRef = typedSWVersion.swVersions.first?.threadSafeReference, let swVersion = RDDBHandler.resolve(swVersionRef) {
                            swVersion.updated = false
                            
                            prvc = JDFacade.ux.showProgressPopup(title: "Update [\(upindex+1)/\(typedSWVersions.count)] - CRC Check", message: swVersion.file, progress: 0, completion: nil)
                            
                            //file header info
                            if let prepare = try await(self.prepareSWFileToRD(swVersion: swVersion, index: upindex, total: typedSWVersions.count)), prepare == true {
                                print("header success")
                            }
                            
                            //get file info
                            if let upload = try await(self.uploadSWFileToRD(swVersion: swVersion, index: upindex, total: typedSWVersions.count)), upload == true {
                                print("upload success")
                            }
                            
                            swVersion.updated = true
                        }
                        
                        //3. all
                        upindex += 1
                    }
                    prvc?.dismiss(animated: true, completion: nil)
                    rdVersion.store()

                } catch {
                    
                }
            }
        }
    }
    
    func uploadSWFileToRD(swVersion: SWVersion, index: Int, total: Int) -> Promise<Bool?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            do {
                guard let destURL = self.documentDirectory?.appendingPathComponent(swVersion.file) else {
                    throw RDError.none
                }

                let rdfile = try FileHandle(forReadingFrom: destURL)
                //                rdfile.seek(toFileOffset: 0x400)
                
                let file_data = FileData2(withFileHandle: rdfile);
                let send_data = BinaryReader(data: file_data)
                send_data.seek(count: 0x400)
                
                let filesize = file_data.data.count - 0x400
                
                var i = 0, send_cnt = 0
                while i < filesize {
                    if i + 1024 < filesize {
                        send_cnt = 1024
                        i += send_cnt
                    } else {
                        send_cnt = filesize - i
                        i += send_cnt
                    }
                    
                    let buffer = send_data.readBytes(count: send_cnt)
                    let data = Data(bytes: buffer)
                    RDHandler.handler.sendSWFile(swfile: data, completion: nil)
//                    debugPrint("\(percent)%")
                    
                    let percent = i.d / filesize.d
                    JDFacade.ux.showProgressPopup(title: "Update [\(index+1)/\(total)] - Upload", message: swVersion.file, progress: percent, completion: nil)
                }
                
                fulfill(true)
                
            } catch let error as NSError {
                reject(error)
            }
        })
        
    }
    
//    func crc16ccitt(data: [UInt8],seed: UInt16 = 0x1d0f, final: UInt16 = 0xffff)->UInt16{
//        var crc = seed
//        data.forEach { (byte) in
//            crc ^= UInt16(byte) << 8
//            (0..<8).forEach({ _ in
//                crc = (crc & UInt16(0x8000)) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
//            })
//        }
//        return UInt16(crc & final)
//    }
    
    let crc_table: [UInt16] = [
        
        0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
        0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
        0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
        0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
        0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
        0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
        0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
        0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
        0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
        0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
        0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
        0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
        0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
        0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
        0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
        0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
        0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
        0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
        0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
        0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
        0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
        0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
        0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
        0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
        0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
        0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
        0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
        0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
        0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
        0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
        0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
        0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0
    ]
    
    
    func crc16Ccitt(data: [UInt8], seed: UInt16 = 0x1d0f, final: UInt16 = 0xffff)->UInt16
    {
        
        var crc: UInt32 = UInt32(seed)
        var temp: UInt32 = 0
        
        data.forEach { byte in
            temp = UInt32(byte) ^ (crc >> 8) & 0xff
            crc = UInt32(crc_table[Int(temp)]) ^ (crc << 8)
        }
        
        return UInt16((crc ^ UInt32(final)) & 0xffff)
    }
    
    func prepareSWFileToRD(swVersion: SWVersion, index: Int, total: Int) -> Promise<Bool?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            do {
                guard let destURL = self.documentDirectory?.appendingPathComponent(swVersion.file) else {
                    throw RDError.none
                }
                
                let rdfile = try FileHandle(forReadingFrom: destURL)
                
                let file_data = FileData2(withFileHandle: rdfile);
                let send_data = BinaryReader(data: file_data)
                send_data.seek(count: 0x400)
                
                let filesize = file_data.data.count - 0x400
                
                var crc: UInt16 = 0
                do {
//                    crc = self.crc16ccitt(data: send_data.readBytes(count: filesize))
                      crc = self.crc16Ccitt(data: send_data.readBytes(count: filesize))
//                    for i in 0 ..< filesize {
//                        let data = send_data.readUInt8()
//                        crc =  UInt16((crc >> 8) | (crc << 8))
//                        crc ^= UInt16(data)
//                        crc ^= UInt16(((crc & 0xff) >> 4))
//                        crc ^= UInt16((crc << 12))
//                        crc ^= UInt16(((crc & 0xff) << 5))
//
//                        //show progress
                        JDFacade.ux.showProgressPopup(title: "Update [\(index+1)/\(total)] - CRC Check", message: swVersion.file, progress: 1.0, completion: nil)
//                    }
                }
                
                var fheader = "<Download file=\(swVersion.file),"
                fheader += "len=\(filesize),"
                fheader += "crc=" + String.init(format: "%02X", crc)
                fheader += "/>"

                RDHandler.handler.sendFileHeader(header: fheader, completion: nil)
                
                fulfill(true)
                
            } catch let error as NSError {
                reject(error)
            }
        })
        

    }
    
    ///get sw files from server whom checked
    func downloadSWVersionsFromServer(typedSWVersions: [SWVersionsBySWType], completion: JDFacadeCompletionBlockWithObject? = nil) {
        
        //reset thread safe object
        typedSWVersions.forEach({ $0.swVersions.first?.generateThreadSafeReference() })
        
        async { [unowned self] in
            autoreleasepool {
                do {
                    defer {//return
                        completion?(nil)
                    }

                    //1.get list from FTP
                    guard let items = try await(self.getListsOnServer()), let serverVersion = self.serverVersion else {
                        return
                    }
                    
                    //prepare app version
                    let appVersion = DCVersionModel(device: DeviceType.App)
                    appVersion.updateNumber = serverVersion.updateNumber
                    
                    var dnindex = 0
                    for typedSWVersion in typedSWVersions {//download if match the filename
                        //precondition(typedSwVersion.swVersions.first != nil)
                        
                        if let swVersionRef = typedSWVersion.swVersions.first?.threadSafeReference, let swVersion = RDDBHandler.resolve(swVersionRef) {
                            swVersion.downloaded = false
                            
                            if let swItem = items.filter({ $0.name.lowercased() == swVersion.file.lowercased() }).first {
                                
                                //1. download
                                if let fileURL = try await(self.downloadSWFileFromServer(item: swItem, index: dnindex, total: typedSWVersions.count)) {
                                    swVersion.filePath = fileURL.path
                                    swVersion.downloaded = true
                                    
                                    //2. move files to documents
                                    if let moved = try await(self.moveSWFileToDocuments(swVersion: swVersion)), moved == true {
                                        appVersion.setVersion(swVersion.version, file: swVersion.file, type: swVersion.swType)
                                    }
                                }
                            }
                        }
                        //2. db update
                        
                        //3. all
                        dnindex += 1
                    }
                    
                    appVersion.store()
                    
                } catch {
                    
                }
            }
        }
    }
    
    ///rquest download item.
    func downloadSWFileFromServer(item: ResourceItem, index: Int, total: Int) -> Promise<URL?> {
        
        return Promise(resolvers: { [weak self] (fulfill, reject) in
            
            self?.ftpSession.download(item.path, progressHandler: { (progress) in
                let vc = JDFacade.ux.showProgressPopup(title: "Download", message: item.name, progress: progress, completion: nil)
                JDLogger.debug("download \(progress)")
                if index == total-1 && progress == 1.0 {
                    vc.dismiss(animated: true, completion: nil)
                }
                
            }, completionHandler: { (fileURL, error) in
                guard let fileURL = fileURL, error == nil else {
                    JDFacade.ux.alert(title: "Error", message: error?.localizedDescription ?? "", completion: nil)
                    return reject(error ?? RDError.unknownError)
                }
                
                fulfill(fileURL)
            })
        })
        
    }
    
    
    func moveSWFileToDocuments(swVersion: SWVersion) -> Promise<Bool?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            do {
                guard let destURL = self.documentDirectory?.appendingPathComponent(swVersion.file) else {
                    throw RDError.none
                }
                
                let fm = FileManager.default
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                
                let fileURL = URL(fileURLWithPath: swVersion.filePath)
                try fm.moveItem(at: fileURL, to: destURL)
                
                fulfill(true)
                
            } catch let error as NSError {
                reject(error)
            }
        })
    }
    
    
    
    
    /// ftp, app, rd version
    func getVersionsOfAllDevices(completion: JDFacadeCompletionBlockWithObject? = nil) {
        isReqFinishedAll = (false, false, false)
        
        self.finishedSignal.observeValues {(value: Bool) in
            completion?(self.versions)
        }
        
        //1. get FTP Version and store DB
        self.getVersionOfServer { [weak self] (result) in
            if let version = result as? DCVersionModel {
                self?.versions.append(version)
                self?.isReqFinishedAll.0 = true
            }
        }
        
        //2. get version of RD device
        self.getVersionOfRD { [weak self] (result) in
            if let version = result as? DCVersionModel {
                self?.versions.append(version)
                self?.isReqFinishedAll.1 = true
            }
        }

        //3. get version of app
        self.getVersionOfApp { [weak self] (result) in
            if let version = result as? DCVersionModel {
                self?.versions.append(version)
                self?.isReqFinishedAll.2 = true
            }
        }
    }
    
    //get version of App
    func getVersionOfApp(completion: JDFacadeCompletionBlockWithObject? = nil) {
        //check downloaded files, only check db
        defer {
            completion?(DCVersionModel())
        }
    }
    
    //get version of RD
    func getVersionOfRD(completion: JDFacadeCompletionBlockWithObject? = nil) {
        
        //request to rd only check
        async { [unowned self] in
            do {
                var rdVersion: DCVersionModel?
                defer {
                    completion?(rdVersion)
                }
                
                //4. save to local db?
                guard let version = try await(self.getSystemInfoFromCurrentInterface()) else {
                    return
                }
                
                rdVersion = version
                
            } catch {//define! error
                JDLogger.log("eeror")
            }
        }
    }
    
    func getSystemInfoFromCurrentInterface() -> Promise<DCVersionModel?> {
        return Promise (resolvers: { (fulfill, reject) in
            RDHandler.handler.getSystemInfo(completion: { (result) in
                guard let version = result as? DCVersionModel else {
                    return reject(RDInterfaceError.disconnectToServer)
                }
                
                version.store()
                fulfill(version)
            })
        })
    }
    
    //get versions of server
    func getVersionOfServer(completion: JDFacadeCompletionBlockWithObject? = nil) {

        async { [unowned self] in
            do {
                var serverVersion: DCVersionModel?
                defer {
                    completion?(serverVersion)
                }
                
                //1.get list from FTP
                guard let items = try await(self.getListsOnServer()) else {
                    return
                }
//                self.ftpItems = items //store
                
                //2. download inf
                guard let downloadURL = try await(self.downloadSpecFromServer(items: items)) else {
                    return
                }
                
                //3. store local path
                try await(self.moveSpecFileToStorage(fileURL: downloadURL))
                
                //4. save to local db?
                guard let version = try await(self.storeVersionInfToDatabase()) else {
                    return
                }
                
                serverVersion = version

            } catch {//define! error
                JDLogger.log("eeror")
            }
        }
    }
    
    ///get list of server path
    func getListsOnServer() -> Promise<[ResourceItem]?> {
        return Promise (resolvers: { (fulfill, reject) in
            self.ftpSession.list(RDConstants.server.path) { (items, error) in
                guard error == nil else {
                    JDFacade.ux.alert(title: "Error", message: error?.localizedDescription ?? "", completion: nil)
                    return reject(error ?? RDError.unknownError)
                }

                fulfill(items)
            }
        })
    }
    
    ///download versionInf from server
    func downloadSpecFromServer(items: [ResourceItem]) -> Promise<URL?> {
        
        return Promise(resolvers: { [weak self] (fulfill, reject) in
            
            if let inf = items.filter({ $0.name == RDServer.versionInf}).first {
                
                self?.ftpSession.download(inf.path, completionHandler: { (fileURL, error) in
                    //print("Download file with result:\n\(fileURL), error: \(error)\n\n")
                    guard let fileURL = fileURL, error == nil else {
                        JDFacade.ux.alert(title: "Error", message: error?.localizedDescription ?? "", completion: nil)
                        return reject(error ?? RDError.unknownError)
                    }
                    
                    fulfill(fileURL)
                })
            }
        })
        
        //        appConfig.setFtpDirectory("/test/jinjin");
        //
        //        UpdateNumber=0001
        //        FILE=RG79HT_RD_TEST.rd,FW_VER=0001
        //        FILE=DB_TEST.db,DB_VER=0001
        //        FILE=RG79HT_VOICE_TEST.vce,VOICE_VER=0001
        //        FILE=RG79HT_VOICE_TEST.vce,GPS_VER=0001
        //        FILE=RG79HT_VOICE_TEST.vce,WIFI_VER=0001
    }
    

    ///move versionInf to documents
    func moveSpecFileToStorage(fileURL: URL) -> Promise<Void> {
        
        return Promise(resolvers: { (fulfill, reject) in
            do {
                guard let destURL = self.versionInfPath else {
                    throw RDError.none
                }
                
                let fm = FileManager.default
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                
                try fm.moveItem(at: fileURL, to: destURL)
                fulfill()
                
            } catch let error as NSError {
                reject(error)
            }
        })
    }
    
    ///store versionInfo to db
    func storeVersionInfToDatabase() -> Promise<DCVersionModel?> {
        
        return Promise(resolvers: { (fulfill, reject) in
            do {
                guard let destURL = self.versionInfPath else {
                    throw RDError.none
                }
                
                guard let fileContent = try? NSString(contentsOf: destURL, encoding: String.Encoding.utf8.rawValue) else {
                    throw RDError.none
                }
                
                let serverVersion = DCVersionModel(device: DeviceType.Server)
                for content in fileContent.components(separatedBy: "\r\n") {
                    
                    if content.contains(",") {
                        let components = content.components(separatedBy: ",")
                        
                        if let versions = components.filter({ $0.contains("_VER")}).first, let files = components.filter({ $0.contains("FILE")}).first {
                            if let swType = versions.components(separatedBy: "=").first , let version = versions.components(separatedBy: "=").last, let file = files.components(separatedBy: "=").last {
                                serverVersion.setVersion(version, file: file, type: swType)
                            }
                        }
                        continue
                    }
                    
                    serverVersion.updateNumber = content.components(separatedBy: "=").last ?? ""
                }
                
                serverVersion.store()
                
                fulfill(serverVersion)
                
            } catch let error as NSError {
                reject(error)
            } catch {
                reject(error)
            }
        })
    }



    

}

extension RDVersionHandler {

}
