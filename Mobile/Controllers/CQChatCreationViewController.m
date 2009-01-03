#import "CQChatCreationViewController.h"

#import "CQChatController.h"
#import "CQChatEditViewController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "NSStringAdditions.h"

@implementation CQChatCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;
	self.delegate = self;
	return self;
}

- (void) dealloc {
	[_editViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	_editViewController = [[CQChatEditViewController alloc] init];
	_editViewController.roomTarget = _roomTarget;

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
	_editViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	NSString *label = (_roomTarget ? NSLocalizedString(@"Join", @"Join button title") : NSLocalizedString(@"Chat", @"Chat button title"));
	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:label style:UIBarButtonItemStyleDone target:self action:@selector(commit:)];
	_editViewController.navigationItem.rightBarButtonItem = doneItem;
	[doneItem release];

	_editViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_editViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);

	[self pushViewController:_editViewController animated:NO];
}

- (void) viewDidDisappear:(BOOL) animated {
	[_editViewController release];
	_editViewController = nil;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return (UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

@synthesize roomTarget = _roomTarget;

- (BOOL) isRoomTarget {
	return _roomTarget;
}

#pragma mark -

- (void) cancel:(id) sender {
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	if (_editViewController.selectedConnectionIndex == NSNotFound) {
		[self.parentViewController dismissModalViewControllerAnimated:YES];
		return;
	}

	[self.view endEditing:YES];

	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:_editViewController.selectedConnectionIndex];

	[connection connect];

	if (_roomTarget) {
		NSString *roomName = (_editViewController.name.length ? [connection properNameForChatRoomNamed:_editViewController.name] : @"#help");

		// Pass nil for the room name, so rooms that are forwarded will show.
		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:nil andConnection:connection];

		[connection joinChatRoomNamed:roomName withPassphrase:_editViewController.password];
	} else if (_editViewController.name.length) {
		MVChatUser *user = [[connection chatUsersWithNickname:_editViewController.name] anyObject];
		CQDirectChatController *chatController = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:chatController animated:NO];
	}

	[CQColloquyApplication sharedApplication].tabBarController.selectedViewController = [CQChatController defaultController];
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewWillDisappear: and viewWillAppear: are not called when this navigation controller is a modal view.
	if (navigationController.topViewController != viewController)
		[navigationController.topViewController viewWillDisappear:animated];
	[viewController viewWillAppear:animated];
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewDidAppear: is not called when this navigation controller is a modal view.
	[viewController viewDidAppear:animated];
}
@end
