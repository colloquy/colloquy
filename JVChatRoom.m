#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatScriptPlugin.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSMethodSignatureAdditions.h>

#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "JVNotificationController.h"
#import "MVBuddyListController.h"
#import "JVBuddy.h"
#import "MVTextView.h"
#import "NSURLAdditions.h"

@interface JVDirectChat (JVDirectChatPrivate)
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
- (void) _makeHyperlinksInString:(NSMutableString *) string;
- (void) _didConnect:(NSNotification *) notification;
- (void) _didDisconnect:(NSNotification *) notification;
@end

#pragma mark -

@interface JVChatRoomMember (JVChatMemberPrivate)
- (void) _setNickname:(NSString *) name;
- (void) _setVoice:(BOOL) voice;
- (void) _setOperator:(BOOL) operator;
@end

#pragma mark -

@implementation JVChatRoom
- (id) init {
	if( ( self = [super init] ) ) {
		topicLine = nil;
		_topic = nil;
		_topicAuth = nil;
		_topicAttributed = nil;
		_members = [[NSMutableDictionary dictionary] retain];
		_sortedMembers = [[NSMutableArray array] retain];
		_kickedFromRoom = NO;
		_invalidateMembers = NO;
	}
	return self;
}

- (void) awakeFromNib {
	[topicLine setDrawsBackground:NO];
	[[topicLine enclosingScrollView] setDrawsBackground:NO];
	[super awakeFromNib];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatConnectionGotRoomModeNotification object:[self connection]];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], _target]];

	[_filePath autorelease];
	_filePath = [[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Recent Chat Rooms/%@ (%@).inetloc", _target, [[self connection] server]] stringByExpandingTildeInPath] retain];

	[url writeToInternetLocationFile:_filePath];
	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:_filePath];

	if( ! [[NSFileManager defaultManager] fileExistsAtPath:_filePath] ) {
		[_filePath autorelease];
		_filePath = nil;
	}
}

- (void) dealloc {
	[[self connection] partChatRoom:[self target]];

	[_members release];
	[_sortedMembers release];
	[_topic release];
	[_topicAuth release];
	[_topicAttributed release];

	_members = nil;
	_sortedMembers = nil;
	_topic = nil;
	_topicAuth = nil;
	_topicAttributed = nil;

	[super dealloc];
}

#pragma mark -

- (void) willDispose {
	[self parting];
}

#pragma mark -

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Chat Room"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	
	[_toolbarItems release];
	_toolbarItems = [[NSMutableDictionary dictionary] retain];
	
	return [toolbar autorelease];
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatRoom" owner:self];
	return contents;
}

#pragma mark -

- (BOOL) isEnabled {
	return ! _invalidateMembers;
}

- (NSString *) title {
	NSMutableString *title = [NSMutableString stringWithString:_target];
	[title deleteCharactersInRange:NSMakeRange( 0, 1 )];
	return [[title retain] autorelease];
}

- (NSString *) windowTitle {
	NSMutableString *title = [NSMutableString stringWithString:_target];
	[title deleteCharactersInRange:NSMakeRange( 0, 1 )];
	return [NSString stringWithFormat:NSLocalizedString( @"%@ (%@)", "chat room window - window title" ), title, [[self connection] server]];
}

- (NSString *) information {
	if( _kickedFromRoom )
		return [NSString stringWithFormat:NSLocalizedString( @"kicked out", "chat room kicked status line in drawer" )];
	if( [[self connection] isConnected] )
		return [NSString stringWithFormat:@"%d members", [_sortedMembers count]];
	return [NSString stringWithFormat:NSLocalizedString( @"disconnected", "disconnected status info line in drawer" )];
}

#pragma mark -

- (int) numberOfChildren {
	return [_sortedMembers count];
}

- (id) childAtIndex:(int) index {
	return [_sortedMembers objectAtIndex:index];
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""] autorelease];
	[item setTarget:_windowController];
	[menu addItem:item];
	
	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add to Favorites", "add to favorites contextual menu") action:@selector( addToFavorites: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];
	
	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Leave Room", "leave room contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];
	
	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"room"];
}

#pragma mark -

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Chat Room %@ (%@)", _target, [[self connection] server]];
}

#pragma mark -

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return NO;
}

- (void) handleDraggedFile:(NSString *) path {
	[NSException raise:NSIllegalSelectorException format:@"JVChatRoom does not implement handleDraggedFile:"];
	return;
}

