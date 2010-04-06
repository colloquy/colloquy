#import "CQChatRoomController.h"

#import "CQChatController.h"
#import "CQChatUserListViewController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQChatPresentationController.h"
#import "CQProcessChatMessageOperation.h"
#import "CQSoundController.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

static BOOL showJoinEvents;
static BOOL showHostmasksOnJoin;
static BOOL showHostmasksOnPart;
static BOOL showLeaveEvents;

@interface CQDirectChatController (CQDirectChatControllerPrivate)
- (void) _processMessageData:(NSData *) messageData target:(id) target action:(SEL) action userInfo:(id) userInfo;
- (void) _didDisconnect:(NSNotification *) notification;
- (void) userDefaultsChanged;
@end

#pragma mark -

@interface CQChatRoomController (CQChatRoomControllerPrivate)
- (void) _updateRightBarButtonItemAnimated:(BOOL) animated;
- (NSString *) _markupForUser:(MVChatUser *) user;
- (NSString *) _markupForMemberUser:(MVChatUser *) user;
- (void) _sortMembers;
- (void) _displayCurrentTopicOnlyIfSet:(BOOL) onlyIfSet;
@end

#pragma mark -

@implementation CQChatRoomController
+ (void) userDefaultsChanged {
	showJoinEvents = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowJoinEvents"];
	showHostmasksOnJoin = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowHostmaskOnJoin"];
	showHostmasksOnPart = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowHostmaskOnPart"];
	showLeaveEvents = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowLeaveEvents"];
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

- (id) initWithTarget:(id) target {
	if (!(self = [super initWithTarget:target]))
		return nil;

	[self _updateRightBarButtonItemAnimated:NO];

	_orderedMembers = [[NSMutableArray alloc] initWithCapacity:100];

	_encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQChatRoomEncoding"];

	self.room.encoding = self.encoding;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_partedRoom:) name:MVChatRoomPartedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_kicked:) name:MVChatRoomKickedNotification object:target];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberNicknameChanged:) name:MVChatUserNicknameChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberModeChanged:) name:MVChatRoomUserModeChangedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberBanned:) name:MVChatRoomUserBannedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberBanRemoved:) name:MVChatRoomUserBanRemovedNotification object:target];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bannedMembersSynced:) name:MVChatRoomBannedUsersSyncedNotification object:target];
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

	_joined = [[state objectForKey:@"joined"] boolValue];
	_joinCount = 1;

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

	if (_showingMembersInNavigationController) {
		_showingMembersInNavigationController = NO;
		[_currentUserListViewController release];
		_currentUserListViewController = nil;
	}
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	if (!_currentUserListViewController)
		[[CQColloquyApplication sharedApplication] showTabBarWithTransition:YES];
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
	return self.room.displayName;
}

- (MVChatConnection *) connection {
	return self.room.connection;
}

- (BOOL) available {
	return (self.connection.connected && self.room.joined && !_parting);
}

- (NSDictionary *) persistentState {
	NSMutableDictionary *state = (NSMutableDictionary *)[super persistentState];

	if (self.room)
		[state setObject:self.room.name forKey:@"room"];
	if (_currentUserListViewController)
		[state setObject:[NSNumber numberWithBool:YES] forKey:@"active"];
	if (_joined)
		[state setObject:[NSNumber numberWithBool:YES] forKey:@"joined"];

	return state;
}

- (NSArray *) currentViewToolbarItems {
	NSMutableArray *currentViewToolbarItems = [NSMutableArray arrayWithArray:[super currentViewToolbarItems]];

	for (UIBarButtonItem *toolbarItem in currentViewToolbarItems) {
		if (toolbarItem.tag == ToolbarTitleButtonTag) {
			UILabel *titleLabel = (UILabel *)toolbarItem.customView;
			titleLabel.text = self.room.displayName;
			[titleLabel sizeToFit];

			toolbarItem.customView = titleLabel;
		} else if (toolbarItem.tag == ToolbarLastButtonTag && self.connection.connected) {
			toolbarItem.image = [UIImage imageNamed:@"members.png"];
			toolbarItem.action = @selector(showMembers);
		}
	}

	return currentViewToolbarItems;
}

#pragma mark -

- (void) join {
	[self.connection connectAppropriately];
	[self.room join];
}

