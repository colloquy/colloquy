#import "JVChatController.h"
#import "JVTabbedChatWindowController.h"
#import "MVConnectionsController.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVNotificationController.h"
#import "MVBuddyListController.h"
#import "JVBuddy.h"
#import "JVChatMessage.h"
#import "MVTextView.h"
#import "JVStyleView.h"
#import "NSAttributedStringMoreAdditions.h"
#import "NSRegularExpressionAdditions.h"
#import "MVChatUserAdditions.h"
#import "MVApplicationController.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const MVFavoritesListDidUpdateNotification = @"MVFavoritesListDidUpdateNotification";

@interface JVChatRoomPanel (Private)
// TODO: This method is overwriting a method of superclass category JVDirectChatPanel+Private, undefined behavior.
- (void) _didDisconnect:(NSNotification *) notification; // overwrite
- (void) _partedRoom:(NSNotification *) notification;
- (void) _roomModeChanged:(NSNotification *) notification;
- (void) _selfNicknameChanged:(NSNotification *) notification;
- (void) _memberNicknameChanged:(NSNotification *) notification;
- (void) _memberJoined:(NSNotification *) notification;
- (void) _memberParted:(NSNotification *) notification;
- (void) _userBricked:(NSNotification *) notification;
- (void) _kicked:(NSNotification *) notification;
- (void) _memberKicked:(NSNotification *) notification;
- (void) _memberBanned:(NSNotification *) notification;
- (void) _memberBanRemoved:(NSNotification *) notification;
- (void) _memberModeChanged:(NSNotification *) notification;
- (void) _membersSynced:(NSNotification *) notification;
- (void) _bannedMembersSynced:(NSNotification *) notification;
- (void) _topicChanged:(nullable id) sender;
- (void) _didClearDisplay:(NSNotification *) notification;

- (NSInteger) _roomIndexInFavoritesMenu;
@end

#pragma mark -

@implementation JVChatRoomPanel
- (instancetype) initWithTarget:(id) target {
	if( ( self = [super initWithTarget:target] ) ) {
		_sortedMembers = [[NSMutableArray alloc] initWithCapacity:100];
		_preferredTabCompleteNicknames = [[NSMutableArray alloc] initWithCapacity:10];
		_nextMessageAlertMembers = [[NSMutableSet alloc] initWithCapacity:5];
		_cantSendMessages = YES;
		_kickedFromRoom = NO;
		_banListSynced = NO;
		_joinCount = 0;

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _partedRoom: ) name:MVChatRoomPartedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _kicked: ) name:MVChatRoomKickedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberJoined: ) name:MVChatRoomUserJoinedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberParted: ) name:MVChatRoomUserPartedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberKicked: ) name:MVChatRoomUserKickedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatRoomModesChangedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberModeChanged: ) name:MVChatRoomUserModeChangedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberBanned: ) name:MVChatRoomUserBannedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberBanRemoved: ) name:MVChatRoomUserBanRemovedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _membersSynced: ) name:MVChatRoomMemberUsersSyncedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _bannedMembersSynced: ) name:MVChatRoomBannedUsersSyncedNotification object:target];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _memberNicknameChanged: ) name:MVChatUserNicknameChangedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _userBricked: ) name:MVChatRoomUserBrickedNotification object:target];
	}

	return self;
}

- (void) awakeFromNib {
	[super awakeFromNib];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didClearDisplay: ) name:JVStyleViewDidClearNotification object:display];

	[display setBodyTemplate:@"chatRoom"];
	[display addBanner:@"roomTopicBanner"];
}

- (void) dealloc {
	[self partChat:nil];

	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter chatCenter] removeObserver:self];

	[_sortedMembers makeObjectsPerformSelector:@selector( _detach )];
	[_nextMessageAlertMembers makeObjectsPerformSelector:@selector( _detach )];
}

#pragma mark -
#pragma mark Chat View Protocol Support

- (void) setWindowController:(nullable JVChatWindowController *) controller {
	[super setWindowController:controller];
	if( [[self preferenceForKey:@"expanded"] boolValue] )
		[controller performSelector:@selector( expandListItem: ) withObject:self afterDelay:0.];
}

- (void) willDispose {
	[super willDispose];
	[self partChat:nil];
}

#pragma mark -

- (NSString *) title {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowFullRoomNames"] )
		return [(MVChatRoom *)[self target] name];
	return [[self target] displayName];
}

- (NSString *) windowTitle {
	return [NSString stringWithFormat:@"%@ (%@)", [self title], [[self connection] server]];
}

- (nullable NSString *) information {
	if( _kickedFromRoom )
		return NSLocalizedString( @"kicked out", "chat room kicked status line in drawer" );
	if( ! [_sortedMembers count] )
		return NSLocalizedString( @"joining...", "joining status info line in drawer" );
	if( [[self connection] isConnected] ) {
		if( [[[MVConnectionsController defaultController] connectedConnections] count] == 1 ) {
			if( [_sortedMembers count] > 1 )
				return [NSString stringWithFormat:NSLocalizedString( @"%d members", "number of room members information line" ), [_sortedMembers count]];
			else if( [_sortedMembers count] == 1 )
				return NSLocalizedString( @"1 member", "one room member information line" );
		} else return [[self connection] server];
	}
	return NSLocalizedString( @"disconnected", "disconnected status info line in drawer" );
}

- (NSString *) toolTip {
	NSString *messageCount = @"";
	NSString *memberCount = @"";

	if( [self newMessagesWaiting] == 0 ) messageCount = NSLocalizedString( @"no messages waiting", "no messages waiting room tooltip" );
	else if( [self newMessagesWaiting] == 1 ) messageCount = NSLocalizedString( @"1 message waiting", "one message waiting room tooltip" );
	else messageCount = [NSString stringWithFormat:NSLocalizedString( @"%d messages waiting", "messages waiting room tooltip" ), [self newMessagesWaiting]];

	if( [_sortedMembers count] == 1 ) memberCount = NSLocalizedString( @"1 member", "one member room status info tooltip" );
	else memberCount = [NSString stringWithFormat:NSLocalizedString( @"%d members", "number of members room status info tooltip" ), [_sortedMembers count]];

	return [NSString stringWithFormat:@"%@ (%@)\n%@\n%@", _target, [[self connection] server], memberCount, messageCount];
}

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Chat Room %@ (%@)", [self target], [[self connection] server]];
}

#pragma mark -

- (NSImage *) icon {
	return [NSImage imageNamed:@"roomIcon"];
}

- (nullable NSImage *) statusImage {
	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] ) {
		if( _isActive && [[[self view] window] isKeyWindow] ) {
			_newMessageCount = 0;
			_newHighlightMessageCount = 0;
			[(MVApplicationController *)[NSApp delegate] updateDockTile];
			return nil;
		}

		return ( [_waitingAlerts count] ? [NSImage imageNamed:NSImageNameCaution] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"roomTabNewHighlightMessage"] : [NSImage imageNamed:@"roomTabNewMessage"] ) : nil ) );
	}

	return [super statusImage];
}

- (BOOL) isEnabled {
	return [[self target] isJoined];
}

#pragma mark -

- (NSUInteger) numberOfChildren {
	return [_sortedMembers count];
}

- (id) childAtIndex:(NSUInteger) index {
	return _sortedMembers[index];
}

- (nullable NSArray *) children {
	return _sortedMembers;
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""];
	[item setTarget:_windowController];
	[menu addItem:item];

	if ([self _roomIndexInFavoritesMenu] != NSNotFound)
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Remove from Favorites", "add to favorites contextual menu") action:@selector( toggleFavorites: ) keyEquivalent:@""];
	else item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add to Favorites", "add to favorites contextual menu") action:@selector( toggleFavorites: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	if( [[[self windowController] allChatViewControllers] count] > 1 ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""];
		[item setRepresentedObject:self];
		[item setTarget:[JVChatController defaultController]];
		[menu addItem:item];
	}

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Auto Join", "auto join contextual menu") action:@selector( toggleAutoJoin: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	if( [[self target] isJoined] ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Leave Room", "leave room contextual menu item title" ) action:@selector( partChat: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	} else {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Rejoin Room", "rejoin room contextual menu item title" ) action:@selector( joinChat: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ignore Notifications", "lists whether or not notifications are enabled") action:@selector( toggleNotifications: ) keyEquivalent:@""];
	[item setEnabled:YES];
	[item setTarget:self];
	[menu addItem:item];

	return menu;
}

