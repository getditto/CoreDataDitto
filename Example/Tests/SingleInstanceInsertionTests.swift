import XCTest
import CoreData
import CoreDataDitto
import Fakery

class SingleInstanceInsertionTests: BaseTestCase {
    
    func testSingleInstanceInsertion() {
        let ex = expectation(description: "Initial Core Data objects")

        // lets insert 20 items
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedContext1)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }

        let token = managedContext1.bind(to: ditto1, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items
            in
            XCTAssert(items.count == 20)
            ex.fulfill()
        }

        waitForExpectations(timeout: 3) { _ in
            token.stop()
        }
    }

    func testSingleInstanceInsertionWithSubsequentInsertions() {
        let ex = expectation(description: "Initial Core Data objects")

        // lets insert 20 items
        for _ in 0..<20 {
            let menuItem = MenuItem(context: managedContext1)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }

        var calledTimes = 0
        let token = managedContext1.bind(to: ditto1, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items
            in
            calledTimes = calledTimes + 1
            if calledTimes == 1 {
                XCTAssertEqual(items.count, 20)
            }
            if calledTimes == 6 {
                XCTAssertEqual(items.count, 25)
                ex.fulfill()
            }
        }

        // lets add 5 more
        for _ in 0..<5 {
            let menuItem = MenuItem(context: managedContext1)
            menuItem.id = UUID().uuidString
            menuItem.name = Faker().commerce.productName()
            menuItem.details = Faker().lorem.sentence()
        }

        waitForExpectations(timeout: 15) { _ in
            token.stop()
        }
    }
}
