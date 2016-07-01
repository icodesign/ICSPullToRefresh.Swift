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
public typealias ActionHandler = () -> Void

public extension UIScrollView {
    public var pullToRefreshView: PullToRefreshView? {
        get {
            return objc_getAssociatedObject(self, &pullToRefreshViewKey) as? PullToRefreshView
        }
        set {
            willChangeValueForKey("ICSPullToRefreshView")
            objc_setAssociatedObject(self, &pullToRefreshViewKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
            didChangeValueForKey("ICSPullToRefreshView")
        }
    }

    public func addPullToRefreshHandler(actionHandler: ActionHandler) {
        if pullToRefreshView == nil {
            pullToRefreshView = PullToRefreshView(frame: CGRect(x: 0, y: -ICSPullToRefreshViewHeight, width: bounds.width, height: ICSPullToRefreshViewHeight))
            addSubview(pullToRefreshView!)
            pullToRefreshView?.autoresizingMask = .FlexibleWidth
            pullToRefreshView?.scrollViewOriginContentTopInset = contentInset.top
        }
        pullToRefreshView?.actionHandler = actionHandler
        showsPullToRefresh = true
    }

    public func triggerPullToRefresh() {
        pullToRefreshView?.state = .Triggered
        pullToRefreshView?.startAnimating()
    }

    public var showsPullToRefresh: Bool {
        get { return pullToRefreshView?.hidden ?? false }
        set {
            guard let pullToRefreshView = pullToRefreshView else { return }

            pullToRefreshView.hidden = !newValue

            if newValue {
                addPullToRefreshObservers()
            } else {
                removePullToRefreshObservers()
            }
        }
    }

    private func addPullToRefreshObservers() {
        guard let pullToRefreshView = pullToRefreshView where !pullToRefreshView.isObserving else { return }

        addObserver(pullToRefreshView, forKeyPath: observeKeyContentOffset, options: .New, context: nil)
        addObserver(pullToRefreshView, forKeyPath: observeKeyFrame, options: .New, context: nil)
        pullToRefreshView.isObserving = true
    }

    private func removePullToRefreshObservers() {
        guard let pullToRefreshView = pullToRefreshView where pullToRefreshView.isObserving else { return }

        removeObserver(pullToRefreshView, forKeyPath: observeKeyContentOffset)
        removeObserver(pullToRefreshView, forKeyPath: observeKeyFrame)
        pullToRefreshView.isObserving = false
    }
}

public class PullToRefreshView: UIView {
    private lazy var defaultView = UIView()
    private var triggeredByUser = false
    public var actionHandler: ActionHandler?
    public var isObserving = false
    public var scrollView: UIScrollView? {
        return superview as? UIScrollView
    }

    public lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        activityIndicator.hidesWhenStopped = false
        return activityIndicator
    }()

    public var scrollViewOriginContentTopInset: CGFloat = 0

    public enum State {
        case Stopped
        case Triggered
        case Loading
        case All
    }

    public var state: State = .Stopped {
        willSet {
            guard state != newValue else { return }
            setNeedsLayout()

            if case .Loading = newValue {
                setScrollViewContentInsetForLoading()
                if state == .Triggered {
                    actionHandler?()
                }
            }
        }
        didSet {
            if case .Stopped = state {
                resetScrollViewContentInset()
            }
        }
    }

    // MARK: Init Methods

    public convenience init() {
        self.init(frame: .zero)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        addSubview(defaultView)
        defaultView.addSubview(activityIndicator)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        defaultView.frame = bounds
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
        guard newSuperview == nil else { return }
        scrollView?.removePullToRefreshObservers()
    }

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == observeKeyContentOffset {
            scrollViewDidScroll(change?[NSKeyValueChangeNewKey]?.CGPointValue)
        } else if keyPath == observeKeyFrame {
            setNeedsLayout()
        }
    }

    public func startAnimating() {
        guard let scrollView = scrollView else { return }

        animate {
            scrollView.contentOffset.y = -(scrollView.contentInset.top + self.bounds.height)
        }

        triggeredByUser = true
        state = .Loading
    }

    public func stopAnimating() {
        state = .Stopped

        guard let scrollView = scrollView where triggeredByUser else { return }

        animate {
            scrollView.setContentOffset(CGPoint(
                x: scrollView.contentOffset.x,
                y: -scrollView.contentInset.top
            ), animated: false)
        }
    }

    private func scrollViewDidScroll(contentOffset: CGPoint?) {
        guard let contentOffset = contentOffset, scrollView = scrollView where state != .Loading else {
            return
        }

        let scrollOffsetThreshold = frame.origin.y - scrollViewOriginContentTopInset

        if !scrollView.dragging && state == .Triggered {
            state = .Loading
        } else if contentOffset.y < scrollOffsetThreshold && scrollView.dragging && state == .Stopped {
            state = .Triggered
        } else if contentOffset.y >= scrollOffsetThreshold && state != .Stopped {
            state == .Stopped
        }
    }

    private func setScrollViewContentInset(contentInset: UIEdgeInsets) {
        animate {
            self.scrollView?.contentInset = contentInset
        }
    }

    private func resetScrollViewContentInset() {
        guard let scrollView = scrollView else { return }

        var currentInset = scrollView.contentInset
        currentInset.top = scrollViewOriginContentTopInset
        setScrollViewContentInset(currentInset)
    }

    private func setScrollViewContentInsetForLoading() {
        guard let scrollView = scrollView else { return }

        let offset = max(scrollView.contentOffset.y * -1, 0)
        var currentInset = scrollView.contentInset
        currentInset.top = min(offset, scrollViewOriginContentTopInset + bounds.height)
        setScrollViewContentInset(currentInset)
    }

    // MARK: Helpers

    private func animate(animations: () -> Void) {
        UIView.animateWithDuration(0.3,
            delay: 0,
            options: [.AllowUserInteraction, .BeginFromCurrentState],
            animations: animations
        ) { _ in
            self.setNeedsLayout()
        }
    }
}
