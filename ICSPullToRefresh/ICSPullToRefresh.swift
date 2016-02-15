//
//  ICSPullToRefresh.swift
//  ICSPullToRefresh
//
//  Created by LEI on 3/15/15.
//  Copyright (c) 2015 TouchingAPP. All rights reserved.
//

import UIKit

private var pullToRefreshViewKey: Void?
private let observeKeyContentOffset = "contentOffset"
private let observeKeyFrame = "frame"

private let ICSPullToRefreshViewHeight: CGFloat = 60

public typealias ActionHandler = () -> ()

public extension UIScrollView{
    
    public var pullToRefreshView: PullToRefreshView? {
        get {
            return objc_getAssociatedObject(self, &pullToRefreshViewKey) as? PullToRefreshView
        }
        set(newValue) {
            self.willChangeValueForKey("ICSPullToRefreshView")
            objc_setAssociatedObject(self, &pullToRefreshViewKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            self.didChangeValueForKey("ICSPullToRefreshView")
        }
    }
    
    public var showsPullToRefresh: Bool {
        return pullToRefreshView != nil ? pullToRefreshView!.hidden : false
    }
    
    public func addPullToRefreshHandler(actionHandler: ActionHandler){
        if pullToRefreshView == nil {
            pullToRefreshView = PullToRefreshView(frame: CGRect(x: CGFloat(0), y: -ICSPullToRefreshViewHeight, width: self.bounds.width, height: ICSPullToRefreshViewHeight))
            addSubview(pullToRefreshView!)
            pullToRefreshView?.scrollViewOriginContentTopInset = contentInset.top
        }
        pullToRefreshView?.actionHandler = actionHandler
        setShowsPullToRefresh(true)
    }
    
    public func triggerPullToRefresh() {
        pullToRefreshView?.state = .Triggered
        pullToRefreshView?.startAnimating()
    }
    
    public func setShowsPullToRefresh(showsPullToRefresh: Bool) {
        if pullToRefreshView == nil {
            return
        }
        pullToRefreshView!.hidden = !showsPullToRefresh
        if showsPullToRefresh{
            addPullToRefreshObservers()
        }else{
            removePullToRefreshObservers()
        }
    }
    
    func addPullToRefreshObservers() {
        if pullToRefreshView?.isObserving != nil && !pullToRefreshView!.isObserving{
            addObserver(pullToRefreshView!, forKeyPath: observeKeyContentOffset, options:.New, context: nil)
            addObserver(pullToRefreshView!, forKeyPath: observeKeyFrame, options:.New, context: nil)
            pullToRefreshView!.isObserving = true
        }
    }
    
    func removePullToRefreshObservers() {
        if pullToRefreshView?.isObserving != nil && pullToRefreshView!.isObserving{
            removeObserver(pullToRefreshView!, forKeyPath: observeKeyContentOffset)
            removeObserver(pullToRefreshView!, forKeyPath: observeKeyFrame)
            pullToRefreshView!.isObserving = false
        }
    }

    
}

public class PullToRefreshView: UIView {
    public var actionHandler: ActionHandler?
    public var isObserving: Bool = false
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
        didSet {
            switch state {
            case .Stopped:
                resetScrollViewContentInset()
                
            default:
                break
            }
        }
    }
    
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        initViews()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initViews()
    }
    
    public func startAnimating() {
        if scrollView == nil {
            return
        }

        animate {
            self.scrollView?.setContentOffset(CGPoint(
                x: self.scrollView!.contentOffset.x,
                y: -(self.scrollView!.contentInset.top + self.bounds.height)
            ), animated: false)
        }

        triggeredByUser = true
        state = .Loading
    }
    
    public func stopAnimating() {
        state = .Stopped
        if triggeredByUser {
            animate {
                self.scrollView?.setContentOffset(CGPoint(
                    x: self.scrollView!.contentOffset.x,
                    y: -self.scrollView!.contentInset.top
                ), animated: false)
            }
        }
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == observeKeyContentOffset {
            srollViewDidScroll(change?[NSKeyValueChangeNewKey]?.CGPointValue)
        } else if keyPath == observeKeyFrame {
            setNeedsLayout()
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
        animate {
            self.scrollView?.contentInset = contentInset
        }
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

    private func animate(animations: () -> ()) {
        UIView.animateWithDuration(0.3,
            delay: 0,
            options: [.AllowUserInteraction, .BeginFromCurrentState],
            animations: animations
        ) { _ in
            self.setNeedsLayout()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
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
            if scrollView?.showsPullToRefresh != nil && scrollView!.showsPullToRefresh{
                scrollView?.removePullToRefreshObservers()
            }
        }
    }
    
    // MARK: Basic Views
    
    func initViews() {
        addSubview(defaultView)
        defaultView.addSubview(activityIndicator)
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

    public func setActivityIndicatorColor(color: UIColor) {
        activityIndicator.color = color
    }

    public func setActivityIndicatorStyle(style: UIActivityIndicatorViewStyle) {
        activityIndicator.activityIndicatorViewStyle = style
    }
    
}