- (void) part {
	_parting = YES;
	[self.room part];
}

- (void) close {
	[self part];
}

#pragma mark -

- (void) didJoin {
	[_orderedMembers removeAllObjects];
	[_orderedMembers addObjectsFromArray:[self.room.memberUsers allObjects]];

	[self _updateRightBarButtonItemAnimated:YES];

	if (++_joinCount > 1)
		[self addEventMessage:NSLocalizedString(@"You joined the room.", "Joined room event message") withIdentifier:@"rejoined"];

	[self _displayCurrentTopicOnlyIfSet:YES];

	_joined = YES;
	_parting = NO;
	_banListSynced = NO;
	_membersNeedSorted = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_nicknameChanged:) name:MVChatConnectionNicknameAcceptedNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_topicChanged:) name:MVChatRoomTopicChangedNotification object:self.room];
}

- (void) showMembers {
	if ([[UIDevice currentDevice] isPadModel]) {
		if (!_currentUserListPopoverController)
			_currentUserListPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.detailViewController];
		if (!_currentUserListPopoverController.popoverVisible) {
			UIBarButtonItem *membersButton = [((CQChatPresentationController *)[CQChatController defaultController].chatPresentationController).currentViewToolbarItems lastObject];
			[_currentUserListPopoverController presentPopoverFromBarButtonItem:membersButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		}
	} else {
		if (!self.navigationController || _showingMembersInNavigationController)
			return;

		_showingMembersInNavigationController = YES;
		[self.navigationController pushViewController:self.detailViewController animated:YES];
	}
}

#pragma mark -

- (void) hideCurrentUserListPopoverController {
	if (_currentUserListPopoverController.popoverVisible)
		[_currentUserListPopoverController dismissPopoverAnimated:YES];
}

#pragma mark -

- (UIViewController *) detailViewController {
	if (!_currentUserListViewController) {
		if (_membersNeedSorted)
			[self _sortMembers];

		_currentUserListViewController = [[CQChatUserListViewController alloc] init];
		_currentUserListViewController.users = _orderedMembers;
		_currentUserListViewController.room = self.room;
	}

	return _currentUserListViewController;
}

- (void) detailViewDidHide:(BOOL) animated {
	id old = _currentUserListViewController;
	_currentUserListViewController = nil;
	[old release];
}

#pragma mark -

