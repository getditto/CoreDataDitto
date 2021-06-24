import DittoSwift
import CoreData

extension NSManagedObject {

    func asDittoDictionary(managedObjectIdKeyPath: String) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict["_id"] = dict[managedObjectIdKeyPath]
        dict.removeValue(forKey: managedObjectIdKeyPath)

        return dict
    }

    func valuesWithoutId(managedObjectIdKeyPath: String) -> [String: Any] {
        let keys = Array(self.entity.attributesByName.keys)
        var dict = self.dictionaryWithValues(forKeys: keys)
        dict.removeValue(forKey: managedObjectIdKeyPath)
        dict.removeValue(forKey: "_id")
        return dict
    }
}

protocol CoreDataDittoDelegate: class {
    func snapshot<T: NSManagedObject>(snapshot: Snapshot<T>)
}

public struct Snapshot<T: NSManagedObject> {
    public let managedObjects: [T]
    public let documents: [DittoDocument]
}

public class CoreDataDitto<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {

    var liveQuery: DittoLiveQuery?

    weak var delegate: CoreDataDittoDelegate?

    public let ditto: Ditto
    public let collection: String
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

    public func sync() throws {
        self.fetchedResultsController.delegate = self

        let initialDocs = pendingCursorOperation.exec()
        try fetchedResultsController.performFetch()
        let fetchedObjects = fetchedResultsController.fetchedObjects ?? []

        ditto.store.write { txn in
            initialDocs
                .filter({ !fetchedObjects.compactMap({ $0.value(forKey: self.managedObjectIdKeyPath) as? NSObject }).contains($0.id.value as! NSObject) }).forEach { dittoDocument in
                    txn[self.collection].findByID(dittoDocument.id).remove()
                }

            fetchedObjects
                .filter({ !initialDocs.compactMap({ $0.id.value as? NSObject }).contains($0.value(forKey: self.managedObjectIdKeyPath) as! NSObject) }).forEach { managedObject in
                    try! txn[self.collection].insert(managedObject.asDittoDictionary(managedObjectIdKeyPath: self.managedObjectIdKeyPath))
                }

            fetchedObjects.forEach { managedObject in
                guard let doc = initialDocs.first(where: { $0.id.value as? NSObject == managedObject.value(forKey: self.managedObjectIdKeyPath) as? NSObject }) else { return }

                txn[self.collection].findByID(doc.id).update { doc in
                    guard let doc = doc else { return }
                    let dict = managedObject.valuesWithoutId(managedObjectIdKeyPath: self.managedObjectIdKeyPath)
                    doc.value.keys.filter({ !dict.keys.contains($0) }).forEach { key in
                        doc[key].remove()
                    }
                    dict.forEach { key, val in
                        doc[key].set(val)
                    }
                }
            }
        }

        // do the initial update to the delegate or callback
        delegate?.snapshot(snapshot: self.snapshot)
        liveSnapshot?(self.snapshot)

        liveQuery = pendingCursorOperation.observe(eventHandler: { [weak self] newDocs, event in
            guard let `self` = self else { return }
            switch event {
            case.update(let info):

                info.insertions.map({ newDocs[$0] }).forEach { doc in
                    let managedObject = T(context: self.fetchedResultsController.managedObjectContext)
                    doc.value.forEach { k, v in
                        if k == "_id" {
                            managedObject.setValue(v, forKey: self.managedObjectIdKeyPath)
                        } else {
                            managedObject.setValue(v, forKey: k)
                        }
                    }
                    self.fetchedResultsController.managedObjectContext.insert(managedObject)
                }

                info.updates.map({ newDocs[$0] }).forEach { doc in
                    guard let managedObject = self.fetchedResultsController.fetchedObjects?.first(where: { managedObject in
                        managedObject.value(forKey: self.managedObjectIdKeyPath) as? NSObject == doc.id.value as? NSObject
                    }) else { return }

                    doc.value.forEach { k, v in
                        if k == "_id" {
                            // we need to map the document `_id` to the configured `managedObjectIdKeyPath`
                            managedObject.setValue(v, forKey: self.managedObjectIdKeyPath)
                        } else {
                            // we need to map value to managedObject's key value path
                            managedObject.setValue(v, forKey: k)
                        }
                    }
                    try? self.fetchedResultsController.managedObjectContext.save()
                }
                // ditto wants to delete an object from core data
                info.deletions.map({ info.oldDocuments[$0] }).forEach { doc in
                    guard let objectToDelete = (self.fetchedResultsController.fetchedObjects ?? []).first(where: { $0.value(forKey: self.managedObjectIdKeyPath) as? NSObject == doc.id.value as? NSObject }) else { return }
                    self.fetchedResultsController.managedObjectContext.delete(objectToDelete)
                }
            default:
                // We probably want to handle the `initial` event to, if we want full bi-directional sync
                return
            }
            self.delegate?.snapshot(snapshot: self.snapshot)
            self.liveSnapshot?(self.snapshot)
        })
    }

    public func stop() {
        liveQuery?.stop()
        fetchedResultsController.delegate = nil
    }

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
            let dict = managedObject.asDittoDictionary(managedObjectIdKeyPath: managedObjectIdKeyPath)
            try! self.ditto.store[collection].insert(dict)
        case .delete:
            guard let id = managedObject.value(forKey: managedObjectIdKeyPath) else { return }
            self.ditto.store[collection].findByID(id).remove()
        case .update:
            guard let id = managedObject.value(forKey: managedObjectIdKeyPath) else { return }
            self.ditto.store[collection].findByID(id).update { doc in
                guard let doc = doc else { return }
                let dict = managedObject.valuesWithoutId(managedObjectIdKeyPath: self.managedObjectIdKeyPath)
                dict.forEach { (k, v) in
                    if !doc.value.keys.contains(k) && k != "_id" {
                        doc[k].remove()
                    } else {
                        if doc.value[k] as? NSObject != v as? NSObject {
                            doc[k].set(v)
                        }
                    }
                }
            }
        default:
            break
        }
        self.delegate?.snapshot(snapshot: self.snapshot)
        self.liveSnapshot?(self.snapshot)
    }
}
