import DittoSwift
import CoreData

extension NSManagedObject {


    /// This function will take the core data object and turn it into an acceptable DittoDocument [String: Any]
    /// It will take the `managedObjectIdKeyPath` and map it to `_id`
    /// - Parameter managedObjectIdKeyPath: the primary key in the core data object
    /// - Returns: A dictionary acceptable for `ditto.store[collectionName].insert`
    func asDittoDictionary(managedObjectIdKeyPath: String) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict["_id"] = dict[managedObjectIdKeyPath]
        dict.removeValue(forKey: managedObjectIdKeyPath)
        return dict
    }


    /// This function will take the core data object and turn it into an acceptable DittoDocument [String: Any]
    /// however this will omit the specified `_id` or `managedObjectKeyPath` field
    /// - Parameter managedObjectIdKeyPath: the primary key in the core data object
    /// - Returns: A dictionary acceptable for `ditto.store[collectionName].insert` without the `_id` field
    func valuesWithoutId(managedObjectIdKeyPath: String) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict.removeValue(forKey: managedObjectIdKeyPath)
        dict.removeValue(forKey: "_id")
        return dict
    }


    /// Checks if a DittoDocument has the same value as the representation of the CoreData object
    /// - Parameters:
    ///   - dittoDocument: the ditto document to compare
    ///   - managedObjectIdKeyPath: the primary key field for this core data object used to compare the `_id`
    /// - Returns: Is of equal value
    public func isEqual(to dittoDocument: DittoDocument, managedObjectIdKeyPath: String) -> Bool {
        return dittoDocument.isEqual(to: self, managedObjectIdKeyPath: managedObjectIdKeyPath)
    }


    /// Takes a ditto document, iterates over its keys and value
    /// - Parameters:
    ///   - dittoDocument: The DittoDocument
    ///   - managedObjectIdKeyPath: the primary key field for this core data object used to set the `_id`
    func setWithDittoDocument(dittoDocument: DittoDocument, managedObjectIdKeyPath: String) {
        dittoDocument.value.forEach { k, v in
            if k == "_id" {
                self.setValue(v, forKey: managedObjectIdKeyPath)
            } else {
                self.setValue(v, forKey: k)
            }
        }
    }
}

extension DittoDocument {

    public func isEqual(to managedObject: NSManagedObject, managedObjectIdKeyPath: String) -> Bool {
        let managedObjectAsDict = managedObject.asDittoDictionary(managedObjectIdKeyPath: managedObjectIdKeyPath)
        return NSDictionary(dictionary: self.value as [AnyHashable : Any]).isEqual(NSDictionary(dictionary: managedObjectAsDict))
    }

}

extension DittoMutableDocument {

    /// Takes a managed object from Core Data, and applies all the values
    /// - Parameters:
    ///   - managedObject: The core data managed object
    ///   - managedObjectIdKeyPath: the primary key field for this core data object used to set the `_id`
    func setWithManagedObject(managedObject: NSManagedObject, managedObjectIdKeyPath: String) {
        let dict = managedObject.valuesWithoutId(managedObjectIdKeyPath: managedObjectIdKeyPath)
        dict.forEach { (key, value) in
            self[key].set(value)
        }
    }
}


/// An alternative delegate that will notify snapshot changes
protocol CoreDataDittoDelegate: class {
    func snapshot<T: NSManagedObject>(snapshot: Snapshot<T>)
}

public struct Snapshot<T: NSManagedObject> {
    public let managedObjects: [T]
    public let documents: [DittoDocument]
}

public final class CoreDataDitto<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {

    var liveQuery: DittoLiveQuery?

    weak var delegate: CoreDataDittoDelegate?

    public let ditto: Ditto

    /// The name of the collection
    public let collection: String

    /// The Ditto query that should match the `fetchRequest`
    public let pendingCursorOperation: DittoPendingCursorOperation

    public let fetchRequest: NSFetchRequest<T>
    public let fetchedResultsController: NSFetchedResultsController<T>

    /**
     In order for this library to work, it needs to know which field in the CoreData
     entity is the primary key. Ensure that this key is unique
     */
    public let managedObjectIdKeyPath: String

    /// The current snapshot of entities and documents given the DittoPendingCursorOperation and fetch results
    /// This is a synchronous return of values.
    public var snapshot: Snapshot<T> {
        let managedObjects = fetchedResultsController.fetchedObjects ?? []
        let docs = pendingCursorOperation.exec()
        return Snapshot(managedObjects: managedObjects, documents: docs)
    }

    public var liveSnapshot: ((Snapshot<T>) -> Void)?

    /// Constructs a bidirectional sync between core data and a ditto live query
    /// - Parameters:
    ///   - ditto: the ditto instance
    ///   - collection: the name of the collection to sync with core data
    ///   - pendingCursorOperation: the pending cursor operation to sync with core data
    ///   - fetchRequest: the fetch request from core data. This needs to match up logically with the pendingCursorOperation or else the syncing will not produce proper results
    ///   - context: the managed object context
    ///   - managedObjectIdKeyPath: the name of the property or key of the core data entity that represents the primary unique key
    public init(
        ditto: Ditto,
        collection: String,
        pendingCursorOperation: DittoPendingCursorOperation,
        fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        managedObjectIdKeyPath: String
    ) {
        self.ditto = ditto
        self.collection = collection
        self.pendingCursorOperation = pendingCursorOperation
        self.fetchRequest = fetchRequest

        if self.fetchRequest.sortDescriptors == nil {
            // in order for NSFetchedResultsController to work it _needs_ a sort descriptor
            // the user can specify one but if the user omits it, we will sort by the managedObjectIdKey
            let sort = NSSortDescriptor(key: managedObjectIdKeyPath, ascending: false)
            self.fetchRequest.sortDescriptors = [sort]
        }
        self.managedObjectIdKeyPath = managedObjectIdKeyPath
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: self.fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    }