- (UIActionSheet *) actionSheet {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	if (self.available)
		sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Leave Chat Room", @"Leave Chat Room button title")];
	else [sheet addButtonWithTitle:NSLocalizedString(@"Join Chat Room", @"Join Chat Room button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	return [sheet autorelease];
}

#pragma mark -

- (BOOL) handleTopicCommandWithArguments:(NSString *) arguments {
	if (![arguments stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length) {
		[self _displayCurrentTopicOnlyIfSet:NO];
		return YES;
	}

	return NO;
}

#pragma mark -

- (NSArray *) chatInputBar:(CQChatInputBar *) inputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range {
	NSMutableArray *completions = [[NSMutableArray alloc] init];

	if ([word hasPrefix:@"/"]) {
		static NSArray *commands;
		if (!commands) commands = [[NSArray alloc] initWithObjects:@"/me", @"/msg", @"/nick", @"/join", @"/away", @"/topic", @"/kick", @"/ban", @"/kickban", @"/mode", @"/op", @"/voice", @"/halfop", @"/quiet", @"/deop", @"/devoice", @"/dehalfop", @"/dequiet", @"/unban", @"/bankick", @"/cycle", @"/hop", nil];

		for (NSString *command in commands) {
			if ([command hasCaseInsensitivePrefix:word] && ![command isCaseInsensitiveEqualToString:word])
				[completions addObject:command];
			if (completions.count >= 10)
				break;
		}
	}

	if (word.length >= 2 && completions.count < 10) {
		if (_membersNeedSorted)
			[self _sortMembers];

		for (MVChatUser *member in _orderedMembers) {
			NSString *nickname = (range.location ? member.nickname : [member.nickname stringByAppendingString:@":"]);
			if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
				[completions addObject:nickname];
			if (completions.count >= 10)
				break;
		}
	}

	if (completions.count < 10)
		[completions addObjectsFromArray:[super chatInputBar:inputBar completionsForWordWithPrefix:word inRange:range]];

	return [completions autorelease];
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

#pragma mark -

- (NSString *) _markupForUser:(MVChatUser *) user {
	return [NSString stringWithFormat:@"<span class=\"user\">%@</span>", [user.nickname stringByEncodingXMLSpecialCharactersAsEntities]];
}

- (NSString *) _markupForMemberUser:(MVChatUser *) user {
	return [NSString stringWithFormat:@"<span class=\"member user\">%@</span>", [user.nickname stringByEncodingXMLSpecialCharactersAsEntities]];
}

- (void) _displayCurrentTopicOnlyIfSet:(BOOL) onlyIfSet {
	NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:onlyIfSet], @"onlyIfSet", self.room.topicAuthor, @"author", nil];
	[self _processMessageData:self.room.topic target:self action:@selector(_displayProcessedTopic:) userInfo:context];
}

- (void) _displayProcessedTopic:(CQProcessChatMessageOperation *) operation {
	NSString *topicString = operation.processedMessageAsHTML;
	BOOL onlyIfSet = [[operation.userInfo objectForKey:@"onlyIfSet"] boolValue];

	MVChatUser *user = [operation.userInfo objectForKey:@"author"];
	if (user.localUser && topicString.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"Current chat topic is \"%@\", set by you.", "Current topic set by you event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, topicString] withIdentifier:@"topic"];
	} else if (user && topicString.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"Current chat topic is \"%@\", set by %@.", "Current topic event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, topicString, [self _markupForMemberUser:user]] withIdentifier:@"topic"];
	} else if (topicString.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"Current chat topic is \"%@\".", "Current topic with no user event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, topicString] withIdentifier:@"topic"];
	} else if (!onlyIfSet) {
		[self addEventMessage:NSLocalizedString(@"No chat topic is set.", "No chat topic event message") withIdentifier:@"topic"];
	}
}

- (void) _sortMembers {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"])
		[_orderedMembers sortUsingFunction:sortMembersByStatus context:self];
	else [_orderedMembers sortUsingFunction:sortMembersByNickname context:self];

	_membersNeedSorted = NO;
}

- (void) _didConnect:(NSNotification *) notification {
	_parting = NO;

	if (!_joined)
		return;

	if (self.room.modes & MVChatRoomInviteOnlyMode)
		return;

	[self.room performSelector:@selector(join) withObject:nil afterDelay:0.];
}

- (void) _didDisconnect:(NSNotification *) notification {
	if (_joined)
		[super _didDisconnect:notification];

	_parting = NO;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatRoomTopicChangedNotification object:nil];

	[self _updateRightBarButtonItemAnimated:YES];
}

- (void) _partedRoom:(NSNotification *) notification {
	[self addEventMessage:NSLocalizedString(@"You left the room.", "Left room event message") withIdentifier:@"parted"];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatRoomTopicChangedNotification object:nil];

	[self _updateRightBarButtonItemAnimated:YES];

	[_orderedMembers removeAllObjects];
	_membersNeedSorted = NO;

	_parting = NO;
	_joined = NO;
}

- (void) _displayProcessedKickReason:(CQProcessChatMessageOperation *) operation {
	NSString *reason = operation.processedMessageAsHTML;
	MVChatUser *user = [operation.userInfo objectForKey:@"byUser"];

	if (reason.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"You were kicked from the room by %@. (%@)", "You were kicked from the room with reason event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [self _markupForMemberUser:user], reason] withIdentifier:@"kicked"];
	} else {
		NSString *eventMessageFormat = [NSLocalizedString(@"You were kicked from the room by %@.", "You were kicked from the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [self _markupForMemberUser:user]] withIdentifier:@"kicked"];
	}
}

- (void) _kicked:(NSNotification *) notification {
	NSData *reasonData = [notification.userInfo objectForKey:@"reason"];
	MVChatUser *user = [notification.userInfo objectForKey:@"byUser"];

	[self _processMessageData:reasonData target:self action:@selector(_displayProcessedKickReason:) userInfo:notification.userInfo];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatRoomTopicChangedNotification object:nil];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoRejoinRoomsOnKick"]) {
		[self.room performSelector:@selector(join) withObject:nil afterDelay:5.];
		return;
	}

	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.tag = RejoinRoomAlertTag;
	alert.delegate = self;
	alert.title = NSLocalizedString(@"Kicked from Room", "Kicked from room alert title");
	alert.message = [NSString stringWithFormat:NSLocalizedString(@"You were kicked from \"%@\" by \"%@\" on \"%@\".", "Kicked from room alert message"), self.room.displayName, user.displayName, self.connection.displayName];

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	[alert addButtonWithTitle:NSLocalizedString(@"Rejoin", @"Rejoin alert button title")];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQVibrateOnHighlight"])
		[CQSoundController vibrate];

	[alert show];
	[alert release];
}

