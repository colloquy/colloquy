#import "JVChatRoomInspector.h"
#import "JVChatRoomMember.h"
#import "JVDirectChat.h"
#import "JVChatTranscript.h"
#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>

@interface JVChatTranscript (JVChatTranscriptPrivate)
- (NSMenu *) _stylesMenu;
- (NSMenu *) _emoticonsMenu;
@end

#pragma mark -

@interface JVDirectChat (JVDirectChatPrivate)
- (NSMenu *) _encodingMenu;
@end

#pragma mark -

@interface JVChatRoomInspector (JVChatRoomInspectorPrivate)
- (void) _topicChanged:(NSNotification *) notification;
- (void) _refreshEditStatus:(NSNotification *) notification;
@end

#pragma mark -

@implementation JVChatRoom (JVChatRoomInspection)
- (id <JVInspector>) inspector {
	return [[[JVChatRoomInspector alloc] initWithRoom:self] autorelease];
}
@end

#pragma mark -

@implementation JVChatRoomInspector
- (id) initWithRoom:(JVChatRoom *) room {
	if( ( self = [self init] ) ) {
		_room = [room retain];
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_room release];
	_room = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVRoomInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 275., 390. );
}

- (NSString *) title {
	return [_room title];
}

- (NSString *) type {
	return NSLocalizedString( @"Room", "chat room inspector type" );
}