#pragma mark -

- (void) setTarget:(NSString *) target {
	[NSException raise:NSIllegalSelectorException format:@"JVChatRoom does not implement setTarget:"];
	return;
}

- (JVBuddy *) buddy {
	[NSException raise:NSIllegalSelectorException format:@"JVChatRoom does not implement buddy:"];
	return nil;
}

#pragma mark -

- (void) unavailable {
	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You're offline", "title of the you're offline message sheet" ), NSLocalizedString( @"You are no longer connected to the server where you were chatting. No messages can be sent at this time. Reconnecting might be in progress.", "chat window error description for loosing connection" ), @"OK", nil, nil ) withName:@"disconnected"];
	_cantSendMessages = YES;
}

- (IBAction) addToFavorites:(id) sender {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], _target]];
	NSString *path = [[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Favorites/%@ (%@).inetloc", _target, [[self connection] server]] stringByExpandingTildeInPath] retain];

	[url writeToInternetLocationFile:path];
	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:path];

	[MVConnectionsController refreshFavoritesMenu];
}

#pragma mark -

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( JVChatRoom * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processUserCommand:withArguments:toRoom: )];
	[invocation setArgument:&command atIndex:2];
	[invocation setArgument:&arguments atIndex:3];
	[invocation setArgument:&self atIndex:4];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	return [[results lastObject] boolValue];
}

- (void) processMessage:(NSMutableData *) message asAction:(BOOL) action fromUser:(NSString *) user {
	JVChatRoomMember *member = [self chatRoomMemberWithName:user];
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( BOOL ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processMessage:asAction:fromMember:inRoom: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&action atIndex:3];
	[invocation setArgument:&member atIndex:4];
	[invocation setArgument:&self atIndex:5];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (void) sendAttributedMessage:(NSMutableAttributedString *) message asAction:(BOOL) action {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:NO], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:NO], @"NSHTMLIgnoreFontTraits", nil];
	NSData *msgData = [message HTMLWithOptions:options usingEncoding:_encoding allowLossyConversion:YES];
	NSString *messageString = [[[NSString alloc] initWithData:msgData encoding:_encoding] autorelease];
	
	[message setAttributedString:[[[NSAttributedString alloc] initWithString:messageString] autorelease]];

	NSSet *plugins = [[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processMessage:asAction:toRoom: )];
	NSEnumerator *enumerator = [plugins objectEnumerator];
	id item = nil;

	while( ( item = [enumerator nextObject] ) )
		if( [item isKindOfClass:[MVChatScriptPlugin class]] )
			[item processMessage:message asAction:action toRoom:self];

	[message setAttributedString:[NSAttributedString attributedStringWithHTMLFragment:[message string] baseURL:nil]];

	enumerator = [plugins objectEnumerator];
	while( ( item = [enumerator nextObject] ) )
		if( ! [item isKindOfClass:[MVChatScriptPlugin class]] )
			[item processMessage:message asAction:action toRoom:self];

	if( [[message string] length] )
		[[self connection] sendMessage:message withEncoding:_encoding toUser:[self target] asAction:action];
}

#pragma mark -

