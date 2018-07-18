//
//  ViewController.swift
//  ICSPullToRefreshDemo
//
//  Created by LEI on 3/15/15.
//  Copyright (c) 2015 TouchingAPP. All rights reserved.
//

import UIKit
import ICSPullToRefresh

class ViewController: UITableViewController {
    
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.addPullToRefreshHandler { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async{
                sleep(3)
                self?.k = 0;
                DispatchQueue.main.async {
                    self?.tableView.pullToRefreshView?.stopAnimating()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double((Int64) (1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) { () -> Void in
            self.tableView.triggerPullToRefresh()
        }
        
        tableView.addInfiniteScrollingWithHandler { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                sleep(3)
                DispatchQueue.main.async {
                    
                    self?.k += 1
                    self?.tableView.reloadData()
                    self?.tableView.infiniteScrollingView?.stopAnimating()
                }
            }
        }

    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10 + 4 * k
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "cell"
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        if cell == nil{
            cell = UITableViewCell(style: .value1, reuseIdentifier: identifier)
        }
        cell!.textLabel?.text = "Test"
        return cell!
    }


}

