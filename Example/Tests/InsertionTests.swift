import XCTest
import CoreData
import DittoSwift
import CoreDataDitto
import Fakery


class InsertionTests: XCTestCase {

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
    
    func testHydratingDittoWithInitialCoreData() {
        // we begin by seeding core data with 20 random objects
        let ex = XCTestExpectation(description: "Ditto documents have synced with CoreData")
        self.coreDataDitto.liveSnapshot = { (snapshot) in
            if (snapshot.documents.count == 20 && snapshot.managedObjects.count == 20) {
                ex.fulfill()
            }
        }

        let managedObjectContext = self.coreDataDitto.fetchedResultsController.managedObjectContext;
        // we begin by seeding core data with 20 random objects
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }
        try! coreDataDitto.startSync()
        
        wait(for: [ex], timeout: 5)
    }

    func testHydratingDittoWithCoreData() {
        let ex = XCTestExpectation(description: "documents have synchronised into Ditto's store")
        var callTimes = 0
        self.coreDataDitto.liveSnapshot = { (snapshot) in
            callTimes = callTimes + 1
            if callTimes == 1 {
                XCTAssert(snapshot.documents.count == 20)
                XCTAssert(snapshot.managedObjects.count == 20)
            }
            if callTimes > 1 && snapshot.documents.count == 25 && snapshot.managedObjects.count == 25 {
                ex.fulfill()
            }
        }

        let managedObjectContext = self.coreDataDitto.fetchedResultsController.managedObjectContext;
        // we begin by seeding core data with 20 random objects
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }

        try! coreDataDitto.startSync()

        //let's insert another 5 documents
        //this should trigger the fetchResultsControllerDelegate to insert these 5 documents into ditto
        for _ in 0..<5 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }
        wait(for: [ex], timeout: 5)
    }
    
    func testCoreDataInsertAndSync() {
        try! coreDataDitto.startSync()
        try! coreDataDitto2.startSync()
        
        // we begin by seeding core data with 20 random objects
        let ex = XCTestExpectation(description: "Ditto documents have synced with CoreData locally")
        let ex2 = XCTestExpectation(description: "Ditto documents have synced with CoreData on second instance")
        self.coreDataDitto.liveSnapshot = { (snapshot) in
            print("Ditto1: documents count \(snapshot.documents.count) managed objects count \(snapshot.managedObjects.count)")
            if (snapshot.documents.count == 20 && snapshot.managedObjects.count == 20) {
                ex.fulfill()
            }
        }
        
        self.coreDataDitto2.liveSnapshot = { (snapshot) in
            print("Ditto2: documents count \(snapshot.documents.count) managed objects count \(snapshot.managedObjects.count)")
            if (snapshot.documents.count == 20 && snapshot.managedObjects.count == 20) {
                ex2.fulfill()
            }
        }

        let managedObjectContext = self.coreDataDitto.fetchedResultsController.managedObjectContext;
        // we begin by seeding core data with 20 random objects
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }
        
        wait(for: [ex, ex2], timeout: 15)
    }
}
