#import "CQChatPresentationController.h"

#import "CQColloquyApplication.h"
#import "CQChatController.h"

@implementation CQChatPresentationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	UIBarButtonItem *connectionsButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connections", @"Connections button title") style:UIBarButtonItemStyleBordered target:[CQColloquyApplication sharedApplication] action:@selector(showConnections:)];
	_standardToolbarItems = [[NSArray alloc] initWithObjects:connectionsButton, nil];
	[connectionsButton release];

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
	UIViewController <CQChatViewController> *old = _topChatViewController;

	if (old) {
		[old viewWillDisappear:NO];
		[old.view removeFromSuperview];
		[old viewDidDisappear:NO];
	}

	_topChatViewController = [chatViewController retain];
	[old release];

	UIView *view = _topChatViewController.view;

	CGRect frame = self.view.bounds;
	frame.origin.y += _toolbar.frame.size.height;
	frame.size.height -= _toolbar.frame.size.height;
	view.frame = frame;

	[_topChatViewController viewWillAppear:NO];
	[self.view insertSubview:view aboveSubview:_toolbar];
	[_topChatViewController viewDidAppear:NO];
}
@end
