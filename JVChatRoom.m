#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatPlugin.h>

#import "JVChatController.h"
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "MVTextView.h"

@interface JVDirectChat (JVDirectChatPrivate)
- (void) _makeHyperlinksInString:(NSMutableString *) string;
- (void) _didConnect:(NSNotification *) notification;
@end

#pragma mark -

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
	[topicLine setDrawsBackground:NO];
	[[topicLine enclosingScrollView] setDrawsBackground:NO];
	[super awakeFromNib];
	[self changeTopic:nil by:nil];
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

- (NSString *) identifier {
	return [NSString stringWithFormat:@"%@.%@.chatRoom", [[self connection] server], _target];
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

- (IBAction) changeEncoding:(id) sender {
	[super changeEncoding:sender];
	[self changeTopic:_topic by:_topicAuth];
}

- (void) changeTopic:(NSData *) topic by:(NSString *) author {
	if( ! [topic isMemberOfClass:[NSNull class]] ) {
		NSMutableString *topicString = [[[NSMutableString alloc] initWithData:topic encoding:_encoding] autorelease];
		if( ! topicString )
			topicString = [[[NSMutableString alloc] initWithData:topic encoding:NSNonLossyASCIIStringEncoding] autorelease];

		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
			[self _makeHyperlinksInString:topicString];

		if( ! [topicString length] )
			topicString = [NSString stringWithFormat:@"<span style=\"color: #6c6c6c\">%@</span>", NSLocalizedString( @"(no chat topic is set)", "no chat topic is set message" )];

		topicString = [NSString stringWithFormat:@"<span style=\"font-size: 11px; font-family: Lucida Grande, san-serif\">%@</span>", topicString];

		[[topicRenderer mainFrame] loadHTMLString:topicString baseURL:nil];
		
		[_topic autorelease];
		_topic = [topic copy];
	}

	if( ! [author isMemberOfClass:[NSNull class]] ) {
		[_topicAuth autorelease];
		_topicAuth = [author retain];
	}

	[NSTimer scheduledTimerWithTimeInterval:0. target:self selector:@selector( _finishTopicChange: ) userInfo:NULL repeats:NO];
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

#pragma mark -

@implementation JVChatRoom (JVChatRoomPrivate)
- (void) _didConnect:(NSNotification *) notification {
	[[self connection] joinChatForRoom:_target];
	[super _didConnect:notification];
}

- (void) _finishTopicChange:(id) sender {
	NSMutableAttributedString *topic = [[[(id <WebDocumentText>)[[[topicRenderer mainFrame] frameView] documentView] attributedString] mutableCopy] autorelease];
	NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	NSString *toolTip = nil;
	[paraStyle setMaximumLineHeight:13.];
	[paraStyle setAlignment:NSCenterTextAlignment];
	[topic addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange( 0, [topic length] )];
	[[topicLine textStorage] setAttributedString:topic];

	toolTip = [[[topic string] copy] autorelease];
	if( _topicAuth ) {
		toolTip = [toolTip stringByAppendingString:@"\n"];
		toolTip = [toolTip stringByAppendingFormat:NSLocalizedString( @"Topic set by: %@", "topic author tooltip" ), _topicAuth];
	}
	[[topicLine enclosingScrollView] setToolTip:toolTip];
}
@end