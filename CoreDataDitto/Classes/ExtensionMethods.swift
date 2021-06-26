//
//  ExtensionMethods.swift
//  CoreDataDitto
//
//  Created by Maximilian Alexander on 6/25/21.
//

import DittoSwift
import CoreData
import DeepDiff


extension Dictionary: DiffAware where Key == String, Value == Any {
    public typealias DiffId = AnyHashable
    public var diffId: AnyHashable {
        return self["_id"] as! AnyHashable
    }
    public static func compareContent(_ a: Dictionary<String, Any>, _ b: Dictionary<String, Any>) -> Bool {
        return NSDictionary(dictionary: a).isEqual(NSDictionary(dictionary: b))
    }
}


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
        var dictionaryOfDittoDocument = dittoDocument.value
        dictionaryOfDittoDocument.removeValue(forKey: "_id")
        self.setValue(dittoDocument.id.value, forKey: primaryKeyPath._kvcKeyPathString!)
        self.setValuesForKeys(dictionaryOfDittoDocument as [String : Any])
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
    func setWithManagedObject<Root, Value>(managedObject: NSManagedObject, managedObjectIdKeyPath: KeyPath<Root, Value>) {
        let dict = managedObject.valuesWithoutId(managedObjectIdKeyPath: managedObjectIdKeyPath)
        dict.forEach { (key, value) in
            self[key].set(value)
        }
    }
}