#pragma mark -

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return NO;
}

- (void) handleDraggedFile:(NSString *) path {
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( toggleFavorites: ) && [menuItem tag] == 10 ) {
		NSInteger favoritesIndex = [self _roomIndexInFavoritesMenu];

		if (favoritesIndex != NSNotFound)
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString( @"Remove \"%@ (%@)\"", "add to favorites contextual menu"), _target, [[self connection] server]]];
		else [menuItem setTitle:[NSString stringWithFormat:NSLocalizedString( @"Add \"%@ (%@)\"", "add to favorites contextual menu"), _target, [[self connection] server]]];
		[menuItem setTarget:self];
	} else if( [menuItem action] == @selector( toggleAutoJoin: ) ) {
		[menuItem setState:NSOffState];
		for( id object in [[MVConnectionsController defaultController] joinRoomsForConnection:[self connection]] )
			if( [_target isEqual:[[self connection] chatRoomWithName:(NSString *)object]] )
				[menuItem setState:NSOnState];
	}

	return [super validateMenuItem: menuItem];
}

#pragma mark -
#pragma mark Miscellaneous

- (IBAction) clearDisplay:(nullable id) sender {
	[display clear];
}

- (IBAction) toggleFavorites:(nullable id) sender {
	NSURL *appSupport = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
	appSupport = [[appSupport URLByAppendingPathComponent:@"Colloquy"] URLByAppendingPathComponent:@"Favorites"];
	appSupport = [appSupport URLByAppendingPathComponent:@"Favorites.plist" isDirectory:NO];
	NSMutableArray *favorites = [[NSMutableArray alloc] initWithContentsOfURL:appSupport];
	if (!favorites) {
		//fall-back to old location/method
		NSString *favoritesPath = [@"~/Library/Application Support/Colloquy/Favorites/Favorites.plist" stringByExpandingTildeInPath];
		favorites = [[NSMutableArray alloc] initWithContentsOfFile:favoritesPath];
	}
	if (!favorites)
		favorites = [[NSMutableArray alloc] init];

	NSInteger favoriteIndex = [self _roomIndexInFavoritesMenu];
	if (favoriteIndex != NSNotFound)
		[favorites removeObjectAtIndex:favoriteIndex];
	else [favorites addObject:@{@"target": [_target description], @"server": [[self connection] server], @"scheme": [[self connection] urlScheme]}];

	[favorites writeToURL:appSupport atomically:YES];

	[MVConnectionsController refreshFavoritesMenu];

	[[NSNotificationCenter chatCenter] postNotificationName:MVFavoritesListDidUpdateNotification object:self];
}

- (IBAction) toggleAutoJoin:(id) sender {
	NSMutableArray *rooms = [[[MVConnectionsController defaultController] joinRoomsForConnection:[self connection]] mutableCopy];
	if( [(NSMenuItem *)sender state] == NSOnState ) {
		for( id object in rooms )
			if( [_target isEqual:[[self connection] chatRoomWithName:(NSString *)object]] ) {
				[rooms removeObject:object];
				break;
			}
	} else [rooms addObject:[_target name]];

	[[MVConnectionsController defaultController] setJoinRooms:rooms forConnection:[self connection]];
}

- (IBAction) changeEncoding:(nullable id) sender {
	[super changeEncoding:sender];
	[[self target] setValue:@([self encoding]) forKey:@"encoding"];
	if( sender ) [self _topicChanged:nil];
}

#pragma mark -
#pragma mark Message Handling

- (void) handleRoomMessageNotification:(NSNotification *) notification {
	JVChatMessageType type = ( [[notification userInfo][@"notice"] boolValue] ? JVChatMessageNoticeType : JVChatMessageNormalType );
	[self addMessageToDisplay:[notification userInfo][@"message"] fromUser:[notification userInfo][@"user"] withAttributes:[notification userInfo] withIdentifier:[notification userInfo][@"identifier"] andType:type];
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message {
	JVChatRoomMember *member = [self chatRoomMemberForUser:[message sender]];
	if( member ) [message setSender:member];

	if( [message isHighlighted] && [message ignoreStatus] == JVNotIgnored ) {
		[_preferredTabCompleteNicknames removeObject:[[message sender] nickname]];
		[_preferredTabCompleteNicknames insertObject:[[message sender] nickname] atIndex:0];
	}

	if( [message ignoreStatus] == JVNotIgnored && [[message sender] respondsToSelector:@selector( isLocalUser )] && ! [[message sender] isLocalUser] ) {
		NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
		context[@"title"] = [NSString stringWithFormat:NSLocalizedString( @"%@ Room Activity", "room activity bubble title" ), [self title]];
		if( [self newMessagesWaiting] == 1 ) context[@"title"] = [NSString stringWithFormat:NSLocalizedString( @"%@ has a message waiting\nfrom %@.", "new single room message bubble text" ), [self title], [member displayName]];
		else context[@"title"] = [NSString stringWithFormat:NSLocalizedString( @"%@ has %d messages waiting.\nLast from %@", "new room messages bubble text" ), [self title], [self newMessagesWaiting], [member displayName]];
		context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@", "room activity bubble message" ), [message bodyAsPlainText]];
		context[@"image"] = [NSImage imageNamed:@"roomIcon"];
		context[@"coalesceKey"] = [[self windowTitle] stringByAppendingString:@"JVChatRoomActivity"];
		context[@"target"] = self;
		context[@"action"] = NSStringFromSelector( @selector( activate: ) );
		context[@"subtitle"] = [NSString stringWithFormat:@"%@ — %@: %@", [member displayName], self.target, [message bodyAsPlainText]];
		[self performNotification:@"JVChatRoomActivity" withContextInfo:context];
	}

	if( [message ignoreStatus] == JVNotIgnored && [_nextMessageAlertMembers containsObject:[message sender]] ) {
		NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
		context[@"title"] = [NSString stringWithFormat:NSLocalizedString( @"%@ Replied", "member replied bubble title" ), [[message sender] title]];
		context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@ has possibly replied to your message.", "new room messages bubble text" ), [[message sender] title]];
		context[@"image"] = [NSImage imageNamed:@"activityNewImportant"];
		context[@"target"] = self;
		context[@"action"] = NSStringFromSelector( @selector( activate: ) );
		context[@"subtitle"] = [NSString stringWithFormat:@"%@: %@", self.target, [message bodyAsPlainText]];
		[self performNotification:@"JVChatReplyAfterAddressing" withContextInfo:context];

		[_nextMessageAlertMembers removeObject:[message sender]];
	}


	NSString *plainText = [message bodyAsPlainText];
	for( NSTextCheckingResult *match in [_membersRegex cq_matchesInString:plainText] ) {
		NSRange foundRange = [match range];
		// don't highlight nicks in the middle of a link
		if( ! [[message body] attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL] ) {
			NSMutableSet *classes = [NSMutableSet setWithSet:[[message body] attribute:@"CSSClasses" atIndex:foundRange.location effectiveRange:NULL]];
			[classes addObject:@"member"];
			[[message body] addAttribute:@"CSSClasses" value:[NSSet setWithSet:classes] range:foundRange];
		}
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processIncomingMessage:inView: )];
	MVAddUnsafeUnretainedAddress(message, 2);
	MVAddUnsafeUnretainedAddress(self, 3);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (void) sendMessage:(JVMutableChatMessage *) message {
	[super sendMessage:message];

	NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"^(.*?)[:;,-]" options:NSRegularExpressionCaseInsensitive error:nil];
	NSString *bodyAsPlainText = [message bodyAsPlainText];
	NSTextCheckingResult *match = [regex firstMatchInString:bodyAsPlainText options:0 range:NSMakeRange( 0, bodyAsPlainText.length) ];
	if( match && [match numberOfRanges] ) {
		JVChatRoomMember *mbr = [self firstChatRoomMemberWithName:[bodyAsPlainText substringWithRange:[match rangeAtIndex:1]]];
		if( mbr ) [_nextMessageAlertMembers addObject:mbr];
	}
}

