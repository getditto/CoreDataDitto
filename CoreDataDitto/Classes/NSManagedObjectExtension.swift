//
//  NSManagedObjectExtension.swift
//  CoreDataDitto
//
//  Created by Maximilian Alexander on 6/25/21.
//

import CoreData

extension NSManagedObject {

    /// Generates a ditto document compatable dictionary with a specified primary key
    /// - Parameter primaryKeyPath: The key path specifying the
    /// - Returns: A [String: Any
    public func dittoDocumentDictionary<Root, Val>(primaryKeyPath: KeyPath<Root, Val>) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict["_id"] = dict[primaryKeyPath._kvcKeyPathString!]
        dict.removeValue(forKey: primaryKeyPath._kvcKeyPathString!)
        return dict
    }



    /// Retrieves the document id from the managed object as an `NSObject`
    /// This is primarily a utility method for easy equality comparisons
    /// - Parameter primaryKeyPath: <#primaryKeyPath description#>
    /// - Returns: <#description#>
    func docId<Root, V>(primaryKeyPath: KeyPath<Root, V>) -> NSObject {
        return self.value(forKey:primaryKeyPath._kvcKeyPathString!) as! NSObject
    }
}