    public func startSync() throws {
        self.fetchedResultsController.delegate = self

        let initialDocs = pendingCursorOperation.exec()
        try fetchedResultsController.performFetch()
        let fetchedObjects = fetchedResultsController.fetchedObjects ?? []

        ditto.store.write { txn in
            /**
             Loop through all the intial Ditto documents
             Find the ones that don't exist in core data
             Remove them from Ditto (we are preferring what is in core data first!)
             */
            initialDocs
                .filter({ !fetchedObjects.compactMap({ $0.value(forKey: self.managedObjectIdKeyPath) as? NSObject }).contains($0.id.value as! NSObject) }).forEach { dittoDocument in
                    txn[self.collection].findByID(dittoDocument.id).remove()
                }

            /**
             Loop through all the fetched object, find if they do not exist with the same id in Ditto
             and proceed to insert them into Ditto
             */
            fetchedObjects
                .filter({ !initialDocs.compactMap({ $0.id.value as? NSObject }).contains($0.value(forKey: self.managedObjectIdKeyPath) as! NSObject) }).forEach { managedObject in

                    let dictionary = managedObject.asDittoDictionary(managedObjectIdKeyPath: self.managedObjectIdKeyPath)
                    try! txn[self.collection].insert(dictionary)
                }

            /**
             Find all the matching ids and update the ditto documents to match the CoreData object
             */
            fetchedObjects.forEach { managedObject in
                guard let doc = initialDocs.first(where: { $0.id.value as? NSObject == managedObject.value(forKey: self.managedObjectIdKeyPath) as? NSObject }) else { return }

                txn[self.collection].findByID(doc.id).update { doc in
                    guard let doc = doc else { return }
                    doc.setWithManagedObject(managedObject: managedObject, managedObjectIdKeyPath: self.managedObjectIdKeyPath)
                }
            }
        }

        // do the initial update to the delegate or callback
        delegate?.snapshot(snapshot: self.snapshot)
        liveSnapshot?(self.snapshot)

        liveQuery = pendingCursorOperation.observe(eventHandler: { [weak self] newDocs, event in
            guard let `self` = self else { return }
            switch event {
            case .update(let info):
                info.insertions.map({ newDocs[$0] }).forEach { doc in
                    let managedObject = T(context: self.fetchedResultsController.managedObjectContext)
                    managedObject.setWithDittoDocument(dittoDocument: doc, managedObjectIdKeyPath: self.managedObjectIdKeyPath)
                    self.fetchedResultsController.managedObjectContext.insert(managedObject)
                }
                info.updates.map({ newDocs[$0] }).forEach { doc in
                    let managedObject = self.fetchedResultsController.fetchedObjects?.first(where: { managedObject in
                        managedObject.value(forKey: self.managedObjectIdKeyPath) as? NSObject == doc.id.value as? NSObject
                    }) ?? T(context: self.fetchedResultsController.managedObjectContext)
                    // we've found a managedObject with the same ids
                    managedObject.setWithDittoDocument(dittoDocument: doc, managedObjectIdKeyPath: self.managedObjectIdKeyPath)
                    try? self.fetchedResultsController.managedObjectContext.save()
                }
                // ditto wants to delete an object from core data
                info.deletions.map({ info.oldDocuments[$0] }).forEach { doc in
                    guard let objectToDelete = (self.fetchedResultsController.fetchedObjects ?? []).first(where: { $0.value(forKey: self.managedObjectIdKeyPath) as? NSObject == doc.id.value as? NSObject }) else { return }
                    self.fetchedResultsController.managedObjectContext.delete(objectToDelete)
                }
            default:
                // We probably want to handle the `initial` event to, if we want full bi-directional sync
                break
            }
            let snapshot = Snapshot(managedObjects: self.fetchedResultsController.fetchedObjects ?? [], documents: newDocs)
            self.delegate?.snapshot(snapshot: snapshot)
            self.liveSnapshot?(snapshot)
        })
    }

    public func stop() {
        liveQuery?.stop()
        fetchedResultsController.delegate = nil
    }

    /**
     If this object is deallocated
     */
    deinit {
        self.stop()
    }

    /**
     NSFetchedResultsControllerDelegate implementation
     */
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let managedObject = anObject as? T else { return }
        switch type {
        case .insert:
            /**
             The user has inserted a new CoreData object, we need to turn that into a new insertion into Ditto
             */
            let dict = managedObject.asDittoDictionary(managedObjectIdKeyPath: managedObjectIdKeyPath)
            try! self.ditto.store[collection].insert(dict)
        case .delete:
            /**
             The user has deleted a CoreData object, find the ditto document by Id and delete it
             */
            guard let id = managedObject.value(forKey: managedObjectIdKeyPath) else { return }
            self.ditto.store[collection].findByID(id).remove()
        case .update:
            /**
             The user has updated a CoreData object, find the ditto document set it's values to match
             */
            guard let id = managedObject.value(forKey: managedObjectIdKeyPath) else { return }
            self.ditto.store[collection].findByID(id).update { doc in
                guard let doc = doc else { return }
                doc.setWithManagedObject(managedObject: managedObject, managedObjectIdKeyPath: self.managedObjectIdKeyPath)
            }
        default:
            // there is a `.move` case but we don't really care about it.
            break
        }
        let docs = pendingCursorOperation.exec()
        let snapshot = Snapshot(managedObjects: self.fetchedResultsController.fetchedObjects ?? [], documents: docs)
        self.delegate?.snapshot(snapshot: snapshot)
        self.liveSnapshot?(snapshot)
    }
}
