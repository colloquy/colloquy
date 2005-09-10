#import "JVChatRoomInspector.h"
#import "JVChatRoomMember.h"
#import "JVDirectChatPanel.h"
#import "JVChatTranscriptPanel.h"

@interface JVChatTranscriptPanel (JVChatTranscriptPrivate)
- (NSMenu *) _stylesMenu;
- (NSMenu *) _emoticonsMenu;
@end

#pragma mark -

@interface JVDirectChatPanel (JVDirectChatPrivate)
- (NSMenu *) _encodingMenu;
@end

#pragma mark -

@interface JVChatRoomInspector (JVChatRoomInspectorPrivate)
- (void) _topicChanged:(NSNotification *) notification;
- (void) _refreshEditStatus:(NSNotification *) notification;
- (void) _roomModeChanged:(NSNotification *)notification;
@end

#pragma mark -

@implementation JVChatRoomPanel (JVChatRoomInspection)
- (id <JVInspector>) inspector {
	return [[[JVChatRoomInspector alloc] initWithRoom:self] autorelease];
}
@end

#pragma mark -

@implementation JVChatRoomInspector
- (id) initWithRoom:(JVChatRoomPanel *) room {
	if( ( self = [self init] ) )
		_room = [room retain];
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
	[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@", (MVChatRoom *)[_room target]]];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _topicChanged: ) name:MVChatRoomTopicChangedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatRoomUserModeChangedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatRoomModesChangedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatRoomKickedNotification object:[_room target]];

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
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomPassphraseToJoinMode];
	} else if( sender == limitMembers ) {
		[memberLimit setEnabled:(BOOL)[sender state]];
		if( [sender state] ) [[memberLimit window] makeFirstResponder:memberLimit];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomLimitNumberOfMembersMode];
	} else if( sender == password ) {
		BOOL enabled = ( [[sender stringValue] length] ? YES : NO );
		if( enabled ) [(MVChatRoom *)[_room target] setMode:MVChatRoomPassphraseToJoinMode withAttribute:[sender stringValue]];
		else {
			[requiresPassword setState:NSOffState];
			[sender setEnabled:NO];
		}
	} else if( sender == memberLimit ) {
		BOOL enabled = ( [sender intValue] > 1 ? YES : NO );
		if( enabled ) [(MVChatRoom *)[_room target] setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:[sender stringValue]];
		else {
			[limitMembers setState:NSOffState];
			[sender setEnabled:NO];
		}
	} else if( [sender selectedCell] == privateRoom ) {
		if( [[sender selectedCell] state] ) [(MVChatRoom *)[_room target] setMode:MVChatRoomPrivateMode];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomPrivateMode];
	} else if( [sender selectedCell] == secretRoom ) {
		if( [[sender selectedCell] state] ) [(MVChatRoom *)[_room target] setMode:MVChatRoomSecretMode];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomSecretMode];
	} else if( [sender selectedCell] == inviteOnly ) {
		if( [[sender selectedCell] state] ) [(MVChatRoom *)[_room target] setMode:MVChatRoomInviteOnlyMode];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomInviteOnlyMode];
	} else if( [sender selectedCell] == noOutside ) {
		if( [[sender selectedCell] state] ) [(MVChatRoom *)[_room target] setMode:MVChatRoomNoOutsideMessagesMode];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomNoOutsideMessagesMode];
	} else if( [sender selectedCell] == topicChangeable ) {
		if( [[sender selectedCell] state] ) [(MVChatRoom *)[_room target] setMode:MVChatRoomOperatorsOnlySetTopicMode];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomOperatorsOnlySetTopicMode];
	} else if( [sender selectedCell] == moderated ) {
		if( [[sender selectedCell] state] ) [(MVChatRoom *)[_room target] setMode:MVChatRoomNormalUsersSilencedMode];
		else [(MVChatRoom *)[_room target] removeMode:MVChatRoomNormalUsersSilencedMode];
	}
}

#pragma mark -

- (BOOL) textView:(NSTextView *) textView clickedOnLink:(id) link atIndex:(unsigned) charIndex {
	return YES;
}

- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event {
	unichar zeroWidthSpaceChar = 0x200b;
	[[[topic textStorage] mutableString] replaceOccurrencesOfString:[NSString stringWithCharacters:&zeroWidthSpaceChar length:1] withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [[topic string] length] )];
	[(MVChatRoom *)[_room target] setTopic:[topic textStorage]];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event {
	[self textView:textView returnKeyPressed:event];
	return YES;
}

- (void) textDidEndEditing:(NSNotification *) notification {
	[self textView:topic returnKeyPressed:nil];
}
@end

