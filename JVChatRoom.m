#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatScriptPlugin.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <AGRegex/AGRegex.h>

#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "JVNotificationController.h"
#import "MVBuddyListController.h"
#import "JVBuddy.h"
#import "MVTextView.h"
#import "NSURLAdditions.h"

NSString *MVChatRoomModeChangedNotification = @"MVChatRoomModeChangedNotification";

@interface JVDirectChat (JVDirectChatPrivate)
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
- (void) _makeHyperlinksInString:(NSMutableString *) string;
- (void) _didConnect:(NSNotification *) notification;
- (void) _didDisconnect:(NSNotification *) notification;
@end

#pragma mark -

@interface JVChatRoomMember (JVChatMemberPrivate)
- (NSString *) _selfStoredNickname;
- (NSString *) _selfCompositeName;

- (void) _setNickname:(NSString *) name;
- (void) _setAddress:(NSString *) address;
- (void) _setRealName:(NSString *) name;
- (void) _setVoice:(BOOL) voice;
- (void) _setOperator:(BOOL) operator;
- (void) _setHalfOperator:(BOOL) operator;
- (void) _setServerOperator:(BOOL) operator;
@end

#pragma mark -

@implementation JVChatRoom
- (id) init {
	if( ( self = [super init] ) ) {
		topicLine = nil;
		_topic = nil;
		_topicAuth = nil;
		_modes = 0;
		_topicAttributed = nil;
		_members = [[NSMutableDictionary dictionary] retain];
		_sortedMembers = [[NSMutableArray array] retain];
		_kickedFromRoom = NO;
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
	if (_inRoom) {
		[[self connection] partChatRoom:[self target]];
	}

	[_members release];
	[_sortedMembers release];
	[_key release];
	[_topic release];
	[_topicAuth release];
	[_topicAttributed release];

	_members = nil;
	_sortedMembers = nil;
	_key = nil;
	_topic = nil;
	_topicAuth = nil;
	_topicAttributed = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Delegate Methods
//or method
- (void) willDispose {
	[self partChat:nil];
}

#pragma mark -
#pragma mark Miscellaneous Support

- (NSString *) title {
	NSMutableString *title = [NSMutableString stringWithString:_target];
	[title deleteCharactersInRange:NSMakeRange( 0, 1 )];
	return [[title retain] autorelease];
}

- (NSString *) windowTitle {
	NSMutableString *title = [NSMutableString stringWithString:_target];
	[title deleteCharactersInRange:NSMakeRange( 0, 1 )];
	return [NSString stringWithFormat:@"%@ (%@)", title, [[self connection] server]];
}

- (NSString *) information {
	if( _kickedFromRoom )
		return NSLocalizedString( @"kicked out", "chat room kicked status line in drawer" );
	if( ! [_sortedMembers count] )
		return NSLocalizedString( @"joining...", "joining status info line in drawer" );
	if( [[self connection] isConnected] ) {
		if ( [[[MVConnectionsController defaultManager] connectedConnections] count] == 1 ) return [NSString stringWithFormat:@"%d members", [_sortedMembers count]];
		else return [_connection server];
	}
	return NSLocalizedString( @"disconnected", "disconnected status info line in drawer" );
}

- (NSString *) toolTip {
	NSString *messageCount = @"";
	if( [self newMessagesWaiting] == 0 ) messageCount = NSLocalizedString( @"no messages waiting", "no messages waiting room tooltip" );
	else if( [self newMessagesWaiting] == 1 ) messageCount = NSLocalizedString( @"1 message waiting", "one message waiting room tooltip" );
	else messageCount = [NSString stringWithFormat:NSLocalizedString( @"%d messages waiting", "messages waiting room tooltip" ), [self newMessagesWaiting]];
	return [NSString stringWithFormat:NSLocalizedString( @"%@ (%@)\n%d members\n%@", "room status info tooltip in drawer" ), _target, [_connection server], [_sortedMembers count], messageCount];
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatRoom" owner:self];
	return contents;
}

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Chat Room %@ (%@)", _target, [[self connection] server]];
}

#pragma mark -
#pragma mark Drawer/Outline View Support

- (NSImage *) icon {
	return [NSImage imageNamed:@"room"];
}

- (BOOL) isEnabled {
	return _inRoom;
}

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

	if( _inRoom ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Leave Room", "leave room contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	} else {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Join Room", "join room contextual menu item title" ) action:@selector( joinChat: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

#pragma mark -
#pragma mark Drag & Drop Support

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return NO;
}

- (void) handleDraggedFile:(NSString *) path {
	[NSException raise:NSIllegalSelectorException format:@"JVChatRoom does not implement handleDraggedFile:"];
	return;
}

#pragma mark -
#pragma mark Unsupported Methods Inherited Methods

- (void) setTarget:(NSString *) target {
	[NSException raise:NSIllegalSelectorException format:@"JVChatRoom does not implement setTarget:"];
	return;
}

- (JVBuddy *) buddy {
	[NSException raise:NSIllegalSelectorException format:@"JVChatRoom does not implement buddy:"];
	return nil;
}

#pragma mark -
#pragma mark Miscellaneous

- (void) unavailable {
//	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You're offline", "title of the you're offline message sheet" ), NSLocalizedString( @"You are no longer connected to the server where you were chatting. No messages can be sent at this time. Reconnecting might be in progress.", "chat window error description for loosing connection" ), @"OK", nil, nil ) withName:@"disconnected"];
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
#pragma mark Modes

- (void) setModes:(unsigned int) modes {
	_modes = modes;
}

- (unsigned int) modes {
	return _modes;
}

#pragma mark -

- (void) setKey:(NSString *) key {
	[_key autorelease];
	_key = [key copy];
}

- (NSString *) key {
	return [[_key autorelease] retain];
}

#pragma mark -

- (void) setLimit:(unsigned int) limit {
	_limit = limit;
}

- (unsigned int) limit {
	return _limit;
}

#pragma mark -
#pragma mark Message Handling

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

- (void) processMessage:(NSMutableString *) message asAction:(BOOL) action fromUser:(NSString *) user {
	JVChatRoomMember *member = [self chatRoomMemberWithName:user];

	if( ! [user isEqualToString:[[self connection] nickname]] && ( ! [[[self view] window] isMainWindow] || ! _isActive ) ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ Room Activity", "room activity bubble title" ), [self title]] forKey:@"title"];
		if( [self newMessagesWaiting] == 1 ) [context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ has 1 message waiting.", "new single room message bubble text" ), [self title]] forKey:@"description"];
		else [context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ has %d messages waiting.", "new room messages bubble text" ), [self title], [self newMessagesWaiting]] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"room"] forKey:@"image"];
		[context setObject:_target forKey:@"performedOn"];
		[context setObject:user forKey:@"performedBy"];
		[context setObject:_target forKey:@"performedInRoom"];
		[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatRoomActivity"] forKey:@"coalesceKey"];
		[[JVNotificationController defaultManager] performNotification:@"JVChatRoomActivity" withContextInfo:context];
	}

	NSEnumerator *enumerator = [_sortedMembers objectEnumerator];
	AGRegex *regex = nil;
	NSString *name = nil;
	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];

	while( ( name = [[enumerator nextObject] nickname] ) ) {
		// Avoid putting stuff in the autorelease pool if we don't have to
		// On #gentoo this will be called 800+ times
		NSMutableString *escapedName = [name mutableCopy];
		[escapedName escapeCharactersInSet:escapeSet];
		NSString *pattern = [[NSString alloc] initWithFormat:@"(?:\\W|^)(%@)(?:\\W|$)", escapedName];
		regex = [AGRegex regexWithPattern:pattern options:AGRegexCaseInsensitive];
		[escapedName release];
		[pattern release];
		NSRange searchRange = NSMakeRange(0, [message length]);
		NSRange backSearchRange = NSMakeRange(0, [message length]);
		AGRegexMatch *match = [regex findInString:message range:searchRange];
		while ( match ) {
			NSRange foundRange = [match rangeAtIndex:1];
			backSearchRange.length = foundRange.location - backSearchRange.location;
			
			// Search to see if we're in a tag
			NSRange leftRange = [message rangeOfString:@"<" options:(NSBackwardsSearch|NSLiteralSearch) range:backSearchRange];
			NSRange rightRange = [message rangeOfString:@">" options:(NSBackwardsSearch|NSLiteralSearch) range:backSearchRange];
			
			if( leftRange.location == NSNotFound || ( rightRange.location != NSNotFound && rightRange.location > leftRange.location ) ) {
				// Search to see if we're in a link
				NSRange openRange = [message rangeOfString:@"<a " options:(NSBackwardsSearch|NSLiteralSearch) range:backSearchRange];
				NSRange closeRange = [message rangeOfString:@"</a>" options:(NSBackwardsSearch|NSLiteralSearch) range:backSearchRange];

				if( openRange.location == NSNotFound || ( closeRange.location != NSNotFound && closeRange.location > openRange.location ) ) {
					[message replaceCharactersInRange:foundRange withString:[NSString stringWithFormat:@"<span class=\"member\">%@</span>", [match groupAtIndex:1]]];
					searchRange.location = NSMaxRange( foundRange ) + 28;
					searchRange.length = [message length] - searchRange.location;
					backSearchRange.location = searchRange.location;
				} else {
					searchRange.location = NSMaxRange( foundRange );
					searchRange.length = [message length] - searchRange.location;
				}
			} else {
				searchRange.location = NSMaxRange( foundRange );
				searchRange.length = [message length] - searchRange.location;
			}
			match = [regex findInString:message range:searchRange];
		}
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableString * ), @encode( BOOL ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), nil];
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
#pragma mark Operator Support
//It's their world, we just live in it

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
				message = [NSString stringWithFormat:NSLocalizedString( @"You were promoted to operator by <span class=\"member\">%@</span>.", "we are now a chat room operator status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"promoted";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to operator by you.", "we gave user chat room operator status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was promoted to operator by <span class=\"member\">%@</span>.", "user is now a chat room operator status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"bynickname", member, @"who", ( mbr ? [mbr title] : member ), @"whonickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberPromoted:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			//create notification
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"Room Member Promoted", "member promoted title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ was promoted to operator by %@ in %@.", "bubble message member operator promotion string" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by ), _target] forKey:@"description"];
			[context setObject:member forKey:@"performedOn"];
			[context setObject:by forKey:@"performedBy"];
			[context setObject:_target forKey:@"performedInRoom"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberPromoted" withContextInfo:context];
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
				message = [NSString stringWithFormat:NSLocalizedString( @"You were demoted from operator by <span class=\"member\">%@</span>.", "we are no longer a chat room operator status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"demoted";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from operator by you.", "we removed user's chat room operator status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was demoted from operator by <span class=\"member\">%@</span>.", "user is no longer a chat room operator status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"bynickname", ( mbr ? [mbr title] : member ), @"who", member, @"whonickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberDemoted:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			//create notification
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"Room Member Demoted", "member demoted title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ was demoted from operator by %@ in %@.", "bubble message member operator demotion string" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by ), _target] forKey:@"description"];
			[context setObject:member forKey:@"performedOn"];
			[context setObject:by forKey:@"performedBy"];
			[context setObject:_target forKey:@"performedInRoom"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberDemoted" withContextInfo:context];
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
				message = [NSString stringWithFormat:NSLocalizedString( @"You were granted voice by <span class=\"member\">%@</span>.", "we now have special voice status to talk in moderated rooms status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"voiced";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was granted voice by you.", "we gave user special voice status to talk in moderated rooms status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> was granted voice by <span class=\"member\">%@</span>.", "user now has special voice status to talk in moderated rooms status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"bynickname", ( mbr ? [mbr title] : member ), @"who", member, @"whonickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberVoiced:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			//create notification
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"Room Member Voiced", "member voiced title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ was granted voice by %@ in %@.", "bubble message member voiced string" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by ), _target] forKey:@"description"];
			[context setObject:member forKey:@"performedOn"];
			[context setObject:by forKey:@"performedBy"];
			[context setObject:_target forKey:@"performedInRoom"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberVoiced" withContextInfo:context];
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
				message = [NSString stringWithFormat:NSLocalizedString( @"You had voice removed by <span class=\"member\">%@</span>.", "we no longer has special voice status and can't talk in moderated rooms status message" ), ( byMbr ? [byMbr title] : by )];
				name = @"devoiced";
			} else if( [byMbr isLocalUser] ) {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> had voice removed by you.", "we removed user's special voice status and can't talk in moderated rooms status message" ), ( mbr ? [mbr title] : member )];
			} else {
				message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> had voice removed by <span class=\"member\">%@</span>.", "user no longer has special voice status and can't talk in moderated rooms status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
			}

			[self addEventMessageToDisplay:message withName:name andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"bynickname", ( mbr ? [mbr title] : member ), @"who", member, @"whonickname", nil]];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), @encode( JVChatRoomMember * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( memberDevoiced:inRoom:by: )];
			[invocation setArgument:&mbr atIndex:2];
			[invocation setArgument:&self atIndex:3];
			[invocation setArgument:&byMbr atIndex:4];

			[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

			//create notification
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"Room Member Lost Voice", "member devoiced title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ had voice removed by %@ in %@.", "bubble message member lost voice string" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by ), _target] forKey:@"description"];
			[context setObject:member forKey:@"performedOn"];
			[context setObject:by forKey:@"performedBy"];
			[context setObject:_target forKey:@"performedInRoom"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatMemberDevoiced" withContextInfo:context];
		}
	}

	// sort again if needed
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] )
		[self resortMembers];
}

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

	NSString *message = nil;
	if( [byMbr isLocalUser] ) {
		message = [NSString stringWithFormat:NSLocalizedString( @"You kicked %@ from the chat room.", "you removed a user by force from a chat room status message" ), ( mbr ? [mbr title] : member )];
	} else {
		message = [NSString stringWithFormat:NSLocalizedString( @"%@ was kicked from the chat room by <span class=\"member\">%@</span>.", "user has been removed by force from a chat room status message" ), ( mbr ? [mbr title] : member ), ( byMbr ? [byMbr title] : by )];
	}
	[self addEventMessageToDisplay:message withName:@"memberKicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( byMbr ? [byMbr title] : by ), @"by", by, @"bynickname", ( mbr ? [mbr title] : member ), @"who", member, @"whonickname", ( [mbr address] ? [mbr address] : @"" ), @"mask", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	//create notification
	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	[context setObject:NSLocalizedString( @"Room Member Kicked", "member kicked title" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ was kicked from %@ by %@.", "bubble message member kicked string" ), ( mbr ? [mbr title] : member ), _target, ( byMbr ? [byMbr title] : by )] forKey:@"description"];
	[context setObject:member forKey:@"performedOn"];
	[context setObject:( byMbr ? [byMbr title] : by ) forKey:@"performedBy"];
	[context setObject:_target forKey:@"performedInRoom"];
	[[JVNotificationController defaultManager] performNotification:@"JVChatMemberKicked" withContextInfo:context];
}

- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;

	NSParameterAssert( by != nil );

	rstring = [[[NSString alloc] initWithData:reason encoding:_encoding] autorelease];
	if( ! rstring ) rstring = [NSString stringWithCString:[reason bytes] length:[reason length]];

	JVChatRoomMember *byMbr = [self chatRoomMemberWithName:by];
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"You were kicked from the chat room by %@.", "you were removed by force from a chat room status message" ), ( byMbr ? [byMbr title] : by )];
	[self addEventMessageToDisplay:message withName:@"kicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[byMbr title], @"by", by, @"bynickname", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

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

	_kickedFromRoom = YES;
	_cantSendMessages = YES;
	_inRoom = NO;

	[_windowController reloadListItem:self andChildren:YES];
	//create notification
	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	[context setObject:NSLocalizedString( @"You Were Kicked", "member kicked title" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You were kicked from %@ by %@.", "bubble message member kicked string" ), _target, ( byMbr ? [byMbr title] : by )] forKey:@"description"];
	[context setObject:[[self connection] nickname] forKey:@"performedOn"];
	[context setObject:( byMbr ? [byMbr title] : by ) forKey:@"performedBy"];
	[context setObject:_target forKey:@"performedInRoom"];
	[[JVNotificationController defaultManager] performNotification:@"JVChatMemberKicked" withContextInfo:context];

	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You were kicked from the chat room.", "you were removed by force from a chat room error message title" ), NSLocalizedString( @"You were kicked from the chat room by %@. You are no longer part of this chat and can't send anymore messages.", "you were removed by force from a chat room error message" ), @"OK", nil, nil, ( byMbr ? [byMbr title] : by ) ) withName:nil];
}

- (void) changeTopic:(NSData *) topic by:(NSString *) author displayChange:(BOOL) showChange {
	NSMutableString *topicString = ( topic ? [[[NSMutableString alloc] initWithData:topic encoding:_encoding] autorelease] : nil );
	if( ! topicString && topic ) topicString = [NSMutableString stringWithCString:[topic bytes] length:[topic length]];

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
		[self _makeHyperlinksInString:topicString];

	if( showChange && author ) {
		JVChatRoomMember *mbr = [self chatRoomMemberWithName:author];
		if( [mbr isLocalUser] ) {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You changed the topic to \"%@\".", "you changed the topic chat room status message" ), topicString] withName:@"topicChanged" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? [mbr title] : author ), @"by", author, @"bynickname", topicString, @"topic", nil]];
		} else {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"Topic changed to \"%@\" by <span class=\"member\">%@</span>.", "topic changed chat room status message" ), topicString, ( mbr ? [mbr title] : author )] withName:@"topicChanged" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? [mbr title] : author ), @"by", author, @"bynickname", topicString, @"topic", nil]];
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

	[_topicAuth autorelease];
	_topicAuth = [author retain];

	NSMutableString *toolTip = [[[_topicAttributed string] mutableCopy] autorelease];
	[toolTip appendString:@"\n"];
	[toolTip appendFormat:NSLocalizedString( @"Topic set by: %@", "topic author tooltip" ), _topicAuth];

	[[topicLine enclosingScrollView] setToolTip:toolTip];
}

