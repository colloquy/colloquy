#import "JVChatRoomInspector.h"
#import "JVChatRoomMember.h"
#import "JVDirectChat.h"
#import "JVChatTranscript.h"
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
- (void) _roomModeChanged:(NSNotification *)notification;
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
		_modes = 0;
		_key = [[NSString alloc] init];
		_limit = 0;
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
	[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@", [_room target]]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _topicChanged: ) name:MVChatConnectionGotRoomTopicNotification object:[_room connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatConnectionGotMemberModeNotification object:[_room connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatRoomModeChangedNotification object:_room];

	[encodingSelection setMenu:[_room _encodingMenu]];
	[styleSelection setMenu:[_room _stylesMenu]];
	[emoticonSelection setMenu:[_room _emoticonsMenu]];

	[self _topicChanged:nil];
	[self _roomModeChanged:nil];
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
	
	[topic setEditable:(canEdit || ! (_modes & MVChatRoomSetTopicOperatorOnlyMode))];

	[limitMembers setEnabled:canEdit];
	if( [limitMembers state] == NSOnState ) [memberLimit setEnabled:canEdit];
	else [memberLimit setEnabled:NO];

	[requiresPassword setEnabled:canEdit];
	if( [requiresPassword state] == NSOnState ) [password setEnabled:canEdit];
	else [password setEnabled:NO];
}

- (void) _roomModeChanged:(NSNotification *) notification {
	//if( [notification object] != _room ) return;
	
	unsigned int currentModes = [_room modes];
	unsigned int newModes = currentModes & ~ _modes;
	unsigned int oldModes = _modes & ~ currentModes;
	unsigned int changedModes = newModes | oldModes;
	_modes = [_room modes];
	NSString *key = [_room key];
	int limit = [_room limit];
			
	if (changedModes & MVChatRoomPrivateMode) {
		[privateRoom setState:(newModes & MVChatRoomPrivateMode ? NSOnState : NSOffState)];
	}
	if (changedModes & MVChatRoomSecretMode) {
		[secretRoom setState:(newModes & MVChatRoomSecretMode ? NSOnState : NSOffState)];
	}
	if (changedModes & MVChatRoomInviteOnlyMode) {
		[inviteOnly setState:(newModes & MVChatRoomInviteOnlyMode ? NSOnState : NSOffState)];
	}
	if (changedModes & MVChatRoomModeratedMode) {
		[moderated setState:(newModes & MVChatRoomModeratedMode ? NSOnState : NSOffState)];
	}
	if (changedModes & MVChatRoomSetTopicOperatorOnlyMode) {
		BOOL enabled = (newModes & MVChatRoomSetTopicOperatorOnlyMode ? YES : NO);
		if (enabled) [self _topicChanged:nil];
		if ([[_room chatRoomMemberWithName:[[_room connection] nickname]] operator]) {
			[topic setEditable:YES];
		} else [topic setEditable: (!enabled)];
		[topicChangeable setState:(enabled ? NSOnState : NSOffState)];
	}
	if (changedModes & MVChatRoomNoOutsideMessagesMode) {
		[noOutside setState:(newModes & MVChatRoomNoOutsideMessagesMode ? NSOnState : NSOffState)];
	}
	if ((changedModes & MVChatRoomPasswordRequiredMode) || 
		((currentModes & MVChatRoomPasswordRequiredMode) && ![key isEqualToString:_key])) {
		[requiresPassword setState:(newModes & MVChatRoomPasswordRequiredMode ? NSOnState : NSOffState)];
		if (currentModes & MVChatRoomPasswordRequiredMode) {
			[password setStringValue:key];
			[_key autorelease];
			_key = [key copy];
		} else {
			[password setStringValue:@""];
		}
	}
	if ((changedModes & MVChatRoomMemberLimitMode) ||
		((currentModes & MVChatRoomMemberLimitMode) && (limit != _limit))) {
		[limitMembers setState:(newModes & MVChatRoomMemberLimitMode ? NSOnState : NSOffState)];
		if (currentModes & MVChatRoomMemberLimitMode) {
			[memberLimit setIntValue:limit];
			_limit = limit;
		} else {
			[memberLimit setStringValue:@""];
		}
	}
	
	[self _refreshEditStatus:nil];
}

@end