#pragma mark -
#pragma mark Join & Part Handling

- (void) joined {
	_banListSynced = NO;

	[_sortedMembers makeObjectsPerformSelector:@selector( _detach )];
	[_sortedMembers removeAllObjects];

	[_preferredTabCompleteNicknames removeAllObjects];

	[_nextMessageAlertMembers makeObjectsPerformSelector:@selector( _detach )];
	[_nextMessageAlertMembers removeAllObjects];

	for( MVChatUser *user in [[self target] memberUsers] ) {
		JVChatRoomMember *member = [[JVChatRoomMember alloc] initWithRoom:self andUser:user];
		[_sortedMembers addObject:member];
	}

	[self resortMembers];

	_cantSendMessages = NO;
	_kickedFromRoom = NO;

	[_windowController reloadListItem:self andChildren:YES];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomPanel * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( joinedRoom: )];
	MVAddUnsafeUnretainedAddress(self, 2);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatRoomTopicChangedNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _selfNicknameChanged: ) name:MVChatConnectionNicknameAcceptedNotification object:[self connection]];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _topicChanged: ) name:MVChatRoomTopicChangedNotification object:[self target]];

	[self _topicChanged:nil];

	if( _joinCount ) [self addEventMessageToDisplay:NSLocalizedString( @"You rejoined the room.", "rejoined the room status message" ) withName:@"rejoined" andAttributes:nil];
	_joinCount++;
}

- (void) parting {
	if( [[self target] isJoined] ) {
		_cantSendMessages = YES;

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomPanel * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( partingFromRoom: )];
		MVAddUnsafeUnretainedAddress(self, 2);

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

		[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:nil];
		[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatRoomTopicChangedNotification object:nil];
	}
}

#pragma mark -

- (void) joinChat:(nullable id) sender {
	if( ! [[self connection] isConnected] )
		[[self connection] connect];
	[[self target] join];
}

- (void) partChat:(nullable id) sender {
	if( [[self target] isJoined] ) {
		[self parting];
		[[self target] part];
	}
}

#pragma mark -
#pragma mark User List Access

- (NSSet *) chatRoomMembersWithName:(NSString *) name {
	if( ! [name length] ) return nil;

	NSMutableSet *ret = [[NSMutableSet alloc] init];
	JVChatRoomMember *member = nil;

	for( member in _sortedMembers ) {
		if( [[member nickname] caseInsensitiveCompare:name] == NSOrderedSame ) {
			[ret addObject:member];
		} else if( [[member realName] caseInsensitiveCompare:name] == NSOrderedSame ) {
			[ret addObject:member];
		} else if( [[member title] caseInsensitiveCompare:name] == NSOrderedSame ) {
			[ret addObject:member];
		}
	}

	return [NSSet setWithSet:ret];
}

- (JVChatRoomMember *) firstChatRoomMemberWithName:(NSString *) name {
	if( ! [name length] ) return nil;

	JVChatRoomMember *member = nil;

	for( member in _sortedMembers ) {
		if( [[member nickname] caseInsensitiveCompare:name] == NSOrderedSame ) {
			return member;
		} else if( [[member title] caseInsensitiveCompare:name] == NSOrderedSame ) {
			return member;
		}
	}

	return nil;
}

- (JVChatRoomMember *) chatRoomMemberForUser:(MVChatUser *) user {
	if( ! user ) return nil;

	JVChatRoomMember *member = nil;

	for( member in _sortedMembers )
		if( [[member user] isEqualToChatUser:user] )
			return member;

	return nil;
}

- (JVChatRoomMember *) localChatRoomMember {
	JVChatRoomMember *member = nil;

	for( member in _sortedMembers )
		if( [[member user] isLocalUser] )
			return member;

	return nil;
}

- (void) resortMembers {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] ) {
		[_sortedMembers sortUsingSelector:@selector( compareUsingStatus: )];
	} else [_sortedMembers sortUsingSelector:@selector( compare: )];

	static NSCharacterSet *escapeSet = nil;
	if (!escapeSet)
		escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];

	NSMutableString *regexEscapedNicknames = [[NSMutableString alloc] init];
	for( JVChatRoomMember *member in _sortedMembers ) {
		NSMutableString *escapedName = [[member nickname] mutableCopy];
		[escapedName escapeCharactersInSet:escapeSet];
		[regexEscapedNicknames appendFormat:@"%@|", escapedName];
	}

	if( regexEscapedNicknames.length )
		[regexEscapedNicknames deleteCharactersInRange:NSMakeRange(regexEscapedNicknames.length - 1, 1)];

	NSString *pattern = [[NSString alloc] initWithFormat:@"(?<=^|\\s|[^\\w])%@(?=$|\\s|[^\\w])", regexEscapedNicknames];
	_membersRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];

	[_windowController reloadListItem:self andChildren:YES];
}

#pragma mark -
#pragma mark WebKit Support

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	// valid member links: "member:xenon" or "member:identifier:qI+rEcbsuX1T0tNbi6mM+A=="
	if( [[element[WebElementLinkURLKey] scheme] isEqualToString:@"member"] ) {
		NSString *resource = [[element[WebElementLinkURLKey] resourceSpecifier] stringByDecodingIllegalURLCharacters];
		BOOL specific = [resource hasPrefix:@"identifier:"];
		NSString *nick = [resource substringFromIndex:( specific ? 11 : 0 )];
		JVChatRoomMember *mbr = nil;
		MVChatUser *user = nil;

		if( specific ) user = [[self connection] chatUserWithUniqueIdentifier:nick];
		else user = [[self firstChatRoomMemberWithName:nick] user];

		if( ! user ) user = [[[self connection] chatUsersWithNickname:nick] anyObject];

		if( user ) mbr = [self chatRoomMemberForUser:user];
		else mbr = [self firstChatRoomMemberWithName:nick];

		NSMutableArray *ret = [[NSMutableArray alloc] init];
		NSMenuItem *item = nil;

		if( mbr ) {
			for( item in [[mbr menu] itemArray] ) {
				item = [item copy];
				[ret addObject:item];
			}
		} else if( user ) {
			for( item in [user standardMenuItems] )
				[ret addObject:item];
		}

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
		if( mbr ) {
			MVAddUnsafeUnretainedAddress(mbr, 2);
		} else {
			MVAddUnsafeUnretainedAddress(user, 2);
		}
		MVAddUnsafeUnretainedAddress(self, 3);

		NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
		if( [results count] ) {
			[ret addObject:[NSMenuItem separatorItem]];

			NSArray *items = nil;
			for( items in results ) {
				if( ![items conformsToProtocol:@protocol(NSFastEnumeration)] ) continue;

				for( item in items )
					if( [item isKindOfClass:[NSMenuItem class]] ) [ret addObject:item];
			}

			if( [[ret lastObject] isSeparatorItem] )
				[ret removeObjectIdenticalTo:[ret lastObject]];
		}

		return ret;
	}

	return [super webView:sender contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	// valid member links: "member:xenon" or "member:identifier:qI+rEcbsuX1T0tNbi6mM+A=="
	if( [[actionInformation[WebActionOriginalURLKey] scheme] isEqualToString:@"member"] ) {
		NSString *resource = [[actionInformation[WebActionOriginalURLKey] resourceSpecifier] stringByDecodingIllegalURLCharacters];
		BOOL specific = [resource hasPrefix:@"identifier:"];
		NSString *nick = [resource substringFromIndex:( specific ? 11 : 0 )];
		MVChatUser *user = nil;

		if( specific ) user = [[self connection] chatUserWithUniqueIdentifier:nick];
		else user = [[self firstChatRoomMemberWithName:nick] user];

		if( ! user ) user = [[[self connection] chatUsersWithNickname:nick] anyObject];

		if( user && ! [user isLocalUser] )
			[[JVChatController defaultController] chatViewControllerForUser:user ifExists:NO];

		[listener ignore];
	} else {
		[super webView:sender decidePolicyForNavigationAction:actionInformation request:request frame:frame decisionListener:listener];
	}
}

