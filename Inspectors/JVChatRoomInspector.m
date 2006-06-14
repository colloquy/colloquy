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
- (void) _reloadTopic;
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
	[_latestBanList release];

	_room = nil;
	_latestBanList = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVRoomInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 275., 340. );
}

- (NSString *) title {
	return [_room title];
}

- (NSString *) type {
	return NSLocalizedString( @"Room", "chat room inspector type" );
}

- (void) willLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _topicChanged: ) name:MVChatRoomTopicChangedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatRoomUserModeChangedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatRoomModesChangedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatRoomKickedNotification object:[_room target]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( refreshBanList: ) name:MVChatRoomBannedUsersSyncedNotification object:[_room target]];

	[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@", (MVChatRoom *)[_room target]]];

	[nameField setStringValue:[_room title]];

	NSDateFormatter *formatter = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) {
		formatter = [[[NSDateFormatter alloc] initWithDateFormat:@"%1m/%1d/%Y %1I:%M%p" allowNaturalLanguage:YES] autorelease];
		[saveTopic setBezelStyle:NSShadowlessSquareBezelStyle];
		[resetTopic setBezelStyle:NSShadowlessSquareBezelStyle];
	} else {
		formatter = [[[NSDateFormatter alloc] init] autorelease];
		[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[formatter setDateStyle:NSDateFormatterShortStyle];
		[formatter setTimeStyle:NSDateFormatterShortStyle];
	}

	if( [[_room target] isJoined] )
		[infoField setObjectValue:[NSString stringWithFormat:NSLocalizedString( @"Joined: %@", "chat room joined date label" ), [formatter stringFromDate:[[_room target] dateJoined]]]];
	else [infoField setObjectValue:[NSString stringWithFormat:NSLocalizedString( @"Parted: %@", "chat room parted date label" ), [formatter stringFromDate:[[_room target] dateParted]]]];

	[encodingSelection setMenu:[_room _encodingMenu]];
	[styleSelection setMenu:[_room _stylesMenu]];
	[emoticonSelection setMenu:[_room _emoticonsMenu]];

	[self _reloadTopic];
	[self _roomModeChanged:nil];
	[self refreshBanList:nil];
}

- (BOOL) shouldUnload {
	[[view window] makeFirstResponder:view];
	return YES;
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

- (IBAction) refreshBanList:(id) sender {
	[_latestBanList autorelease];
	_latestBanList = [[[[_room target] bannedUsers] allObjects] mutableCopy];

	SEL sortSelector = NULL;
	int sortKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatRoomInspectorBanListSort"];
	switch( sortKey ) {
		default:
		case 1: sortSelector = @selector( compareByNickname: ); break;
		case 2: sortSelector = @selector( compareByUsername: ); break;
		case 3: sortSelector = @selector( compareByAddress: );
	}

	[_latestBanList sortUsingSelector:sortSelector];
	[banRules reloadData];	
}

#pragma mark -

- (IBAction) saveTopic:(id) sender {
	[(MVChatRoom *)[_room target] setTopic:[topic textStorage]];
}

- (IBAction) resetTopic:(id) sender {
	[self _reloadTopic];
}

- (BOOL) textView:(NSTextView *) textView clickedOnLink:(id) link atIndex:(unsigned) charIndex {
	// do nothing, ignore clicked links
	return YES;
}

- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event {
	// do nothing, don't insert line returns
	return YES;
}

- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event {
	// do nothing, don't insert line returns
	return YES;
}

#pragma mark -

- (IBAction) newBanRule:(id) sender {
	[_latestBanList addObject:@""];
	[banRules noteNumberOfRowsChanged];
	[banRules selectRow:( [_latestBanList count] - 1 ) byExtendingSelection:NO];
	[banRules editColumn:0 row:( [_latestBanList count] - 1 ) withEvent:nil select:NO];
}

- (IBAction) deleteBanRule:(id) sender {
	if( ! [banRules numberOfSelectedRows] || [banRules editedRow] != -1 ) return;

	NSIndexSet *selection = [banRules selectedRowIndexes];

	[banRules deselectAll:nil];

	unsigned int count = [selection count];
	unsigned int buffer[count];
	count = [selection getIndexes:buffer maxCount:count inIndexRange:NULL];
	if( ! count ) return;

	unsigned int i = count;

	do {
		if( i >= 1 ) i--;
		unsigned int index = buffer[i];
		if( index >= [_latestBanList count] ) continue;
		MVChatUser *ban = [_latestBanList objectAtIndex:index];
		[[_room target] removeBanForUser:ban];
		[_latestBanList removeObjectAtIndex:index];
	} while( i );

	[banRules reloadData];
}

- (IBAction) editBanRule:(id) sender {
	int row = [banRules selectedRow];
	if( row == -1 || [banRules numberOfSelectedRows] > 1 ) return;
	[banRules editColumn:0 row:row withEvent:nil select:YES];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) tableView {
	return [_latestBanList count];
}

- (id) tableView:(NSTableView *) tableView objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	return [[_latestBanList objectAtIndex:row] description];
}

