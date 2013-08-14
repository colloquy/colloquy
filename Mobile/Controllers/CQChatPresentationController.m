#import "CQChatPresentationController.h"

#import "CQChatController.h"

@implementation CQChatPresentationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	_standardToolbarItems = [[NSArray alloc] init];

	return self;
}

#pragma mark -

- (void) loadView {
	UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.view = view;

	view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	view.clipsToBounds = YES;

	_toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
	_toolbar.layer.shadowOpacity = 1.;
	_toolbar.layer.shadowRadius = 3.;
	_toolbar.layer.shadowOffset = CGSizeMake(0., 0.);
	_toolbar.items = _standardToolbarItems;
	_toolbar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);

	[_toolbar sizeToFit];

	[view addSubview:_toolbar];
}

- (void) viewDidUnload {
	[super viewDidUnload];

	_toolbar = nil;
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation duration:(NSTimeInterval) duration {
    [self updateToolbarForInterfaceOrientation:interfaceOrientation animated:NO];
}

#pragma mark -

- (void) updateToolbarAnimated:(BOOL) animated {
	[self updateToolbarForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation animated:animated];
}

- (void) updateToolbarForInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation animated:(BOOL) animated {
	NSMutableArray *allItems = [_standardToolbarItems mutableCopy];

	UIBarButtonItem *leftBarButtonItem = _topChatViewController.navigationItem.leftBarButtonItem;
	if (leftBarButtonItem)
		[allItems addObject:leftBarButtonItem];

	NSString *title = _topChatViewController.navigationItem.title;
	if (title.length) {
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.textColor = [UIColor colorWithRed:(113. / 255.) green:(120. / 255.) blue:(128. / 255.) alpha:1.];
		titleLabel.font = [UIFont boldSystemFontOfSize:20.];
		titleLabel.text = title;
		titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.5];
		titleLabel.shadowOffset = CGSizeMake(0., 1.);

		[titleLabel sizeToFit];

		UIBarButtonItem *leftSpaceItem = nil;
		// Only used a fixed space if there are 2 standard toolbar buttons. This means the sidebar is hidden
		// and we should try to center the title to the device.
		if (_standardToolbarItems.count == 2 && [[[NSLocale currentLocale] localeIdentifier] hasCaseInsensitivePrefix:@"en"]) {
			leftSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

			// This calculation makes a big assumption about the width of the right side buttons.
			// So this is only correct for English, and needs updated if the right buttons change in width.
			CGFloat offset = UIDeviceOrientationIsPortrait(interfaceOrientation) ? 182. : 310.;
			leftSpaceItem.width = offset - (titleLabel.frame.size.width / 2.);
		} else leftSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

		UIBarButtonItem *titleItem = [[UIBarButtonItem alloc] initWithCustomView:titleLabel];
		UIBarButtonItem *rightSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

		[allItems addObject:leftSpaceItem];
		[allItems addObject:titleItem];
		[allItems addObject:rightSpaceItem];

	}

	[allItems addObjectsFromArray:_topChatViewController.toolbarItems];

	UIBarButtonItem *rightBarButtonItem = _topChatViewController.navigationItem.rightBarButtonItem;
	if (rightBarButtonItem)
		[allItems addObject:rightBarButtonItem];

	[_toolbar setItems:allItems animated:animated];
}

#pragma mark -

@synthesize standardToolbarItems = _standardToolbarItems;

- (void) setStandardToolbarItems:(NSArray *) items {
	[self setStandardToolbarItems:items animated:YES];
}

- (void) setStandardToolbarItems:(NSArray *) items animated:(BOOL) animated {
	NSParameterAssert(items);

	_standardToolbarItems = [items copy];

	[self updateToolbarAnimated:animated];
}

#pragma mark -

@synthesize topChatViewController = _topChatViewController;

- (void) setTopChatViewController:(UIViewController <CQChatViewController> *) chatViewController {
	if (chatViewController == _topChatViewController)
		return;

	UIViewController <CQChatViewController> *oldViewController = _topChatViewController;

	[oldViewController viewWillDisappear:NO];

	_topChatViewController = chatViewController;

	UIView *view = _topChatViewController.view;

	if (_topChatViewController) {
		CGRect frame = self.view.bounds;
		frame.origin.y += _toolbar.frame.size.height;
		frame.size.height -= _toolbar.frame.size.height;
		view.frame = frame;

		frame = _toolbar.frame;
		frame.size.width = view.frame.size.width;
		_toolbar.frame = frame;

		[_topChatViewController viewWillAppear:NO];
	}

	if ([oldViewController respondsToSelector:@selector(dismissPopoversAnimated:)])
		[oldViewController dismissPopoversAnimated:NO];
	[oldViewController.view removeFromSuperview];
	[oldViewController viewDidDisappear:NO];


	[self updateToolbarAnimated:NO];

	if (!_topChatViewController)
		return;

	[self.view insertSubview:view aboveSubview:_toolbar];
	[_topChatViewController viewDidAppear:NO];
}
@end