- (void) _displayTopicChange:(CQProcessChatMessageOperation *) operation {
	NSString *topicString = operation.processedMessageAsHTML;
	MVChatUser *user = [operation.userInfo objectForKey:@"author"];

	if (!topicString.length || !user)
		return;

	if (user.localUser) {
		NSString *eventMessageFormat = [NSLocalizedString(@"You changed the topic to \"%@\".", "You changed the room topic event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, topicString] withIdentifier:@"topicChanged"];
	} else {
		NSString *eventMessageFormat = [NSLocalizedString(@"%@ changed the topic to \"%@\".", "User changed the room topic event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [self _markupForMemberUser:user], topicString] withIdentifier:@"topicChanged"];
	}
}

- (void) _topicChanged:(NSNotification *) notification {
	NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys:self.room.topicAuthor, @"author", nil];
	[self _processMessageData:self.room.topic target:self action:@selector(_displayTopicChange:) userInfo:context];
}

- (void) _nicknameChanged:(NSNotification *) notification {
	NSString *eventMessageFormat = [NSLocalizedString(@"You are now known as %@.", "You changed nicknames event message") stringByEncodingXMLSpecialCharactersAsEntities];
	[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [self _markupForMemberUser:self.connection.localUser]] withIdentifier:@"newNickname"];
}

- (void) _memberNicknameChanged:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	if (![self.room hasUser:user])
		return;

	NSString *oldNickname = [notification.userInfo objectForKey:@"oldNickname"];
	NSString *eventMessageFormat = [NSLocalizedString(@"%@ is now known as %@.", "User changed nicknames event message") stringByEncodingXMLSpecialCharactersAsEntities];
	[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [oldNickname stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]] withIdentifier:@"memberNewNickname"];

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	NSUInteger originalIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (originalIndex == NSNotFound)
		return;

	[self _sortMembers];

	NSUInteger newIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (newIndex == originalIndex) {
		[_currentUserListViewController updateUserAtIndex:newIndex];
		return;
	}

	[_currentUserListViewController moveUserAtIndex:originalIndex toIndex:newIndex];
}