- (NSAttributedString *) topic {
	return [[_topicAttributed retain] autorelease];
}

#pragma mark -
#pragma mark Encoding Support

- (IBAction) changeEncoding:(id) sender {
	[super changeEncoding:sender];
	[self changeTopic:_topic by:_topicAuth displayChange:NO];
}

#pragma mark -
#pragma mark Join & Part Handling

- (void) joined {
	[_members removeAllObjects];
	[_sortedMembers removeAllObjects];

	_cantSendMessages = NO;
	_kickedFromRoom = NO;
	_inRoom = YES;
	[_windowController reloadListItem:self andChildren:YES];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoom * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( joinedRoom: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}	

- (void) parting {
	if (_inRoom) {
		_inRoom = NO;
		_cantSendMessages = YES;
		
		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoom * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( partingFromRoom: )];
		[invocation setArgument:&self atIndex:2];

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	}
}

- (void) joinChat:(id) sender {
	if( ! _inRoom ) [[self connection] joinChatRoom:_target];
}

- (void) partChat:(id) sender {
	if( _inRoom ) {
		[self parting];
		[[self connection] partChatRoom:_target];
	}
}

#pragma mark -
#pragma mark User List Management

- (JVChatRoomMember *) chatRoomMemberWithName:(NSString *) name {
	JVChatRoomMember *member = nil;
	if( ( member = [_members objectForKey:member] ) )
		return member;

	NSEnumerator *enumerator = [_members objectEnumerator];
	while( ( member = [enumerator nextObject] ) )
		if( [[member nickname] caseInsensitiveCompare:name] == NSOrderedSame)
			return member;

	enumerator = [_members objectEnumerator];
	while( ( member = [enumerator nextObject] ) )
		if( [[member title] caseInsensitiveCompare:name] == NSOrderedSame )
			return member;

	return nil;
}

