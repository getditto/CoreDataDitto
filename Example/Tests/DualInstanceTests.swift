import XCTest
import CoreData
import CoreDataDitto
import Fakery

class DualInstanceTests: BaseTestCase {

    
    func testCoreDataInsertAndSync() {
        // we begin by seeding core data with 20 random objects
        let ex1 = expectation(description: "Ditto documents have synced with CoreData locally")
        ex1.assertForOverFulfill = false
        let ex2 = expectation(description: "Ditto documents have synced with CoreData on second instance")
        ex2.assertForOverFulfill = false
        
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

    func testCoreDataInsertUpdateSync() {
        let ex1 = expectation(description: "Initial MenuItem synced")
        ex1.assertForOverFulfill = false
        let ex2 = expectation(description: "Updated MenuItem synced")
        ex2.assertForOverFulfill = false
        
        let details1 = "Adam"
        let details2 = "Max"
        
        let token1 = managedContext1.bind(to: ditto1, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            // Unused
        }

        let token2 = managedContext2.bind(to: ditto2, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            if let item = items.first {
                if item.details == details1 {
                    ex1.fulfill()
                }
                else if item.details == details2 {
                    ex2.fulfill()
                }
            }
        }

        let menuItem = MenuItem(context: managedContext1)
        menuItem.id = UUID().uuidString
        menuItem.name = Faker().commerce.productName()
        menuItem.details = details1

        wait(for: [ex1], timeout: 10)
        
        menuItem.details = details2
        
        try! managedContext1.save()
        
        wait(for: [ex2], timeout: 10)
        
        token1.stop()
        token2.stop()
    }
    
    func testCoreDataInsertUpdateDeleteSync() {
        let ex1 = expectation(description: "Initial MenuItem synced")
        let ex2 = expectation(description: "Updated MenuItem synced")
        let ex3 = expectation(description: "Deleted MenuItem synced")
        
        let details1 = "Adam"
        let details2 = "Max"
        
        let token1 = managedContext1.bind(to: ditto1, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            // Unused
        }
        
        var calledTimes = 0
        let token2 = managedContext2.bind(to: ditto2, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            if calledTimes == 0 {
                XCTAssertTrue(items.count == 0)
            }
            else if calledTimes == 1 {
                if let item = items.first {
                    XCTAssertTrue(item.details == details1)
                    ex1.fulfill()
                }
            }
            else if calledTimes == 2 {
                if let item = items.first {
                    XCTAssertTrue(item.details == details2 )
                    ex2.fulfill()
                }
            }
            else if calledTimes == 3 {
                XCTAssertTrue(items.count == 0)
                ex3.fulfill()
            }
            calledTimes = calledTimes + 1
        }
        
        // Test insert
        let menuItem = MenuItem(context: managedContext1)
        menuItem.id = UUID().uuidString
        menuItem.name = Faker().commerce.productName()
        menuItem.details = details1

        wait(for: [ex1], timeout: 10)
        
        // Test update
        menuItem.details = details2
        
        try! managedContext1.save()
        
        wait(for: [ex2], timeout: 10)
        
        // Test delete
        managedContext1.delete(menuItem)
        
        try! managedContext1.save()
        
        wait(for: [ex3], timeout: 10)
        
        token1.stop()
        token2.stop()
    }
    
    func testInstance1InsertInstance2Update() {
        let ex1 = expectation(description: "Initial MenuItem synced to instance2")
        let ex2 = expectation(description: "Updated MenuItem synced to instance1")
        
        let details1 = "Adam"
        let details2 = "Max"
        
        var calledTimes1 = 0
        let token1 = managedContext1.bind(to: ditto1, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            if calledTimes1 == 0 {
                XCTAssertTrue(items.count == 0)
            }
            else if calledTimes1 == 1 {
                if let item = items.first {
                    XCTAssertTrue(item.details == details1)
                }
            }
            else if calledTimes1 == 2 {
                if let item = items.first {
                    XCTAssertTrue(item.details == details2)
                    ex2.fulfill()
                }
            }
            calledTimes1 = calledTimes1 + 1
        }
        
        var calledTimes2 = 0
        let token2 = managedContext2.bind(to: ditto2, primaryKeyPath: \MenuItem.id, collectionName: "menuItems") { items in
            if calledTimes2 == 0 {
                XCTAssertTrue(items.count == 0)
            }
            else if calledTimes2 == 1 {
                if let item = items.first {
                    XCTAssertTrue(item.details == details1)
                    ex1.fulfill()
                    
                    // Update the MenuItem to verify resync
                    item.details = details2
                }
            }
            else if calledTimes2 == 2 {
                if let item = items.first {
                    XCTAssertTrue(item.details == details2)
                }
            }
            calledTimes2 = calledTimes2 + 1
        }
        
        // Test insert
        let menuItem = MenuItem(context: managedContext1)
        menuItem.id = UUID().uuidString
        menuItem.name = Faker().commerce.productName()
        menuItem.details = details1

        wait(for: [ex1, ex2], timeout: 10)
        
        token1.stop()
        token2.stop()
    }
}