- (void) joined {
	if( _invalidateMembers ) {
		[_members removeAllObjects];
		[_sortedMembers removeAllObjects];
		_invalidateMembers = NO;
	}

	_cantSendMessages = NO;
	_kickedFromRoom = NO;
	[_windowController reloadListItem:self andChildren:YES];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoom * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( joinedRoom: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) parting {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoom * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( partingFromRoom: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

#pragma mark -

- (void) addMemberToChat:(NSString *) member asPreviousMember:(BOOL) previous {
	NSParameterAssert( member != nil );

	if( _invalidateMembers ) {
		[_members removeAllObjects];
		[_sortedMembers removeAllObjects];
		_invalidateMembers = NO;
	}

	if( ! [self chatRoomMemberWithName:member] ) {
		JVChatRoomMember *listItem = [[[JVChatRoomMember alloc] initWithRoom:self andNickname:member] autorelease];

		[_members setObject:listItem forKey:member];
		[_sortedMembers addObject:listItem];

		[self resortMembers];

		if( ! previous ) {
			NSString *name = [listItem title];
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ joined the chat room.", "a user has join a chat room status message" ), name] withName:@"memberJoined" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:member, @"nickname", name, @"who", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberJoined:inRoom: )];
			[invocation setArgument:&listItem atIndex:2];
			[invocation setArgument:&self atIndex:3];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberJoinedRoom" withContextInfo:nil];
		}
	}
}

- (void) removeChatMember:(NSString *) member withReason:(NSData *) reason {
	NSParameterAssert( member != nil );

	JVChatRoomMember *mbr = nil;
	if( ( mbr = [[[self chatRoomMemberWithName:member] retain] autorelease] ) ) {
		NSString *rstring = nil;
		if( reason && ! [reason isMemberOfClass:[NSNull class]] ) {
			rstring = [[[NSString alloc] initWithData:reason encoding:_encoding] autorelease];
			if( ! rstring ) rstring = [NSString stringWithCString:[reason bytes] length:[reason length]];
		}

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( NSString * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( memberParted:fromRoom:forReason: )];
		[invocation setArgument:&mbr atIndex:2];
		[invocation setArgument:&self atIndex:3];
		[invocation setArgument:&rstring atIndex:4];

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

		if( [_windowController selectedListItem] == mbr )
			[_windowController showChatViewController:[_windowController activeChatViewController]];

		[_members removeObjectForKey:member];
		[_sortedMembers removeObjectIdenticalTo:mbr];

		[_windowController reloadListItem:self andChildren:YES];

		NSString *name = [mbr title];
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ left the chat room.", "a user has left the chat room status message" ), name] withName:@"memberParted" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:name, @"who", member, @"nickname", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

		[[JVNotificationController defaultManager] performNotification:@"JVChatMemberLeftRoom" withContextInfo:nil];
	}
}

- (void) changeChatMember:(NSString *) member to:(NSString *) nick {
	NSParameterAssert( member != nil );
	NSParameterAssert( nick != nil );

	JVChatRoomMember *mbr = nil;
	if( ( mbr = [[[self chatRoomMemberWithName:member] retain] autorelease] ) ) {
		NSString *name = [[[mbr title] copy] autorelease];

		[_members setObject:mbr forKey:nick];
		[_members removeObjectForKey:member];
		[mbr _setNickname:nick];

		[self resortMembers];

		if( [mbr isLocalUser] ) {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You are now known as %@.", "you changed nicknames" ), nick] withName:@"newNickname" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[mbr title], @"name", member, @"old", nick, @"new", nil]];
		} else {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ is now known as %@.", "user has changed nicknames" ), name, nick] withName:@"memberNewNickname" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", member, @"old", nick, @"new", nil]];
		}

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSString * ), @encode( NSString * ), @encode( JVChatRoom * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( userNamed:isNowKnowAs:inView: )];
		[invocation setArgument:&member atIndex:2];
		[invocation setArgument:&nick atIndex:3];
		[invocation setArgument:&self atIndex:4];

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	}
}

#pragma mark -

- (void) promoteChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );

	JVChatRoomMember *mbr = nil;
	if( ( mbr = [self chatRoomMemberWithName:member] ) ) {
		[mbr _setOperator:YES];
		[_windowController reloadListItem:mbr andChildren:NO];

		if( by && ! [by isMemberOfClass:[NSNull class]] ) {
			JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];

			NSString *message = nil;
			NSString *name = @"memberPromoted";
			if( [mbr isLocalUser] && [byMbr isLocalUser] ) { // only server oppers would ever see this
				message = NSLocalizedString( @"You promoted yourself to operator.", "we gave ourself the chat room operator privilege status message" );
				name = @"promoted";
			} else if( [mbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"You were promoted to operator by %@.", "we are now a chat room operator status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"promoted";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ was promoted to operator by you.", "we gave user chat room operator status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ was promoted to operator by %@.", "user is now a chat room operator status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"byNickname", member, @"who", ( mbr ? [mbr title] : member ), @"whoNickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberPromoted:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberPromoted" withContextInfo:nil];
		}
	}

	// sort again if needed
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] )
		[self resortMembers];
}

