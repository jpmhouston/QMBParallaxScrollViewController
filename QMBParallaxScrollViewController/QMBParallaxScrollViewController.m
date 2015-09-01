//
//  QMBParallaxScrollViewController.m
//  QMBParallaxScrollViewController
//
//  Based on QMBParallaxScrollViewController created by Toni Möckel on 02.11.13
//  and heavily modified by Robert Böhnke on 02.20.14, then by Pierre Houston on 08.31.2015
//  (if nothing left of the original code, perhaps ok to change copyright)
//  Copyright (c) 2013 Toni Möckel. All rights reserved.
//

#import "QMBParallaxScrollViewController.h"
#import "QMBRelationshipSegue.h"


NSString * const QMBTopControllerRelationshipSegueIdentifier = @"ParallaxTop";
NSString * const QMBBottomControllerRelationshipSegueIdentifier = @"ParallaxBottom";

@interface QMBParallaxScrollViewController ()

@property (nonatomic, strong, readwrite) UIViewController *topViewController;
@property (nonatomic, strong, readwrite) UIViewController *bottomViewController;

@property (nonatomic, strong) UIView *topView;
@property (nonatomic, strong) UIView *bottomView;

@property (nonatomic, assign) CGFloat pendingTopHeight;
@property (nonatomic, assign) CGFloat pendingBottomHeight;
@property (nonatomic, assign) BOOL pendingWithAnimation;
@property (nonatomic, assign, getter=isAnimating) BOOL animating;
@property (nonatomic, assign, readwrite) BOOL fixedBackgroundTopView;

@property (readonly, nonatomic, assign) CGFloat effectiveSnapHeight;
@property (readonly, nonatomic, assign) CGFloat effectiveMaxHeight;
@property (readonly, nonatomic, assign) CGFloat collapsedHeight;
@property (readonly, nonatomic, assign) CGFloat fullHeight;

@end

@implementation QMBParallaxScrollViewController

@dynamic collapsedHeight, fullHeight, effectiveSnapHeight, effectiveMaxHeight;
@dynamic bottomHeight, bottomSnapHeight, bottomMinHeight;

#pragma mark - Lifecycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self == nil) return nil;
    
    self.topSnapHeight = 180;
    self.topMaxHeight = -1;
    self.snapThreshold = 40;
    self.animationDuration = 0.2;
    
    self.pendingTopHeight = -1;
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self == nil) return nil;
    
    self.topSnapHeight = 180;
    self.topMaxHeight = -1;
    self.snapThreshold = 40;
    self.animationDuration = 0.2;
    
    self.pendingTopHeight = -1;
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // if view controllers not setup by caller (using setup methods below) then look for relationship segues
    // that define the top & bottom view controllers
    if (!self.topViewController) {
        @try {
            [self performSegueWithIdentifier:QMBTopControllerRelationshipSegueIdentifier sender:nil];
        }
        @catch (NSException *exception) { } // ignore segue not defined exception
    }
    if (!self.bottomViewController) {
        @try {
            [self performSegueWithIdentifier:QMBBottomControllerRelationshipSegueIdentifier sender:nil];
        }
        @catch (NSException *exception) { } // ignore segue not defined exception
    }
    
    [self delayedSetup];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // allows top & bottom view controllers to be defined in a storyboard: add custom segues to each from the
    // parallax view controller, use class QMBRelationshipSegue and set the identifiers to ParallaxTop & ParallaxBottom
    if ([segue isKindOfClass:[QMBRelationshipSegue class]] && segue.sourceViewController == self) {
        if ([segue.identifier isEqualToString:QMBTopControllerRelationshipSegueIdentifier]) {
            self.topViewController = segue.destinationViewController;
            self.fixedBackgroundTopView = [self.topViewController conformsToProtocol:@protocol(QMBParallaxScrollViewParallaxDelegate)];
        }
        else if ([segue.identifier isEqualToString:QMBBottomControllerRelationshipSegueIdentifier]) {
            self.bottomViewController = segue.destinationViewController;
        }
    }
}

#pragma mark - QMBParallaxScrollViewController Methods

- (void)setupWithTopViewController:(UIViewController *)topViewController withHeight:(CGFloat)topHeight bottomViewController:(UIViewController *)bottomViewController {
    
    self.observedScrollView = nil;
    
    self.topViewController = topViewController;
    self.bottomViewController = bottomViewController;
    
    self.topHeight = topHeight >= 0 ? topHeight : (self.topSnapHeight >= 0 ? self.topSnapHeight : FLT_MAX);
}

