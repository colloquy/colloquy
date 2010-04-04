#import "CQChatPresentationController.h"

#import "CQColloquyApplication.h"
#import "CQChatController.h"

@implementation CQChatPresentationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	UIBarButtonItem *connectionsButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connections", @"Connections button title") style:UIBarButtonItemStyleBordered target:[CQColloquyApplication sharedApplication] action:@selector(showConnections:)];
	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	titleLabel.backgroundColor = [UIColor clearColor];
	titleLabel.textColor = [UIColor colorWithRed:(113 / 255) green:(120 / 255) blue:(128 / 255) alpha:.5];
	titleLabel.font = [UIFont boldSystemFontOfSize:20.];

	UIBarButtonItem *titleButton = [[UIBarButtonItem alloc] initWithCustomView:titleLabel];
	UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *membersButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"members.png"] style:UIBarButtonItemStyleBordered target:nil action:nil];
	membersButton.accessibilityLabel = NSLocalizedString(@"Members List", @"Voiceover members list label");

	_standardToolbarItems = [[NSArray alloc] initWithObjects:connectionsButton, flexibleSpace, titleButton, flexibleSpace, membersButton, nil];

	[connectionsButton release];
	[titleLabel release];
	[titleButton release];
	[flexibleSpace release];
	[membersButton release];

	return self;
}

- (void) dealloc {
	[_toolbar release];
	[_standardToolbarItems release];
	[_currentViewToolbarItems release];

    [super dealloc];
}

#pragma mark -

- (void) loadView {
	UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
	self.view = view;

	view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	view.clipsToBounds = YES;

	_toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
	_toolbar.layer.shadowOpacity = 1.;
	_toolbar.layer.shadowRadius = 3.;
	_toolbar.layer.shadowOffset = CGSizeMake(0., 0.);
	_toolbar.items = _standardToolbarItems;

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

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[_toolbar performSelector:@selector(sizeToFit) withObject:nil afterDelay:.08];
}

#pragma mark -

@synthesize standardToolbarItems = _standardToolbarItems;

- (void) setStandardToolbarItems:(NSArray *) items {
	[self setStandardToolbarItems:items animated:YES];
}

- (void) setStandardToolbarItems:(NSArray *) items animated:(BOOL) animated {
	id old = _standardToolbarItems;
	_standardToolbarItems = [items copy];
	[old release];

	NSArray *allItems = [_standardToolbarItems arrayByAddingObjectsFromArray:_currentViewToolbarItems];
	[_toolbar setItems:allItems animated:animated];
}

#pragma mark -

@synthesize topChatViewController = _topChatViewController;

- (void) setTopChatViewController:(id <CQChatViewController>) chatViewController {
	if (chatViewController == _topChatViewController)
		return;

	UIViewController <CQChatViewController> *old = _topChatViewController;

	if (old) {
		[old viewWillDisappear:NO];
		[old.view removeFromSuperview];
		[old viewDidDisappear:NO];
	}

	_topChatViewController = [chatViewController retain];
	[old release];

	if (!_topChatViewController)
		return;

	UIView *view = _topChatViewController.view;

	CGRect frame = self.view.bounds;
	frame.origin.y += _toolbar.frame.size.height;
	frame.size.height -= _toolbar.frame.size.height;
	frame.size.width = [UIScreen mainScreen].applicationFrame.size.width;
	view.frame = frame;

	((UILabel *)((UIBarButtonItem *)[_standardToolbarItems objectAtIndex:(_standardToolbarItems.count - 3)]).customView).text = chatViewController.title;
	[((UIBarButtonItem *)[_standardToolbarItems objectAtIndex:(_standardToolbarItems.count - 3)]).customView sizeToFit];

	[_toolbar sizeToFit];

	[_topChatViewController viewWillAppear:NO];
	[self.view insertSubview:view aboveSubview:_toolbar];
	[_topChatViewController viewDidAppear:NO];
}
@end
