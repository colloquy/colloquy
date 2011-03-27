#import "CQChatCreationViewController.h"

#import "CQChatController.h"
#import "CQChatEditViewController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "CQKeychain.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQChatCreationViewController
- (void) dealloc {
	[_selectedConnection release];
	[_searchString release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	if (!_rootViewController) {
		CQChatEditViewController *editViewController = [[CQChatEditViewController alloc] init];
		editViewController.roomTarget = _roomTarget;
		editViewController.selectedConnection = _selectedConnection;

		_rootViewController = editViewController;
	}

	NSString *label = (_roomTarget ? NSLocalizedString(@"Join", @"Join button title") : NSLocalizedString(@"Chat", @"Chat button title"));
	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:label style:UIBarButtonItemStyleDone target:self action:@selector(commit:)];
	_rootViewController.navigationItem.rightBarButtonItem = doneItem;
	[doneItem release];

	_rootViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_rootViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);

	[super viewDidLoad];

	if (_showListOnLoad) {
		[(CQChatEditViewController *)_rootViewController showRoomListFilteredWithSearchString:_searchString];

		[_searchString release];
		_searchString = nil;

		_showListOnLoad = NO;
	}
}

#pragma mark -

@synthesize roomTarget = _roomTarget;

- (void) setRoomTarget:(BOOL) roomTarget {
	_roomTarget = roomTarget;

	CQChatEditViewController *editViewController = (CQChatEditViewController *)_rootViewController;
	editViewController.roomTarget = _roomTarget;
	editViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);
}

@synthesize selectedConnection = _selectedConnection;

- (void) setSelectedConnection:(MVChatConnection *) connection {
	id old = _selectedConnection;
	_selectedConnection = [connection retain];
	[old release];

	((CQChatEditViewController *)_rootViewController).selectedConnection = connection;
}

#pragma mark -

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString {
	if (!_rootViewController) {
		id old = _searchString;
		_searchString = [searchString copy];
		[old release];

		_showListOnLoad = YES;
		return;
	}

	[(CQChatEditViewController *)_rootViewController showRoomListFilteredWithSearchString:searchString];
}

- (void) commit:(id) sender {
	CQChatEditViewController *editViewController = (CQChatEditViewController *)_rootViewController;
	MVChatConnection *connection = editViewController.selectedConnection;
	if (!connection) {
		[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
		return;
	}

	[editViewController endEditing];

	[connection connectAppropriately];

	if (_roomTarget) {
		NSString *roomName = (editViewController.name.length ? [connection properNameForChatRoomNamed:editViewController.name] : @"#help");

		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];

		if (editViewController.password.length) {
			[[CQKeychain standardKeychain] setPassword:editViewController.password forServer:connection.uniqueIdentifier area:roomName];
			[connection joinChatRoomNamed:roomName withPassphrase:editViewController.password];
		} else [connection joinChatRoomNamed:roomName];
	} else if (editViewController.name.length) {
		MVChatUser *user = [[connection chatUsersWithNickname:editViewController.name] anyObject];
		CQDirectChatController *chatController = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:chatController animated:NO];
	}

	[[CQColloquyApplication sharedApplication] showColloquies:nil];

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
