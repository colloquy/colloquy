#import "JVChatRoomInspector.h"
#import "JVChatRoomMember.h"
#import "JVDirectChatPanel.h"
#import "JVChatTranscriptPanel.h"

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
	return [[JVChatRoomInspector alloc] initWithRoom:self];
}
@end

#pragma mark -

@implementation JVChatRoomInspector
- (instancetype) initWithRoom:(JVChatRoomPanel *) room {
	if( ( self = [super init] ) )
		_room = room;
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];

	[banRules setDataSource:nil];
	[banRules setDelegate:nil];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVRoomInspector" owner:self topLevelObjects:NULL];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 315., 340. );
}

- (NSString *) title {
	return [_room title];
}

- (NSString *) type {
	return NSLocalizedString( @"Room", "chat room inspector type" );
}

- (void) willLoad {
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _topicChanged: ) name:MVChatRoomTopicChangedNotification object:[_room target]];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatRoomUserModeChangedNotification object:[_room target]];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _roomModeChanged: ) name:MVChatRoomModesChangedNotification object:[_room target]];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshEditStatus: ) name:MVChatRoomKickedNotification object:[_room target]];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( refreshBanList: ) name:MVChatRoomBannedUsersSyncedNotification object:[_room target]];

	[[_room connection] sendRawMessage:[NSString stringWithFormat:@"MODE %@", (MVChatRoom *)[_room target]]];

	[nameField setStringValue:[_room title]];

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];

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
			[(MVChatRoom *)[_room target] removeMode:MVChatRoomPassphraseToJoinMode];
			[requiresPassword setState:NSOffState];
			[sender setEnabled:NO];
		}
	} else if( sender == memberLimit ) {
		BOOL enabled = ( [sender intValue] > 1 ? YES : NO );
		if( enabled ) [(MVChatRoom *)[_room target] setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:[sender stringValue]];
		else {
			[(MVChatRoom *)[_room target] removeMode:MVChatRoomLimitNumberOfMembersMode];
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
	_latestBanList = [[[[_room target] bannedUsers] allObjects] mutableCopy];

	SEL sortSelector = NULL;
	NSInteger sortKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatRoomInspectorBanListSort"];
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
	[(MVChatRoom *)[_room target] changeTopic:[topic textStorage]];
}

- (IBAction) resetTopic:(id) sender {
	[self _reloadTopic];
}

- (BOOL) textView:(NSTextView *) textView clickedOnLink:(id) link atIndex:(NSUInteger) charIndex {
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
	[banRules selectRowIndexes:[NSIndexSet indexSetWithIndex:( [_latestBanList count] - 1 )] byExtendingSelection:NO];
	[banRules editColumn:0 row:( [_latestBanList count] - 1 ) withEvent:nil select:NO];
}

- (IBAction) deleteBanRule:(id) sender {
	if( ! [banRules numberOfSelectedRows] || [banRules editedRow] != -1 ) return;

	NSIndexSet *selection = [banRules selectedRowIndexes];

	[banRules deselectAll:nil];

	NSUInteger count = [selection count];
	NSUInteger buffer[count];
	count = [selection getIndexes:buffer maxCount:count inIndexRange:NULL];
	if( ! count ) return;

	NSUInteger i = count;

	do {
		if( i >= 1 ) i--;
		NSUInteger index = buffer[i];
		if( index >= [_latestBanList count] ) continue;
		MVChatUser *ban = _latestBanList[index];
		[[_room target] removeBanForUser:ban];
		[_latestBanList removeObjectAtIndex:index];
	} while( i );

	[banRules reloadData];
}

- (IBAction) editBanRule:(id) sender {
	NSInteger row = [banRules selectedRow];
	if( row == -1 || [banRules numberOfSelectedRows] > 1 ) return;
	[banRules editColumn:0 row:row withEvent:nil select:YES];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) tableView {
	return [_latestBanList count];
}

- (id) tableView:(NSTableView *) tableView objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if ( [[column identifier] isEqualToString:@"author"] ) {
		MVChatUser *user = _latestBanList[row];
		if( [user respondsToSelector:@selector( attributeForKey: )] )
			return [user attributeForKey:MVChatUserBanServerAttribute];
		return nil;
	}
	return [_latestBanList[row] description];
}

- (NSString *) tableView:(NSTableView *) tableView toolTipForCell:(NSCell *) cell rect:(NSRectPointer) rect tableColumn:(NSTableColumn *) column row:(NSInteger) row mouseLocation:(NSPoint) mouseLocation {
	MVChatUser *user = _latestBanList[row];
	NSDate *date = [user attributeForKey:MVChatUserBanDateAttribute];
	NSString *dateString = nil;

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateStyle:NSDateFormatterShortStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	dateString = [formatter stringFromDate:date];

	NSString *server = [user attributeForKey:MVChatUserBanServerAttribute];

	return [NSString stringWithFormat:@"%@ (%@)", dateString, server];
}

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	MVChatUser *newBan = [MVChatUser wildcardUserFromString:object];
	id ban = _latestBanList[row];
	if( [ban isEqual:newBan] ) return;

	if( [ban isKindOfClass:[MVChatUser class]] )
		[[_room target] removeBanForUser:ban];

	if( newBan && [(NSString *)object length] ) {
		[[_room target] addBanForUser:newBan];
		_latestBanList[row] = newBan;
	} else [_latestBanList removeObjectAtIndex:row];

	[banRules reloadData];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	NSUInteger localUserModes = ( [[_room connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] : 0 );
	BOOL canEdit = ( localUserModes & MVChatRoomMemberOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberHalfOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberAdministratorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberFounderMode );
	if( ! canEdit ) canEdit = [[[_room connection] localUser] isServerOperator];

	[deleteBanButton setEnabled:( canEdit && [banRules selectedRow] != -1 )];
	[editBanButton setEnabled:( canEdit && [banRules selectedRow] != -1 && [banRules numberOfSelectedRows] == 1 )];
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
	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:@([_room encoding]), @"StringEncoding", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]), @"IgnoreFontColors", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]), @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSAttributedString *messageString = [NSAttributedString attributedStringWithChatFormat:[(MVChatRoom *)[_room target] topic] options:options];

	if( ! messageString ) {
		options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);
		messageString = [NSAttributedString attributedStringWithChatFormat:[(MVChatRoom *)[_room target] topic] options:options];
	}

	[[topic textStorage] setAttributedString:messageString];
}

- (void) _refreshEditStatus:(NSNotification *) notification {
	if( notification && ! [[notification userInfo][@"who"] isLocalUser] ) return;

	NSUInteger localUserModes = ( [[_room connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] : 0 );
	BOOL canEdit = ( localUserModes & MVChatRoomMemberOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberHalfOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberAdministratorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberFounderMode );
	if( ! canEdit ) canEdit = [[[_room connection] localUser] isServerOperator];

	[newBanButton setEnabled:canEdit];
	[deleteBanButton setEnabled:( canEdit && [banRules selectedRow] != -1 )];
	[editBanButton setEnabled:( canEdit && [banRules selectedRow] != -1 && [banRules numberOfSelectedRows] == 1 )];

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
	NSUInteger changedModes = ( notification ? [[notification userInfo][@"changedModes"] unsignedIntValue] : [(MVChatRoom *)[_room target] modes] );
	NSUInteger newModes = [(MVChatRoom *)[_room target] modes];
	NSUInteger localUserModes = ( [[_room connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[_room connection] localUser]] : 0 );

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