- (void) willLoad {
	[loadProgress startAnimation:nil];
	[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@", [_room target]]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _topicChanged: ) name:MVChatConnectionGotRoomTopicNotification object:[_room connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatConnectionGotMemberModeNotification object:[_room connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatConnectionGotRoomModeNotification object:[_room connection]];

	[encodingSelection setMenu:[_room _encodingMenu]];
	[styleSelection setMenu:[_room _stylesMenu]];
	[emoticonSelection setMenu:[_room _emoticonsMenu]];

	[self _topicChanged:nil];
}

#pragma mark -

- (IBAction) changeChatOption:(id) sender {
	if( sender == requiresPassword ) {
		[password setEnabled:(BOOL)[sender state]];
		if( [sender state] ) [[password window] makeFirstResponder:password];
		else [[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ -k *", [_room target]]];
	} else if( sender == limitMembers ) {
		[memberLimit setEnabled:(BOOL)[sender state]];
		if( [sender state] ) [[memberLimit window] makeFirstResponder:memberLimit];
		else [[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ -l *", [_room target]]];
	} else if( sender == password ) {
		BOOL enabled = ( [[sender stringValue] length] ? YES : NO );
		if( enabled ) [[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ +k %@", [_room target], [sender stringValue]]];
		else {
			[requiresPassword setState:NSOffState];
			[sender setEnabled:NO];
		}
	} else if( sender == memberLimit ) {
		BOOL enabled = ( [sender intValue] > 1 ? YES : NO );
		if( enabled ) [[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ +l %d", [_room target], [sender intValue]]];
		else {
			[limitMembers setState:NSOffState];
			[sender setEnabled:NO];
		}
	} else if( [sender selectedCell] == privateRoom ) {
		[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %cp", [_room target], ( [[sender selectedCell] state] ? '+' : '-' )]];
	} else if( [sender selectedCell] == secretRoom ) {
		[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %cs", [_room target], ( [[sender selectedCell] state] ? '+' : '-' )]];
	} else if( [sender selectedCell] == inviteOnly ) {
		[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %ci", [_room target], ( [[sender selectedCell] state] ? '+' : '-' )]];
	} else if( [sender selectedCell] == noOutside ) {
		[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %cn", [_room target], ( [[sender selectedCell] state] ? '+' : '-' )]];
	} else if( [sender selectedCell] == topicChangeable ) {
		[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %ct", [_room target], ( [[sender selectedCell] state] ? '+' : '-' )]];
	} else if( [sender selectedCell] == moderated ) {
		[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@ %cm", [_room target], ( [[sender selectedCell] state] ? '+' : '-' )]];
	}
}

#pragma mark -

- (BOOL) textView:(NSTextView *) textView clickedOnLink:(id) link atIndex:(unsigned) charIndex {
	return YES;
}

- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event {
	unichar zeroWidthSpaceChar = 0x200b;	
	[[[topic textStorage] mutableString] replaceOccurrencesOfString:[NSString stringWithCharacters:&zeroWidthSpaceChar length:1] withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [[topic textStorage] length] )];
	[[_room connection] setTopic:[topic textStorage] withEncoding:[_room encoding] forRoom:[_room target]];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event {
	[self textView:textView returnKeyPressed:event];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView tabKeyPressed:(NSEvent *) event {
	return YES;
}

- (void) textDidEndEditing:(NSNotification *) notification {
	[[_room connection] setTopic:[topic textStorage] withEncoding:[_room encoding] forRoom:[_room target]];
}
@end

#pragma mark -

@implementation JVChatRoomInspector (JVChatRoomInspectorPrivate)
- (void) _topicChanged:(NSNotification *) notification {
	if( [[[notification userInfo] objectForKey:@"room"] caseInsensitiveCompare:[_room target]] != NSOrderedSame ) return;
	if( [[topic window] firstResponder] == topic && [topic isEditable] ) return;

	NSMutableAttributedString *topicString = [[[_room topic] mutableCopy] autorelease];
	[topicString removeAttribute:NSParagraphStyleAttributeName range:NSMakeRange( 0, [topicString length] )];
	[topicString removeAttribute:NSLinkAttributeName range:NSMakeRange( 0, [topicString length] )];
	[[topic textStorage] setAttributedString:topicString];
}

- (void) _refreshEditStatus:(NSNotification *) notification {
	if( notification && [[[notification userInfo] objectForKey:@"room"] caseInsensitiveCompare:[_room target]] != NSOrderedSame && [[[_room connection] nickname] isEqualToString:[[notification userInfo] objectForKey:@"who"]] ) return;

	BOOL canEdit = [[_room chatRoomMemberWithName:[[_room connection] nickname]] operator];

	[topicChangeable setEnabled:canEdit];
	[privateRoom setEnabled:canEdit];
	[secretRoom setEnabled:canEdit];
	[inviteOnly setEnabled:canEdit];
	[noOutside setEnabled:canEdit];
	[moderated setEnabled:canEdit];

	[limitMembers setEnabled:canEdit];
	if( [limitMembers state] == NSOnState ) [memberLimit setEnabled:canEdit];
	else [memberLimit setEnabled:NO];

	[requiresPassword setEnabled:canEdit];
	if( [requiresPassword state] == NSOnState ) [password setEnabled:canEdit];
	else [password setEnabled:NO];
}

- (void) _roomModeChanged:(NSNotification *) notification {
	BOOL enabled = NO;

	if( notification && [[[notification userInfo] objectForKey:@"room"] caseInsensitiveCompare:[_room target]] != NSOrderedSame ) return;

	switch( [[[notification userInfo] objectForKey:@"mode"] unsignedIntValue] ) {
	case MVChatRoomPrivateMode:
		[privateRoom setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		break;
	case MVChatRoomSecretMode:
		[secretRoom setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		break;
	case MVChatRoomInviteOnlyMode:
		[inviteOnly setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		break;
	case MVChatRoomModeratedMode:
		[moderated setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		break;
	case MVChatRoomSetTopicOperatorOnlyMode:
		enabled = [[[notification userInfo] objectForKey:@"enabled"] boolValue];
		if( enabled ) [self _topicChanged:nil];
		if( [[_room chatRoomMemberWithName:[[_room connection] nickname]] operator] ) {
			[topic setEditable:YES];
		} else [topic setEditable:( ! enabled )];
		[topicChangeable setState:(NSCellStateValue)enabled];
		break;
	case MVChatRoomNoOutsideMessagesMode:
		[noOutside setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		break;
	case MVChatRoomPasswordRequiredMode:
		[requiresPassword setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
			[password setStringValue:[[notification userInfo] objectForKey:@"param"]];
		} else {
			[password setStringValue:@""];
		}
		break;
	case MVChatRoomMemberLimitMode:
		[limitMembers setState:(NSCellStateValue)[[[notification userInfo] objectForKey:@"enabled"] boolValue]];
		if( [[[notification userInfo] objectForKey:@"enabled"] boolValue] ) {
			[memberLimit setStringValue:[[notification userInfo] objectForKey:@"param"]];
		} else {
			[memberLimit setStringValue:@""];
		}
		break;
	}

	[loadProgress stopAnimation:nil];
	[self _refreshEditStatus:nil];
}
@end
