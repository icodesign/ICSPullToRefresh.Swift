//
//  ICSPullToRefresh.swift
//  ICSPullToRefresh
//
//  Created by LEI on 3/15/15.
//  Copyright (c) 2015 TouchingAPP. All rights reserved.
//

import Foundation

private var pullToRefreshViewKey: Void?
private let observeKeyContentOffset = "contentOffset"
private let observeKeyFrame = "frame"
private let observeKeyContentInset = "contentInset"


private let ICSPullToRefreshViewHeight: CGFloat = 60

private var myContext = 0

public typealias ActionHandler = () -> ()

public extension UIScrollView{
    
    public var pullToRefreshView: PullToRefreshView? {
        get {
            return objc_getAssociatedObject(self, &pullToRefreshViewKey) as? PullToRefreshView
        }
        set(newValue) {
            objc_setAssociatedObject(self, &pullToRefreshViewKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
        }
    }
    
    public var showsPullToRefresh: Bool {
        return pullToRefreshView != nil ? pullToRefreshView!.hidden : false
    }
    
    public func addPullToFreshHandler(actionHandler: ActionHandler){
        if pullToRefreshView == nil {
            pullToRefreshView = PullToRefreshView(frame: CGRect(x: CGFloat(0), y: -ICSPullToRefreshViewHeight, width: self.bounds.width, height: ICSPullToRefreshViewHeight))
            addSubview(pullToRefreshView!)
        }
        pullToRefreshView?.actionHandler = actionHandler
        pullToRefreshView?.scrollViewOriginContentTopInset = contentInset.top
        setShowsPullToRefresh(true)
    }
    
    public func triggerPullToRefresh() {
        pullToRefreshView?.state = .Triggered
        pullToRefreshView?.startAnimating()
    }
    
    public func setShowsPullToRefresh(showsToPullToRefresh: Bool) {
        if pullToRefreshView == nil {
            return
        }
        pullToRefreshView!.hidden = !showsToPullToRefresh
        if showsToPullToRefresh{
            if !pullToRefreshView!.isObserving{
                addPullToRefreshObservers()
            }
        }else{
            if pullToRefreshView!.isObserving{
                removePullToRefreshObservers()
            }
        }
    }
    
    func addPullToRefreshObservers() {
        addObserver(pullToRefreshView!, forKeyPath: observeKeyContentOffset, options:.New, context: nil)
        addObserver(pullToRefreshView!, forKeyPath: observeKeyFrame, options:.New, context: nil)
        addContentInsetObserver()
        pullToRefreshView!.isObserving = true
    }
    
    func removePullToRefreshObservers() {
        removeObserver(pullToRefreshView!, forKeyPath: observeKeyContentOffset)
        removeObserver(pullToRefreshView!, forKeyPath: observeKeyFrame)
        removeContentInsetObserver()
        pullToRefreshView!.isObserving = false
    }
    
    func addContentInsetObserver(){
        if pullToRefreshView != nil && !pullToRefreshView!.isContentInsetObserving {
            addObserver(pullToRefreshView!, forKeyPath: observeKeyContentInset, options:.New, context: nil)
            pullToRefreshView!.isContentInsetObserving = true
        }
    }
    
    func removeContentInsetObserver(){
        if pullToRefreshView != nil && pullToRefreshView!.isContentInsetObserving {
            removeObserver(pullToRefreshView!, forKeyPath: observeKeyContentInset)
            pullToRefreshView!.isContentInsetObserving = false
        }
    }
    
}

public class PullToRefreshView: UIView {
    public var actionHandler: ActionHandler?
    public var isObserving: Bool = false
    public var isContentInsetObserving: Bool = false
    var triggeredByUser: Bool = false
    
    public var scrollView: UIScrollView? {
        return self.superview as? UIScrollView
    }
    
    public var scrollViewOriginContentTopInset: CGFloat = 0
    
