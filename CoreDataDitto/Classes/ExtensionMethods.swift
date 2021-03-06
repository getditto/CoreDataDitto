//
//  ExtensionMethods.swift
//  CoreDataDitto
//
//  Created by Maximilian Alexander on 6/25/21.
//

import DittoSwift
import CoreData


extension NSManagedObject {


    /// This function will take the core data object and turn it into an acceptable DittoDocument [String: Any]
    /// It will take the `managedObjectIdKeyPath` and map it to `_id`
    /// - Parameter managedObjectIdKeyPath: the primary key in the core data object
    /// - Returns: A dictionary acceptable for `ditto.store[collectionName].insert`
    public func asDittoDictionary(managedObjectIdKeyPath: AnyKeyPath) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict["_id"] = dict[managedObjectIdKeyPath._kvcKeyPathString!]
        dict.removeValue(forKey: managedObjectIdKeyPath._kvcKeyPathString!)
        return dict
    }

    /// This function will take the core data object and turn it into an acceptable DittoDocument [String: Any]
    /// however this will omit the specified `_id` or `managedObjectKeyPath` field
    /// - Parameter managedObjectIdKeyPath: the primary key in the core data object
    /// - Returns: A dictionary acceptable for `ditto.store[collectionName].insert` without the `_id` field
    func valuesWithoutId(managedObjectIdKeyPath: AnyKeyPath) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict.removeValue(forKey: managedObjectIdKeyPath._kvcKeyPathString!)
        dict.removeValue(forKey: "_id")
        return dict
    }

    func setWithDittoDocumentValues<Root, Value>(
        dittoDocument: DittoDocument,
        primaryKeyPath: KeyPath<Root, Value>
    ) {
        dittoDocument.value.forEach { k, v in
            if k == "_id" {
                if !objectEquals(a: self.value(forKey: primaryKeyPath._kvcKeyPathString!), b: v) {
                    self.setValue(v, forKey: primaryKeyPath._kvcKeyPathString!)
                }
            } else {
                if !objectEquals(a: self.value(forKey: k), b: v) {
                    self.setValue(v, forKey: k)
                }
            }
        }
    }
}

extension DittoDocument {


    /// This is just a internal helper to transform the id into NSObject for easier equality checks
    var docId: NSObject {
        return self.id.value as! NSObject
    }

}

extension DittoMutableDocument {

    /// Takes a managed object from Core Data, and applies all the values
    /// - Parameters:
    ///   - managedObject: The core data managed object
    ///   - managedObjectIdKeyPath: the primary key field for this core data object used to set the `_id`
    public func setWithManagedObject<Root, Value>(managedObject: NSManagedObject, managedObjectIdKeyPath: KeyPath<Root, Value>) {
        let dict = managedObject.valuesWithoutId(managedObjectIdKeyPath: managedObjectIdKeyPath)
        let dittoDict = self.value
        dict.forEach { (key, value) in
            if let dittoValue = dittoDict[key], !objectEquals(a: dittoValue, b: value) {
                self[key].set(value)
            }
        }
    }
}

func objectEquals(a: Any?, b: Any?) -> Bool {
    let objA = a as? NSObject
    let objB = b as? NSObject
    if objA == nil && objB == nil {
        return true
    }
    if let objA = objA, let objB = objB {
        return objA.isEqual(objB)
    }
    return false
}