- (void) demoteChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	
	JVChatRoomMember *mbr = nil;
	if( ( mbr = [self chatRoomMemberWithName:member] ) ) {
		[mbr _setOperator:NO];
		[_windowController reloadListItem:mbr andChildren:NO];

		if( by && ! [by isMemberOfClass:[NSNull class]] ) {
			JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];

			NSString *message = nil;
			NSString *name = @"memberDemoted";
			if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
				message = NSLocalizedString( @"You demoted yourself from operator.", "we removed our chat room operator privilege status message" );
				name = @"demoted";
			} else if( [mbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"You were demoted from operator by %@.", "we are no longer a chat room operator status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"demoted";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ was demoted from operator by you.", "we removed user's chat room operator status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ was demoted from operator by %@.", "user is no longer a chat room operator status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"byNickname", ( mbr ? [mbr title] : member ), @"who", member, @"whoNickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberDemoted:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];
		
			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberDemoted" withContextInfo:nil];
		}
	}

	// sort again if needed
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] )
		[self resortMembers];
}

- (void) voiceChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	
	JVChatRoomMember *mbr = nil;
	if( ( mbr = [self chatRoomMemberWithName:member] ) ) {
		[mbr _setVoice:YES];
		[_windowController reloadListItem:mbr andChildren:NO];

		if( by && ! [by isMemberOfClass:[NSNull class]] ) {
			JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];

			NSString *message = nil;
			NSString *name = @"memberVoiced";
			if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
				message = NSLocalizedString( @"You gave yourself voice.", "we gave ourself special voice status to talk in moderated rooms status message" );
				name = @"voiced";
			} else if( [mbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"You were granted voice by %@.", "we now have special voice status to talk in moderated rooms status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"voiced";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ was granted voice by you.", "we gave user special voice status to talk in moderated rooms status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ was granted voice by %@.", "user now has special voice status to talk in moderated rooms status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"byNickname", ( mbr ? [mbr title] : member ), @"who", member, @"whoNickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberVoiced:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];
		
			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberVoiced" withContextInfo:nil];
		}
	}

	// sort again if needed
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] )
		[self resortMembers];
}

- (void) devoiceChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	
	JVChatRoomMember *mbr = nil;
	if( ( mbr = [self chatRoomMemberWithName:member] ) ) {
		[mbr _setVoice:NO];
		[_windowController reloadListItem:mbr andChildren:NO];

		if( by && ! [by isMemberOfClass:[NSNull class]] ) {
			JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];

			NSString *message = nil;
			NSString *name = @"memberDevoiced";
			if( [mbr isLocalUser] && [byMbr isLocalUser] ) {
				message = NSLocalizedString( @"You removed voice from yourself.", "we removed our special voice status to talk in moderated rooms status message" );
				name = @"devoiced";
			} else if( [mbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"You had voice removed by %@.", "we no longer has special voice status and can't talk in moderated rooms status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"devoiced";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ had voice removed by you.", "we removed user's special voice status and can't talk in moderated rooms status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"%@ had voice removed by %@.", "user no longer has special voice status and can't talk in moderated rooms status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"byNickname", ( mbr ? [mbr title] : member ), @"who", member, @"whoNickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberDevoiced:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberDevoiced" withContextInfo:nil];
		}
	}

	// sort again if needed
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] )
		[self resortMembers];
}

#pragma mark -

- (void) chatMember:(NSString *) member kickedBy:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;

	NSParameterAssert( member != nil );
	NSParameterAssert( by != nil );

	rstring = [[[NSString alloc] initWithData:reason encoding:_encoding] autorelease];
	if( ! rstring ) rstring = [NSString stringWithCString:[reason bytes] length:[reason length]];

	JVChatRoomMember *mbr = [[[self chatRoomMemberWithName:member] retain] autorelease];
	JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), @encode( NSString * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( memberKicked:fromRoom:by:forReason: )];
	[invocation setArgument:&mbr atIndex:2];
	[invocation setArgument:&self atIndex:3];
	[invocation setArgument:&byMbr atIndex:4];
	[invocation setArgument:&rstring atIndex:5];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	if( [_windowController selectedListItem] == mbr )
		[_windowController showChatViewController:[_windowController activeChatViewController]];

	[_members removeObjectForKey:member];
	[_sortedMembers removeObjectIdenticalTo:mbr];

	[_windowController reloadListItem:self andChildren:YES];

	if( [byMbr isLocalUser] ) {
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You kicked %@ from the chat room.", "you removed a user by force from a chat room status message" ), ( mbr ? [mbr title] : member )] withName:@"memberKicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"byNickname", ( mbr ? [mbr title] : member ), @"who", member, @"whoNickname", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];
	} else {
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ was kicked from the chat room by %@.", "user has been removed by force from a chat room status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )] withName:@"memberKicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"byNickname", ( mbr ? [mbr title] : member ), @"who", member, @"whoNickname", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];
	}

	[[JVNotificationController defaultManager] performNotification:@"JVChatMemberKicked" withContextInfo:nil];
}

- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;

	NSParameterAssert( by != nil );

	rstring = [[[NSString alloc] initWithData:reason encoding:_encoding] autorelease];
	if( ! rstring ) rstring = [NSString stringWithCString:[reason bytes] length:[reason length]];

	JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];
	[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You were kicked from the chat room by %@.", "you were removed by force from a chat room status message" ), by] withName:@"kicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[byMbr title], @"by", by, @"byNickname", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	JVChatRoomMember *mbr = [[[self chatRoomMemberWithName:[[self connection] nickname]] retain] autorelease];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), @encode( NSString * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( kickedFromRoom:by:forReason: )];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&byMbr atIndex:3];
	[invocation setArgument:&rstring atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	if( [_windowController selectedListItem] == mbr )
		[_windowController showChatViewController:[_windowController activeChatViewController]];

	[_members removeObjectForKey:[mbr nickname]];
	[_sortedMembers removeObjectIdenticalTo:mbr];

	[_windowController reloadListItem:self andChildren:YES];

	_invalidateMembers = YES;
	_kickedFromRoom = YES;
	_cantSendMessages = YES;

	[[JVNotificationController defaultManager] performNotification:@"JVChatMemberKicked" withContextInfo:nil];

	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You were kicked from the chat room.", "you were removed by force from a chat room error message title" ), NSLocalizedString( @"You were kicked from the chat room by %@. You are no longer part of this chat and can't send anymore messages.", "you were removed by force from a chat room error message" ), @"OK", nil, nil, ( byMbr ? [byMbr title] : by ) ) withName:nil];
}

#pragma mark -

- (IBAction) changeEncoding:(id) sender {
	[super changeEncoding:sender];
	[self changeTopic:_topic by:_topicAuth];
}

- (void) changeTopic:(NSData *) topic by:(NSString *) author {
	if( ! [topic isMemberOfClass:[NSNull class]] ) {
		NSMutableString *topicString = ( topic ? [[[NSMutableString alloc] initWithData:topic encoding:_encoding] autorelease] : nil );
		if( ! topicString && topic ) topicString = [NSMutableString stringWithCString:[topic bytes] length:[topic length]];

		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
			[self _makeHyperlinksInString:topicString];

		if( topic && author && ! [author isMemberOfClass:[NSNull class]] ) {
			JVChatRoomMember *mbr = [self chatRoomMemberWithName:author];
			if( [mbr isLocalUser] ) {
				[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You changed the topic to \"%@\".", "you changed the topic chat room status message" ), topicString] withName:@"topicChanged" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? [mbr title] : author ), @"by", author, @"byNickname", topicString, @"topic", nil]];
			} else {
				[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"Topic changed to \"%@\" by %@.", "topic changed chat room status message" ), topicString, ( mbr ? [mbr title] : author )] withName:@"topicChanged" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? [mbr title] : author ), @"by", author, @"byNickname", topicString, @"topic", nil]];
			}

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSString * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( topicChangedTo:inRoom:by: )];
			[invocation setArgument:&topicString atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&mbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
		}

		if( ! [topicString length] )
			topicString = [NSString stringWithFormat:@"<span style=\"color: #6c6c6c\">%@</span>", NSLocalizedString( @"(no chat topic is set)", "no chat topic is set message" )];

		topicString = [NSString stringWithFormat:@"<span style=\"font-size: 11px; font-family: Lucida Grande, san-serif\">%@</span>", topicString];

		[_topic autorelease];
		_topic = [topic copy];

		[_topicAttributed autorelease];
		_topicAttributed = [[NSMutableAttributedString attributedStringWithHTMLFragment:topicString baseURL:nil] retain];

		NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[paraStyle setMaximumLineHeight:13.];
		[paraStyle setAlignment:NSCenterTextAlignment];
		[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		[(NSMutableAttributedString *)_topicAttributed addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange( 0, [_topicAttributed length] )];

		[[topicLine textStorage] setAttributedString:_topicAttributed];
	}

	if( author && ! [author isMemberOfClass:[NSNull class]] ) {
		[_topicAuth autorelease];
		_topicAuth = [author retain];
	}

	NSMutableString *toolTip = [[[_topicAttributed string] mutableCopy] autorelease];
	if( _topicAuth ) {
		[toolTip appendString:@"\n"];
		[toolTip appendFormat:NSLocalizedString( @"Topic set by: %@", "topic author tooltip" ), _topicAuth];
	}

	[[topicLine enclosingScrollView] setToolTip:toolTip];
}