    public enum State {
        case Stopped
        case Triggered
        case Loading
        case All
    }
    
    public var state: State = .Stopped {
        willSet {
            if state != newValue {
                self.setNeedsLayout()
                switch newValue{
                case .Stopped:
                    resetScrollViewContentInset()
                case .Loading:
                    setScrollViewContentInsetForLoading()
                    if state == .Triggered {
                        actionHandler?()
                    }
                default:
                    break
                }
            }
        }
    }
    
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        initViews()
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initViews()
    }
    
    public func startAnimating() {
        if scrollView == nil {
            return
        }
        scrollView?.setContentOffset(CGPoint(x: scrollView!.contentOffset.x, y: -(scrollView!.contentInset.top + bounds.height)), animated: true)
        triggeredByUser = true
        state = .Loading
    }
    
    public func stopAnimating() {
        state = .Stopped
        if triggeredByUser {
            scrollView?.setContentOffset(CGPoint(x: scrollView!.contentOffset.x, y: -scrollView!.contentInset.top), animated: true)
        }
    }
    
    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == observeKeyContentOffset {
            srollViewDidScroll(change[NSKeyValueChangeNewKey]?.CGPointValue())
        } else if keyPath == observeKeyFrame {
            setNeedsLayout()
        } else if keyPath == observeKeyContentInset {
            if let new = change[NSKeyValueChangeNewKey]?.CGPointValue() {
                scrollViewOriginContentTopInset = new.x
            }
        }
    }
    
    private func srollViewDidScroll(contentOffset: CGPoint?) {
        if scrollView == nil || contentOffset == nil{
            return
        }
        if state != .Loading {
            let scrollOffsetThreshold = frame.origin.y - scrollViewOriginContentTopInset
            if !scrollView!.dragging && state == .Triggered {
                state = .Loading
            } else if contentOffset!.y < scrollOffsetThreshold && scrollView!.dragging && state == .Stopped {
                state = .Triggered
            } else if contentOffset!.y >= scrollOffsetThreshold && state != .Stopped {
                state == .Stopped
            }
        }
    }
    
    private func setScrollViewContentInset(contentInset: UIEdgeInsets) {
        scrollView?.removeContentInsetObserver()
        UIView.animateWithDuration(0.3, delay: 0, options: .AllowUserInteraction | .BeginFromCurrentState, animations: { () -> Void in
            scrollView?.contentInset = contentInset
        }, completion: { finished in
            if finished {
                self.scrollView?.addContentInsetObserver()
            }
        })
    }
    
    private func resetScrollViewContentInset() {
        if scrollView == nil {
            return
        }
        var currentInset = scrollView!.contentInset
        currentInset.top = scrollViewOriginContentTopInset
        setScrollViewContentInset(currentInset)
    }
    
    private func setScrollViewContentInsetForLoading() {
        if scrollView == nil {
            return
        }
        let offset = max(scrollView!.contentOffset.y * -1, 0)
        var currentInset = scrollView!.contentInset
        currentInset.top = min(offset, scrollViewOriginContentTopInset + bounds.height)
        setScrollViewContentInset(currentInset)
    }
    
    public override func layoutSubviews() {
        defaultView.frame = self.bounds
        activityIndicator.center = defaultView.center
        switch state {
        case .Stopped:
            activityIndicator.stopAnimating()
        case .Loading:
            activityIndicator.startAnimating()
        default:
            break
        }
    }
    
    public override func willMoveToSuperview(newSuperview: UIView?) {
        if superview != nil && newSuperview == nil {
            if let isShow = scrollView?.showsPullToRefresh {
                if isObserving {
                    scrollView?.removePullToRefreshObservers()
                }
            }
        }
    }
    
    // MARK: Basic Views
    
    func initViews() {
        addSubview(defaultView)
        defaultView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    lazy var defaultView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        activityIndicator.hidesWhenStopped = false
        return activityIndicator
    }()
    
}