import XCTest
import CoreData
import CoreDataDitto
import Fakery

class DualInstanceInsertionTests: BaseTestCase {

    
    func testCoreDataInsertAndSync() {
        // we begin by seeding core data with 20 random objects
        let ex1 = XCTestExpectation(description: "Ditto documents have synced with CoreData locally")
        let ex2 = XCTestExpectation(description: "Ditto documents have synced with CoreData on second instance")

        let token1 = managedContext1.bind(to: ditto1, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            if items.count == 20 {
                ex1.fulfill()
            }
        }

        let token2 = managedContext2.bind(to: ditto2, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            if items.count == 20 {
                ex2.fulfill()
            }
        }

        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedContext1)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }

        waitForExpectations(timeout: 15) { _ in
            token1.stop()
            token2.stop()
        }
    }


}