- (NSAttributedString *) topic {
	return [[_topicAttributed retain] autorelease];
}

#pragma mark -

- (JVChatRoomMember *) chatRoomMemberWithName:(NSString *) name {
	JVChatRoomMember *member = nil;
	if( ( member = [_members objectForKey:member] ) )
		return member;

	NSEnumerator *enumerator = [_members objectEnumerator];
	while( ( member = [enumerator nextObject] ) )
		if( [[member nickname] isEqualToString:name] )
			return member;

	enumerator = [_members objectEnumerator];
	while( ( member = [enumerator nextObject] ) )
		if( [[member title] isEqualToString:name] )
			return member;

	return nil;
}

- (void) resortMembers {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] ) {
		[_sortedMembers sortUsingSelector:@selector( compareUsingStatus: )];
	} else [_sortedMembers sortUsingSelector:@selector( compare: )];

	[_windowController reloadListItem:self andChildren:YES];
}

#pragma mark -

- (BOOL) textView:(NSTextView *) textView tabKeyPressed:(NSEvent *) event {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVUsePantherTextCompleteOnTab"] ) {
		[textView complete:nil];
		return YES;
	}

	NSArray *tabArr = [[send string] componentsSeparatedByString:@" "];
	NSMutableArray *found = [NSMutableArray array];
	NSEnumerator *enumerator = [_sortedMembers objectEnumerator];
	NSString *name = nil, *shortest = nil;
	unsigned len = [(NSString *)[tabArr lastObject] length], count = 0;
	if( ! len ) return YES;
	while( ( name = [[enumerator nextObject] nickname] ) ) {
		if( len <= [name length] && [(NSString *)[tabArr lastObject] caseInsensitiveCompare:[name substringToIndex:len]] == NSOrderedSame ) {
			[found addObject:name];
			if( [name length] < [shortest length] || ! shortest ) shortest = [[name copy] autorelease];
			count++;
		}
	}
	if( count == 1 ) {
		[[send textStorage] replaceCharactersInRange:NSMakeRange([[send textStorage] length] - len, len) withString:shortest];
		if( ! [[send string] rangeOfString:@" "].length ) [send replaceCharactersInRange:NSMakeRange([[send textStorage] length], 0) withString:@": "];
		else [send replaceCharactersInRange:NSMakeRange([[send textStorage] length], 0) withString:@" "];
	} else if( count > 1 ) {
		BOOL match = YES;
		unsigned i = 0;
		NSString *cut = nil;
		count = NSNotFound;
		while( 1 ) {
			if( count == NSNotFound ) count = [shortest length];
			if( (signed) count <= 0 ) return YES;
			cut = [shortest substringToIndex:count];
			for( i = 0, match = YES; i < [found count]; i++ ) {
				if( ! [[found objectAtIndex:i] hasPrefix:cut] ) {
					match = NO;
					break;
				}
			}
			count--;
			if( match ) break;
		}
		[[send textStorage] replaceCharactersInRange:NSMakeRange([[send textStorage] length] - len, len) withString:cut];
	}
	return YES;
}

- (NSArray *) textView:(NSTextView *) textView completions:(NSArray *) words forPartialWordRange:(NSRange) charRange indexOfSelectedItem:(int *) index {
	NSString *search = [[[send textStorage] string] substringWithRange:charRange];
	NSEnumerator *enumerator = [_sortedMembers objectEnumerator];
	NSMutableArray *ret = [NSMutableArray array];
	NSString *name = nil;
	unsigned int length = [search length];
	while( length && ( name = [[enumerator nextObject] nickname] ) ) {
		if( length <= [name length] && [search caseInsensitiveCompare:[name substringToIndex:length]] == NSOrderedSame ) {
			[ret addObject:name];
		}
	}
	[ret addObjectsFromArray:words];
	return ret;
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = nil;
	if( toolbarItem ) return toolbarItem;
	else return [super toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:willBeInserted];
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarDefaultItemIdentifiers:toolbar]];
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
	return list;
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	return [super validateToolbarItem:toolbarItem];
}
@end

