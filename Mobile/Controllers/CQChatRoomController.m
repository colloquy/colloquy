#import "CQChatRoomController.h"

#import "CQChatUserListViewController.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

@interface CQChatRoomController (CQChatRoomControllerPrivate)
- (void) _sortMembers;
@end

@implementation CQChatRoomController
- (id) initWithTarget:(id) target {
	if (!(self = [super initWithTarget:target]))
		return nil;

	UIBarButtonItem *membersItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"members.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showMembers)];
	self.navigationItem.rightBarButtonItem = membersItem;
	[membersItem release];

	_orderedMembers = [[NSMutableArray alloc] initWithCapacity:100];

	_encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQChatRoomEncoding"];

	self.room.encoding = self.encoding;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberNicknameChanged:) name:MVChatUserNicknameChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberModeChanged:) name:MVChatRoomUserModeChangedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_membersSynced:) name:MVChatRoomMemberUsersSyncedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberJoined:) name:MVChatRoomUserJoinedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberParted:) name:MVChatRoomUserPartedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberKicked:) name:MVChatRoomUserKickedNotification object:target];

	return self;
}

- (id) initWithPersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection {
	NSString *roomName = [state objectForKey:@"room"];
	if (!roomName) {
		[self release];
		return nil;
	}

	MVChatRoom *room = [connection chatRoomWithName:roomName];
	if (!room) {
		[self release];
		return nil;
	}

	if (!(self = [self initWithTarget:room]))
		return nil;

	return [super initWithPersistentState:state usingConnection:connection];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_orderedMembers release];
	[_currentUserListViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	[_currentUserListViewController release];
	_currentUserListViewController = nil;
}

#pragma mark -

- (MVChatUser *) user {
	return nil;
}

- (MVChatRoom *) room {
	return (MVChatRoom *)_target;
}

- (UIImage *) icon {
	return [UIImage imageNamed:@"roomIcon.png"];
}

- (NSString *) title {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowFullRoomNames"])
		return self.room.name;
	return self.room.displayName;
}

- (MVChatConnection *) connection {
	return self.room.connection;
}

- (BOOL) available {
	return (self.connection && self.room.joined);
}

- (NSDictionary *) persistentState {
	NSMutableDictionary *state = (NSMutableDictionary *)[super persistentState];

	if (self.room)
		[state setObject:self.room.name forKey:@"room"];

	return state;
}

#pragma mark -

- (void) close {
	[self.room part];
}

#pragma mark -

- (void) joined {
	[_orderedMembers removeAllObjects];
	[_orderedMembers addObjectsFromArray:[self.room.memberUsers allObjects]];

	_membersNeedSorted = YES;
}

- (void) showMembers {
	if (_currentUserListViewController)
		return;

	if (_membersNeedSorted)
		[self _sortMembers];

	_currentUserListViewController = [[CQChatUserListViewController alloc] init];

	_currentUserListViewController.title = NSLocalizedString(@"Members", @"Members view title");
	_currentUserListViewController.users = _orderedMembers;
	_currentUserListViewController.room = self.room;

	[self.navigationController pushViewController:_currentUserListViewController animated:YES];
}

#pragma mark -

static NSInteger sortMembersByStatus(MVChatUser *user1, MVChatUser *user2, void *context) {
	CQChatRoomController *room = (CQChatRoomController *)context;

	unsigned char user1Status = 0;
	unsigned char user2Status = 0;

	unsigned long modes = [room.room modesForMemberUser:user1];

	if (user1.serverOperator) user1Status = 6;
	else if (modes & MVChatRoomMemberFounderMode) user1Status = 5;
	else if (modes & MVChatRoomMemberAdministratorMode) user1Status = 4;
	else if (modes & MVChatRoomMemberOperatorMode) user1Status = 3;
	else if (modes & MVChatRoomMemberHalfOperatorMode) user1Status = 2;
	else if (modes & MVChatRoomMemberVoicedMode) user1Status = 1;

	modes = [[room target] modesForMemberUser:user2];

	if (user2.serverOperator) user2Status = 6;
	else if (modes & MVChatRoomMemberFounderMode) user2Status = 5;
	else if (modes & MVChatRoomMemberAdministratorMode) user2Status = 4;
	else if (modes & MVChatRoomMemberOperatorMode) user2Status = 3;
	else if (modes & MVChatRoomMemberHalfOperatorMode) user2Status = 2;
	else if (modes & MVChatRoomMemberVoicedMode) user2Status = 1;

	if (user1Status > user2Status)
		return NSOrderedAscending;
	if (user1Status < user2Status)
		return NSOrderedDescending;

	return [user1.displayName caseInsensitiveCompare:user2.displayName];
}

