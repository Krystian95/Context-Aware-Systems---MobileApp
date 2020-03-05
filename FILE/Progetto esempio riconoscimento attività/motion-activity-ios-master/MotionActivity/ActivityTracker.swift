//
//  ActivityTracker.swift
//  MotionActivity
//
//  Created by yhashimoto on 2019/06/26.
//  Copyright © 2019 yhashimoto. All rights reserved.
//

import Foundation
import CoreMotion

protocol ActivityTrackerDelegate: class {
    func activityTracker(_ sender: ActivityTracker, didUpdateActivity activity: Activity)
}
final class ActivityTracker {
    private let manager = CMMotionManager()

    private let activityManager = CMMotionActivityManager()

    weak var delegate: ActivityTrackerDelegate?

    init(delegate: ActivityTrackerDelegate? = nil) {
        self.delegate = delegate
    }

    func start() {
        DispatchQueue.global().async {
            self.activityManager.startActivityUpdates(to: OperationQueue()) { [weak self] motionActivity in
                guard let `self` = self else { return }
                guard let motionActivity = motionActivity else {
                    self.delegate?.activityTracker(self, didUpdateActivity: Activity(type: .unknown, startDate: Date()))
                    return
                }
                
                print("Prova")
                let type: ActivityType
                if motionActivity.stationary {
                    type = .stationary
                    print("User stationary")
                } else if motionActivity.walking {
                    type = .walking
                    print("User walking")
                } else if motionActivity.running {
                    type = .running
                    print("User running")
                } else if motionActivity.automotive {
                    type = .automotive
                    print("User automotive")
                } else if motionActivity.cycling {
                    type = .cycling
                    print("User cycling")
                } else {
                    type = .unknown
                    print("User unknown")
                }

                let activity = Activity(type: type, startDate: motionActivity.startDate)
                self.delegate?.activityTracker(self, didUpdateActivity: activity)
            }

        }
    }
}
