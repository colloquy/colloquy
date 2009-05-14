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

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_editViewController)
		return;

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

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return (UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

@synthesize roomTarget = _roomTarget;

- (void) setRoomTarget:(BOOL) roomTarget {
	_roomTarget = roomTarget;

	_editViewController.roomTarget = _roomTarget;
	_editViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);
}

#pragma mark -

- (void) cancel:(id) sender {
	[self dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	if (_editViewController.selectedConnectionIndex == NSNotFound) {
		[self dismissModalViewControllerAnimated:YES];
		return;
	}

	[self.view endEditing:YES];

	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:_editViewController.selectedConnectionIndex];

	[connection connect];

	if (_roomTarget) {
		NSString *roomName = (_editViewController.name.length ? [connection properNameForChatRoomNamed:_editViewController.name] : @"#help");

		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];

		[connection joinChatRoomNamed:roomName withPassphrase:_editViewController.password];
	} else if (_editViewController.name.length) {
		MVChatUser *user = [[connection chatUsersWithNickname:_editViewController.name] anyObject];
		CQDirectChatController *chatController = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:chatController animated:NO];
	}

	[CQColloquyApplication sharedApplication].tabBarController.selectedViewController = [CQChatController defaultController];
	[self dismissModalViewControllerAnimated:YES];
}
@end
