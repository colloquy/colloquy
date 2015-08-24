#import "CQChatCreationViewController.h"

#import "CQChatOrderingController.h"
#import "CQChatEditViewController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "CQKeychain.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  CQChatCreationViewController {
	NSString *_name;
	NSString *_password;
	BOOL _showListOnLoad;
	NSString *_searchString;
}

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

	_rootViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_rootViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);

	[super viewDidLoad];

	if (_showListOnLoad) {
		[(CQChatEditViewController *)_rootViewController showRoomListFilteredWithSearchString:_searchString];

		_searchString = nil;

		_showListOnLoad = NO;
	}
}

#pragma mark -

- (void) setRoomTarget:(BOOL) roomTarget {
	_roomTarget = roomTarget;

	CQChatEditViewController *editViewController = (CQChatEditViewController *)_rootViewController;
	editViewController.roomTarget = _roomTarget;
	editViewController.navigationItem.rightBarButtonItem.enabled = (_roomTarget ? YES : NO);
}

- (void) setSelectedConnection:(MVChatConnection *) connection {
	_selectedConnection = connection;

	((CQChatEditViewController *)_rootViewController).selectedConnection = connection;
}

#pragma mark -

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString {
	if (!_rootViewController) {
		_searchString = [searchString copy];

		_showListOnLoad = YES;
		return;
	}

	[(CQChatEditViewController *)_rootViewController showRoomListFilteredWithSearchString:searchString];
}

- (void) commit:(__nullable id) sender {
	CQChatEditViewController *editViewController = (CQChatEditViewController *)_rootViewController;
	MVChatConnection *connection = editViewController.selectedConnection;

	if ([UIDevice currentDevice].isPadModel || !connection)
		[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];

	if (!connection) {
		return;
	}

	[editViewController endEditing];

	[connection connectAppropriately];

	if (_roomTarget) {
		NSString *roomName = nil;
		if (editViewController.name.length)
			roomName = [connection properNameForChatRoomNamed:editViewController.name];
		else if ([connection.server hasCaseInsensitiveSubstring:@"undernet"])
			roomName = @"#undernet";
		else roomName = @"#help";

		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];

		if (editViewController.password.length) {
			[[CQKeychain standardKeychain] setPassword:editViewController.password forServer:connection.uniqueIdentifier area:roomName];
			[connection joinChatRoomNamed:roomName withPassphrase:editViewController.password];
		} else [connection joinChatRoomNamed:roomName];
	} else if (editViewController.name.length) {
		MVChatUser *user = [[connection chatUsersWithNickname:editViewController.name] anyObject];
		CQDirectChatController *chatController = [[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:chatController animated:NO];
	}
}
@end

NS_ASSUME_NONNULL_END
