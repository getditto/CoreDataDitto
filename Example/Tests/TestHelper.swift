//
//  CoreDataHelper.swift
//  CoreDataDitto_Tests
//
//  Created by Maximilian Alexander on 6/23/21.
//  Copyright © 2021 CocoaPods. All rights reserved.
//
import UIKit
import DittoSwift
import CoreData

class CoreDataContainer: NSPersistentContainer {
    init(name: String, bundles: [Bundle] = Bundle.allBundles, inMemory: Bool = false) {
        guard let mom = NSManagedObjectModel.mergedModel(from: bundles) else {
            fatalError("Failed to create mom")
        }
        super.init(name: name, managedObjectModel: mom)
        configureDefaults(inMemory)
    }
    private func configureDefaults(_ inMemory: Bool = false) {
        if let storeDescription = persistentStoreDescriptions.first {
            storeDescription.shouldAddStoreAsynchronously = true
            if inMemory {
                storeDescription.url = URL(fileURLWithPath: "/dev/null")
                storeDescription.shouldAddStoreAsynchronously = false
            }
        }
    }
}

func getTopLevelDittoDir() -> URL {
    let fileManager = FileManager.default
    return try! fileManager.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
    ).appendingPathComponent("ditto_top_level")
}

func removeDirectory(_ dir: URL) {
    let fileManager = FileManager.default
    do {
        print("About to remove directory: \(dir.path)")
        try fileManager.removeItem(at: dir)
        print("Removed directory: \(dir.path)")
    } catch let err {
        print("Failed to remove directory: \(dir.path). Error: \(err.localizedDescription)")
    }
}

func randomAppName() -> String {
    return "test.ditto.\(ProcessInfo.processInfo.globallyUniqueString)"
}

class TestHelper {

    static func ditto(appName: String) -> Ditto {
        func readLicenseToken() -> String {
            let path = Bundle.main.path(forResource: "license_token", ofType: "txt") // file path for file "data.txt"
            let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            return string
        }
        
        let appName = appName
        let siteID: UInt64 = 1
        let dittoPersistenceDir = getTopLevelDittoDir().appendingPathComponent(appName).appendingPathComponent("ditto")
        let ditto = Ditto(
            identity: .development(appName: appName, siteID: siteID),
            persistenceDirectory: dittoPersistenceDir
        )
        ditto.setAccessLicense(readLicenseToken())
        let config = DittoTransportConfig()
        config.peerToPeer.lan.isEnabled = true
        ditto.setTransportConfig(config: config)
        return ditto
    }
    
    static func ditto2(appName: String) -> Ditto {
        func readLicenseToken() -> String {
            let path = Bundle.main.path(forResource: "license_token", ofType: "txt") // file path for file "data.txt"
            let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            return string
        }
        
        let appName = appName
        let siteID: UInt64 = 2
        let dittoPersistenceDir = getTopLevelDittoDir().appendingPathComponent(appName).appendingPathComponent("ditto2")
        let ditto = Ditto(
            identity: .development(appName: appName, siteID: siteID),
            persistenceDirectory: dittoPersistenceDir
        )
        ditto.setAccessLicense(readLicenseToken())
        let config = DittoTransportConfig()
        config.peerToPeer.lan.isEnabled = true
        ditto.setTransportConfig(config: config)
        return ditto
    }

    static func persistentContainer() -> CoreDataContainer {
        return CoreDataContainer(name: "Model", inMemory: true)
    }
}
