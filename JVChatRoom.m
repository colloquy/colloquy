#import <Cocoa/Cocoa.h>
#import "JVChatController.h"
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "MVChatConnection.h"
#import "MVChatPluginManager.h"
#import "MVTextView.h"
#import "NSAttributedStringAdditions.h"

@implementation JVChatRoom
- (id) init {
	if( ( self = [super init] ) ) {
		_topic = nil;
		_topicAuth = nil;
		_members = [[NSMutableDictionary dictionary] retain];
		_sortedMembers = [[NSMutableArray array] retain];
		_kickedFromRoom = NO;
		_invalidateMembers = NO;
	}
	return self;
}

- (void) awakeFromNib {
	[super awakeFromNib];
}

- (void) dealloc {
	[[self connection] partChatForRoom:[self target]];

	[_members autorelease];
	[_sortedMembers autorelease];
	[_topic autorelease];
	[_topicAuth autorelease];

	_members = nil;
	_sortedMembers = nil;
	_topic = nil;
	_topicAuth = nil;

	[super dealloc];
}

#pragma mark -

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"chat.chatRoom"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatRoom" owner:self];
	return contents;
}

#pragma mark -

- (NSString *) title {
	NSMutableString *title = [NSMutableString stringWithString:_target];
	[title deleteCharactersInRange:NSMakeRange( 0, 1 )];
	return [[title retain] autorelease];
}

- (NSString *) windowTitle {
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - Chat Room", "chat room window - window title" ), _target];
}

- (NSString *) information {
	return [NSString stringWithFormat:@"%d members", [_sortedMembers count]];
}

#pragma mark -

- (int) numberOfChildren {
	return [_sortedMembers count];
}

- (id) childAtIndex:(int) index {
	return [[_members objectForKey:[_sortedMembers objectAtIndex:index]] objectForKey:@"listItem"];
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

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

- (void) setTarget:(NSString *) target {
	NSAssert( YES, @"JVChatRoom does not implement setTarget:" );
	return;
}

#pragma mark -

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments {
	BOOL handled = NO;
	id item = nil;
	NSEnumerator *enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processUserCommand:withArguments:toRoom:forConnection: )] objectEnumerator];

	while( ( item = [enumerator nextObject] ) ) {
		handled = [item processUserCommand:command withArguments:arguments toRoom:[self target] forConnection:[self connection]];
		if( handled ) break;
	}

	return handled;
}

- (NSMutableAttributedString *) sendAttributedMessage:(NSMutableAttributedString *) message asAction:(BOOL) action {
	NSEnumerator *enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processRoomMessage:toRoom:asAction:forConnection: )] objectEnumerator];
	id item = nil;

	while( ( item = [enumerator nextObject] ) )
		message = [item processRoomMessage:message toRoom:[self target] asAction:action forConnection:[self connection]];

	[[self connection] sendMessageToChatRoom:[self target] attributedMessage:message withEncoding:_encoding asAction:action];

	return [[message retain] autorelease];
}

#pragma mark -

- (void) addMemberToChat:(NSString *) member asPreviousMember:(BOOL) previous {
	NSParameterAssert( member != nil );

	if( _invalidateMembers ) {
		[_members removeAllObjects];
		[_sortedMembers removeAllObjects];
		_invalidateMembers = NO;
	}

	if( ! [_members objectForKey:member] ) {
		JVChatRoomMember *listItem = [[[JVChatRoomMember alloc] init] autorelease];

		[_members setObject:[NSMutableDictionary dictionary] forKey:member];
		if( [member isEqualToString:[_connection nickname]] )
			[[_members objectForKey:member] setObject:[NSNumber numberWithBool:YES] forKey:@"self"];

		[listItem setParent:self];
		[listItem setMemberName:member];

		[[_members objectForKey:member] setObject:listItem forKey:@"listItem"];

		[_sortedMembers addObject:member];
		[_sortedMembers sortUsingSelector:@selector( caseInsensitiveCompare: )];

		[_windowController reloadChatView:self];

/*		if( ! previous ) {
			[self addMessageToDisplay:NSLocalizedString( @"joined the chat room.", "a user has join a chat room - presented as an action" ) fromUser:member asAction:YES];
			MVChatPlaySoundForAction( @"MVChatMemberJoinedRoomAction" );
		}*/
	}
}

- (void) updateMember:(NSString *) member withInfo:(NSDictionary *) info {
	NSParameterAssert( member != nil );
	NSParameterAssert( info != nil );
	if( [_members objectForKey:member] ) {
		[[_members objectForKey:member] addEntriesFromDictionary:info];
		[_windowController reloadChatView:self];		
	}
}