- (void) resortMembers {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSortRoomMembersByStatus"] ) {
		[_sortedMembers sortUsingSelector:@selector( compareUsingStatus: )];
	} else [_sortedMembers sortUsingSelector:@selector( compare: )];

	[_windowController reloadListItem:self andChildren:YES];
}

- (void) addExistingMembersToChat:(NSArray *) members {
	[_members removeAllObjects];
	[_sortedMembers removeAllObjects];

	NSEnumerator *enumerator = [members objectEnumerator];
	NSDictionary *info = nil;
	NSString *member = nil;

	while( ( info = [enumerator nextObject] ) ) {
		member = [info objectForKey:@"nickname"];

		JVChatRoomMember *listItem = [[[JVChatRoomMember alloc] initWithRoom:self andNickname:member] autorelease];
		[listItem _setAddress:[info objectForKey:@"address"]];
		[listItem _setOperator:[[info objectForKey:@"operator"] boolValue]];
		[listItem _setHalfOperator:[[info objectForKey:@"halfOperator"] boolValue]];
		[listItem _setServerOperator:[[info objectForKey:@"serverOperator"] boolValue]];
		[listItem _setVoice:[[info objectForKey:@"voice"] boolValue]];

		[_members setObject:listItem forKey:member];
		[_sortedMembers addObject:listItem];
	}

	[self resortMembers];
}