#pragma mark -

@implementation JVChatRoomInspector (JVChatRoomInspectorPrivate)
- (void) _topicChanged:(NSNotification *) notification {
	if( [[topic window] firstResponder] == topic && [topic isEditable] ) return;

	NSFont *baseFont = [NSFont userFontOfSize:12.];
	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[_room encoding]], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSAttributedString *messageString = [NSAttributedString attributedStringWithChatFormat:[(MVChatRoom *)[_room target] topic] options:options];

	if( ! messageString ) {
		[options setObject:[NSNumber numberWithUnsignedInt:NSISOLatin1StringEncoding] forKey:@"StringEncoding"];
		messageString = [NSAttributedString attributedStringWithChatFormat:[(MVChatRoom *)[_room target] topic] options:options];
	}

	[[topic textStorage] setAttributedString:messageString];
}

- (void) _refreshEditStatus:(NSNotification *) notification {
	if( notification && ! [[[notification userInfo] objectForKey:@"who"] isLocalUser] ) return;

	BOOL canEdit = [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] & MVChatRoomMemberOperatorMode;

	[topicChangeable setEnabled:canEdit];
	[privateRoom setEnabled:canEdit];
	[secretRoom setEnabled:canEdit];
	[inviteOnly setEnabled:canEdit];
	[noOutside setEnabled:canEdit];
	[moderated setEnabled:canEdit];

	[topic setEditable:( canEdit || ! ( [(MVChatRoom *)[_room target] modes] & MVChatRoomOperatorsOnlySetTopicMode ) )];

	[limitMembers setEnabled:canEdit];
	if( [limitMembers state] == NSOnState ) [memberLimit setEnabled:canEdit];
	else [memberLimit setEnabled:NO];

	[requiresPassword setEnabled:canEdit];
	if( [requiresPassword state] == NSOnState ) [password setEnabled:canEdit];
	else [password setEnabled:NO];
}

- (void) _roomModeChanged:(NSNotification *) notification {
	unsigned int changedModes = ( notification ? [[[notification userInfo] objectForKey:@"changedModes"] unsignedIntValue] : [(MVChatRoom *)[_room target] modes] );
	unsigned int newModes = [(MVChatRoom *)[_room target] modes];

	if( changedModes & MVChatRoomPrivateMode )
		[privateRoom setState:( newModes & MVChatRoomPrivateMode ? NSOnState : NSOffState )];

	if( changedModes & MVChatRoomSecretMode )
		[secretRoom setState:( newModes & MVChatRoomSecretMode ? NSOnState : NSOffState )];

	if( changedModes & MVChatRoomInviteOnlyMode )
		[inviteOnly setState:( newModes & MVChatRoomInviteOnlyMode ? NSOnState : NSOffState )];

	if( changedModes & MVChatRoomNormalUsersSilencedMode )
		[moderated setState:( newModes & MVChatRoomNormalUsersSilencedMode ? NSOnState : NSOffState )];

	if( changedModes & MVChatRoomOperatorsOnlySetTopicMode ) {
		BOOL enabled = ( newModes & MVChatRoomOperatorsOnlySetTopicMode ? YES : NO );
		if( enabled ) [self _topicChanged:nil];
		if( [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] & MVChatRoomMemberOperatorMode ) [topic setEditable:YES];
		else [topic setEditable:( ! enabled )];
		[topicChangeable setState:( enabled ? NSOnState : NSOffState )];
	}

	if( changedModes & MVChatRoomNoOutsideMessagesMode )
		[noOutside setState:( newModes & MVChatRoomNoOutsideMessagesMode ? NSOnState : NSOffState )];

	if( changedModes & MVChatRoomPassphraseToJoinMode ) {
		[requiresPassword setState:( newModes & MVChatRoomPassphraseToJoinMode ? NSOnState : NSOffState )];
		if( newModes & MVChatRoomPassphraseToJoinMode ) [password setStringValue:[(MVChatRoom *)[_room target] attributeForMode:MVChatRoomPassphraseToJoinMode]];
		else [password setStringValue:@""];
	}

	if( changedModes & MVChatRoomLimitNumberOfMembersMode ) {
		[limitMembers setState:( newModes & MVChatRoomLimitNumberOfMembersMode ? NSOnState : NSOffState )];
		if( newModes & MVChatRoomLimitNumberOfMembersMode ) [memberLimit setObjectValue:[(MVChatRoom *)[_room target] attributeForMode:MVChatRoomLimitNumberOfMembersMode]];
		else [memberLimit setStringValue:@""];
	}

	[self _refreshEditStatus:nil];
}
@end