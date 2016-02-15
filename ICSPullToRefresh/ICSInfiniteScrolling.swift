//
//  ICSInfiniteScrolling.swift
//  ICSPullToRefresh
//
//  Created by LEI on 3/17/15.
//  Copyright (c) 2015 TouchingAPP. All rights reserved.
//

import UIKit

private var infiniteScrollingViewKey: Void?
private let observeKeyContentOffset = "contentOffset"
private let observeKeyContentSize = "contentSize"
private let observeKeyContentInset = "contentInset"

private let ICSInfiniteScrollingViewHeight: CGFloat = 60

public extension UIScrollView{
    
    public var infiniteScrollingView: InfiniteScrollingView? {
        get {
            return objc_getAssociatedObject(self, &infiniteScrollingViewKey) as? InfiniteScrollingView
        }
        set(newValue) {
            self.willChangeValueForKey("ICSInfiniteScrollingView")
            objc_setAssociatedObject(self, &infiniteScrollingViewKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            self.didChangeValueForKey("ICSInfiniteScrollingView")
        }
    }
    
    public var showsInfiniteScrolling: Bool {
        return infiniteScrollingView != nil ? infiniteScrollingView!.hidden : false
    }
    
    public func addInfiniteScrollingWithHandler(actionHandler: ActionHandler){
        if infiniteScrollingView == nil {
            infiniteScrollingView = InfiniteScrollingView(frame: CGRect(x: CGFloat(0), y: contentSize.height, width: self.bounds.width, height: ICSInfiniteScrollingViewHeight))
            addSubview(infiniteScrollingView!)
            infiniteScrollingView?.scrollViewOriginContentBottomInset = contentInset.bottom
        }
        infiniteScrollingView?.actionHandler = actionHandler
        setShowsInfiniteScrolling(true)
    }
    
    public func triggerInfiniteScrolling() {
        infiniteScrollingView?.state = .Triggered
        infiniteScrollingView?.startAnimating()
    }
    
    public func setShowsInfiniteScrolling(showsInfiniteScrolling: Bool) {
        if infiniteScrollingView == nil {
            return
        }
        infiniteScrollingView!.hidden = !showsInfiniteScrolling
        if showsInfiniteScrolling{
            addInfiniteScrollingViewObservers()
        }else{
            removeInfiniteScrollingViewObservers()
            infiniteScrollingView!.setNeedsLayout()
            infiniteScrollingView!.frame = CGRect(x: CGFloat(0), y: contentSize.height, width: infiniteScrollingView!.bounds.width, height: ICSInfiniteScrollingViewHeight)
        }
    }
    
    func addInfiniteScrollingViewObservers() {
        if infiniteScrollingView != nil && !infiniteScrollingView!.isObserving {
            addObserver(infiniteScrollingView!, forKeyPath: observeKeyContentOffset, options:.New, context: nil)
            addObserver(infiniteScrollingView!, forKeyPath: observeKeyContentSize, options:.New, context: nil)
            infiniteScrollingView!.isObserving = true
        }
    }
    
    func removeInfiniteScrollingViewObservers() {
        if infiniteScrollingView != nil && infiniteScrollingView!.isObserving {
            removeObserver(infiniteScrollingView!, forKeyPath: observeKeyContentOffset)
            removeObserver(infiniteScrollingView!, forKeyPath: observeKeyContentSize)
            infiniteScrollingView!.isObserving = false
        }
    }
    
}

public class InfiniteScrollingView: UIView {
    public var actionHandler: ActionHandler?
    public var isObserving: Bool = false
    
    public var scrollView: UIScrollView? {
        return self.superview as? UIScrollView
    }
    
    public var scrollViewOriginContentBottomInset: CGFloat = 0
    
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
                    setScrollViewContentInsetForInfiniteScrolling()
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
        state = .Loading
    }
    
    public func stopAnimating() {
        state = .Stopped
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == observeKeyContentOffset {
            srollViewDidScroll(change?[NSKeyValueChangeNewKey]?.CGPointValue)
        } else if keyPath == observeKeyContentSize {
            setNeedsLayout()
            if let _ = change?[NSKeyValueChangeNewKey]?.CGPointValue {
                self.frame = CGRect(x: CGFloat(0), y: scrollView!.contentSize.height, width: self.bounds.width, height: ICSInfiniteScrollingViewHeight)
            }
        }
    }
    
    private func srollViewDidScroll(contentOffset: CGPoint?) {
        if scrollView == nil || contentOffset == nil{
            return
        }
        if state != .Loading {
            let scrollViewContentHeight = scrollView!.contentSize.height
            var scrollOffsetThreshold = scrollViewContentHeight - scrollView!.bounds.height + 40
            if (scrollViewContentHeight < self.scrollView!.bounds.height) {
                scrollOffsetThreshold = 40 - self.scrollView!.contentInset.top
            }

            activityIndicator.hidesWhenStopped = !(
                scrollView!.dragging &&
                scrollViewContentHeight > self.scrollView!.bounds.height
            )

            if !scrollView!.dragging && state == .Triggered {
                state = .Loading
            } else if contentOffset!.y > scrollOffsetThreshold && state == .Stopped && scrollView!.dragging {
                state = .Triggered
            } else if contentOffset!.y < scrollOffsetThreshold && state != .Stopped {
                state == .Stopped
            }
        }
    }
    
    private func setScrollViewContentInset(contentInset: UIEdgeInsets) {
        UIView.animateWithDuration(0.3, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: { () -> Void in
            self.scrollView?.contentInset = contentInset
        }, completion: nil)
    }
    
    private func resetScrollViewContentInset() {
        if scrollView == nil {
            return
        }
        var currentInset = scrollView!.contentInset
        currentInset.bottom = scrollViewOriginContentBottomInset
        setScrollViewContentInset(currentInset)
    }
    
    private func setScrollViewContentInsetForInfiniteScrolling() {
        if scrollView == nil {
            return
        }
        var currentInset = scrollView!.contentInset
        currentInset.bottom = scrollViewOriginContentBottomInset + ICSInfiniteScrollingViewHeight
        setScrollViewContentInset(currentInset)
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
            if scrollView?.showsInfiniteScrolling != nil && scrollView!.showsInfiniteScrolling{
                scrollView?.removeInfiniteScrollingViewObservers()
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
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()

    public func setActivityIndicatorColor(color: UIColor) {
        activityIndicator.color = color
    }

    public func setActivityIndicatorStyle(style: UIActivityIndicatorViewStyle) {
        activityIndicator.activityIndicatorViewStyle = style
    }
    
}