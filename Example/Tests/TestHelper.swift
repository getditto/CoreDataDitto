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
    init(name: String, mom: NSManagedObjectModel, inMemory: Bool = false) {
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

    static func readLicenseToken() -> String {
        let path = Bundle.main.path(forResource: "license_token", ofType: "txt") // file path for file "data.txt"
        let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
        return string
    }

    static func ditto1(appName: String) -> Ditto {
        let appName = appName
        let siteID: UInt64 = 1
        let dittoPersistenceDir = getTopLevelDittoDir().appendingPathComponent(appName).appendingPathComponent("ditto1")
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

    static func persistentContainer(mom: NSManagedObjectModel) -> CoreDataContainer {
        return CoreDataContainer(name: "Model", mom: mom, inMemory: true)
    }
    
    static func createMom() -> NSManagedObjectModel {
        guard let mom = NSManagedObjectModel.mergedModel(from: Bundle.allBundles) else {
            fatalError("Failed to create mom")
        }
        return mom
    }
}