#pragma mark -

@implementation JVChatRoom (JVChatRoomPrivate)
- (void) _didConnect:(NSNotification *) notification {
	_invalidateMembers = YES;
	[[self connection] joinChatRoom:_target];
	[super _didConnect:notification];
}

- (void) _didDisconnect:(NSNotification *) notification {
	_kickedFromRoom = NO;
	_invalidateMembers = YES;
	[super _didDisconnect:notification];
	[_windowController reloadListItem:self andChildren:YES];
}

- (char *) _classificationForNickname:(NSString *) nickname {
	JVChatRoomMember *member = [self chatRoomMemberWithName:nickname];
	if( [member operator] ) return "operator";
	else if( [member voice] ) return "voice";
	return "normal";
}

- (void) _roomModeChanged:(NSNotification *) notification {
	if( notification && [[[notification userInfo] objectForKey:@"room"] caseInsensitiveCompare:_target] != NSOrderedSame ) return;
	if( [[[notification userInfo] objectForKey:@"by"] isMemberOfClass:[NSNull class]] ) return;

	NSString *member = [[notification userInfo] objectForKey:@"by"];
	JVChatRoomMember *mbr = [self chatRoomMemberWithName:member];
	NSString *message = nil;
	NSString *mode = nil;

	switch( [[[notification userInfo] objectForKey:@"mode"] unsignedIntValue] ) {
		case MVChatRoomPrivateMode:
			mode = @"chatRoomPrivateMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room private.", "private room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room private.", "someone else private room status message" ), ( mbr ? [mbr title] : member )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room public.", "public room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room public.", "someone else public room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomSecretMode:
			mode = @"chatRoomSecretMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room secret.", "secret room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room secret.", "someone else secret room status message" ), ( mbr ? [mbr title] : member )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer a secret.", "no longer secret room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer a secret.", "someone else no longer secret room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomInviteOnlyMode:
			mode = @"chatRoomInviteOnlyMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room invite only.", "invite only room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room invite only.", "someone else invite only room status message" ), ( mbr ? [mbr title] : member )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer invite only.", "no longer invite only room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer invite only.", "someone else no longer invite only room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomModeratedMode:
			mode = @"chatRoomModeratedMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room moderated.", "moderated room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room moderated.", "someone else moderated room status message" ), ( mbr ? [mbr title] : member )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You made this room no longer moderated.", "no longer moderated room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ made this room no longer moderated.", "someone else no longer moderated room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomSetTopicOperatorOnlyMode:
			mode = @"chatRoomSetTopicOperatorOnlyMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to require opperator status to change the topic.", "require op to set topic room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to require opperator status to change the topic.", "someone else required op to set topic room status message" ), ( mbr ? [mbr title] : member )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to allow anyone to change the topic.", "don't require op to set topic room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to allow anyone to change the topic.", "someone else don't required op to set topic room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomNoOutsideMessagesMode:
			mode = @"chatRoomNoOutsideMessagesMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to prohibit outside messages.", "prohibit outside messages room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to prohibit outside messages.", "someone else prohibit outside messages room status message" ), ( mbr ? [mbr title] : member )];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to permit outside messages.", "permit outside messages room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to permit outside messages.", "someone else permit outside messages room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomPasswordRequiredMode:
			mode = @"chatRoomPasswordRequiredMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = [NSString stringWithFormat:NSLocalizedString( @"You changed this room to require a password of \"%@\".", "password required room status message" ), [[notification userInfo] objectForKey:@"param"]];
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to require a password of \"%@\".", "someone else password required room status message" ), ( mbr ? [mbr title] : member ), [[notification userInfo] objectForKey:@"param"]];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to no longer require a password.", "no longer passworded room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to no longer require a password.", "someone else no longer passworded room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
		case MVChatRoomMemberLimitMode:
			mode = @"chatRoomMemberLimitMode";
			if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
				if( [mbr isLocalUser] ) {
					message = [NSString stringWithFormat:NSLocalizedString( @"You set a limit on the number of room members to %@.", "member limit room status message" ), [[notification userInfo] objectForKey:@"param"]];
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ set a limit on the number of room members to %@.", "someone else member limit room status message" ), ( mbr ? [mbr title] : member ), [[notification userInfo] objectForKey:@"param"]];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You removed the room member limit.", "no member limit room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ removed the room member limit", "someone else no member limit room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
			break;
	}

	[self addEventMessageToDisplay:message withName:@"modeChange" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? [mbr title] : member ), @"by", member, @"byNickname", mode, @"mode", ( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ? @"yes" : @"no" ), @"enabled", [[notification userInfo] objectForKey:@"param"], @"parameter", nil]];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatRoomMemberObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[JVChatRoom class]];
	NSScriptObjectSpecifier *container = [_parent objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatMembers" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVChatRoom (JVChatRoomScripting)
- (NSArray *) chatMembers {
	return [[_sortedMembers retain] autorelease];
}

- (JVChatRoomMember *) valueInChatMembersWithName:(NSString *) name {
	return [self chatRoomMemberWithName:name];
}

- (JVChatRoomMember *) valueInChatMembersWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [_members objectEnumerator];
	JVChatRoomMember *member = nil;

	while( ( member = [enumerator nextObject] ) )
		if( [[member uniqueIdentifier] isEqual:identifier] )
			return member;

	return nil;
}