#pragma mark -
#pragma mark TextView/Input Support

- (NSArray *) textView:(NSTextView *) textView stringCompletionsForPrefix:(NSString *) prefix {
	NSMutableArray *possibleCompletion = [[NSMutableArray alloc] init];

	if( [prefix isEqualToString:@""] ) {
		if( [_preferredTabCompleteNicknames count] )
			[possibleCompletion addObject:_preferredTabCompleteNicknames[0]];
		return possibleCompletion;
	}

	for( NSString *name in _preferredTabCompleteNicknames )
		if( [name rangeOfString:prefix options:( NSCaseInsensitiveSearch | NSAnchoredSearch )].location == NSOrderedSame )
			[possibleCompletion addObject:name];

	for( JVChatRoomMember *member in _sortedMembers ) {
		NSString *name = [member nickname];
		if( ! [possibleCompletion containsObject:name] && [name rangeOfString:prefix options:( NSCaseInsensitiveSearch | NSAnchoredSearch )].location == NSOrderedSame )
			[possibleCompletion addObject:name];
	}

	static NSArray *commands;
	if (!commands) commands = @[@"/topic ", @"/kick ", @"/ban ", @"/kickban ", @"/op ", @"/voice ", @"/halfop ", @"/quiet ", @"/deop ", @"/devoice ", @"/dehalfop ", @"/dequiet ", @"/unban ", @"/bankick ", @"/cycle ", @"/hop ", @"/me ", @"/msg ", @"/nick ", @"/away ", @"/say ", @"/raw ", @"/quote ", @"/join ", @"/quit ", @"/disconnect ", @"/query ", @"/umode ", @"/globops ", @"/google ", @"/part "];

	for( NSString *name in commands )
		if ([name hasCaseInsensitivePrefix:prefix])
			[possibleCompletion addObject:name];

	for ( MVChatRoom* room in self.connection.knownChatRooms )
	{
		if ( [room.uniqueIdentifier hasCaseInsensitivePrefix:prefix] )
			[possibleCompletion addObject:room.uniqueIdentifier];
		if ( [room.displayName hasCaseInsensitivePrefix:prefix] )
			[possibleCompletion addObject:room.displayName];
	}

	return possibleCompletion;
}

- (void) textView:(NSTextView *) textView selectedCompletion:(NSString *) completion fromPrefix:(NSString *) prefix {
	if( [completion isEqualToString:[[[self connection] localUser] nickname]] ) return;
	[_preferredTabCompleteNicknames removeObject:completion];
	[_preferredTabCompleteNicknames insertObject:completion atIndex:0];
}

- (NSArray *) textView:(NSTextView *) textView completions:(NSArray *) words forPartialWordRange:(NSRange) charRange indexOfSelectedItem:(NSInteger *) index {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSString *search = [[[send textStorage] string] substringWithRange:charRange];
	NSMutableArray *ret = [[NSMutableArray alloc] init];
	NSString *suffix = ( ! ( [event modifierFlags] & NSAlternateKeyMask ) ? ( charRange.location == 0 ? @": " : @" " ) : @"" );
	NSUInteger length = [search length];

	for( JVChatRoomMember *member in _sortedMembers ) {
		if (!length) break;

		NSString *name = [member nickname];

		if( length <= [name length] && [search caseInsensitiveCompare:[name substringToIndex:length]] == NSOrderedSame )
			[ret addObject:[name stringByAppendingString:suffix]];
	}

	unichar chr = 0;
	if( [[event charactersIgnoringModifiers] length] )
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];

	if( chr != NSTabCharacter ) [ret addObjectsFromArray:words];
	return ret;
}

#pragma mark -
#pragma mark Toolbar Support
- (NSString *) toolbarIdentifier {
	return @"Chat Room";
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarDefaultItemIdentifiers:toolbar]];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	[list addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[list addObject:JVToolbarMarkItemIdentifier];
	[list addObject:JVToolbarClearScrollbackItemIdentifier];
	[list addObject:NSToolbarSeparatorItemIdentifier];
	[list addObject:JVToolbarQuickSearchItemIdentifier];
	return list;
}
@end

#pragma mark -

@implementation JVChatRoomPanel (Private)

- (void) _didDisconnect:(NSNotification *) notification {
	_kickedFromRoom = NO;
	[super _didDisconnect:notification];
	[_windowController reloadListItem:self andChildren:YES];

	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatRoomTopicChangedNotification object:nil];
}

- (void) _partedRoom:(NSNotification *) notification {
	if( ! [[self connection] isConnected] ) return;

	_cantSendMessages = NO;

	NSMutableAttributedString *rstring = [self _convertRawMessage:[notification userInfo][@"reason"]];
	[self addEventMessageToDisplay:NSLocalizedString( @"You left the room.", "you parted the room status message" ) withName:@"parted" andAttributes:@{@"reason": ( rstring ? (id) rstring : (id) [NSNull null] )}];
}