static NSInteger sortMembersByNickname(MVChatUser *user1, MVChatUser *user2, void *context) {
	return [user1.displayName caseInsensitiveCompare:user2.displayName];
}

- (void) _sortMembers {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"])
		[_orderedMembers sortUsingFunction:sortMembersByStatus context:self];
	else [_orderedMembers sortUsingFunction:sortMembersByNickname context:self];

	_membersNeedSorted = NO;
}

- (void) _memberNicknameChanged:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	if (![self.room hasUser:user])
		return;

	NSUInteger originalIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (originalIndex == NSNotFound)
		return;

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	[self _sortMembers];

	NSUInteger newIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (newIndex == originalIndex) {
		[_currentUserListViewController updateUserAtIndex:newIndex];
		return;
	}

	[_currentUserListViewController moveUserAtIndex:originalIndex toIndex:newIndex];
}

- (void) _memberModeChanged:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"who"];
	if (!user)
		return;

	NSUInteger originalIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (originalIndex == NSNotFound)
		return;

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	[self _sortMembers];

	NSUInteger newIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (newIndex == originalIndex) {
		[_currentUserListViewController updateUserAtIndex:newIndex];
		return;
	}

	[_currentUserListViewController moveUserAtIndex:originalIndex toIndex:newIndex];
}

- (void) _membersSynced:(NSNotification *) notification {
	NSDictionary *userInfo = [notification userInfo];
	if (!userInfo)
		return;

	BOOL modifed = NO;
	for (MVChatUser *user in [userInfo objectForKey:@"added"]) {
		if ([_orderedMembers indexOfObjectIdenticalTo:user] == NSNotFound) {
			[_orderedMembers addObject:user];
			modifed = YES;
		}
	}

	for (MVChatUser *user in [userInfo objectForKey:@"removed"]) {
		int index = [_orderedMembers indexOfObjectIdenticalTo:user];
		if (index != NSNotFound) {
			[_orderedMembers removeObjectAtIndex:index];
			modifed = YES;
		}
	}

	if (!modifed)
		return;

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	[self _sortMembers];

	// This should add/remove each user individually. But this isn't
	// common, so we just replace the list.
	_currentUserListViewController.users = _orderedMembers;
}

- (void) _memberJoined:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	if ([_orderedMembers indexOfObjectIdenticalTo:user] != NSNotFound)
		return;

	[_orderedMembers addObject:user];

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	[self _sortMembers];

	NSUInteger index = [_orderedMembers indexOfObjectIdenticalTo:user];
	[_currentUserListViewController insertUser:user atIndex:index];
}

- (void) _memberParted:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	NSUInteger index = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (index == NSNotFound)
		return;

	[_orderedMembers removeObjectAtIndex:index];
	[_currentUserListViewController removeUserAtIndex:index];
}

- (void) _memberKicked:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	NSUInteger index = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (index == NSNotFound)
		return;

	[_orderedMembers removeObjectAtIndex:index];
	[_currentUserListViewController removeUserAtIndex:index];
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (alertView.tag != 2) {
		[super alertView:alertView clickedButtonAtIndex:buttonIndex];
		return;
	}

	if (buttonIndex != 0)
		return;

	[self.room join];
}

#pragma mark -

- (void) _showCantSendMessagesWarning {
	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;
	alert.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (!self.connection.connected) {
		alert.tag = 1;
		alert.message = NSLocalizedString(@"You are currently disconnected,\nreconnect and try again.", @"Can't send message to room because server is disconnected alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect alert button title")];
	} else if (!self.room.joined) {
		alert.tag = 2;
		alert.message = NSLocalizedString(@"You are not a room member,\nrejoin and try again.", @"Can't send message to room because not a member alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Join", @"Join alert button title")];
	} else {
		[alert release];
		return;
	}

	[alert addButtonWithTitle:NSLocalizedString(@"Close", @"Close alert button title")];

	alert.cancelButtonIndex = 1;

	[alert show];

	[alert release];
}

- (void) _connectionDidConnect:(NSNotification *) notification {
	[self.room join];
}
@end
