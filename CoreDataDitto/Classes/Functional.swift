//
//  Functional.swift
//  CoreDataDitto
//
//  Created by Maximilian Alexander on 6/25/21.
//

import Foundation
import DittoSwift
import CoreData


public final class Token<T: NSManagedObject, V> {
    private let liveQuery: DittoLiveQuery
    private let fetchObserver: FetchObserver<T, V>
    internal init (liveQuery: DittoLiveQuery, fetchObserver: FetchObserver<T, V>) {
        self.liveQuery = liveQuery
        self.fetchObserver = fetchObserver;
    }
    public func stop() {
        self.liveQuery.stop()
    }
    deinit {
        self.stop()
    }
}

public typealias SnapshotCallBack<T> = ([T]) -> Void

extension NSManagedObjectContext {

    public func bind<T: NSManagedObject, V>(
        to ditto: Ditto,
        primaryKeyPath: KeyPath<T, V>,
        collectionName: String,
        snapshotCallBack: @escaping SnapshotCallBack<T>
    ) -> Token<T, V> {

        // NSFetchedResultsController requires a sort direction
        let fetchRequest: NSFetchRequest<T> = NSFetchRequest<T>(entityName: T.entity().name!)
        let sort = NSSortDescriptor(key: primaryKeyPath._kvcKeyPathString!, ascending: true)
        fetchRequest.sortDescriptors = [sort]
        // We create the exact matched pending cursor for Ditto's side. Notice that we are also sorting on the _id like the
        // NSSortDescriptor above.
        let pendingCursorOperation = ditto.store[collectionName].findAll().sort("_id", direction: .ascending)

        // hydrate the fetch results controller
        let fetchController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self, sectionNameKeyPath: nil, cacheName: nil)
        try! fetchController.performFetch()

        let fetchObserver = FetchObserver(ditto: ditto, collectionName: collectionName, primaryKeyPath: primaryKeyPath) { items in
            snapshotCallBack(items)
        }
        fetchController.delegate = fetchObserver

        /**
         Subsequent Updates From Ditto
         */
        let liveQuery = pendingCursorOperation.observe { docs, event in
            switch event {
            /**
             Initial Fetch
             Here we go through ditto and the context managed objects and we force ditto to match the core data objects
             */
            case .initial:
                let managedObjects = fetchController.fetchedObjects ?? []
                ditto.store.write { trx in
                    docs.forEach { doc in
                        // update it
                        if let managedObject = managedObjects.first(where: { $0[keyPath: primaryKeyPath] as! NSObject == doc.docId }) {
                            trx[collectionName].findByID(doc.id).update { mutableDoc in
                                mutableDoc?.setWithManagedObject(managedObject: managedObject, managedObjectIdKeyPath: primaryKeyPath)
                            }
                        } else {
                            // delete it
                            trx[collectionName].findByID(doc.id).remove()
                        }
                    }

                    managedObjects.forEach { managedObject in
                        let managedObjectId = managedObject[keyPath: primaryKeyPath] as! NSObject
                        if !docs.map({ $0.docId }).contains(managedObjectId) {
                            // docs don't contain this managed object id, create the document
                            let dictionary = managedObject.asDittoDictionary(managedObjectIdKeyPath: primaryKeyPath)
                            try! trx[collectionName].insert(dictionary)
                        }
                    }
                }
                
                snapshotCallBack(managedObjects)
            case .update(let info):
                let managedObjects = (fetchController.fetchedObjects ?? [])
                let oldDocs = info.oldDocuments

                func upsertDocumentIntoManagedObject(doc: DittoDocument) {
                    if let foundManagedObject = managedObjects.first(where: { $0.docId(primaryKeyPath: primaryKeyPath)  == doc.docId }) {
                        foundManagedObject.setWithDittoDocumentValues(dittoDocument: doc, primaryKeyPath: primaryKeyPath)
                    } else {
                        let managedObject = T(context: self)
                        managedObject.setWithDittoDocumentValues(dittoDocument: doc, primaryKeyPath: primaryKeyPath)
                    }
                }

                info.insertions.map { docs[$0] }.forEach { doc in
                    upsertDocumentIntoManagedObject(doc: doc)
                }
                info.updates.map { docs[$0] }.forEach { doc in
                    upsertDocumentIntoManagedObject(doc: doc)
                }
                info.deletions.map { oldDocs[$0].docId }.forEach { docId in
                    guard let managedObject = (fetchController.fetchedObjects ?? []).first(where: { $0.docId(primaryKeyPath: primaryKeyPath) == docId }) else { return }
                    self.delete(managedObject)
                }
                
                try! self.save()
            }
        }
        return Token(liveQuery: liveQuery, fetchObserver: fetchObserver)
    }
}

class FetchObserver<T: NSManagedObject, V>: NSObject, NSFetchedResultsControllerDelegate {

    private let ditto: Ditto
    private let collectionName: String
    private let primaryKeyPath: KeyPath<T, V>

    let callback: SnapshotCallBack<T>

    init(ditto: Ditto, collectionName: String, primaryKeyPath: KeyPath<T, V>, _ callback: @escaping SnapshotCallBack<T>) {
        self.ditto = ditto
        self.collectionName = collectionName
        self.callback = callback
        self.primaryKeyPath = primaryKeyPath
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let managedObjects = controller.fetchedObjects as? [T] else { return }
        let managedObject = anObject as! T
        switch type {
        case .insert:
            let dictionary = managedObject.asDittoDictionary(managedObjectIdKeyPath: self.primaryKeyPath)
            try! self.ditto.store[self.collectionName].insert(dictionary)
            break
        case .delete:
            // the user is attempting to delete an object, this call
            let docId = managedObject.docId(primaryKeyPath: self.primaryKeyPath)
            self.ditto.store[self.collectionName].findByID(DittoDocumentID(value: docId)).remove()
            break
        case .move:
            // we sorted both the pending cursor and fetch results by the primary key
            // objects should not move
            break
        case .update:
            let docId = managedObject.docId(primaryKeyPath: self.primaryKeyPath)
            let dictionary = managedObject.asDittoDictionary(managedObjectIdKeyPath: self.primaryKeyPath)
            if self.ditto.store[self.collectionName].findByID(DittoDocumentID(value: docId)).exec() == nil {
                try! self.ditto.store[self.collectionName].insert(dictionary)
            } else {
                self.ditto.store[self.collectionName].findByID(DittoDocumentID(value: docId)).update { mutable in
                    mutable?.setWithManagedObject(managedObject: managedObject, managedObjectIdKeyPath: self.primaryKeyPath)
                }
            }
            break
        }
        callback(managedObjects)
    }

}
