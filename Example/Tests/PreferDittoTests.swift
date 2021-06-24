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
        // This is an example of a functional test case.
        let managedObjectContext = self.coreDataDitto.fetchedResultsController.managedObjectContext;
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
            managedObjectContext.insert(menuItem)
        }
        try! coreDataDitto.start()
        let docs = ditto.store["menuItems"].findAll().exec()
        XCTAssertEqual(docs.count, 20)
    }

    func testHydratingDittoWithCoreData() {
        let managedObjectContext = self.coreDataDitto.fetchedResultsController.managedObjectContext;
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
            managedObjectContext.insert(menuItem)
        }
        try! coreDataDitto.start()
        // let's insert another 5 documents
        // this should trigger the fetchResultsControllerDelegate
        for _ in 0..<5 {
            let menuItem = MenuItem(context: managedObjectContext)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
            managedObjectContext.insert(menuItem)
        }
        let docs = ditto.store.collection("menuItems").findAll().exec()
        XCTAssertEqual(docs.count, 25)
    }
}