- (void) _roomModeChanged:(NSNotification *) notification {
	MVChatUser *user = [notification userInfo][@"by"];

	if( ! user ) return;
	if( [[self connection] type] == MVChatConnectionIRCType && [[user nickname] rangeOfString:@"."].location != NSNotFound )
		return; // a server telling us the initial modes when we join, ignore these on IRC connections

	JVChatRoomMember *mbr = [self chatRoomMemberForUser:user];

	NSUInteger changedModes = [[notification userInfo][@"changedModes"] unsignedIntValue];
	NSUInteger newModes = [[self target] modes];

	while( changedModes ) {
		NSString *message = nil;
		NSString *mode = nil;
		id parameter = nil;

		if( changedModes & MVChatRoomPrivateMode ) {
			changedModes &= ~MVChatRoomPrivateMode;
			mode = @"chatRoomPrivateMode";
			if( newModes & MVChatRoomPrivateMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room private.", "private room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room private.", "someone else private room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room public.", "public room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room public.", "someone else public room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomSecretMode ) {
			changedModes &= ~MVChatRoomSecretMode;
			mode = @"chatRoomSecretMode";
			if( newModes & MVChatRoomSecretMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room secret.", "secret room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room secret.", "someone else secret room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer a secret.", "no longer secret room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer a secret.", "someone else no longer secret room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomInviteOnlyMode ) {
			changedModes &= ~MVChatRoomInviteOnlyMode;
			mode = @"chatRoomInviteOnlyMode";
			if( newModes & MVChatRoomInviteOnlyMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room invite only.", "invite only room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room invite only.", "someone else invite only room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer invite only.", "no longer invite only room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer invite only.", "someone else no longer invite only room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomNormalUsersSilencedMode ) {
			changedModes &= ~MVChatRoomNormalUsersSilencedMode;
			mode = @"chatRoomNormalUsersSilencedMode";
			if( newModes & MVChatRoomNormalUsersSilencedMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room moderated for normal users.", "moderated for normal users room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room moderated for normal users.", "someone else moderated for normal users room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer moderated for normal users.", "no longer moderated for normal users room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer moderated for normal users.", "someone else no longer moderated for normal users room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomOperatorsSilencedMode ) {
			changedModes &= ~MVChatRoomOperatorsSilencedMode;
			mode = @"chatRoomOperatorsSilencedMode";
			if( newModes & MVChatRoomOperatorsSilencedMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room moderated for operators.", "moderated for operators room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room moderated for operators.", "someone else moderated for operators room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer moderated for operators.", "no longer moderated for operators room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer moderated for operators.", "someone else no longer moderated for operators room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomOperatorsOnlySetTopicMode ) {
			changedModes &= ~MVChatRoomOperatorsOnlySetTopicMode;
			mode = @"MVChatRoomOperatorsOnlySetTopicMode";
			if( newModes & MVChatRoomOperatorsOnlySetTopicMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to require operator status to change the topic.", "require op to set topic room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to require operator status to change the topic.", "someone else required op to set topic room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to allow anyone to change the topic.", "don't require op to set topic room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to allow anyone to change the topic.", "someone else don't required op to set topic room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomNoOutsideMessagesMode ) {
			changedModes &= ~MVChatRoomNoOutsideMessagesMode;
			mode = @"chatRoomNoOutsideMessagesMode";
			if( newModes & MVChatRoomNoOutsideMessagesMode ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to prohibit outside messages.", "prohibit outside messages room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to prohibit outside messages.", "someone else prohibit outside messages room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to permit outside messages.", "permit outside messages room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to permit outside messages.", "someone else permit outside messages room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomPassphraseToJoinMode ) {
			changedModes &= ~MVChatRoomPassphraseToJoinMode;
			mode = @"chatRoomPassphraseToJoinMode";
			if( newModes & MVChatRoomPassphraseToJoinMode ) {
				parameter = [[self target] attributeForMode:MVChatRoomPassphraseToJoinMode];
				if( [mbr isLocalUser] ) {
					message = [NSString stringWithFormat:NSLocalizedString( @"You changed this room to require a password of \"%@\".", "password required room status message" ), parameter];
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to require a password of \"%@\".", "someone else password required room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), parameter];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to no longer require a password.", "no longer passworded room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to no longer require a password.", "someone else no longer passworded room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		} else if( changedModes & MVChatRoomLimitNumberOfMembersMode ) {
			changedModes &= ~MVChatRoomLimitNumberOfMembersMode;
			mode = @"chatRoomLimitNumberOfMembersMode";
			if( newModes & MVChatRoomLimitNumberOfMembersMode ) {
				parameter = [[self target] attributeForMode:MVChatRoomLimitNumberOfMembersMode];
				if( [mbr isLocalUser] ) {
					message = [NSString stringWithFormat:NSLocalizedString( @"You set a limit on the number of room members to %@.", "member limit room status message" ), parameter];
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ set a limit on the number of room members to %@.", "someone else member limit room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), parameter];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You removed the room member limit.", "no member limit room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ removed the room member limit", "someone else no member limit room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
				}
			}
		}

		if( message && mode ) [self addEventMessageToDisplay:message withName:@"modeChange" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? (id) mbr : (id) user ), @"by", mode, @"mode", ( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ? @"yes" : @"no" ), @"enabled", parameter, @"parameter", nil]];

		NSString *unsupportedModes = (notification.userInfo)[@"unsupportedModes"];
		if (unsupportedModes.length) {
			NSString *message = nil;
			if (unsupportedModes.length > 2) {
				if (user.localUser)
					message = [NSString stringWithFormat:[NSLocalizedString(@"You set modes %@.", @"unknown modes changed") stringByEncodingXMLSpecialCharactersAsEntities], unsupportedModes];
				else message = [NSString stringWithFormat:[NSLocalizedString(@"%@ set modes %@.", @"unknown modes changed") stringByEncodingXMLSpecialCharactersAsEntities], [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities], unsupportedModes];
			} else {
				if (user.localUser)
					message = [NSString stringWithFormat:[NSLocalizedString(@"You set mode %@.", @"unknown mode changed") stringByEncodingXMLSpecialCharactersAsEntities], unsupportedModes];
				else message = [NSString stringWithFormat:[NSLocalizedString(@"%@ set mode %@.", @"unknown mode changed") stringByEncodingXMLSpecialCharactersAsEntities], [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities], unsupportedModes];
			}

			[self addEventMessageToDisplay:message withName:@"unknownRoomModesSet" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? (id) mbr : (id) user ), @"by", nil]];
		}
	}
}

- (void) _selfNicknameChanged:(NSNotification *) notification {
	[self resortMembers];
	[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You are now known as <span class=\"member\">%@</span>.", "you changed nicknames" ), [[[self connection] nickname] stringByEncodingXMLSpecialCharactersAsEntities]] withName:@"newNickname" andAttributes:@{@"who": [self localChatRoomMember]}];
}

- (void) _memberNicknameChanged:(NSNotification *) notification {
	if( ! [[self target] hasUser:[notification object]] ) return;

	[self resortMembers];

	JVChatRoomMember *member = [self chatRoomMemberForUser:[notification object]];
	if( ! member ) return;

	NSString *oldNickname = [notification userInfo][@"oldNickname"];

	NSUInteger index = [_preferredTabCompleteNicknames indexOfObject:oldNickname];
	if( index != NSNotFound ) _preferredTabCompleteNicknames[index] = [member nickname];

	[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ is now known as <span class=\"member\">%@</span>.", "user has changed nicknames" ), [oldNickname stringByEncodingXMLSpecialCharactersAsEntities], [[member nickname] stringByEncodingXMLSpecialCharactersAsEntities]] withName:@"memberNewNickname" andAttributes:@{@"old": oldNickname, @"who": member}];
}

- (void) _memberJoined:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];
	JVChatRoomMember *member = [self chatRoomMemberForUser:user];

	if( ! member ) {
		member = [[JVChatRoomMember alloc] initWithRoom:self andUser:user];
		[_sortedMembers addObject:member];
		[self resortMembers];
	}

	NSString *name = [member title];
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> joined the chat room.", "a user has join a chat room status message" ), [name stringByEncodingXMLSpecialCharactersAsEntities]];
	[self addEventMessageToDisplay:message withName:@"memberJoined" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", nil]];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoomPanel * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( memberJoined:inRoom: )];
	MVAddUnsafeUnretainedAddress(member, 2);
	MVAddUnsafeUnretainedAddress(self, 3);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
	context[@"title"] = NSLocalizedString( @"Room Member Joined", "member joined title" );
	context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@ joined the chat room %@.", "bubble message member joined string" ), name, _target];
	context[@"target"] = self;
	context[@"action"] = NSStringFromSelector( @selector( activate: ) );
	[self performNotification:@"JVChatMemberJoinedRoom" withContextInfo:context];
}

- (void) _memberParted:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];
	JVChatRoomMember *member = [self chatRoomMemberForUser:user];
	if( ! member ) return;

	NSMutableAttributedString *rstring = [self _convertRawMessage:[notification userInfo][@"reason"]];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoomPanel * ), @encode( NSAttributedString * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( memberParted:fromRoom:forReason: )];
	MVAddUnsafeUnretainedAddress(member, 2);
	MVAddUnsafeUnretainedAddress(self, 3);
	MVAddUnsafeUnretainedAddress(rstring, 4);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	if( [_windowController selectedListItem] == member )
		[_windowController showChatViewController:[_windowController activeChatViewController]];

	NSString *name = [member title];
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> left the chat room.", "a user has left the chat room status message" ), [name stringByEncodingXMLSpecialCharactersAsEntities]];

	[self addEventMessageToDisplay:message withName:@"memberParted" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
	[context setObject:NSLocalizedString( @"Room Member Left", "member left title" ) forKey:@"title"];
	context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@ left the chat room %@.", "bubble message member left string" ), name, _target];
	context[@"target"] = self;
	context[@"action"] = NSStringFromSelector( @selector( activate: ) );
	[self performNotification:@"JVChatMemberLeftRoom" withContextInfo:context];

	[member _detach];

	[_preferredTabCompleteNicknames removeObject:[member nickname]];
	[_sortedMembers removeObjectIdenticalTo:member];
	[_nextMessageAlertMembers removeObject:member];
	[_windowController reloadListItem:self andChildren:YES];
}

- (void) _userBricked:(NSNotification *) notification {
	MVChatUser *user = [notification userInfo][@"user"];

	NSString *message = nil;
	NSString *ctxmessage = nil;
	if( user ) {
		if( [user isLocalUser] ) {
			message = NSLocalizedString( @"You have been bricked.", "you have been bricked status message" );
			ctxmessage = NSLocalizedString( @"You have been bricked.", "bubble message user bricked string" );
		} else {
			NSString *name = [user nickname];
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> has been bricked.", "a user has been bricked status message" ), [name stringByEncodingXMLSpecialCharactersAsEntities]];
			ctxmessage = [NSString stringWithFormat:NSLocalizedString( @"%@ has been bricked.", "bubble message user bricked string" ), name];
		}

		[self addEventMessageToDisplay:message withName:@"userBricked" andAttributes:@{@"who": user}];
	} else {
		message = NSLocalizedString( @"A brick flies off into the ether.", "a brick flies off into the ether status message" );
		ctxmessage = NSLocalizedString( @"A brick flies off into the ether.", "bubble message nobody bricked string" );

		[self addEventMessageToDisplay:message withName:@"userBricked" andAttributes:nil];
	}
	NSAssert( message, @"message not initialized in conditional" );
	NSAssert( ctxmessage, @"ctxmessage not initialized in conditional" );

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatUser * ), @encode( JVChatRoomPanel * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( userBricked:inRoom: )];
	MVAddUnsafeUnretainedAddress(user, 2);
	MVAddUnsafeUnretainedAddress(self, 3);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
	context[@"title"] = NSLocalizedString( @"Chat User Bricked", "user bricked title" );
	context[@"description"] = ctxmessage;
	context[@"target"] = self;
	context[@"action"] = NSStringFromSelector( @selector( activate: ) );
}

