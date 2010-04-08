#import "CQChatPresentationController.h"

#import "CQChatController.h"

@implementation CQChatPresentationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	_standardToolbarItems = [[NSArray alloc] init];

	return self;
}

- (void) dealloc {
	[_toolbar release];
	[_standardToolbarItems release];

    [super dealloc];
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

	[view release];
}

- (void) viewDidUnload {
	[super viewDidUnload];

	[_toolbar release];
	_toolbar = nil;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

#pragma mark -

- (void) updateToolbarAnimated:(BOOL) animated {
	NSMutableArray *allItems = [_standardToolbarItems mutableCopy];

	UIBarButtonItem *leftBarButtonItem = _topChatViewController.navigationItem.leftBarButtonItem;
	if (leftBarButtonItem)
		[allItems addObject:leftBarButtonItem];

	NSString *title = _topChatViewController.navigationItem.title;
	if (title.length) {
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.textColor = [UIColor colorWithRed:(113 / 255) green:(120 / 255) blue:(128 / 255) alpha:.5];
		titleLabel.font = [UIFont boldSystemFontOfSize:20.];
		titleLabel.text = _topChatViewController.navigationItem.title;

		[titleLabel sizeToFit];

		UIBarButtonItem *titleItem = [[UIBarButtonItem alloc] initWithCustomView:titleLabel];
		UIBarButtonItem *flexibleSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

		[allItems addObject:flexibleSpaceItem];
		[allItems addObject:titleItem];
		[allItems addObject:flexibleSpaceItem];

		[titleItem release];
		[flexibleSpaceItem release];
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

	id old = _standardToolbarItems;
	_standardToolbarItems = [items copy];
	[old release];

	[self updateToolbarAnimated:animated];
}

#pragma mark -

@synthesize topChatViewController = _topChatViewController;

- (void) setTopChatViewController:(id <CQChatViewController>) chatViewController {
	if (chatViewController == _topChatViewController)
		return;

	UIViewController <CQChatViewController> *oldViewController = _topChatViewController;

	if (oldViewController) {
		[oldViewController viewWillDisappear:NO];
		if ([oldViewController respondsToSelector:@selector(dismissPopoversAnimated:)])
			[oldViewController dismissPopoversAnimated:NO];
		[oldViewController.view removeFromSuperview];
		[oldViewController viewDidDisappear:NO];
	}

	_topChatViewController = [chatViewController retain];
	[oldViewController release];

	if (!_topChatViewController)
		return;

	UIView *view = _topChatViewController.view;

	CGRect frame = self.view.bounds;
	frame.origin.y += _toolbar.frame.size.height;
	frame.size.height -= _toolbar.frame.size.height;
	view.frame = frame;

	[self updateToolbarAnimated:NO];

	[_topChatViewController viewWillAppear:NO];
	[self.view insertSubview:view aboveSubview:_toolbar];
	[_topChatViewController viewDidAppear:NO];
}
@end
