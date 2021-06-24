import DittoSwift
import CoreData

extension DittoDocument: Equatable {
    public static func == (lhs: DittoDocument, rhs: DittoDocument) -> Bool {
        return NSDictionary(dictionary: lhs.value as [AnyHashable : Any]).isEqual(to: rhs.value as [AnyHashable : Any])
    }
}

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

    func isEqual(to dittoDocument: DittoDocument, managedObjectIdKeyPath: String) -> Bool {
        return NSDictionary(dictionary: dittoDocument.value as [AnyHashable : Any])
            .isEqual(to: self.asDittoDictionary(managedObjectIdKeyPath: managedObjectIdKeyPath))
    }
}

public class CoreDataDitto<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {

    var liveQuery: DittoLiveQuery?

    let ditto: Ditto
    let collection: String
    let pendingCursorOperation: DittoPendingCursorOperation

    let fetchRequest: NSFetchRequest<T>
    public let fetchedResultsController: NSFetchedResultsController<T>
    let managedObjectIdKeyPath: String

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
            let sort = NSSortDescriptor(key: managedObjectIdKeyPath, ascending: false)
            self.fetchRequest.sortDescriptors = [sort]
        }
        self.managedObjectIdKeyPath = managedObjectIdKeyPath
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: self.fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    }

    public func start() throws {
        try matchCoreDataToDitto()
    }

    private func matchCoreDataToDitto() throws {
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

        liveQuery = pendingCursorOperation.observe(eventHandler: { newDocs, event in
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
                            managedObject.setValue(v, forKey: self.managedObjectIdKeyPath)
                        } else {
                            managedObject.setValue(v, forKey: k)
                        }
                    }
                }
                // ditto wants to delete an object from core data
                info.deletions.map({ info.oldDocuments[$0] }).forEach { doc in
                    guard let objectToDelete = (self.fetchedResultsController.fetchedObjects ?? []).first(where: { $0.value(forKey: self.managedObjectIdKeyPath) as? NSObject == doc.id.value as? NSObject }) else { return }
                    self.fetchedResultsController.managedObjectContext.delete(objectToDelete)
                }
            default:
                return
            }
            try! self.fetchedResultsController.managedObjectContext.save()
        })
    }

    public func stop() {
        liveQuery?.stop()
    }

    deinit {
        liveQuery?.stop()
    }


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
                doc.value.keys.filter({ !dict.keys.contains($0) }).forEach { key in
                    doc[key].remove()
                }
                dict.forEach { (k, v) in
                    doc[k].set(v)
                }
            }
        default:
            return
        }
    }
}