- (void)setupWithBottomViewController:(UIViewController *)bottomViewController withHeight:(CGFloat)bottomHeight topViewController:(UIViewController *)topViewController {
    
    self.observedScrollView = nil;
    
    self.topViewController = topViewController;
    self.bottomViewController = bottomViewController;
    
    self.bottomHeight = bottomHeight >= 0 ? bottomHeight : (self.bottomSnapHeight >= 0 ? self.bottomSnapHeight : FLT_MAX);
}

- (void)setupWithFixedTopViewController:(UIViewController *)topViewController andBottomViewController:(UIViewController *)bottomViewController withHeight:(CGFloat)bottomHeight {
    
    self.observedScrollView = nil;
    
    self.topViewController = topViewController;
    self.bottomViewController = bottomViewController;
    
    self.fixedBackgroundTopView = YES;
    
    self.bottomHeight = bottomHeight >= 0 ? bottomHeight : (self.bottomSnapHeight >= 0 ? self.bottomSnapHeight : FLT_MAX);
}

- (void)setBottomHeight:(CGFloat)bottomHeight animated:(BOOL)animated {
    if (![self isViewLoaded]) {
        // can't fulfill this until the view is loaded, save it until then
        self.pendingBottomHeight = bottomHeight;
        self.pendingTopHeight = -1;
    }
    else {
        [self setTopHeight:self.view.bounds.size.height - bottomHeight animated:animated];
    }
}

- (void)setTopHeight:(CGFloat)topHeight animated:(BOOL)animated {
    if (![self isViewLoaded]) {
        // can't fulfill this until the view is loaded, save it until then
        self.pendingTopHeight = topHeight;
        self.pendingBottomHeight = -1;
    }
    else if (self.animating) {
        // already animating, save aside the height to be acted upon when animation stops [perhaps stop the animation explicitly here too?]
        self.pendingTopHeight = topHeight;
        self.pendingWithAnimation = animated;
    }
    
    else if (!animated) {
        self.topHeight = topHeight;
        self.pendingTopHeight = -1;
    }
    else {
        self.animating = YES;
        
        UIViewKeyframeAnimationOptions opt = UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateKeyframesWithDuration:self.animationDuration delay:0 options:opt animations:^{
            self.topHeight = topHeight;
            
        } completion:^(BOOL finished) {
            self.animating = NO;
            
            // if pendingTopHeight was changed while animating was YES, call ourselves again to update to that height
            if (self.pendingTopHeight >= 0 && self.pendingTopHeight != topHeight) {
                [self setTopHeight:self.pendingTopHeight animated:self.pendingWithAnimation];
                self.pendingTopHeight = -1;
            }
        }];
    }
}


#pragma mark - Properties

- (void)setTopViewController:(UIViewController *)topViewController {
    [_topViewController removeFromParentViewController];
    
    _topViewController = topViewController;
    
    [_topViewController willMoveToParentViewController:self];
    [self addChildViewController:_topViewController];
    
    self.topView = _topViewController.view;
    
    [_topViewController didMoveToParentViewController:self];
}

- (void)setBottomViewController:(UIViewController *)bottomViewController {
    // clean up previous scrollview delegate or forwarding
    if ([_bottomViewController conformsToProtocol:@protocol(QMBParallaxScrollViewForwardingDelegate)]) {
        ((id<QMBParallaxScrollViewForwardingDelegate>)_bottomViewController).forwardScrollViewDelegateMethods = NO;
    }
    else if ([_bottomViewController.view isKindOfClass:[UIScrollView class]] && ((UIScrollView *)_bottomViewController.view).delegate == self) {
        ((UIScrollView *)_bottomViewController.view).delegate = nil;
    }
    self.observedScrollView = nil;
    
    [_bottomViewController removeFromParentViewController];
    
    _bottomViewController = bottomViewController;
    
    [_bottomViewController willMoveToParentViewController:self];
    [self addChildViewController:_bottomViewController];
    
    self.bottomView = _bottomViewController.view;
    
    [_bottomViewController didMoveToParentViewController:self];
    
    // setup scrollview delegate or forwarding
    if ([self.bottomViewController.view isKindOfClass:[UIScrollView class]]) {
        if ([_bottomViewController conformsToProtocol:@protocol(QMBParallaxScrollViewForwardingDelegate)]) {
            ((id<QMBParallaxScrollViewForwardingDelegate>)_bottomViewController).forwardScrollViewDelegateMethods = YES;
        }
        else {
            ((UIScrollView *)_bottomViewController.view).delegate = self;
        }
        self.observedScrollView = (UIScrollView *)self.bottomViewController.view;
        self.observedScrollView.alwaysBounceVertical = YES;
    }
}

