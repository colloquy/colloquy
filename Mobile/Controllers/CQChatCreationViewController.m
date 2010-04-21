#import "CQChatCreationViewController.h"

#import "CQChatController.h"
#import "CQConnectionsController.h"
#import "CQChatEditViewController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQDirectChatController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQChatCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
		self.modalPresentationStyle = UIModalPresentationFormSheet;

	return self;
}

- (void) dealloc {
	[_editViewController release];
	[_selectedConnection release];
	[_searchString release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_editViewController)
		return;

	_editViewController = [[CQChatEditViewController alloc] init];
	_editViewController.roomTarget = _roomTarget;
	_editViewController.selectedConnection = _selectedConnection;

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

	if (_showListOnLoad) {
		[_editViewController showRoomListFilteredWithSearchString:_searchString];

		[_searchString release];
		_searchString = nil;

		_showListOnLoad = NO;
	}
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:animated];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

#pragma mark -

@synthesize roomTarget = _roomTarget;

- (void) setRoomTarget:(BOOL) roomTarget {
	_roomTarget = roomTarget;

	_editViewController.roomTarget = _roomTarget;
	_editViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);
}

@synthesize selectedConnection = _selectedConnection;

- (void) setSelectedConnection:(MVChatConnection *) connection {
	id old = _selectedConnection;
	_selectedConnection = [connection retain];
	[old release];

	_editViewController.selectedConnection = connection;
}

#pragma mark -

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString {
	if (!_editViewController) {
		id old = _searchString;
		_searchString = [searchString copy];
		[old release];

		_showListOnLoad = YES;
		return;
	}

	[_editViewController showRoomListFilteredWithSearchString:searchString];
}

- (void) cancel:(id) sender {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	MVChatConnection *connection = _editViewController.selectedConnection;
	if (!connection) {
		[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
		return;
	}

	[_editViewController endEditing];

	[connection connectAppropriately];

	if (_roomTarget) {
		NSString *roomName = (_editViewController.name.length ? [connection properNameForChatRoomNamed:_editViewController.name] : @"#help");

		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];

		[connection joinChatRoomNamed:roomName withPassphrase:_editViewController.password];
	} else if (_editViewController.name.length) {
		MVChatUser *user = [[connection chatUsersWithNickname:_editViewController.name] anyObject];
		CQDirectChatController *chatController = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:chatController animated:NO];
	}

	[[CQColloquyApplication sharedApplication] showColloquies:nil];

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
