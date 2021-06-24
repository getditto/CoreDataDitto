import XCTest
import CoreData
import DittoSwift
import CoreDataDitto
import Fakery


struct Car {
    var name: String
    var mileage: Float
}
/**
 This test case will test ensuring
 */
class PreferDittoTests: XCTestCase {

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
        let managedObjectContext = self.coreDataDitto.fetchedResultsController.managedObjectContext;
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
            managedObjectContext.insert(menuItem)
        }
        // begin syncing
        try! coreDataDitto.sync()
        // check if ditto has 20 items
        let docs = ditto.store["menuItems"].findAll().exec()
        XCTAssertEqual(docs.count, 20)
    }

    func testHydratingDittoWithCoreData() {
        let ex = XCTestExpectation(description: "documents have synchronised into Ditto's store")

        self.coreDataDitto.syncOccurredHandler = { [weak ditto] in
            guard let ditto = ditto else { return }

            // there should eventually be 25 documents (20 from the initial, 5 after)
            let docs = ditto.store.collection("menuItems").findAll().exec()
            if docs.count == 25 {
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
            managedObjectContext.insert(menuItem)
        }
        try! coreDataDitto.sync()
        // let's insert another 5 documents
        // this should trigger the fetchResultsControllerDelegate to insert these 5 documents into ditto
        for _ in 0..<5 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
            managedObjectContext.insert(menuItem)
        }

        wait(for: [ex], timeout: 5)
    }
}