- (void)setTopView:(UIView *)topView {
    [_topView removeFromSuperview];
    
    _topView = topView;
    
    if (self.bottomView)
        [self.view insertSubview:_topView belowSubview:self.bottomView]; // bottom view overlaps top view
    else
        [self.view addSubview:_topView];
}

- (void)setBottomView:(UIView *)bottomView {
    [_bottomView removeFromSuperview];
    
    _bottomView = bottomView;
    
    if (self.topView)
        [self.view insertSubview:_bottomView aboveSubview:self.topView]; // bottom view overlaps top view
    else
        [self.view addSubview:_bottomView];
}


- (CGFloat)bottomSnapHeight {
    if ([self isViewLoaded]) {
        return self.topSnapHeight < 0 ? -1 : (self.view.bounds.size.height - self.topLayoutGuide.length) - self.topSnapHeight;
    }
    return -1;
}

- (void)setBottomSnapHeight:(CGFloat)snapHeight {
    if ([self isViewLoaded]) {
        self.topSnapHeight = snapHeight < 0 ? -1 : (self.view.bounds.size.height - self.topLayoutGuide.length) - snapHeight;
    }
}

- (CGFloat)bottomMinHeight {
    if ([self isViewLoaded]) {
        return self.topMaxHeight < 0 ? -1 : MAX((self.view.bounds.size.height - self.topLayoutGuide.length) - self.topMaxHeight, -1); // if topMax=FLT_MAX, cap neg values at -1
    }
    return -1;
}

- (void)setBottomMinHeight:(CGFloat)minHeight {
    if ([self isViewLoaded]) {
        self.topMaxHeight = minHeight <= 0 ? -1 : (self.view.bounds.size.height - self.topLayoutGuide.length) - minHeight;
    }
}

- (CGFloat)bottomMaxHeight {
    if ([self isViewLoaded]) {
        return self.topMinHeight <= 0 ? -1 : (self.view.bounds.size.height - self.topLayoutGuide.length) - self.topMinHeight;
    }
    return -1;
}

- (void)setBottomMaxHeight:(CGFloat)maxHeight {
    if ([self isViewLoaded]) {
        self.topMinHeight = maxHeight < 0 ? 0 : MAX((self.view.bounds.size.height - self.topLayoutGuide.length) - maxHeight, 0); // if max=FLT_MAX, return 0 instead of neg value
    }
}


- (void)setTopSnapHeight:(CGFloat)snapHeight {
    if ([self isViewLoaded]) [self willChangeValueForKey:@"bottomSnapHeight"];
    
    _topSnapHeight = snapHeight;
    
    if ([self isViewLoaded]) [self didChangeValueForKey:@"bottomSnapHeight"];
}

- (void)setTopMaxHeight:(CGFloat)maxHeight {
    if ([self isViewLoaded]) [self willChangeValueForKey:@"bottomMinHeight"];
    
    _topMaxHeight = maxHeight;
    
    if ([self isViewLoaded]) [self didChangeValueForKey:@"bottomMinHeight"];
}

- (void)setTopMinHeight:(CGFloat)minHeight {
    if ([self isViewLoaded]) [self willChangeValueForKey:@"bottomMaxHeight"];
    
    _topMinHeight = minHeight;
    
    if ([self isViewLoaded]) [self didChangeValueForKey:@"bottomMaxHeight"];
}

- (CGFloat)bottomHeight {
    if ([self isViewLoaded]) {
        return self.view.bounds.size.height - self.topHeight;
    }
    return self.pendingBottomHeight;
}

- (void)setBottomHeight:(CGFloat)height {
    if ([self isViewLoaded]) {
        [self willChangeValueForKey:@"topHeight"];
        
        _topHeight = [self correctedTopHeight:self.view.bounds.size.height - height];
        [self divideViewFramesForTopHeight:_topHeight];
        
        [self didChangeValueForKey:@"topHeight"];
        
        if (self.fixedBackgroundTopView && [self.topViewController conformsToProtocol:@protocol(QMBParallaxScrollViewParallaxDelegate)])
            [(id<QMBParallaxScrollViewParallaxDelegate>)self.topViewController setVisibleTopHeight:_topHeight];
    }
    else {
        self.pendingBottomHeight = height;
        self.pendingTopHeight = -1;
    }
}

