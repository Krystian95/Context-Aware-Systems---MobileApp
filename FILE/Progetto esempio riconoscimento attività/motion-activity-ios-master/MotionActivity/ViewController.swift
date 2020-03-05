//
//  ViewController.swift
//  MotionActivity
//
//  Created by yhashimoto on 2019/06/26.
//  Copyright © 2019 yhashimoto. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {

    var activities: [Activity] = []
    var activityTracker: ActivityTracker!

    lazy var dateFormatter: DateFormatter = { [unowned self] in
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .long
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        activityTracker = ActivityTracker(delegate: self)
        activityTracker.start()
    }

    private func append(activity: Activity) {
        DispatchQueue.main.sync {
            self.activities.append(activity)
            self.tableView.reloadData()
        }
    }
}


// MARK: UITableViewController

extension ViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return activities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let activity = activities[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else { fatalError() }
        cell.textLabel?.text = activity.type.rawValue
        cell.detailTextLabel?.text = dateFormatter.string(from: activity.startDate)
        return cell
    }
}

extension ViewController: ActivityTrackerDelegate {
    func activityTracker(_ sender: ActivityTracker, didUpdateActivity activity: Activity) {
        append(activity: activity)
    }
}
