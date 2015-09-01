//
//  QMBParallaxScrollViewController.h
//  QMBParallaxScrollViewController
//
//  Based on QMBParallaxScrollViewController created by Toni Möckel on 02.11.13
//  and heavily modified by Robert Böhnke on 02.20.14, then by Pierre Houston on 08.31.2015
//  (if nothing left of the original code, perhaps ok to change copyright)
//  Copyright (c) 2013 Toni Möckel. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const QMBTopControllerRelationshipSegueIdentifier;
extern NSString * const QMBBottomControllerRelationshipSegueIdentifier;

@interface QMBParallaxScrollViewController : UIViewController<UIGestureRecognizerDelegate, UIScrollViewDelegate>

// setup
- (void)setupWithTopViewController:(UIViewController *)topViewController withHeight:(CGFloat)topHeight bottomViewController:(UIViewController *)bottomViewController;

- (void)setupWithBottomViewController:(UIViewController *)bottomViewController withHeight:(CGFloat)bottomHeight topViewController:(UIViewController *)topViewController;

@property (nonatomic, strong, readonly) UIViewController *topViewController;
@property (nonatomic, strong, readonly) UIViewController *bottomViewController;

@property (nonatomic, strong) UIScrollView *observedScrollView; // set automatically if bottom vc's view is a scrollview

// can manage either the top view's height or the bottom view's height, the other will reciprocate
// if setup with one, then setting the other before viewWillAppear: called does nothing
// (currently, controlling height of bottom view never works before viewWillAppear:)

// fixedBackgroundTopView is true if topViewController conforms to QMBParallaxScrollViewParallaxDelegate,
// in which case the top view is always fullscreen and the controller knows how to adjust itself
// when setVisibleTopHeight: called
@property (nonatomic, assign, readonly) BOOL fixedBackgroundTopView;

// use these for controlling the height of the top view

@property (nonatomic, assign) IBInspectable CGFloat topHeight;

- (void)setTopHeight:(CGFloat)topHeight animated:(BOOL)animated;

@property (nonatomic, assign) IBInspectable CGFloat topSnapHeight; // < 0 to not snap to any height
@property (nonatomic, assign) IBInspectable CGFloat topMaxHeight; // < 0 or FLT_MAX to allow full screen
@property (nonatomic, assign) IBInspectable CGFloat topMinHeight; // <= 0 to allow hiding completely

// use these for controlling the height of the bottom view
@property (nonatomic, assign) CGFloat bottomHeight;

- (void)setBottomHeight:(CGFloat)bottomHeight animated:(BOOL)animated;

@property (nonatomic, assign) IBInspectable CGFloat bottomSnapHeight; // < 0 to not snap to any height
@property (nonatomic, assign) IBInspectable CGFloat bottomMinHeight; // <= 0 to allow hiding completely
@property (nonatomic, assign) IBInspectable CGFloat bottomMaxHeight; // < 0 or FLT_MAX to allow fullscreen

// customization
@property (nonatomic, assign) IBInspectable CGFloat snapThreshold; // default 40
@property (nonatomic, assign) IBInspectable NSTimeInterval animationDuration; // default 0.2

@end


@protocol QMBParallaxScrollViewParallaxDelegate <NSObject>
- (void)setVisibleTopHeight:(CGFloat)height;
- (void)startedDraggingParallaxScrollViewAtVisibleTopHeight:(CGFloat)height;
- (void)stoppedDraggingParallaxScrollViewAtVisibleTopHeight:(CGFloat)height;
@end

// if bottom view controller claims to implement this protcol, doesn't change it's (scroll) view's delegate
// it must forward UIScrollViewDelegate methods calls to its parent parallax controller
// (all except for zoom methods, DidEndScrollingAnimation, DidScrollToTop, and can either forward ShouldScrollToTop or simply implement it to return NO)
// TODO: make upstream fork's solution work instead of this hack, which was to have bottom view controller
// set to self.scrollViewDelegate, set its scrollView's delegate to self, and use forwardInvocation
// to call bottom view controller's scrollview delegate methods. but also in the methods we do override,
// call the bottom view controller's implementations, like complete reverse to what i've done with the
// bottom view controller having to call us.
// i think can automatically set scrollViewDelegate if bottom view controller found to conform to the protocol
// kinda like how top view controller checked for conforming to QMBParallaxScrollViewParallaxDelegate
@protocol QMBParallaxScrollViewForwardingDelegate <NSObject>
@property (nonatomic, assign) BOOL forwardScrollViewDelegateMethods;
@end
//
// example boilerplate that observedScrollView conforming to QMBParallaxScrollViewForwardingDelegate should implement:
//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewDidScroll:scrollView];
//}
//- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewWillBeginDragging:scrollView];
//}
//- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
//}
//- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
//}
//- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewWillBeginDecelerating:scrollView];
//}
//- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewDidEndDecelerating:scrollView];
//}
//- (void)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
//    if (self.forwardScrollViewDelegateMethods && [self.parentViewController isKindOfClass:[QMBParallaxScrollViewController class]])
//        [(QMBParallaxScrollViewController *)self.parentViewController scrollViewShouldScrollToTop:scrollView];
//}
