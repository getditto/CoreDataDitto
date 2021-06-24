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

class TestHelper {

    static func ditto() -> Ditto {
        func readLicenseToken() -> String {
            let path = Bundle.main.path(forResource: "license_token", ofType: "txt") // file path for file "data.txt"
            let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            return string
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
        let randomString = ProcessInfo.processInfo.globallyUniqueString
        let appName = "test.ditto.\(randomString)"
        let siteID = UInt64.random(in: 2...UInt64.max)
        let dittoPersistenceDir = getTopLevelDittoDir().appendingPathComponent(randomString).appendingPathComponent("ditto")
        let ditto = Ditto(
            identity: .development(appName: appName, siteID: siteID),
            persistenceDirectory: dittoPersistenceDir
        )
        ditto.setAccessLicense(readLicenseToken())
        return ditto
    }

    static func persistentContainer() -> CoreDataContainer {
        return CoreDataContainer(name: "Model", inMemory: true)
    }
}
