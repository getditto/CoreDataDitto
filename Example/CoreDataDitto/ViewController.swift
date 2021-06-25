//
//  ViewController.swift
//  CoreDataDitto
//
//  Created by 2183729 on 06/23/2021.
//  Copyright (c) 2021 2183729. All rights reserved.
//

import UIKit
import Fakery
import CoreData
import DittoSwift
import CoreDataDitto

class ViewController: UIViewController {

    let tableView = UITableView()
    var tasks = [Task]()

    var coreDataDitto: CoreDataDitto<Task>!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "CoreDataDitto"
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self

        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        let ditto = AppDelegate.ditto
        let pendingCursor = ditto!.store["tasks"].findAll()
        coreDataDitto = CoreDataDitto(ditto: AppDelegate.ditto, collection: "tasks", pendingCursorOperation: pendingCursor, fetchRequest: fetchRequest, context: AppDelegate.persistentContainer.viewContext, managedObjectIdKeyPath: "id")

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addRandomBarButtonDidClick))

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearButtonDidClick))

        try! coreDataDitto.startSync()
        coreDataDitto.liveSnapshot = { [weak self] (snapshot) in
            guard let `self` = self else { return }
            self.tasks = snapshot.managedObjects
            self.tableView.reloadData()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = self.view.frame
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func addRandomBarButtonDidClick() {
        let task = Task(context: coreDataDitto.managedObjectContext)
        task.id = UUID().uuidString
        task.body = Faker().lorem.sentence()
        task.isDone = false
    }

    @objc func clearButtonDidClick(sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if UIDevice.current.userInterfaceIdiom == .pad {
            alertController.popoverPresentationController?.barButtonItem = sender
        }

        alertController.addAction(UIAlertAction(title: "Delete Ditto", style: .default, handler: { _ in
            AppDelegate.ditto.store["tasks"].findAll().remove()
        }))

        alertController.addAction(UIAlertAction(title: "Delete CoreData", style: .default, handler: { _ in
            self.tasks.forEach { task in
                self.coreDataDitto.managedObjectContext.delete(task)
            }
        }))

        alertController.addAction(UIAlertAction(title: "Delete Both", style: .destructive, handler: { _ in
            AppDelegate.ditto.store["tasks"].findAll().remove()
            self.tasks.forEach { task in
                self.coreDataDitto.managedObjectContext.delete(task)
            }
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(alertController, animated: true, completion: nil)
    }

}

extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let task = tasks[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = task.body
        cell.imageView?.image = task.isDone ? UIImage(named: "box_checked") : UIImage(named: "box_empty")
        return cell
    }

}

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let task = tasks[indexPath.row]
        task.isDone = !task.isDone
        try! task.managedObjectContext?.save()
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let task = tasks[indexPath.row]
        coreDataDitto.managedObjectContext.delete(task)
    }

}
