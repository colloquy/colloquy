#import "CQChatPresentationController.h"

#import "CQChatController.h"

#import "CQNavigationToolbar.h"

#import "UIDeviceAdditions.h"
#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQChatPresentationController {
	UIToolbar *_toolbar;
	NSArray <UIBarButtonItem *> *_standardToolbarItems;
	UIViewController <CQChatViewController> *_topChatViewController;
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	_standardToolbarItems = @[];

#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applyiOS7NavigationBarSizing) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
#endif

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) loadView {
	UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.view = view;

	view.clipsToBounds = YES;

	_toolbar = [[CQNavigationToolbar alloc] initWithFrame:CGRectZero];
	_toolbar.layer.shadowOpacity = 0.;
	_toolbar.items = _standardToolbarItems;
	_toolbar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);

	[_toolbar sizeToFit];

	[view addSubview:_toolbar];
}

- (void) viewWillTransitionToSize:(CGSize) size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>) coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

#if SYSTEM(TV) || SYSTEM(MARZIPAN)
	[self updateToolbarAnimated:YES];
#else
	// 480. is an arbitrary value, this can be changed if a new value comes up that makes more sense
	[self updateToolbarForInterfaceOrientation:size.width > 480. ? UIInterfaceOrientationLandscapeLeft : UIInterfaceOrientationPortrait animated:NO];
#endif
}

#pragma mark -

- (void) updateToolbarAnimated:(BOOL) animated {
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	[self updateToolbarForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation animated:animated];
}

- (void) updateToolbarForInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation animated:(BOOL) animated {
#endif
	if (![UIDevice currentDevice].isPadModel)
		return;

	NSMutableArray <UIBarButtonItem *> *allItems = [_standardToolbarItems mutableCopy];

	UIBarButtonItem *leftBarButtonItem = _topChatViewController.navigationItem.leftBarButtonItem;
	if (leftBarButtonItem)
		[allItems addObject:leftBarButtonItem];

	NSString *title = _topChatViewController.navigationItem.title;
	if (title.length) {
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.tag = 1000;
		titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
		titleLabel.textColor = [UIColor blackColor];
		titleLabel.text = title;

		[titleLabel sizeToFit];

		UIBarButtonItem *leftSpaceItem = nil;
		// TODO: Update to calculate width correctly
		// Only used a fixed space if there are 2 standard toolbar buttons. This means the sidebar is hidden
		// and we should try to center the title to the device.
		/* if (_standardToolbarItems.count == 2 && [[[NSLocale currentLocale] localeIdentifier] hasCaseInsensitivePrefix:@"en"]) {
			leftSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

			// This calculation makes a big assumption about the width of the right side buttons.
			// So this is only correct for English, and needs updated if the right buttons change in width.
			CGFloat offset = UIDeviceOrientationIsPortrait(interfaceOrientation) ? 182. : 310.;
			leftSpaceItem.width = offset - (titleLabel.frame.size.width / 2.);
		} else */ leftSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

		UIBarButtonItem *titleItem = [[UIBarButtonItem alloc] initWithCustomView:titleLabel];
		UIBarButtonItem *rightSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

		[allItems addObject:leftSpaceItem];
		[allItems addObject:titleItem];
		[allItems addObject:rightSpaceItem];

	}

#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	[allItems addObjectsFromArray:_topChatViewController.toolbarItems];
#endif

	UIBarButtonItem *rightBarButtonItem = _topChatViewController.navigationItem.rightBarButtonItem;
	if (rightBarButtonItem)
		[allItems addObject:rightBarButtonItem];

	[_toolbar setItems:allItems animated:animated];

	[self _applyiOS7NavigationBarSizing];
}

#pragma mark -

- (void) setStandardToolbarItems:(NSArray <UIBarButtonItem *> *) items {
	[self setStandardToolbarItems:items animated:YES];
}

- (void) setStandardToolbarItems:(NSArray <UIBarButtonItem *> *) items animated:(BOOL) animated {
	NSParameterAssert(items);

	_standardToolbarItems = [items copy];

	[self updateToolbarAnimated:animated];
}

#pragma mark -

- (void) setTopChatViewController:(id <CQChatViewController>) chatViewController {
	if (chatViewController == _topChatViewController)
		return;

	UIViewController <CQChatViewController> *oldViewController = _topChatViewController;

	[oldViewController willMoveToParentViewController:nil];
	[oldViewController viewWillDisappear:NO];

	_topChatViewController = (UIViewController <CQChatViewController> *)chatViewController;

	UIView *view = _topChatViewController.view;
	CGRect frame = self.view.frame;
	frame.origin = CGPointZero;
	view.frame = frame;

	if (_topChatViewController) {
		[self _applyiOS7NavigationBarSizing];

		[self addChildViewController:_topChatViewController];
		[_topChatViewController viewWillAppear:NO];
	}

	if ([oldViewController respondsToSelector:@selector(dismissPopoversAnimated:)])
		[oldViewController dismissPopoversAnimated:NO];

	[oldViewController.view removeFromSuperview];
	[oldViewController viewDidDisappear:NO];
	[oldViewController removeFromParentViewController];
	[oldViewController didMoveToParentViewController:nil];

	[self updateToolbarAnimated:NO];

	if (!_topChatViewController)
		return;

	[self.view insertSubview:view belowSubview:_toolbar];
	[_topChatViewController viewDidAppear:NO];
	[_topChatViewController didMoveToParentViewController:self];
}

#pragma mark -

- (void) _applyiOS7NavigationBarSizing {
	[_toolbar sizeToFit];

	CGRect frame = _toolbar.frame;
	frame.size.width = self.view.frame.size.width;

#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	// If we are on iOS 7 or up, the statusbar is now part of the navigation bar, so, we need to fake its height
	CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
	// We can't do the following:
	// CGFloat height = [[UIApplication sharedApplication].delegate.window convertRect:statusBarFrame toView:nil];
	// because when the app first loads, it fails to convert the rect, and we are given {{0, 0}, {20, 1024}} as the
	// statusBarFrame, even after self.view is added to its superview, is loaded, and self.view.window is set.
	CGFloat statusBarHeight = fmin(statusBarFrame.size.height, statusBarFrame.size.width);
	frame.size.height += statusBarHeight;
	_toolbar.frame = frame;

	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
#endif
		_topChatViewController.scrollView.contentInset = UIEdgeInsetsMake(CGRectGetHeight(_toolbar.frame), 0., 0., 0.);
}
@end

NS_ASSUME_NONNULL_END
