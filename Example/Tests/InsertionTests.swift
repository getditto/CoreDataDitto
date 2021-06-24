import XCTest
import CoreData
import DittoSwift
import CoreDataDitto
import Fakery


class InsertionTests: XCTestCase {

    var ditto: Ditto!
    var coreDataDitto: CoreDataDitto<MenuItem>!
    var pendingCursor: DittoPendingCursorOperation!

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        ditto = TestHelper.ditto()
        pendingCursor = ditto.store["menuItems"].findAll()
        coreDataDitto = CoreDataDitto(ditto: ditto, collection: "menuItems", pendingCursorOperation: pendingCursor, fetchRequest: MenuItem.fetchRequest(), context: TestHelper.persistentContainer().viewContext, managedObjectIdKeyPath: "id")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        self.coreDataDitto?.stop()
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
}