- (void) addMemberToChat:(NSString *) member withInformation:(NSDictionary *) info {
	NSParameterAssert( member != nil );

	if( ! [self chatRoomMemberWithName:member] ) {
		JVChatRoomMember *listItem = [[[JVChatRoomMember alloc] initWithRoom:self andNickname:member] autorelease];
		[listItem _setAddress:[info objectForKey:@"address"]];
		[listItem _setOperator:[[info objectForKey:@"operator"] boolValue]];
		[listItem _setHalfOperator:[[info objectForKey:@"halfOperator"] boolValue]];
		[listItem _setServerOperator:[[info objectForKey:@"serverOperator"] boolValue]];
		[listItem _setVoice:[[info objectForKey:@"voice"] boolValue]];

		[_members setObject:listItem forKey:member];
		[_sortedMembers addObject:listItem];

		[self resortMembers];

		NSString *name = [listItem title];
		NSString *message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> joined the chat room.", "a user has join a chat room status message" ), name];
		[self addEventMessageToDisplay:message withName:@"memberJoined" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:member, @"nickname", name, @"who", ( [listItem address] ? [listItem address] : @"" ), @"mask", nil]];

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVChatRoomMember * ), @encode( JVChatRoom * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( memberJoined:inRoom: )];
		[invocation setArgument:&listItem atIndex:2];
		[invocation setArgument:&self atIndex:3];

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

		//create notification
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"Room Member Joined", "member joined title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ joined the chat room %@.", "bubble message member joined string" ), name, _target] forKey:@"description"];
		[context setObject:member forKey:@"performedOn"];
		[context setObject:_target forKey:@"performedInRoom"];
		[[JVNotificationController defaultManager] performNotification:@"JVChatMemberJoinedRoom" withContextInfo:context];
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
		NSString *message = [NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> left the chat room.", "a user has left the chat room status message" ), name];
		[self addEventMessageToDisplay:message withName:@"memberParted" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:name, @"who", member, @"nickname", ( [mbr address] ? [mbr address] : @"" ), @"mask", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

		//create notification
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"Room Member Left", "member left title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ left the chat room %@.", "bubble message member left string" ), name, _target] forKey:@"description"];
		[context setObject:member forKey:@"performedOn"];
		[context setObject:_target forKey:@"performedInRoom"];
		[[JVNotificationController defaultManager] performNotification:@"JVChatMemberLeftRoom" withContextInfo:context];
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
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You are now known as <span class=\"member\">%@</span>.", "you changed nicknames" ), nick] withName:@"newNickname" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[mbr title], @"name", member, @"old", nick, @"new", nil]];
		} else {
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ is now known as <span class=\"member\">%@</span>.", "user has changed nicknames" ), name, nick] withName:@"memberNewNickname" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", member, @"old", nick, @"new", nil]];
		}

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSString * ), @encode( NSString * ), @encode( JVChatRoom * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( userNamed:isNowKnownAs:inView: )];
		[invocation setArgument:&member atIndex:2];
		[invocation setArgument:&nick atIndex:3];
		[invocation setArgument:&self atIndex:4];

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	}
}