- (void) removeChatMember:(NSString *) member withReason:(NSData *) reason {
	NSParameterAssert( member != nil );
	if( [_members objectForKey:member] ) {
		[_members removeObjectForKey:member];
		[_sortedMembers removeObject:member];
		[_windowController reloadChatView:self];		
		/*if( reason ) {
			NSString *rstring = [[[NSString alloc] initWithData:reason encoding:encoding] autorelease];
			NSData *data = [[NSString stringWithFormat:NSLocalizedString( @"left the chat room for this reason: %@.", "a user has left a chat room with a reason - presented as an action" ), rstring] dataUsingEncoding:encoding allowLossyConversion:YES];
			[self addHTMLMessageToDisplay:data fromUser:member asAction:YES];
		} else [self addMessageToDisplay:NSLocalizedString( @"left the chat room.", "a user has left a chat room - presented as an action" ) fromUser:member asAction:YES];
		MVChatPlaySoundForAction( @"MVChatMemberLeftRoomAction" );*/
	}
}

- (void) changeChatMember:(NSString *) member to:(NSString *) nick {
	NSParameterAssert( member != nil );
	NSParameterAssert( nick != nil );

	if( [_members objectForKey:member] ) {
		[_members setObject:[_members objectForKey:member] forKey:nick];
		[_members removeObjectForKey:member];
		[_sortedMembers removeObject:member];
		[_sortedMembers addObject:nick];
		[_sortedMembers sortUsingSelector:@selector( caseInsensitiveCompare: )];

		[(JVChatRoomMember *)[[_members objectForKey:nick] objectForKey:@"listItem"] setMemberName:nick];

		[_windowController reloadChatView:self];		

/*		[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"is now known as %@.", "user has changed nicknames - presented as an action" ), nick] fromUser:member asAction:YES];
		if( [member isEqualToString:[self targetUser]] ) {
			[window setTitle:[NSString stringWithFormat:NSLocalizedString( @"%@ - Private Message", "private message with user - window title" ), nick]];
			[NSWindow removeFrameUsingName:[window frameAutosaveName]];
			[window setFrameAutosaveName:[NSString stringWithFormat:@"chat.user.%@.%@", [[self connection] server], nick]];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"chat.user.%@.encoding", member]];
			if( encoding != (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatEncoding"] )
				[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:encoding] forKey:[NSString stringWithFormat:@"chat.user.%@.encoding", nick]];
		}*/
	}
}

- (void) changeSelfTo:(NSString *) nick {
	NSEnumerator *enumerator = [_members objectEnumerator], *keyEnumerator = [_members keyEnumerator];
	id item = nil, key = nil;
	NSParameterAssert( nick != nil );
	while( ( item = [enumerator nextObject] ) && ( key = [keyEnumerator nextObject] ) ) {
		if( [[item objectForKey:@"self"] boolValue] ) {
			if( ! [nick isEqualToString:key] ) {
				[_members setObject:item forKey:nick];
				[_members removeObjectForKey:key];
				[_sortedMembers removeObject:key];
				[_sortedMembers addObject:nick];
				[_sortedMembers sortUsingSelector:@selector( caseInsensitiveCompare: )];
			}
			break;
		}
	}
}

#pragma mark -

- (void) promoteChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( [_members objectForKey:member] ) {
		[[_members objectForKey:member] setObject:[NSNumber numberWithBool:YES] forKey:@"op"];

		[(JVChatRoomMember *)[[_members objectForKey:member] objectForKey:@"listItem"] setOperator:YES];

		[_windowController reloadChatView:self];

/*		if( by ) {
			[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"promoted %@ to operator.", "user is now a chat room operator - presented as an action" ), member] fromUser:by asAction:YES];
			MVChatPlaySoundForAction( @"MVChatMemberPromotedAction" );
		}*/
	}
}

- (void) demoteChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( [_members objectForKey:member] ) {
		[[_members objectForKey:member] removeObjectForKey:@"op"];

		[(JVChatRoomMember *)[[_members objectForKey:member] objectForKey:@"listItem"] setOperator:NO];

		[_windowController reloadChatView:self];

/*		if( by ) {
			[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"demoted %@ from operator.", "user was removed from chat room operator status - presented as an action" ), member] fromUser:by asAction:YES];
			MVChatPlaySoundForAction( @"MVChatMemberDemotedAction" );
		}*/
	}
}

- (void) voiceChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( [_members objectForKey:member] ) {
		[[_members objectForKey:member] setObject:[NSNumber numberWithBool:YES] forKey:@"voice"];

		[(JVChatRoomMember *)[[_members objectForKey:member] objectForKey:@"listItem"] setVoice:YES];

		[_windowController reloadChatView:self];

/*		if( by ) {
			[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"granted %@ voice.", "user now has special voice status - presented as an action" ), member] fromUser:by asAction:YES];
			MVChatPlaySoundForAction( @"MVChatMemberVoicedAction" );
		}*/
	}
}

- (void) devoiceChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( [_members objectForKey:member] ) {
		[[_members objectForKey:member] removeObjectForKey:@"voice"];

		[(JVChatRoomMember *)[[_members objectForKey:member] objectForKey:@"listItem"] setVoice:NO];

		[_windowController reloadChatView:self];

/*		if( by ) {
			[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"removed voice from %@.", "user was removed from chat room special voice status - presented as an action" ), member] fromUser:by asAction:YES];
			MVChatPlaySoundForAction( @"MVChatMemberDevoicedAction" );
		}*/
	}
}

