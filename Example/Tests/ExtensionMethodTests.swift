import XCTest
import CoreData
import DittoSwift
import CoreDataDitto
import Fakery


class ExtensionMethodTests: XCTestCase {

    var ditto: Ditto!
    var fetchResultsController: NSFetchedResultsController<MenuItem>!

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        ditto = TestHelper.ditto()
        let fetchRequest: NSFetchRequest<MenuItem> = MenuItem.fetchRequest()
        if fetchRequest.sortDescriptors == nil {
            // in order for NSFetchedResultsController to work it _needs_ a sort descriptor
            // the user can specify one but if the user omits it, we will sort by the managedObjectIdKey
            let sort = NSSortDescriptor(key: "id", ascending: false)
            fetchRequest.sortDescriptors = [sort]
        }
        let context = TestHelper.persistentContainer().viewContext
        fetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    }
    
    override func tearDown() {
        super.tearDown()
    }


    func testDocumentIsEqualManagedObject() {
        let menuItem = MenuItem(context: fetchResultsController.managedObjectContext)
        menuItem.id = UUID().uuidString
        menuItem.name = Faker().lorem.sentence()
        menuItem.details = Faker().lorem.sentence()

        try! ditto.store["menuItems"].insert([
            "_id": menuItem.id,
            "name": menuItem.name,
            "details": menuItem.details,
            "price": menuItem.price
        ])

        let foundDocument = ditto.store["menuItems"].findByID(menuItem.id!).exec()!

        XCTAssertEqual(menuItem.id, foundDocument["_id"].stringValue)
        XCTAssertEqual(menuItem.name, foundDocument["name"].stringValue)
        XCTAssertEqual(menuItem.details, foundDocument["details"].stringValue)
        XCTAssertEqual(menuItem.price, foundDocument["price"].doubleValue)

        XCTAssert(menuItem.isEqual(to: foundDocument, managedObjectIdKeyPath: "id"))
        XCTAssert(foundDocument.isEqual(to: menuItem, managedObjectIdKeyPath: "id"))

    }

}