- (void)setTopHeight:(CGFloat)height {
    if ([self isViewLoaded]) {
        [self willChangeValueForKey:@"bottomHeight"];
        
        _topHeight = [self correctedTopHeight:height];
        [self divideViewFramesForTopHeight:_topHeight];
        
        [self didChangeValueForKey:@"bottomHeight"];
        
        if (self.fixedBackgroundTopView && [self.topViewController conformsToProtocol:@protocol(QMBParallaxScrollViewParallaxDelegate)])
            [(id<QMBParallaxScrollViewParallaxDelegate>)self.topViewController setVisibleTopHeight:_topHeight];
    }
    else {
        self.pendingTopHeight = height;
        self.pendingBottomHeight = -1;
    }
}

#pragma mark - Private

- (void)delayedSetup {
    if ([self isViewLoaded] && self.topViewController && self.bottomViewController) {
        if (self.pendingBottomHeight >= 0) {
            CGFloat delayedHeight = self.pendingBottomHeight;
            self.pendingBottomHeight = self.pendingTopHeight = -1;
            self.bottomHeight = delayedHeight;
        }
        else if (self.pendingTopHeight >= 0) {
            CGFloat delayedHeight = self.pendingTopHeight;
            self.pendingTopHeight = self.pendingBottomHeight = -1;
            self.topHeight = delayedHeight;
        }
    }
}


- (CGFloat)effectiveSnapHeight {
    if ([self isViewLoaded]) {
        return self.topSnapHeight < 0 ? self.topSnapHeight : (self.topLayoutGuide.length + MIN(self.topSnapHeight, self.effectiveMaxHeight));
    }
    return 0;
}

- (CGFloat)effectiveMinHeight {
    if ([self isViewLoaded]) {
        return self.topMinHeight <= 0 ? 0 : MAX(self.topMinHeight, self.collapsedHeight);
    }
    return 0;
}

- (CGFloat)effectiveMaxHeight {
    if ([self isViewLoaded]) {
        return self.topMaxHeight < 0 ? self.fullHeight : MIN(self.topMaxHeight, self.fullHeight);
    }
    return 0;
}

- (CGFloat)collapsedHeight {
    if ([self isViewLoaded]) {
        return self.topLayoutGuide.length;
    }
    return 0;
}

- (CGFloat)fullHeight {
    if ([self isViewLoaded]) {
        return self.view.bounds.size.height - self.bottomLayoutGuide.length;
    }
    return 0;
}


- (CGFloat)correctedTopHeight:(CGFloat)height {
    // set no smaller than the minimum, no larger than the maximum
    CGFloat minHeight = self.effectiveMinHeight;
    CGFloat maxHeight = self.effectiveMaxHeight;
    if (height < minHeight)
        height = minHeight;
    if (height > maxHeight)
        height = maxHeight;
    // round off to a whole integer
    return round(height);
}

- (void)divideViewFramesForTopHeight:(CGFloat)height {
    CGRect top, bottom;
    CGRectDivide(self.view.bounds, &top, &bottom, height, CGRectMinYEdge);
    if (self.fixedBackgroundTopView)
        top = self.view.bounds;
    
    if (!CGRectEqualToRect(self.topView.frame, top))
        self.topView.frame = top;
    
    if (!CGRectEqualToRect(self.bottomView.frame, bottom))
        self.bottomView.frame = bottom;
}


- (void)dragForOffset:(CGFloat *)inOutOffset hasCollapsedTop:(BOOL *)outCollapsedTop
{
    NSParameterAssert(inOutOffset != nil);
    NSParameterAssert(outCollapsedTop != nil);
    CGFloat offset = *inOutOffset;
    BOOL up = offset > 0;
    
    CGFloat minHeight = self.effectiveMinHeight;
    CGFloat maxHeight = self.effectiveMaxHeight;
    
    // if scrolling up while top height at minimum or down while at maximum, then leave both top height & offset unchanged
    
    if (up && self.topHeight <= minHeight) {
        if (self.topHeight < minHeight) {   // ensure no smaller than its min value
            self.topHeight = minHeight;
        }
        *outCollapsedTop = YES;
    }
    else if (!up && self.topHeight >= maxHeight) {
        if (self.topHeight < minHeight) {   // ensure no larger than its max value
            self.topHeight = minHeight;
        }
        *outCollapsedTop = NO;
    }
    else {
        // apply offset on scrollview to the top height, unless reached min or max scrollview offset will then be reset to 0
        CGFloat newHeight = self.topHeight - offset;
        
        if (newHeight <= minHeight) {       // if top height reached minimum then pin it at this value, return offset = remainder
            self.topHeight = minHeight;
            *inOutOffset = minHeight - newHeight;
            *outCollapsedTop = YES;
        }
        else if (newHeight >= maxHeight) {  // if top height reached maximum then pin at this value, return offset = remainder
            self.topHeight = maxHeight;
            *inOutOffset = maxHeight - newHeight;
            *outCollapsedTop = NO;
        }
        else {
            self.topHeight = newHeight;
            *inOutOffset = 0;
            *outCollapsedTop = NO;
        }
    }
}

