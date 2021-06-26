import XCTest
import CoreData
import DittoSwift
import CoreDataDitto
import Fakery


class ExtensionMethodTests: BaseTestCase {
    func testDocumentIsEqualManagedObject() {
        let menuItem = MenuItem(context: managedContext1)
        menuItem.id = UUID().uuidString
        menuItem.name = Faker().lorem.sentence()
        menuItem.details = Faker().lorem.sentence()

        try! ditto1.store["menuItems"].insert([
            "_id": menuItem.id,
            "name": menuItem.name,
            "details": menuItem.details,
            "price": menuItem.price
        ])

        let foundDocument = ditto1.store["menuItems"].findByID(menuItem.id!).exec()!

        XCTAssertEqual(menuItem.id, foundDocument["_id"].stringValue)
        XCTAssertEqual(menuItem.name, foundDocument["name"].stringValue)
        XCTAssertEqual(menuItem.details, foundDocument["details"].stringValue)
        XCTAssertEqual(menuItem.price, foundDocument["price"].doubleValue)
    }

    func testDictionaryFromManagedObject() {
        let menuItem = MenuItem(context: managedContext1)
        menuItem.id = UUID().uuidString
        menuItem.name = Faker().lorem.sentence()
        menuItem.details = Faker().lorem.sentence()

        let dict = menuItem.asDittoDictionary(managedObjectIdKeyPath: \MenuItem.id)
        XCTAssertEqual(menuItem.id, dict["_id"] as? String)
        XCTAssertEqual(menuItem.name, dict["name"] as? String)
        XCTAssertEqual(menuItem.details, dict["details"] as? String)
        XCTAssertEqual(menuItem.price, dict["price"] as? Double)
    }

}