#pragma mark -

- (void) chatMember:(NSString *) member kickedBy:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;

	NSParameterAssert( member != nil );
	NSParameterAssert( by != nil );

	rstring = [[[NSString alloc] initWithData:reason encoding:_encoding] autorelease];
	[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ was kicked from the chat room by %@.", "user has been removed by force from a chat room status message" ), member, by] withName:@"memberKicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:by, @"by", member, @"who", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	[_members removeObjectForKey:member];
	[_sortedMembers removeObject:member];

	[_windowController reloadChatView:self];

//	MVChatPlaySoundForAction( @"MVChatMemberKickedAction" );
}

- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;

	NSParameterAssert( by != nil );

	rstring = [[[NSString alloc] initWithData:reason encoding:_encoding] autorelease];
	[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You were kicked from the chat room by %@.", "you were removed by force from a chat room status message" ), by] withName:@"kicked" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:by, @"by", ( rstring ? (id) rstring : (id) [NSNull null] ), @"reason", nil]];

	[_members removeObjectForKey:[[self connection] nickname]];
	[_sortedMembers removeObject:[[self connection] nickname]];

	[_windowController reloadChatView:self];

//	MVChatPlaySoundForAction( @"MVChatMemberKickedAction" );
	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You were kicked from the chat room.", "you were removed by force from a chat room error message title" ), NSLocalizedString( @"You were kicked from the chat room by %@. You are no longer part of this chat and can't send anymore messages.", "you were removed by force from a chat room error message" ), @"OK", nil, nil, by ) withName:nil];

	_kickedFromRoom = YES;
	_cantSendMessages = YES;
}

#pragma mark -

- (void) changeTopic:(NSData *) topic by:(NSString *) author {
/*	NSData *tData = nil;
	NSRange limitRange, effectiveRange;
	NSMutableAttributedString *topicAttr = [[[NSAttributedString attributedStringWithHTML:tData usingEncoding:_encoding documentAttributes:NULL] mutableCopy] autorelease];
	NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	NSMutableAttributedString *addons = nil;
	NSMutableDictionary *attributes = nil;

	NSParameterAssert( topic != nil );

	if( [topic length] ) {
		tData = topic;
	} else {
		tData = [[NSString stringWithFormat:@"<font color=\"#6c6c6c\">%@</font>", NSLocalizedString( @"(no chat topic is set)", "no chat topic is set message" )] dataUsingEncoding:NSUTF8StringEncoding];
		author = nil;
	}

	[_topic autorelease];
	_topic = [topic retain];
	[_topicAuth autorelease];
	_topicAuth = [author retain];

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] ) {
		[topicAttr preformHTMLBackgroundColoring];
	}

	attributes = [NSMutableDictionary dictionaryWithObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSBoldFontMask weight:5 size:0.] forKey:NSFontAttributeName];
	addons = [[[NSMutableAttributedString alloc] initWithString:NSLocalizedString( @"Topic: ", "chat room topic prefix" ) attributes:attributes] autorelease];
	[topicAttr insertAttributedString:addons atIndex:0];

	if( author ) {
		attributes = [NSMutableDictionary dictionaryWithObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSItalicFontMask weight:5 size:0.] forKey:NSFontAttributeName];
		addons = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString( @" posted by %@", "who posted the current topic" ), author] attributes:attributes] autorelease];
		[topicAttr appendAttributedString:addons];
	}

	limitRange = NSMakeRange( 0, [topicAttr length] );
	while( limitRange.length > 0 ) {
		NSFont *font = [topicAttr attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
		font = [[NSFontManager sharedFontManager] convertFont:font toFamily:@"Helvetica"];
		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] )
			font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask | NSBoldFontMask];
		[topicAttr addAttribute:NSFontAttributeName value:font range:effectiveRange];
		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] )
		[topicAttr addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:0] range:NSMakeRange( 0, [topicAttr length] )];		

	[paraStyle setMaximumLineHeight:15.];
	[topicAttr addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange( 0, [topicAttr length] )];
	[topicLine setAttributedStringValue:topicAttr];*/
}

#pragma mark -

- (BOOL) textView:(NSTextView *) textView tabHit:(NSEvent *) event {
	NSArray *tabArr = [[send string] componentsSeparatedByString:@" "];
	NSMutableArray *found = [NSMutableArray array];
	NSEnumerator *enumerator = [_sortedMembers objectEnumerator];
	NSString *name = nil, *shortest = nil;
	unsigned len = [(NSString *)[tabArr lastObject] length], count = 0;
	if( ! len ) return YES;
	while( ( name = [enumerator nextObject] ) ) {
		if( [[tabArr lastObject] caseInsensitiveCompare:[name substringToIndex:len]] == NSOrderedSame ) {
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

@implementation JVChatRoom (JVChatRoomPrivate)
- (void) _didConnect:(NSNotification *) notification {
	[[self connection] joinChatForRoom:_target];
	[super _didConnect:notification];
}
@end