- (NSTextStorage *) scriptTypedTopic {
	return [[[NSTextStorage alloc] initWithAttributedString:_topicAttributed] autorelease];
}

- (void) setScriptTypedTopic:(NSString *) topic {
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:topic baseURL:nil];
	[[self connection] setTopic:attributeMsg withEncoding:_encoding forRoom:[self target]];
}
@end

#pragma mark -

@implementation MVChatScriptPlugin (MVChatScriptPluginRoomSupport)
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(JVChatRoom *) room {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", [arguments string], @"pcC1", room, @"pcC2", nil];
	id result = [self callScriptHandler:'pcCX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processMessage:(NSMutableData *) message asAction:(BOOL) action fromMember:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room {
	NSString *messageString = [[[NSString alloc] initWithData:message encoding:[room encoding]] autorelease];
	if( ! messageString ) messageString = [NSString stringWithCString:[message bytes] length:[message length]];
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:messageString, @"----", [NSNumber numberWithBool:action], @"piM1", [member nickname], @"piM2", room, @"piM3", nil];
	id result = [self callScriptHandler:'piMX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	else if( [result isKindOfClass:[NSString class]] ) {
		NSData *resultData = [result dataUsingEncoding:[room encoding] allowLossyConversion:YES];
		if( resultData ) [message setData:resultData];
	}
}

- (void) processMessage:(NSMutableAttributedString *) message asAction:(BOOL) action toRoom:(JVChatRoom *) room {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:[message string], @"----", [NSNumber numberWithBool:action], @"poM1", room, @"poM2", nil];
	id result = [self callScriptHandler:'poMX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	else if( [result isKindOfClass:[NSString class]] )
		[message setAttributedString:[[[NSAttributedString alloc] initWithString:result] autorelease]];
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", room, @"mJr1", nil];
	if( ! [self callScriptHandler:'mJrX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoom *) room forReason:(NSString *) reason {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", room, @"mPr1", reason, @"mPr2", nil];
	if( ! [self callScriptHandler:'mPrX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by forReason:(NSString *) reason {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", room, @"mKr1", by, @"mKr2", reason, @"mKr3", nil];
	if( ! [self callScriptHandler:'mKrX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) memberPromoted:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:"cOpr" objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	if( ! [self callScriptHandler:'mScX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) memberDemoted:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:( [member voice] ? "VoIc" : "noRm" ) objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	if( ! [self callScriptHandler:'mScX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) memberVoiced:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:"VoIc" objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	if( ! [self callScriptHandler:'mScX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) memberDevoiced:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:( [member operator] ? "cOpr" : "noRm" ) objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	if( ! [self callScriptHandler:'mScX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoom *) room; {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:room, @"----", nil];
	if( ! [self callScriptHandler:'jRmX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoom *) room; {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:room, @"----", nil];
	if( ! [self callScriptHandler:'pRmX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by forReason:(NSString *) reason {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:room, @"----", by, @"kRm1", reason, @"kRm2", nil];
	if( ! [self callScriptHandler:'kRmX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) topicChangedTo:(NSString *) topic inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) member {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:topic, @"rTc1", member, @"rTc2", room, @"rTc3", nil];
	if( ! [self callScriptHandler:'rTcX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}
@end