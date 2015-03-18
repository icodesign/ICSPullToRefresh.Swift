//
//  ViewController.swift
//  ICSPullToRefreshDemo
//
//  Created by LEI on 3/15/15.
//  Copyright (c) 2015 TouchingAPP. All rights reserved.
//

import UIKit
import ICSPullToRefresh

class ViewController: UITableViewController, UITableViewDataSource {
    
//    lazy var tableView: UITableView = { [unowned self] in
//        let tableView = UITableView(frame: self.view.bounds, style: .Plain)
//        return tableView
//    }()
    
    var k = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        view.addSubview(tableView)
        tableView.dataSource = self
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        tableView.addPullToFreshHandler {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                sleep(3)
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    tableView.pullToRefreshView?.stopAnimating()
                })
            })
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (Int64) (1 * NSEC_PER_SEC) ), dispatch_get_main_queue()) { () -> Void in
            self.tableView.triggerPullToRefresh()
        }
        
        tableView.addInfiniteScrollingWithActionHandler {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                sleep(3)
                dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                    
                    self.k += 1
                    self.tableView.reloadData()
                    self.tableView.infiniteScrollingView?.stopAnimating()
                })
            })
        }

    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10 + 4 * k
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let identifier = "cell"
        var cell = tableView.dequeueReusableCellWithIdentifier(identifier) as? UITableViewCell
        if cell == nil{
            cell = UITableViewCell(style: .Value1, reuseIdentifier: identifier)
        }
        cell!.textLabel?.text = "Test"
        return cell!
    }


}