#pragma mark -
#pragma mark WebKit supprt

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	if( [[[element objectForKey:WebElementLinkURLKey] scheme] isEqualToString:@"member"] ) {
		NSMutableArray *ret = [NSMutableArray array];
		JVChatRoomMember *mbr = [self chatRoomMemberWithName:[[[element objectForKey:WebElementLinkURLKey] resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		NSEnumerator *enumerator = [[[mbr menu] itemArray] objectEnumerator];
		NSMenuItem *item = nil;

		while( ( item = [enumerator nextObject] ) )
			[ret addObject:[[item copy] autorelease]];

		return ret;
	}

	return [super webView:sender contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	if( [[[actionInformation objectForKey:WebActionOriginalURLKey] scheme] isEqualToString:@"member"] ) {
		JVChatRoomMember *mbr = [self chatRoomMemberWithName:[[[actionInformation objectForKey:WebActionOriginalURLKey] resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		if( mbr ) [mbr startChat:nil];
		else [[JVChatController defaultManager] chatViewControllerForUser:[[actionInformation objectForKey:WebActionOriginalURLKey] resourceSpecifier] withConnection:[self connection] ifExists:NO];
		[listener ignore];
	} else {
		[super webView:sender decidePolicyForNavigationAction:actionInformation request:request frame:frame decisionListener:listener];
	}
}

#pragma mark -
#pragma mark TextView/Input supprt

- (BOOL) textView:(NSTextView *) textView tabKeyPressed:(NSEvent *) event {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVUsePantherTextCompleteOnTab"] ) {
		[textView complete:nil];
		return YES;
	}

	// get partial completion & insertion point location
	NSRange curPos = [textView selectedRange];
	NSCharacterSet *illegalCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"[]{}-_^|\'`abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] invertedSet];
	NSString *partialCompletion = nil;
	NSRange wordStart = [[textView string] rangeOfCharacterFromSet:illegalCharacters options:NSBackwardsSearch range:NSMakeRange(0, curPos.location)];

	// get the string before
	if( wordStart.location == NSNotFound )
		wordStart = NSMakeRange( 0, 0 );
	NSRange theRange = NSMakeRange(NSMaxRange(wordStart), curPos.location - NSMaxRange(wordStart));
	partialCompletion = [[textView string] substringWithRange:theRange];

	// continue if necessary
	if( ! [partialCompletion isEqualToString:@""] ) {
		// compile list of possible completions
		NSEnumerator *enumerator = [_sortedMembers objectEnumerator];
		NSMutableArray *possibleNicks = [NSMutableArray array];
		NSString *name = nil;

		while( name = [[enumerator nextObject] nickname] )
			if( [name rangeOfString:partialCompletion options:NSCaseInsensitiveSearch|NSAnchoredSearch].location == 0 )
				[possibleNicks addObject:name];

		// insert word or suggestion
		if( [possibleNicks count] == 1 && ( curPos.location == [[textView string] length] || [illegalCharacters characterIsMember:[[textView string] characterAtIndex:curPos.location]] ) ) {
			name = [possibleNicks objectAtIndex:0];
			NSRange replacementRange = NSMakeRange( curPos.location - [partialCompletion length], [partialCompletion length] );

			[textView replaceCharactersInRange:replacementRange withString:name];
			if( replacementRange.location == 0 ) [textView insertText:@": "];
			else [textView insertText:@" "];
		} else if ( [possibleNicks count] > 1 ) {
			// since several are available, we highlight the modified text

			NSRange wordRange;
			BOOL keepSearching = YES;
			int count = 0;

			wordRange = [[textView string] rangeOfCharacterFromSet:illegalCharacters options:0 range:NSMakeRange( curPos.location, [[textView string] length] - curPos.location )];
			if( wordRange.location == NSNotFound )
				wordRange = NSMakeRange( NSMaxRange( wordStart ), [[textView string] length] - NSMaxRange( wordStart )) ;
			else wordRange = NSMakeRange( NSMaxRange( wordStart ), wordRange.location - NSMaxRange( wordStart ));

			NSString *tempWord = [[textView string] substringWithRange:wordRange];

			do {
				keepSearching = ! [[possibleNicks objectAtIndex:count] isEqualToString:tempWord];
			} while ( ++count < [possibleNicks count] && keepSearching );

			if( count == [possibleNicks count] ) count = 0;

			if( ! keepSearching ) {
				name = [possibleNicks objectAtIndex:count];
				if( wordRange.location == 0 ) name = [name stringByAppendingString:@": "];
				else name = [name stringByAppendingString:@" "];
				[textView replaceCharactersInRange:wordRange withString:[possibleNicks objectAtIndex:count]];
				[textView setSelectedRange:NSMakeRange( curPos.location, [name length] - [partialCompletion length] )];
			} else if( curPos.location == [[textView string] length] || [illegalCharacters characterIsMember:[[textView string] characterAtIndex:curPos.location]] ) {
				NSRange replacementRange = NSMakeRange( curPos.location - [partialCompletion length], [partialCompletion length] );
				name = [possibleNicks objectAtIndex:0];
				if( replacementRange.location == 0 ) name = [name stringByAppendingString:@": "];
				else name = [name stringByAppendingString:@" "];
				[textView replaceCharactersInRange:replacementRange withString:name];
				[textView setSelectedRange:NSMakeRange( curPos.location, [name length] - [partialCompletion length] )];
			}
		}
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
#pragma mark Toolbar Support
- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Chat Room"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];

//	[_toolbarItems release];
//	_toolbarItems = [[NSMutableDictionary dictionary] retain];

	return [toolbar autorelease];
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = nil;
	if( toolbarItem ) return toolbarItem;
	else return [super toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:willBeInserted];
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
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
	[[self connection] joinChatRoom:_target];
	[super _didConnect:notification];
	_cantSendMessages = YES;
}

- (void) _didDisconnect:(NSNotification *) notification {
	_kickedFromRoom = NO;
	_inRoom = NO;
	[super _didDisconnect:notification];
	[_windowController reloadListItem:self andChildren:YES];
}

- (char *) _classificationForNickname:(NSString *) nickname {
	JVChatRoomMember *member = [self chatRoomMemberWithName:nickname];
	if( [member serverOperator] ) return "server operator";
	else if( [member operator] ) return "operator";
	else if( [member halfOperator] ) return "half operator";
	else if( [member voice] ) return "voice";
	return "normal";
}

- (void) _roomModeChanged:(NSNotification *) notification {
	if( [[[notification userInfo] objectForKey:@"room"] caseInsensitiveCompare:_target] != NSOrderedSame ) return;
	
	unsigned int currentModes = [[[notification userInfo] objectForKey:@"mode"] unsignedIntValue];
	unsigned int newModes = currentModes & ~ [self modes];
	unsigned int oldModes = [self modes] & ~ currentModes;
	unsigned int changedModes = newModes | oldModes;

	[self setModes:currentModes];
	[self setKey:[[notification userInfo] objectForKey:@"key"]];
	[self setLimit:[(NSNumber *)[[notification userInfo] objectForKey:@"limit"] unsignedIntValue]];

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomModeChangedNotification object:self];

	if( [[[notification userInfo] objectForKey:@"by"] isMemberOfClass:[NSNull class]] ) return;
	if( [[[notification userInfo] objectForKey:@"by"] rangeOfString:@"."].location != NSNotFound ) return; // It's a server

	NSString *member = [[notification userInfo] objectForKey:@"by"];
	JVChatRoomMember *mbr = [self chatRoomMemberWithName:member];
	NSString *message = nil;
	NSString *mode = nil;

	while (changedModes) {
		if (changedModes & MVChatRoomPrivateMode) {
			changedModes &= ~MVChatRoomPrivateMode;
			mode = @"chatRoomPrivateMode";
			if( newModes & MVChatRoomPrivateMode ) {
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
		} else if (changedModes & MVChatRoomSecretMode) {
			changedModes &= ~MVChatRoomSecretMode;
			mode = @"chatRoomSecretMode";
			if( newModes & MVChatRoomSecretMode ) {
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
		} else if (changedModes & MVChatRoomInviteOnlyMode) {
			changedModes &= ~MVChatRoomInviteOnlyMode;
			mode = @"chatRoomInviteOnlyMode";
			if( newModes & MVChatRoomInviteOnlyMode ) {
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
		} else if (changedModes & MVChatRoomModeratedMode) {
			changedModes &= ~MVChatRoomModeratedMode;
			mode = @"chatRoomModeratedMode";
			if( newModes & MVChatRoomModeratedMode ) {
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
		} else if (changedModes & MVChatRoomSetTopicOperatorOnlyMode) {
			changedModes &= ~MVChatRoomSetTopicOperatorOnlyMode;
			mode = @"chatRoomSetTopicOperatorOnlyMode";
			if( newModes & MVChatRoomSetTopicOperatorOnlyMode ) {
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
		} else if (changedModes & MVChatRoomNoOutsideMessagesMode) {
			changedModes &= ~MVChatRoomNoOutsideMessagesMode;
			mode = @"chatRoomNoOutsideMessagesMode";
			if( newModes & MVChatRoomNoOutsideMessagesMode ) {
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
		} else if (changedModes & MVChatRoomPasswordRequiredMode) {
			changedModes &= ~MVChatRoomPasswordRequiredMode;
			mode = @"chatRoomPasswordRequiredMode";
			if( newModes & MVChatRoomPasswordRequiredMode ) {
				if( [mbr isLocalUser] ) {
					message = [NSString stringWithFormat:NSLocalizedString( @"You changed this room to require a password of \"%@\".", "password required room status message" ), [self key]];
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to require a password of \"%@\".", "someone else password required room status message" ), ( mbr ? [mbr title] : member ), [self key]];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You changed this room to no longer require a password.", "no longer passworded room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ changed this room to no longer require a password.", "someone else no longer passworded room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
		} else if (changedModes & MVChatRoomMemberLimitMode) {
			changedModes &= ~MVChatRoomMemberLimitMode;
			mode = @"chatRoomMemberLimitMode";
			if( newModes & MVChatRoomMemberLimitMode ) {
				if( [mbr isLocalUser] ) {
					message = [NSString stringWithFormat:NSLocalizedString( @"You set a limit on the number of room members to %i.", "member limit room status message" ), [self limit]];
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ set a limit on the number of room members to %i.", "someone else member limit room status message" ), ( mbr ? [mbr title] : member ), [self limit]];
				}
			} else {
				if( [mbr isLocalUser] ) {
					message = NSLocalizedString( @"You removed the room member limit.", "no member limit room status message" );
				} else {
					message = [NSString stringWithFormat:NSLocalizedString( @"%@ removed the room member limit", "someone else no member limit room status message" ), ( mbr ? [mbr title] : member )];
				}
			}
		}

		[self addEventMessageToDisplay:message withName:@"modeChange" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:( mbr ? [mbr title] : member ), @"by", member, @"nickname", mode, @"mode", ( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ? @"yes" : @"no" ), @"enabled", [[notification userInfo] objectForKey:@"param"], @"parameter", nil]];
	}
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

- (void) processMessage:(NSMutableString *) message asAction:(BOOL) action fromMember:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"----", [NSNumber numberWithBool:action], @"piM1", [member nickname], @"piM2", room, @"piM3", nil];
	id result = [self callScriptHandler:'piMX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	else if( [result isKindOfClass:[NSString class]] ) [message setString:result];
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