- (void) _memberModeChanged:(NSNotification *) notification {
	MVChatUser *user = [notification.userInfo objectForKey:@"who"];
	MVChatUser *byUser = [notification.userInfo objectForKey:@"by"];
	if (!user)
		return;

	NSString *message = nil;
	NSString *identifier = nil;
	unsigned long mode = [[notification.userInfo objectForKey:@"mode"] unsignedLongValue];
	BOOL enabled = [[notification.userInfo objectForKey:@"enabled"] boolValue];

	if (mode == MVChatRoomMemberFounderMode && enabled) {
		identifier = @"memberPromotedToFounder";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You promoted yourself to room founder.", "You gave ourself the room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"promotedToFounder";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were promoted to room founder by %@.", "You are now a room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"promotedToFounder";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to room founder by you.", "You gave user room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to room founder by %@.", "User is now a room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberFounderMode && !enabled) {
		identifier = @"memberDemotedFromFounder";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You demoted yourself from room founder.", "You removed our room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"demotedFromFounder";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were demoted from room founder by %@.", "You are no longer a room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"demotedFromFounder";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from room founder by you.", "You removed user's room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from room founder by %@.", "User is no longer a room founder mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberAdministratorMode && enabled) {
		identifier = @"memberPromotedToAdministrator";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You promoted yourself to Administrator.", "You gave ourself the room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"promotedToAdministrator";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were promoted to administrator by %@.", "You are now a room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"promotedToAdministrator";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to administrator by you.", "You gave user room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to administrator by %@.", "User is now a room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberAdministratorMode && !enabled) {
		identifier = @"memberDemotedFromAdministrator";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You demoted yourself from administrator.", "You removed our room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"demotedFromAdministrator";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were demoted from administrator by %@.", "You are no longer a room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"demotedFromAdministrator";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from administrator by you.", "You removed user's room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from administrator by %@.", "User is no longer a room administrator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberOperatorMode && enabled) {
		identifier = @"memberPromotedToOperator";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You promoted yourself to operator.", "You gave ourself the room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"promotedToOperator";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were promoted to operator by %@.", "You are now a room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"promotedToOperator";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to operator by you.", "You gave user room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to operator by %@.", "User is now a room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberOperatorMode && !enabled) {
		identifier = @"memberDemotedFromOperator";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You demoted yourself from operator.", "You removed our room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"demotedFromOperator";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were demoted from operator by %@.", "You are no longer a room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"demotedFromOperator";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from operator by you.", "You removed user's room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from operator by %@.", "User is no longer a room operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberHalfOperatorMode && enabled) {
		identifier = @"memberPromotedToHalfOperator";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You promoted yourself to half-operator.", "You gave ourself the room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"promotedToHalfOperator";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were promoted to half-operator by %@.", "You are now a room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"promotedToHalfOperator";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to half-operator by you.", "You gave user room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was promoted to half-operator by %@.", "User is now a room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberHalfOperatorMode && !enabled) {
		identifier = @"memberDemotedFromHalfOperator";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You demoted yourself from half-operator.", "You removed our room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"demotedFromHalfOperator";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were demoted from half-operator by %@.", "You are no longer a room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"demotedFromHalfOperator";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from half-operator by you.", "You removed user's room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was demoted from half-operator by %@.", "User is no longer a room half-operator mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberVoicedMode && enabled) {
		identifier = @"memberVoiced";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You gave yourself voice.", "You gave ourself special voice status to talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"voiced";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were granted voice by %@.", "You now have special voice status to talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"voiced";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was granted voice by you.", "You gave user special voice status to talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was granted voice by %@.", "User now has special voice status to talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberVoicedMode && !enabled) {
		identifier = @"memberDevoiced";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You removed voice from yourself.", "You removed our special voice status to talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"devoiced";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You had voice removed by %@.", "You no longer has special voice status and can't talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"devoiced";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ had voice removed by you.", "You removed user's special voice status and can't talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ had voice removed by %@.", "User no longer has special voice status and can't talk in moderated rooms mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberQuietedMode && enabled) {
		identifier = @"memberQuieted";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You quieted yourself.", "You quieted and can't talk ourself mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"quieted";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You were quieted by %@.", "You are now quieted and can't talk mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"quieted";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was quieted by you.", "You quieted someone else in the room mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ was quieted by %@.", "User was quieted by someone else in the room mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	} else if (mode == MVChatRoomMemberQuietedMode && !enabled) {
		identifier = @"memberDequieted";
		if (user.localUser && byUser.localUser) {
			message = [NSLocalizedString(@"You made yourself no longer quieted.", "You are no longer quieted and can talk ourself mode event message") stringByEncodingXMLSpecialCharactersAsEntities];
			identifier = @"dequieted";
		} else if (user.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"You are no longer quieted, thanks to %@.", "You are no longer quieted and can talk mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:byUser]];
			identifier = @"dequieted";
		} else if (byUser.localUser) {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ is no longer quieted because of you.", "a user is no longer quieted because of us mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user]];
		} else {
			message = [NSString stringWithFormat:[NSLocalizedString(@"%@ is no longer quieted because of %@.", "User is no longer quieted because of someone else in the room mode event message") stringByEncodingXMLSpecialCharactersAsEntities], [self _markupForMemberUser:user], [self _markupForMemberUser:byUser]];
		}
	}

	[self addEventMessageAsHTML:message withIdentifier:identifier];

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	NSUInteger originalIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (originalIndex == NSNotFound)
		return;

	[self _sortMembers];

	NSUInteger newIndex = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (newIndex == originalIndex) {
		[_currentUserListViewController updateUserAtIndex:newIndex];
		return;
	}

	[_currentUserListViewController moveUserAtIndex:originalIndex toIndex:newIndex];
}

