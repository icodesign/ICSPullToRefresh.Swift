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
            self.willChangeValue(forKey: "ICSPullToRefreshView")
            objc_setAssociatedObject(self, &pullToRefreshViewKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            self.didChangeValue(forKey: "ICSPullToRefreshView")
        }
    }
    
    public var showsPullToRefresh: Bool {
        return pullToRefreshView != nil ? pullToRefreshView!.isHidden : false
    }
    
    public func addPullToRefreshHandler(_ actionHandler: @escaping ActionHandler){
        if pullToRefreshView == nil {
            pullToRefreshView = PullToRefreshView(frame: CGRect(x: CGFloat(0), y: -ICSPullToRefreshViewHeight, width: self.bounds.width, height: ICSPullToRefreshViewHeight))
            addSubview(pullToRefreshView!)
            pullToRefreshView?.autoresizingMask = .flexibleWidth
            pullToRefreshView?.scrollViewOriginContentTopInset = contentInset.top
        }
        pullToRefreshView?.actionHandler = actionHandler
        setShowsPullToRefresh(true)
    }
    
    public func triggerPullToRefresh() {
        pullToRefreshView?.state = .triggered
        pullToRefreshView?.startAnimating()
    }
    
    public func setShowsPullToRefresh(_ showsPullToRefresh: Bool) {
        if pullToRefreshView == nil {
            return
        }
        pullToRefreshView!.isHidden = !showsPullToRefresh
        if showsPullToRefresh{
            addPullToRefreshObservers()
        }else{
            removePullToRefreshObservers()
        }
    }
    
    func addPullToRefreshObservers() {
        if pullToRefreshView?.isObserving != nil && !pullToRefreshView!.isObserving{
            addObserver(pullToRefreshView!, forKeyPath: observeKeyContentOffset, options:.new, context: nil)
            addObserver(pullToRefreshView!, forKeyPath: observeKeyFrame, options:.new, context: nil)
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

open class PullToRefreshView: UIView {
    open var actionHandler: ActionHandler?
    open var isObserving: Bool = false
    var triggeredByUser: Bool = false
    
    open var scrollView: UIScrollView? {
        return self.superview as? UIScrollView
    }
    
    open var scrollViewOriginContentTopInset: CGFloat = 0
    
    public enum State {
        case stopped
        case triggered
        case loading
        case all
    }
    
    open var state: State = .stopped {
        willSet {
            if state != newValue {
                self.setNeedsLayout()
                switch newValue{
                case .loading:
                    setScrollViewContentInsetForLoading()
                    if state == .triggered {
                        actionHandler?()
                    }
                default:
                    break
                }
            }
        }
        didSet {
            switch state {
            case .stopped:
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
    
    open func startAnimating() {
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
        state = .loading
    }
    
    open func stopAnimating() {
        state = .stopped
        if triggeredByUser {
            animate {
                self.scrollView?.setContentOffset(CGPoint(
                    x: self.scrollView!.contentOffset.x,
                    y: -self.scrollView!.contentInset.top
                ), animated: false)
            }
        }
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == observeKeyContentOffset {
            srollViewDidScroll((change?[NSKeyValueChangeKey.newKey] as AnyObject).cgPointValue)
        } else if keyPath == observeKeyFrame {
            setNeedsLayout()
        }
    }
    
    fileprivate func srollViewDidScroll(_ contentOffset: CGPoint?) {
        if scrollView == nil || contentOffset == nil{
            return
        }
        if state != .loading {
            let scrollOffsetThreshold = frame.origin.y - scrollViewOriginContentTopInset
            if !scrollView!.isDragging && state == .triggered {
                state = .loading
            } else if contentOffset!.y < scrollOffsetThreshold && scrollView!.isDragging && state == .stopped {
                state = .triggered
            } else if contentOffset!.y >= scrollOffsetThreshold && state != .stopped {
                state == .stopped
            }
        }
    }
    
    fileprivate func setScrollViewContentInset(_ contentInset: UIEdgeInsets) {
        animate {
            self.scrollView?.contentInset = contentInset
        }
    }
    
    fileprivate func resetScrollViewContentInset() {
        if scrollView == nil {
            return
        }
        var currentInset = scrollView!.contentInset
        currentInset.top = scrollViewOriginContentTopInset
        setScrollViewContentInset(currentInset)
    }
    
    fileprivate func setScrollViewContentInsetForLoading() {
        if scrollView == nil {
            return
        }
        let offset = max(scrollView!.contentOffset.y * -1, 0)
        var currentInset = scrollView!.contentInset
        currentInset.top = min(offset, scrollViewOriginContentTopInset + bounds.height)
        setScrollViewContentInset(currentInset)
    }

    fileprivate func animate(_ animations: @escaping () -> ()) {
        UIView.animate(withDuration: 0.3,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: animations
        ) { _ in
            self.setNeedsLayout()
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        defaultView.frame = self.bounds
        activityIndicator.center = defaultView.center
        switch state {
        case .stopped:
            activityIndicator.stopAnimating()
        case .loading:
            activityIndicator.startAnimating()
        default:
            break
        }
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
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
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        activityIndicator.hidesWhenStopped = false
        return activityIndicator
    }()

    open func setActivityIndicatorColor(_ color: UIColor) {
        activityIndicator.color = color
    }

    open func setActivityIndicatorStyle(_ style: UIActivityIndicatorViewStyle) {
        activityIndicator.activityIndicatorViewStyle = style
    }
    
}