- (NSString *) tableView:(NSTableView *) tableView toolTipForCell:(NSCell *) cell rect:(NSRectPointer) rect tableColumn:(NSTableColumn *) column row:(int) row mouseLocation:(NSPoint) mouseLocation {
	MVChatUser *user = [_latestBanList objectAtIndex:row];
	NSDateFormatter *formatter = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) {
		formatter = [[[NSDateFormatter alloc] initWithDateFormat:@"%1m/%1d/%Y %1I:%M%p" allowNaturalLanguage:YES] autorelease];
	} else {
		formatter = [[[NSDateFormatter alloc] init] autorelease];
		[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[formatter setDateStyle:NSDateFormatterShortStyle];
		[formatter setTimeStyle:NSDateFormatterShortStyle];
	}

	NSDate *date = [user attributeForKey:MVChatUserBanDateAttribute];
	NSString *server = [user attributeForKey:MVChatUserBanServerAttribute];

	return [NSString stringWithFormat:@"%@ (%@)", [formatter stringFromDate:date], server];
}

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	MVChatUser *newBan = [MVChatUser wildcardUserFromString:object];
	id ban = [_latestBanList objectAtIndex:row];
	if( [ban isEqual:newBan] ) return;

	if( [ban isKindOfClass:[MVChatUser class]] )
		[[_room target] removeBanForUser:ban];

	if( newBan && [object length] ) {
		[[_room target] addBanForUser:newBan];
		[_latestBanList replaceObjectAtIndex:row withObject:newBan];
	} else [_latestBanList removeObjectAtIndex:row];

	[banRules reloadData];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	unsigned int localUserModes = ( [[_room connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] : 0 );
	[deleteBanButton setEnabled:( ( localUserModes & MVChatRoomMemberOperatorMode ) && [banRules selectedRow] != -1 )];
	[editBanButton setEnabled:( ( localUserModes & MVChatRoomMemberOperatorMode ) && [banRules selectedRow] != -1 && [banRules numberOfSelectedRows] == 1 )];
}
@end

#pragma mark -

@implementation JVChatRoomInspector (JVChatRoomInspectorPrivate)
- (void) _topicChanged:(NSNotification *) notification {
	if( [[topic window] firstResponder] == topic && [topic isEditable] ) return;
	[self _reloadTopic];
}

- (void) _reloadTopic {
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

	unsigned int localUserModes = ( [[_room connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] : 0 );
	BOOL canEdit = ( localUserModes & MVChatRoomMemberOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberHalfOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberAdministratorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberFounderMode );
	if( ! canEdit ) canEdit = [[[_room connection] localUser] isServerOperator];

	[newBanButton setEnabled:canEdit];
	[deleteBanButton setEnabled:( canEdit && [banRules selectedRow] != -1 )];
	[editBanButton setEnabled:( canEdit && [banRules selectedRow] != -1 )];

	NSTableColumn *column = [banRules tableColumnWithIdentifier:@"rule"];
	[column setEditable:canEdit];

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
	unsigned int localUserModes = ( [[_room connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] : 0 );

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
		if( enabled ) [self _reloadTopic];
		if( localUserModes & MVChatRoomMemberOperatorMode ) [topic setEditable:YES];
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