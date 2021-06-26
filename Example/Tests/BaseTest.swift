//
//  BaseTest.swift
//  CoreDataDitto_Tests
//
//  Created by Maximilian Alexander on 6/25/21.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import XCTest
import CoreData
import DittoSwift
import CoreDataDitto
import Fakery


class BaseTestCase: XCTestCase {

    var ditto1: Ditto!
    var ditto2: Ditto!
    var mom: NSManagedObjectModel!
    var appName = randomAppName()
    var coreData1: CoreDataContainer!
    var coreData2: CoreDataContainer!
    var managedContext1: NSManagedObjectContext!
    var managedContext2: NSManagedObjectContext!
    var fetchRequest: NSFetchRequest<MenuItem>!
    
    static let mom = TestHelper.createMom()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        DittoLogger.minimumLogLevel = .debug
        ditto1 = TestHelper.ditto1(appName: appName)
        ditto2 = TestHelper.ditto2(appName: appName)
        coreData1 = TestHelper.persistentContainer(mom: BaseTestCase.mom)
        coreData2 = TestHelper.persistentContainer(mom: BaseTestCase.mom)
        coreData1.loadPersistentStores { description, err in
            self.managedContext1 = self.coreData1.viewContext
        }
        coreData2.loadPersistentStores { description, err in
            self.managedContext2 = self.coreData2.viewContext
        }

        ditto1.startSync()
        ditto2.startSync()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        ditto1.stopSync()
        ditto2.stopSync()
        removeDirectory(getTopLevelDittoDir())
        super.tearDown()
    }
}