- (BOOL)snapToNearbyHeight
{
    CGFloat minHeight = self.effectiveMinHeight;
    CGFloat maxHeight = self.effectiveMaxHeight;
    CGFloat snapHeight = self.effectiveSnapHeight;
    CGFloat snapThreshold = self.snapThreshold;
    CGFloat midSnapMax = (maxHeight > snapHeight) ? snapHeight + (maxHeight - snapHeight) / 2 : maxHeight;
    CGFloat newHeight = self.topHeight;
    
    // limit to top view minimized (ie. bottom view full)
    if (snapThreshold > 0 && self.topHeight < minHeight + snapThreshold) {
        newHeight = minHeight;
    }
    // snap down to snap point
    else if (snapThreshold > 0 && snapHeight > 0 && self.topHeight < snapHeight && self.topHeight > snapHeight - snapThreshold) {
        newHeight = snapHeight;
    }
    // snap up to snap point
    else if (snapThreshold > 0 && snapHeight > 0 && self.topHeight > snapHeight && self.topHeight < snapHeight + snapThreshold) {
        newHeight = snapHeight;
    }
    // snap down from snap point to top view full (bottom view collapsed)
    else if (snapHeight > 0 && self.topHeight < maxHeight && self.topHeight > midSnapMax) {
        newHeight = maxHeight;
    }
    
    if (newHeight != self.topHeight) {
        [self setTopHeight:newHeight animated:YES];
        return YES;
    }
    return NO;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSParameterAssert(self.observedScrollView == scrollView);
    
    CGPoint offsetPoint = scrollView.contentOffset;
    BOOL collapsed;
    [self dragForOffset:&offsetPoint.y hasCollapsedTop:&collapsed];
    
    if (offsetPoint.y != scrollView.contentOffset.y) {
        scrollView.contentOffset = offsetPoint;
    }
    
    // when top not collapsed, never allow the scroll indicator to show and keep the scrollview's contents pinned to the top
    if (!collapsed && scrollView.contentOffset.y != 0) {
        scrollView.contentOffset = CGPointZero;
    }
    BOOL showScrollIndicator = collapsed;
    if (scrollView.showsVerticalScrollIndicator != showScrollIndicator) {
        scrollView.showsVerticalScrollIndicator = showScrollIndicator;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    NSParameterAssert(self.observedScrollView == scrollView);
    
    if (self.fixedBackgroundTopView && [self.topViewController conformsToProtocol:@protocol(QMBParallaxScrollViewParallaxDelegate)])
        [(id<QMBParallaxScrollViewParallaxDelegate>)self.topViewController startedDraggingParallaxScrollViewAtVisibleTopHeight:self.topHeight];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    NSParameterAssert(self.observedScrollView == scrollView);
    
    // manipulate the targetContentOffset to keep the momentum going
    if (velocity.y < 0) {
        targetContentOffset->y = -200;
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    NSParameterAssert(self.observedScrollView == scrollView);
    
    if (!decelerate) {
        [self snapToNearbyHeight];
        if (self.fixedBackgroundTopView && [self.topViewController conformsToProtocol:@protocol(QMBParallaxScrollViewParallaxDelegate)])
            [(id<QMBParallaxScrollViewParallaxDelegate>)self.topViewController stoppedDraggingParallaxScrollViewAtVisibleTopHeight:self.topHeight];
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSParameterAssert(self.observedScrollView == scrollView);
    
    BOOL animating = [self snapToNearbyHeight];
    
    if (self.fixedBackgroundTopView && [self.topViewController conformsToProtocol:@protocol(QMBParallaxScrollViewParallaxDelegate)]) {
        if (animating)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.animationDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [(id<QMBParallaxScrollViewParallaxDelegate>)self.topViewController stoppedDraggingParallaxScrollViewAtVisibleTopHeight:self.topHeight];
            });
        else
            [(id<QMBParallaxScrollViewParallaxDelegate>)self.topViewController stoppedDraggingParallaxScrollViewAtVisibleTopHeight:self.topHeight];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    NSParameterAssert(self.observedScrollView == scrollView);
    
    return NO;
}

@end
