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

    var ditto: Ditto!
    var ditto2: Ditto!
    var coreDataDitto: CoreDataDitto<MenuItem>!
    var coreDataDitto2: CoreDataDitto<MenuItem>!
    var pendingCursor: DittoPendingCursorOperation!
    var pendingCursor2: DittoPendingCursorOperation!
    let appName = randomAppName()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        DittoLogger.minimumLogLevel = .debug
        ditto = TestHelper.ditto(appName: appName)
        ditto2 = TestHelper.ditto2(appName: appName)
        pendingCursor = ditto.store["menuItems"].findAll()
        pendingCursor2 = ditto2.store["menuItems"].findAll()
        let mom = TestHelper.createMom()
        coreDataDitto = CoreDataDitto(ditto: ditto, collection: "menuItems", pendingCursorOperation: pendingCursor, fetchRequest: MenuItem.fetchRequest(), context: TestHelper.persistentContainer(mom: mom).viewContext, managedObjectIdKeyPath: "id")
        coreDataDitto2 = CoreDataDitto(ditto: ditto2, collection: "menuItems", pendingCursorOperation: pendingCursor, fetchRequest: MenuItem.fetchRequest(), context: TestHelper.persistentContainer(mom: mom).viewContext, managedObjectIdKeyPath: "id")

        ditto.startSync()
        ditto2.startSync()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        self.coreDataDitto?.stop()
        ditto.stopSync()
        ditto2.stopSync()
        removeDirectory(getTopLevelDittoDir())
        super.tearDown()
    }
}