- (void) _memberBanned:(NSNotification *) notification {
	if (!_banListSynced) return;

	MVChatUser *user = [notification.userInfo objectForKey:@"byUser"];
	MVChatUser *bannedUser = [notification.userInfo objectForKey:@"user"];

	if (user.localUser) {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"You set a ban on %@.", "You set a ban in the room event message"), bannedUser.description];
		[self addEventMessage:message withIdentifier:@"memberBanned"];
	} else {
		NSString *eventMessageFormat = [NSLocalizedString(@"%@ set a ban on %@.", "User set a ban in the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [self _markupForMemberUser:user], [bannedUser.description stringByEncodingXMLSpecialCharactersAsEntities]] withIdentifier:@"memberBanned"];
	}
}

- (void) _memberBanRemoved:(NSNotification *) notification {
	MVChatUser *user = [notification.userInfo objectForKey:@"byUser"];
	MVChatUser *bannedUser = [notification.userInfo objectForKey:@"user"];

	if (user.localUser) {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"You removed the ban on %@.", "You removed a ban in the room event message"), bannedUser.description];
		[self addEventMessage:message withIdentifier:@"banRemoved"];
	} else {
		NSString *eventMessageFormat = [NSLocalizedString(@"%@ removed the ban on %@.", "User removed a ban in the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, [self _markupForMemberUser:user], [bannedUser.description stringByEncodingXMLSpecialCharactersAsEntities]] withIdentifier:@"banRemoved"];
	}
}

- (void) _bannedMembersSynced:(NSNotification *) notification {
	_banListSynced = YES;
}

- (void) _membersSynced:(NSNotification *) notification {
	NSDictionary *userInfo = notification.userInfo;
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
	MVChatUser *user = [notification.userInfo objectForKey:@"user"];

	if ([_orderedMembers indexOfObjectIdenticalTo:user] != NSNotFound)
		return;

	if (showJoinEvents) {
		NSString *eventMessageFormat = [NSLocalizedString(@"%@ joined the room.", "User has join the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
		NSString *userInformation = nil;
		
		if (showHostmasksOnJoin)
			userInformation = [NSString stringWithFormat:@"%@!%@@%@", [self _markupForMemberUser:user], user.username, user.address];
		else userInformation = [self _markupForMemberUser:user];

		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation] withIdentifier:@"memberJoined"];
	}

	[_orderedMembers addObject:user];

	if (!_currentUserListViewController) {
		_membersNeedSorted = YES;
		return;
	}

	[self _sortMembers];

	NSUInteger index = [_orderedMembers indexOfObjectIdenticalTo:user];
	[_currentUserListViewController insertUser:user atIndex:index];
}

- (void) _displayProcessedMemberPartReason:(CQProcessChatMessageOperation *) operation {
	NSString *reason = operation.processedMessageAsHTML;
	MVChatUser *user = [operation.userInfo objectForKey:@"user"];
	NSString *userInformation = nil;
	
	if (showHostmasksOnPart)
		userInformation = [NSString stringWithFormat:@"%@!%@@%@", [self _markupForUser:user], user.username, user.address];
	else userInformation = [self _markupForUser:user];

	if (reason.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"%@ left the room. (%@)", "User has left the room with reason event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation, reason] withIdentifier:@"memberParted"];
	} else {
		NSString *eventMessageFormat = [NSLocalizedString(@"%@ left the room.", "User has left the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation] withIdentifier:@"memberParted"];
	}
}

- (void) _memberParted:(NSNotification *) notification {
	MVChatUser *user = [notification.userInfo objectForKey:@"user"];

	if (showLeaveEvents) {
		NSData *reasonData = [notification.userInfo objectForKey:@"reason"];
		[self _processMessageData:reasonData target:self action:@selector(_displayProcessedMemberPartReason:) userInfo:notification.userInfo];
	}

	NSUInteger index = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (index == NSNotFound)
		return;

	[_orderedMembers removeObjectAtIndex:index];
	[_currentUserListViewController removeUserAtIndex:index];
}

- (void) _displayProcessedMemberKickReason:(CQProcessChatMessageOperation *) operation {
	NSString *reason = operation.processedMessageAsHTML;
	MVChatUser *user = [operation.userInfo objectForKey:@"user"];
	MVChatUser *byUser = [operation.userInfo objectForKey:@"byUser"];
	NSString *userInformation = nil;

	if (showHostmasksOnPart)
		userInformation = [NSString stringWithFormat:@"%@!%@@%@", [self _markupForUser:user], user.username, user.address];
	else userInformation = [self _markupForUser:user];

	if (byUser.localUser) {
		if (reason.length) {
			NSString *eventMessageFormat = [NSLocalizedString(@"You kicked %@ from the room. (%@)", "You kicked a user from the room with reason event message") stringByEncodingXMLSpecialCharactersAsEntities];
			[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation, reason] withIdentifier:@"memberKicked"];
		} else {
			NSString *eventMessageFormat = [NSLocalizedString(@"You kicked %@ from the room.", "You kicked a user from the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
			[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation] withIdentifier:@"memberKicked"];
		}
	} else {
		if (reason.length) {
			NSString *eventMessageFormat = [NSLocalizedString(@"%@ was kicked from the room by %@. (%@)", "A user was kicked from the room with reason event message") stringByEncodingXMLSpecialCharactersAsEntities];
			[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation, [self _markupForMemberUser:byUser], reason] withIdentifier:@"memberKicked"];
		} else {
			NSString *eventMessageFormat = [NSLocalizedString(@"%@ was kicked from the room by %@.", "A user was kicked from the room event message") stringByEncodingXMLSpecialCharactersAsEntities];
			[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, userInformation, [self _markupForMemberUser:byUser]] withIdentifier:@"memberKicked"];
		}
	}
}

- (void) _memberKicked:(NSNotification *) notification {
	NSData *reasonData = [notification.userInfo objectForKey:@"reason"];
	[self _processMessageData:reasonData target:self action:@selector(_displayProcessedMemberKickReason:) userInfo:notification.userInfo];

	MVChatUser *user = [notification.userInfo objectForKey:@"user"];
	NSUInteger index = [_orderedMembers indexOfObjectIdenticalTo:user];
	if (index == NSNotFound)
		return;

	[_orderedMembers removeObjectAtIndex:index];
	[_currentUserListViewController removeUserAtIndex:index];
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {	
	if ((alertView.tag != ReconnectAlertTag && alertView.tag != RejoinRoomAlertTag) || buttonIndex == alertView.cancelButtonIndex)
		return [super alertView:alertView clickedButtonAtIndex:buttonIndex];

	if (alertView.tag == ReconnectAlertTag)
		[self.connection connectAppropriately];

	[self.room join];
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (buttonIndex == 0) {
		if (buttonIndex == actionSheet.destructiveButtonIndex)
			[self part];
		else [self join];
	}
}

#pragma mark -

- (void) _updateRightBarButtonItemAnimated:(BOOL) animated {
	UIBarButtonItem *item = nil;
	BOOL isConnected = self.connection.connected;
	
	if (isConnected) {
		item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"members.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showMembers)];
		item.accessibilityLabel = NSLocalizedString(@"Members List", @"Voiceover members list label");
	} else {
		item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Join", "Join button title") style:UIBarButtonItemStyleDone target:self action:@selector(join)];	
		item.accessibilityLabel = NSLocalizedString(@"Join Room", @"Voiceover join room label");
	}

	[self.navigationItem setRightBarButtonItem:item animated:animated];

	[item release];
}

- (void) _showCantSendMessagesWarningForCommand:(BOOL) command {
	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	if (command) alert.title = NSLocalizedString(@"Can't Send Command", @"Can't send command alert title");
	else alert.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (self.connection.status == MVChatConnectionConnectingStatus) {
		alert.message = NSLocalizedString(@"You are currently connecting,\nyou should join the room shortly.", @"Can't send message to room because server is connecting alert message");
	} else if (!self.connection.connected) {
		alert.tag = ReconnectAlertTag;
		alert.message = NSLocalizedString(@"You are currently disconnected,\nreconnect and try again.", @"Can't send message to room because server is disconnected alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];
	} else if (!self.room.joined) {
		alert.tag = RejoinRoomAlertTag;
		alert.message = NSLocalizedString(@"You are not a room member,\nrejoin and try again.", @"Can't send message to room because not a member alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Join", @"Join button title")];
	} else {
		[alert release];
		return;
	}

	[alert show];
	[alert release];
}
@end