- (void) _kicked:(NSNotification *) notification {
	MVChatUser *byUser = [[notification userInfo] objectForKey:@"byUser"];
	JVChatRoomMember *byMember = [self chatRoomMemberForUser:byUser];
	NSMutableAttributedString *rstring = [self _convertRawMessage:[[notification userInfo] objectForKey:@"reason"]];
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"You were kicked from the chat room by %@.", "you were removed by force from a chat room status message" ), ( byMember ? [[byMember title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];

	[self addEventMessageToDisplay:message withName:@"kicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMember ? (id) byMember : (id) byUser ), @"by", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomPanel * ), @encode( JVChatRoomMember * ), @encode( NSAttributedString * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( kickedFromRoom:by:forReason: )];
	MVAddUnsafeUnretainedAddress(self, 2);
	MVAddUnsafeUnretainedAddress(byMember, 3);
	MVAddUnsafeUnretainedAddress(rstring, 4);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	JVChatRoomMember *member = [self localChatRoomMember];
	if( [_windowController selectedListItem] == member )
		[_windowController showChatViewController:[_windowController activeChatViewController]];

	[member _detach];

	[_preferredTabCompleteNicknames removeObject:[member nickname]];
	[_sortedMembers removeObjectIdenticalTo:member];
	[_nextMessageAlertMembers removeObject:member];
	[_windowController reloadListItem:self andChildren:YES];

	_kickedFromRoom = YES;
	_cantSendMessages = YES;

	NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
	[context setObject:NSLocalizedString( @"You Were Kicked", "member kicked title" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You were kicked from %@ by %@.", "bubble message member kicked string" ), [self title], ( byMember ? [[byMember title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )] forKey:@"description"];
	[context setObject:self forKey:@"target"];
	[context setObject:NSStringFromSelector( @selector( activate: ) ) forKey:@"action"];
	[self performNotification:@"JVChatMemberKicked" withContextInfo:context];

	// auto-rejoin on kick
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoRejoinRoomsOnKick"] ) {
		[self performSelector:@selector(joinChat:) withObject:nil afterDelay:[[NSUserDefaults standardUserDefaults] floatForKey:@"JVAutoRejoinRoomsDelay"]];
	} else {
		[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You have been kicked from the chat room.", "you were removed by force from a chat room error message title" ), NSLocalizedString( @"You have been kicked from the chat room by %@ with the reason \"%@\" and cannot send further messages without rejoining.", "you were removed by force from a chat room error message" ), @"OK", nil, nil, ( byMember ? [[byMember title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( rstring ? [rstring string] : @"" ) ) withName:nil];
	}

}

- (void) _memberKicked:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];
	JVChatRoomMember *member = [self chatRoomMemberForUser:user];
	if( ! member ) return;

	MVChatUser *byUser = [[notification userInfo] objectForKey:@"byUser"];
	JVChatRoomMember *byMember = [self chatRoomMemberForUser:byUser];
	NSMutableAttributedString *rstring = [self _convertRawMessage:[[notification userInfo] objectForKey:@"reason"]];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoomPanel * ), @encode( JVChatRoomMember * ), @encode( NSAttributedString * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( memberKicked:fromRoom:by:forReason: )];
	MVAddUnsafeUnretainedAddress(member, 2);
	MVAddUnsafeUnretainedAddress(self, 3);
	MVAddUnsafeUnretainedAddress(byMember, 4);
	MVAddUnsafeUnretainedAddress(rstring, 2);

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	if( [_windowController selectedListItem] == member )
		[_windowController showChatViewController:[_windowController activeChatViewController]];

	[member _detach];

	[_preferredTabCompleteNicknames removeObject:[member nickname]];
	[_sortedMembers removeObjectIdenticalTo:member];
	[_nextMessageAlertMembers removeObject:member];
	[_windowController reloadListItem:self andChildren:YES];

	NSString *message = nil;
	if( [byMember isLocalUser] ) {
		message = [NSString stringWithFormat:NSLocalizedString( @"You kicked %@ from the chat room.", "you removed a user by force from a chat room status message" ), ( member ? [[member title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
	} else {
		message = [NSString stringWithFormat:NSLocalizedString( @"%@ was kicked from the chat room by <span class=\"member\">%@</span>.", "user has been removed by force from a chat room status message" ), ( member ? [[member title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMember ? [[byMember title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
	}

	[self addEventMessageToDisplay:message withName:@"memberKicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( member ? (id) member : (id) user ), @"who", ( byMember ? (id) byMember : (id) byUser ), @"by", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
	[context setObject:NSLocalizedString( @"Room Member Kicked", "member kicked title" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ was kicked from %@ by %@.", "bubble message member kicked string" ), ( member ? [[member title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [self title], ( byMember ? [[byMember title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )] forKey:@"description"];
	[context setObject:self forKey:@"target"];
	[context setObject:NSStringFromSelector( @selector( activate: ) ) forKey:@"action"];
	[self performNotification:@"JVChatMemberKicked" withContextInfo:context];
}

- (void) _memberBanned:(NSNotification *) notification {
	if( ! _banListSynced ) return;

	MVChatUser *byUser = [notification userInfo][@"byUser"];
	JVChatRoomMember *byMbr = [self chatRoomMemberForUser:byUser];

	MVChatUser *ban = [notification userInfo][@"user"];

	NSString *message = nil;
	NSString *banned = nil;

	if ([[ban nickname] hasCaseInsensitiveSubstring:@"$"] || [[ban nickname] hasCaseInsensitiveSubstring:@":"] || [[ban nickname] hasCaseInsensitiveSubstring:@"~"]) { // extended bans on ircd-seven, inspircd and unrealircd
		if ([[ban nickname] hasCaseInsensitiveSubstring:@"~q"] || [[ban nickname] hasCaseInsensitiveSubstring:@"~n"]) {
			banned = [ban displayName]; // These two extended bans on unreal-style ircds take full hostmasks as their arguments
		} else {
			banned = [ban nickname];
		}
	}

	if( [byMbr isLocalUser] ) {
		message = [NSString stringWithFormat:NSLocalizedString( @"You set a ban on %@.", "you set a ban chat room status message" ), (banned ? banned : [[ban description] stringByEncodingXMLSpecialCharactersAsEntities])];
	} else {
		message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> set a ban on %@.", "user set a ban chat room status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), (banned ? banned : [[ban description] stringByEncodingXMLSpecialCharactersAsEntities])];
	}

	[self addEventMessageToDisplay:message withName:@"memberBanned" andAttributes:@{@"ban": [ban description], @"by": byMbr}];
}

- (void) _memberBanRemoved:(NSNotification *) notification {
	MVChatUser *byUser = [notification userInfo][@"byUser"];
	JVChatRoomMember *byMbr = [self chatRoomMemberForUser:byUser];

	MVChatUser *ban = [notification userInfo][@"user"];

	NSString *message = nil;
	NSString *banned = nil;

	if ([[ban nickname] hasCaseInsensitiveSubstring:@"$"] || [[ban nickname] hasCaseInsensitiveSubstring:@":"] || [[ban nickname] hasCaseInsensitiveSubstring:@"~"]) { // extended bans on ircd-seven, inspircd and unrealircd
		if ([[ban nickname] hasCaseInsensitiveSubstring:@"~q"] || [[ban nickname] hasCaseInsensitiveSubstring:@"~n"]) {
			banned = [ban displayName]; // These two extended bans on unreal-style ircds take full hostmasks as their arguments
		} else {
			banned = [ban nickname];
		}
	}

	if( [byMbr isLocalUser] ) {
		message = [NSString stringWithFormat:NSLocalizedString( @"You removed the ban on %@.", "you removed a ban chat room status message" ), (banned ? banned : [[ban description] stringByEncodingXMLSpecialCharactersAsEntities])];
	} else {
		message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> removed the ban on %@.", "user removed a ban chat room status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), (banned ? banned : [[ban description] stringByEncodingXMLSpecialCharactersAsEntities])];
	}

	[self addEventMessageToDisplay:message withName:@"banRemoved" andAttributes:@{@"ban": [ban description], @"by": byMbr}];
}

- (void) _memberModeChanged:(NSNotification *) notification {
	// sort again if needed
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] )
		[self resortMembers];

	MVChatUser *user = [notification userInfo][@"who"];
	MVChatUser *byUser = [notification userInfo][@"by"];

	if( ! user ) return;

	JVChatRoomMember *mbr = [self chatRoomMemberForUser:user];
	JVChatRoomMember *byMbr = [self chatRoomMemberForUser:byUser];

	NSString *name = nil;
	NSString *message = nil;
	NSString *title = nil;
	NSString *description = nil;
	NSString *notificationKey = nil;
	NSUInteger mode = [[notification userInfo][@"mode"] unsignedLongValue];
	BOOL enabled = [[notification userInfo][@"enabled"] boolValue];

	if( mode == MVChatRoomMemberFounderMode && enabled ) {
		name = @"memberPromotedToFounder";
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) { // only server oppers would ever see this
			message = NSLocalizedString( @"You promoted yourself to room founder.", "we gave ourself the chat room founder privilege status message" );
			name = @"promotedToFounder";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were promoted to room founder by <span class=\"member\">%@</span>.", "we are now a chat room founder status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"promotedToFounder";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to room founder by you.", "we gave user chat room founder status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to room founder by <span class=\"member\">%@</span>.", "user is now a chat room founder status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberFounderMode && ! enabled ) {
		name = @"memberDemotedFromFounder";
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You demoted yourself from room founder.", "we removed our chat room founder privilege status message" );
			name = @"demotedFromFounder";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were demoted from room founder by <span class=\"member\">%@</span>.", "we are no longer a chat room founder status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"demotedFromFounder";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from room founder by you.", "we removed user's chat room founder status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from room founder by <span class=\"member\">%@</span>.", "user is no longer a chat room founder status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberAdministratorMode && enabled ) {
		name = @"memberPromotedToAdministrator";
		notificationKey = @"JVChatMemberPromotedAdministrator";
		title = NSLocalizedString( @"New Room Administrator", "room administrator promoted title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was promoted to administrator by %@ in %@.", "bubble message member administrator promotion string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) { // only server oppers would ever see this
			message = NSLocalizedString( @"You promoted yourself to Administrator.", "we gave ourself the chat room administrator privilege status message" );
			name = @"promotedToAdministrator";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were promoted to administrator by <span class=\"member\">%@</span>.", "we are now a chat room administrator status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"promotedToAdministrator";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to administrator by you.", "we gave user chat room administrator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to administrator by <span class=\"member\">%@</span>.", "user is now a chat room administrator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberAdministratorMode && ! enabled ) {
		name = @"memberDemotedFromAdministrator";
		notificationKey = @"JVChatMemberDemotedAdministrator";
		title = NSLocalizedString( @"Room Administrator Demoted", "room administrator demoted title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was demoted from administrator by %@ in %@.", "bubble message member administrator demotion string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You demoted yourself from administrator.", "we removed our chat room administrator privilege status message" );
			name = @"demotedFromAdministrator";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were demoted from administrator by <span class=\"member\">%@</span>.", "we are no longer a chat room administrator status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"demotedFromAdministrator";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from administrator by you.", "we removed user's chat room administrator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from administrator by <span class=\"member\">%@</span>.", "user is no longer a chat room administrator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberOperatorMode && enabled ) {
		name = @"memberPromotedToOperator";
		notificationKey = @"JVChatMemberPromotedOperator";
		title = NSLocalizedString( @"New Room Operator", "member promoted title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was promoted to operator by %@ in %@.", "bubble message member operator promotion string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) { // only server oppers would ever see this
			message = NSLocalizedString( @"You promoted yourself to operator.", "we gave ourself the chat room operator privilege status message" );
			name = @"promotedToOperator";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were promoted to operator by <span class=\"member\">%@</span>.", "we are now a chat room operator status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"promotedToOperator";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to operator by you.", "we gave user chat room operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to operator by <span class=\"member\">%@</span>.", "user is now a chat room operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberOperatorMode && ! enabled ) {
		name = @"memberDemotedFromOperator";
		notificationKey = @"JVChatMemberDemotedOperator";
		title = NSLocalizedString( @"Room Operator Demoted", "room operator demoted title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was demoted from operator by %@ in %@.", "bubble message member operator demotion string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You demoted yourself from operator.", "we removed our chat room operator privilege status message" );
			name = @"demotedFromOperator";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were demoted from operator by <span class=\"member\">%@</span>.", "we are no longer a chat room operator status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"demotedFromOperator";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from operator by you.", "we removed user's chat room operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from operator by <span class=\"member\">%@</span>.", "user is no longer a chat room operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberHalfOperatorMode && enabled ) {
		name = @"memberPromotedToHalfOperator";
		notificationKey = @"JVChatMemberPromotedHalfOperator";
		title = NSLocalizedString( @"New Room Half-Operator", "member promoted to half-operator title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was promoted to half-operator by %@ in %@.", "bubble message member half-operator promotion string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) { // only server oppers would ever see this
			message = NSLocalizedString( @"You promoted yourself to half-operator.", "we gave ourself the chat room half-operator privilege status message" );
			name = @"promotedToHalfOperator";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were promoted to half-operator by <span class=\"member\">%@</span>.", "we are now a chat room half-operator status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"promotedToHalfOperator";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to half-operator by you.", "we gave user chat room half-operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to half-operator by <span class=\"member\">%@</span>.", "user is now a chat room half-operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberHalfOperatorMode && ! enabled ) {
		name = @"memberDemotedFromHalfOperator";
		notificationKey = @"JVChatMemberDemotedHalfOperator";
		title = NSLocalizedString( @"Room Half-Operator Demoted", "room half-operator demoted title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was demoted from half-operator by %@ in %@.", "bubble message member operator demotion string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You demoted yourself from half-operator.", "we removed our chat room half-operator privilege status message" );
			name = @"demotedFromHalfOperator";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were demoted from half-operator by <span class=\"member\">%@</span>.", "we are no longer a chat room half-operator status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"demotedFromHalfOperator";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from half-operator by you.", "we removed user's chat room half-operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from half-operator by <span class=\"member\">%@</span>.", "user is no longer a chat room half-operator status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberVoicedMode && enabled ) {
		name = @"memberVoiced";
		notificationKey = @"JVChatMemberVoiced";
		title = NSLocalizedString( @"Room Member Voiced", "member voiced title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was granted voice by %@ in %@.", "bubble message member voiced string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You gave yourself voice.", "we gave ourself special voice status to talk in moderated rooms status message" );
			name = @"voiced";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were granted voice by <span class=\"member\">%@</span>.", "we now have special voice status to talk in moderated rooms status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"voiced";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was granted voice by you.", "we gave user special voice status to talk in moderated rooms status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was granted voice by <span class=\"member\">%@</span>.", "user now has special voice status to talk in moderated rooms status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberVoicedMode && ! enabled ) {
		name = @"memberDevoiced";
		notificationKey = @"JVChatMemberDevoiced";
		title = NSLocalizedString( @"Room Member Lost Voice", "member devoiced title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ had voice removed by %@ in %@.", "bubble message member lost voice string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You removed voice from yourself.", "we removed our special voice status to talk in moderated rooms status message" );
			name = @"devoiced";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You had voice removed by <span class=\"member\">%@</span>.", "we no longer has special voice status and can't talk in moderated rooms status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"devoiced";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> had voice removed by you.", "we removed user's special voice status and can't talk in moderated rooms status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> had voice removed by <span class=\"member\">%@</span>.", "user no longer has special voice status and can't talk in moderated rooms status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberVoicedMode && enabled ) {
		name = @"memberQuieted";
		notificationKey = @"JVChatMemberQuieted";
		title = NSLocalizedString( @"Room Member Quieted", "member quieted title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"%@ was quieted by %@ in %@.", "bubble message member quieted string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You quieted yourself.", "we quieted and can't talk ourself status message" );
			name = @"quieted";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You were quieted by <span class=\"member\">%@</span>.", "we are now quieted and can't talk status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"quieted";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was quieted by you.", "we quieted someone else in the room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was quieted by <span class=\"member\">%@</span>.", "user was quieted by someone else in the room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	} else if( mode == MVChatRoomMemberVoicedMode && ! enabled ) {
		name = @"memberDequieted";
		notificationKey = @"JVChatMemberDequieted";
		title = NSLocalizedString( @"Quieted Room Member Annulled", "quieted member annulled title" );
		description = [NSString stringWithFormat:NSLocalizedString( @"Quieted %@ was annulled by %@ in %@.", "bubble message quieted member annulled string" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), [[self title] stringByEncodingXMLSpecialCharactersAsEntities]];
		if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
			message = NSLocalizedString( @"You made yourself no longer quieted.", "we are no longer quieted and can talk ourself status message" );
			name = @"dequieted";
		} else if( [mbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"You are no longer quieted, thanks to <span class=\"member\">%@</span>.", "we are no longer quieted and can talk status message" ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
			name = @"dequieted";
		} else if( [byMbr isLocalUser] ) {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> is no longer quieted because of you.", "a user is no longer quieted because of us status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		} else {
			message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> is no longer quieted because of <span class=\"member\">%@</span>.", "user is no longer quieted because of someone else in the room status message" ), ( mbr ? [[mbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[user nickname] stringByEncodingXMLSpecialCharactersAsEntities] ), ( byMbr ? [[byMbr title] stringByEncodingXMLSpecialCharactersAsEntities] : [[byUser nickname] stringByEncodingXMLSpecialCharactersAsEntities] )];
		}
	}

	[self addEventMessageToDisplay:message withName:name andAttributes:@{@"who": ( mbr ? (id) mbr : (id) user ), @"by": ( byMbr ? (id) byMbr : (id) byUser )}];

	if( title && description && notificationKey ) {
		NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
		context[@"title"] = title;
		context[@"description"] = description;
		context[@"target"] = self;
		context[@"action"] = NSStringFromSelector( @selector( activate: ) );
		[self performNotification:notificationKey withContextInfo:context];
	}
}

- (void) _membersSynced:(NSNotification *) notification {
	NSDictionary *userInfo = [notification userInfo];
	if( userInfo ) {
		NSArray *addedUsers = [userInfo objectForKey:@"added"];
		if( addedUsers ) {
			MVChatUser *user = nil;
			for( user in addedUsers ) {
				if( ! [self chatRoomMemberForUser:user] ) {
					JVChatRoomMember *member = [[JVChatRoomMember alloc] initWithRoom:self andUser:user];
					[_sortedMembers addObject:member];
				}
			}
		}

		NSArray *removedUsers = [userInfo objectForKey:@"removed"];
		if( removedUsers ) {
			MVChatUser *user = nil;
			for( user in removedUsers ) {
				JVChatRoomMember *member = [self chatRoomMemberForUser:user];
				if( member ) {
					[member _detach];
					[_sortedMembers removeObjectIdenticalTo:member];
				}
			}
		}
	}

	[self resortMembers];
}

- (void) _bannedMembersSynced:(NSNotification *) notification {
	_banListSynced = YES;
}

- (void) _topicChanged:(nullable id) sender {
	NSAttributedString *topic = [self _convertRawMessage:[[self target] topic]];
	JVChatRoomMember *author = ( [[self target] topicAuthor] ? [self chatRoomMemberForUser:[[self target] topicAuthor]] : nil );
	NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
	NSString *topicString = [topic HTMLFormatWithOptions:options];

	if( topic && [[self target] topicAuthor] && sender ) {
		if( [[[self target] topicAuthor] isLocalUser] ) {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You changed the topic to \"%@\".", "you changed the topic chat room status message" ), topicString] withName:@"topicChanged" andAttributes:@{@"by": ( author ? (id) author : (id) [[self target] topicAuthor] ), @"topic": topic}];
		} else {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"Topic changed to \"%@\" by <span class=\"member\">%@</span>.", "topic changed chat room status message" ), topicString, ( author ? [[author title] stringByEncodingXMLSpecialCharactersAsEntities] : [[[[self target] topicAuthor] displayName] stringByEncodingXMLSpecialCharactersAsEntities] )] withName:@"topicChanged" andAttributes:@{@"by": ( author ? (id) author : (id) [[self target] topicAuthor] ), @"topic": topic}];
		}

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSAttributedString * ), @encode( JVChatRoomPanel * ), @encode( JVChatRoomMember * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( topicChangedTo:inRoom:by: )];
		MVAddUnsafeUnretainedAddress(topic, 2);
		MVAddUnsafeUnretainedAddress(self, 3);
		MVAddUnsafeUnretainedAddress(author, 4);

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	}

	BOOL emptyTopic = NO;
	if( ! [topic length] ) {
		topicString = NSLocalizedString( @"(no chat topic is set)", "no chat topic is set message" );
		emptyTopic = YES;
	}

	id authorArg = ( author ? [author title] : [[[self target] topicAuthor] displayName] );
	NSArray *args = @[topicString, ( authorArg ? authorArg : [NSNull null] ), @(emptyTopic)];
	[[display windowScriptObject] callWebScriptMethod:@"changeTopic" withArguments:args];
}

- (void) _didClearDisplay:(NSNotification *) notification {
	[self performSelector:@selector(_topicChanged:) withObject:nil afterDelay:0.3];
}

- (NSInteger) _roomIndexInFavoritesMenu {
	NSURL *appSupport = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
	appSupport = [[appSupport URLByAppendingPathComponent:@"Colloquy"] URLByAppendingPathComponent:@"Favorites"];
	appSupport = [appSupport URLByAppendingPathComponent:@"Favorites.plist" isDirectory:NO];
	NSMutableArray *favorites = [[NSMutableArray alloc] initWithContentsOfURL:appSupport];
	if (!favorites)
		return NSNotFound;

	for (NSUInteger i = 0; i < favorites.count; i++) {
		NSDictionary *favoritesDictionary = favorites[i];

		if (![favoritesDictionary[@"scheme"] isCaseInsensitiveEqualToString:[[self connection] urlScheme]])
			continue;

		if (![favoritesDictionary[@"server"] isCaseInsensitiveEqualToString:[[self connection] server]])
			continue;

		if (![favoritesDictionary[@"target"] isCaseInsensitiveEqualToString:[_target description]])
			continue;

		return i;
	}

	return NSNotFound;
}
@end

#pragma mark -

@implementation JVChatRoomPanel (JVChatRoomScripting)
- (NSArray *) chatMembers {
	return _sortedMembers;
}

- (JVChatRoomMember *) valueInChatMembersWithName:(NSString *) name {
	return [self firstChatRoomMemberWithName:name];
}

- (JVChatRoomMember *) valueInChatMembersWithUniqueID:(id) identifier {
	JVChatRoomMember *member = nil;

	for( member in _sortedMembers )
		if( [[member uniqueIdentifier] isEqual:identifier] )
			return member;

	return nil;
}

- (NSTextStorage *) scriptTypedTopic {
	NSAttributedString *topic = [self _convertRawMessage:[[self target] topic] withBaseFont:[NSFont systemFontOfSize:11.]];
	return [[NSTextStorage alloc] initWithAttributedString:topic];
}

- (void) setScriptTypedTopic:(NSString *) topic {
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:topic];
	[[self target] changeTopic:attributeMsg];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatRoomMemberObjectSpecifier)
- (nullable NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[JVChatRoomPanel class]];
	NSScriptObjectSpecifier *container = [[self room] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatMembers" uniqueID:[self uniqueIdentifier]];
}
@end

NS_ASSUME_NONNULL_END
