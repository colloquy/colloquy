#import "MVConnectionsController.h"
#import "JVBuddyInspector.h"

@implementation JVBuddy (JVBuddyInspection)
- (id <JVInspector>) inspector {
	return [[[JVBuddyInspector alloc] initWithBuddy:self] autorelease];
}
@end

#pragma mark -

@implementation JVBuddyInspector
- (id) initWithBuddy:(JVBuddy *) buddy {
	if( ( self = [self init] ) )
		_buddy = [buddy retain];
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_buddy release];
	_buddy = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVBuddyInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 250., 330. );
}

- (NSString *) title {
	return [_buddy compositeName];
}

- (NSString *) type {
	return NSLocalizedString( @"Buddy", "buddy inspector type" );
}

- (void) willLoad {
	NSEnumerator *enumerator = [[[MVConnectionsController defaultController] connections] objectEnumerator];
	MVChatConnection *connection = nil;

	while( ( connection = [enumerator nextObject] ) )
		if( [connection type] == MVChatConnectionIRCType )
			[servers addItemWithTitle:[connection server]];

	while( [voices numberOfItems] > 2 )
		[voices removeItemAtIndex:2];

	enumerator = [[NSSpeechSynthesizer availableVoices] objectEnumerator];
	NSString *voiceIdentifier = nil;
	while( ( voiceIdentifier = [enumerator nextObject] ) ) {
		[voices addItemWithTitle:[[NSSpeechSynthesizer attributesForVoice:voiceIdentifier] objectForKey:NSVoiceName]];
		[[voices lastItem] setRepresentedObject:voiceIdentifier];
	}

	[voices selectItemAtIndex:[[voices menu] indexOfItemWithRepresentedObject:[_buddy speechVoice]]];
	if( ! [voices selectedItem] ) [voices selectItemAtIndex:0];

	[removeNickname setTransparent:NO];
	[removeNickname setHidden:YES];

	[picture setImage:[_buddy picture]];
	[firstName setObjectValue:[_buddy firstName]];
	[lastName setObjectValue:[_buddy lastName]];
	[nickname setObjectValue:[_buddy givenNickname]];
	[email setObjectValue:[_buddy primaryEmail]];

	[self changeServer:servers];
}

- (BOOL) shouldUnload {
	[[view window] makeFirstResponder:view];
	return YES;
}

#pragma mark -

- (IBAction) changeServer:(id) sender {
	if( [[sender selectedItem] tag] ) {
		[_activeUsers autorelease];
		_activeUsers = [[_buddy users] mutableCopyWithZone:nil];
		[_activeUsers sortUsingSelector:@selector( compareByNickname: )];
		[[nicknames tableColumnWithIdentifier:@"nickname"] setEditable:NO];
		[addNickname setEnabled:NO];
	} else {
		[_activeUsers autorelease];
		_activeUsers = [[NSMutableArray allocWithZone:nil] initWithCapacity:[[_buddy users] count]];

		NSEnumerator *enumerator = [[_buddy users] objectEnumerator];
		MVChatUser *user = nil;

		while( ( user = [enumerator nextObject] ) )
			if( [[servers titleOfSelectedItem] caseInsensitiveCompare:[user serverAddress]] == NSOrderedSame )
				[_activeUsers addObject:user];

		[_activeUsers sortUsingSelector:@selector( compareByNickname: )];

		[[nicknames tableColumnWithIdentifier:@"nickname"] setEditable:YES];
		[addNickname setEnabled:YES];
	}

	[nicknames deselectAll:nil];
	[nicknames reloadData];
}

#pragma mark -

- (IBAction) addNickname:(id) sender {
	[_activeUsers addObject:[NSNull null]];
	[nicknames noteNumberOfRowsChanged];
	[nicknames selectRow:( [_activeUsers count] - 1 ) byExtendingSelection:NO];
	[nicknames editColumn:0 row:( [_activeUsers count] - 1 ) withEvent:nil select:NO];
}

- (IBAction) removeNickname:(id) sender {
	if( [nicknames selectedRow] == -1 || [nicknames editedRow] != -1 ) return;
//	[_buddy removeUser:[_activeUsers objectAtIndex:[nicknames selectedRow]]];
	[_activeUsers removeObjectAtIndex:[nicknames selectedRow]];
	[nicknames noteNumberOfRowsChanged];
}

#pragma mark -

- (IBAction) editCard:(id) sender {
	[_buddy editInAddressBook];
}

#pragma mark -

- (IBAction) changeBuddyIcon:(id) sender {
	[_buddy setPicture:[sender image]];
}

- (IBAction) changeFirstName:(id) sender {
	[_buddy setFirstName:[sender stringValue]];
}

- (IBAction) changeLastName:(id) sender {
	[_buddy setLastName:[sender stringValue]];
}

- (IBAction) changeNickname:(id) sender {
	[_buddy setGivenNickname:[sender stringValue]];
}

- (IBAction) changeEmail:(id) sender {
	[_buddy setPrimaryEmail:[sender stringValue]];
}

- (IBAction) changeSpeechVoice:(id) sender {
	NSString *voiceIdentifier = @"";
	if( [sender indexOfSelectedItem] != 0 ) {
		voiceIdentifier = [[sender selectedItem] representedObject];
		NSSpeechSynthesizer *synth = [[[NSSpeechSynthesizer alloc] initWithVoice:voiceIdentifier] autorelease];
		[synth startSpeakingString:[[NSSpeechSynthesizer attributesForVoice:voiceIdentifier] objectForKey:NSVoiceDemoText]];
	}

	[_buddy setSpeechVoice:voiceIdentifier];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_activeUsers count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[_activeUsers objectAtIndex:row] isMemberOfClass:[NSNull class]] ) return @"";
	if( [[servers selectedItem] tag] )
		return [NSString stringWithFormat:@"%@ (%@)", [[_activeUsers objectAtIndex:row] nickname], [[_activeUsers objectAtIndex:row] serverAddress]];
	return [[_activeUsers objectAtIndex:row] nickname];
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( ! [(NSString *)object length] ) {
		[_activeUsers removeObjectAtIndex:row];
		[nicknames noteNumberOfRowsChanged];
		return;
	}

	NSString *server = [servers titleOfSelectedItem];
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:[NSString stringWithFormat:@"%@@%@", object, server] andHostMask:nil];

	if( [[_activeUsers objectAtIndex:row] isMemberOfClass:[NSNull class]] ) {
//		[_buddy addUser:user];
		[_activeUsers replaceObjectAtIndex:row withObject:user];
	} else {
//		[_buddy replaceUser:[_activeUsers objectAtIndex:row] withUser:user];
		[_activeUsers replaceObjectAtIndex:row withObject:user];
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	[removeNickname setHidden:( [nicknames selectedRow] == -1 )];
	[removeNickname highlight:NO];
}
@end