#import "MVConnectionsController.h"
#import "MVBuddyListController.h"
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

	[identifiersTable setDataSource:nil];
	[identifiersTable setDelegate:nil];

	[_buddy release];
	[_currentRule release];
	[_editDomains release];

	_buddy = nil;
	_currentRule = nil;
	_editDomains = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVBuddyInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 300., 350. );
}

- (NSString *) title {
	return [_buddy compositeName];
}

- (NSString *) type {
	return NSLocalizedString( @"Buddy", "buddy inspector type" );
}

- (void) willLoad {
	while( [voices numberOfItems] > 2 )
		[voices removeItemAtIndex:2];

	NSEnumerator *enumerator = [[NSSpeechSynthesizer availableVoices] objectEnumerator];
	NSString *voiceIdentifier = nil;
	while( ( voiceIdentifier = [enumerator nextObject] ) ) {
		[voices addItemWithTitle:[[NSSpeechSynthesizer attributesForVoice:voiceIdentifier] objectForKey:NSVoiceName]];
		[[voices lastItem] setRepresentedObject:voiceIdentifier];
	}

	[voices selectItemAtIndex:[[voices menu] indexOfItemWithRepresentedObject:[_buddy speechVoice]]];
	if( ! [voices selectedItem] ) [voices selectItemAtIndex:0];

	[removeIdentifier setEnabled:NO];
	[editIdentifier setEnabled:NO];

	[picture setImage:[_buddy picture]];
	[firstName setObjectValue:[_buddy firstName]];
	[lastName setObjectValue:[_buddy lastName]];
	[nickname setObjectValue:[_buddy givenNickname]];
	[email setObjectValue:[_buddy primaryEmail]];

	[identifiersTable setTarget:self];
	[identifiersTable setDoubleAction:@selector( editIdentifier: )];
}

- (BOOL) shouldUnload {
	[[view window] makeFirstResponder:view];
	[[MVBuddyListController sharedBuddyList] save];
	return YES;
}

#pragma mark -

- (IBAction) addIdentifier:(id) sender {
	[_currentRule release];
	_currentRule = [[MVChatUserWatchRule allocWithZone:nil] init];

	[_editDomains release];
	_editDomains = [[NSMutableArray allocWithZone:nil] init];

	[identifierDomainsTable reloadData];

	[identifierNickname setStringValue:@""];
	[identifierRealName setStringValue:@""];
	[identifierUsername setStringValue:@""];
	[identifierHostname setStringValue:@""];
	[identifierDomainsTable setEnabled:NO];
	[addDomain setEnabled:NO];
	[identifierConnections selectCellWithTag:0];

	[identifierOkay setEnabled:NO];

	[identifierEditPanel makeFirstResponder:identifierNickname];

	_identifierIsNew = YES;
	[[NSApplication sharedApplication] beginSheet:identifierEditPanel modalForWindow:[view window] modalDelegate:self didEndSelector:@selector( identifierSheetDidEnd:returnCode:contextInfo: ) contextInfo:nil];
}

- (IBAction) editIdentifier:(id) sender {
	int index = [identifiersTable selectedRow];
	if( index == -1 ) return;

	[_currentRule release];
	_currentRule = [[[_buddy watchRules] objectAtIndex:index] retain];

	[_editDomains release];
	_editDomains = [[NSMutableArray allocWithZone:nil] init];
	if( [[_currentRule applicableServerDomains] count] ) {
		[_editDomains setArray:[_currentRule applicableServerDomains]];
		[identifierDomainsTable setEnabled:YES];
		[addDomain setEnabled:YES];
		[identifierConnections selectCellWithTag:1];
	} else {
		[identifierDomainsTable setEnabled:NO];
		[addDomain setEnabled:NO];
		[identifierConnections selectCellWithTag:0];
	}

	[identifierDomainsTable reloadData];

	if( [_currentRule nickname] )
		[identifierNickname setStringValue:[_currentRule nickname]];
	else [identifierNickname setStringValue:@""];

	if( [_currentRule realName] )
		[identifierRealName setStringValue:[_currentRule realName]];
	else [identifierRealName setStringValue:@""];

	if( [_currentRule username] )
		[identifierUsername setStringValue:[_currentRule username]];
	else [identifierUsername setStringValue:@""];

	if( [_currentRule address] )
		[identifierHostname setStringValue:[_currentRule address]];
	else [identifierHostname setStringValue:@""];

	[identifierOkay setEnabled:YES];

	[identifierEditPanel makeFirstResponder:identifierNickname];

	_identifierIsNew = NO;
	[[NSApplication sharedApplication] beginSheet:identifierEditPanel modalForWindow:[view window] modalDelegate:self didEndSelector:@selector( identifierSheetDidEnd:returnCode:contextInfo: ) contextInfo:nil];
}

- (IBAction) removeIdentifier:(id) sender {
	int index = [identifiersTable selectedRow];
	if( index == -1 ) return;

	MVChatUserWatchRule *rule = [[_buddy watchRules] objectAtIndex:index];
	[_buddy removeWatchRule:rule];

	[_buddy unregisterWithConnections];
	[_buddy registerWithApplicableConnections];

	[identifiersTable noteNumberOfRowsChanged];
}

- (IBAction) discardIdentifierChanges:(id) sender {
	[[NSApplication sharedApplication] endSheet:identifierEditPanel returnCode:NO];
	[identifierEditPanel orderOut:sender];
}

- (IBAction) saveIdentifierChanges:(id) sender {
	[[NSApplication sharedApplication] endSheet:identifierEditPanel returnCode:YES];
	[identifierEditPanel orderOut:sender];
}

- (void) identifierSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	if( returnCode ) {
		NSString *string = [identifierNickname stringValue];
		[_currentRule setNickname:( [string length] ? string : nil )];

		string = [identifierRealName stringValue];
		[_currentRule setRealName:( [string length] ? string : nil )];

		string = [identifierUsername stringValue];
		[_currentRule setUsername:( [string length] ? string : nil )];

		string = [identifierHostname stringValue];
		[_currentRule setAddress:( [string length] ? string : nil )];

		[_currentRule setApplicableServerDomains:( [_editDomains count] && [identifierConnections selectedTag] ? _editDomains : nil )];

		if( _identifierIsNew )
			[_buddy addWatchRule:_currentRule];

		[_buddy unregisterWithConnections];
		[_buddy registerWithApplicableConnections];

		[identifiersTable reloadData];
	}

	[_currentRule release];
	_currentRule = nil;

	[_editDomains release];
	_editDomains = nil;

	[identifierDomainsTable reloadData];
}

- (IBAction) changeConnectionState:(id) sender {
	BOOL enabled = [identifierConnections selectedTag];
	[identifierDomainsTable setEnabled:enabled];
	[addDomain setEnabled:enabled];
}

- (void) controlTextDidChange:(NSNotification *) notification {
	if( [[identifierNickname stringValue] length] || [[identifierRealName stringValue] length] || 
		[[identifierUsername stringValue] length] || [[identifierHostname stringValue] length] )
		[identifierOkay setEnabled:YES];
	else [identifierOkay setEnabled:NO];
}

#pragma mark -

- (IBAction) addDomain:(id) sender {
	[_editDomains addObject:@""];
	[identifierDomainsTable noteNumberOfRowsChanged];
	[identifierDomainsTable selectRow:( [_editDomains count] - 1 ) byExtendingSelection:NO];
	[identifierDomainsTable editColumn:0 row:( [_editDomains count] - 1 ) withEvent:nil select:NO];
}

- (IBAction) removeDomain:(id) sender {
	if( [identifierDomainsTable selectedRow] == -1 || [identifierDomainsTable editedRow] != -1 ) return;
	[_editDomains removeObjectAtIndex:[identifierDomainsTable selectedRow]];
	[identifierDomainsTable noteNumberOfRowsChanged];
}

#pragma mark -

- (IBAction) changeCard:(id) sender {
	
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
	NSString *voiceIdentifier = nil;

	if( [sender indexOfSelectedItem] != 0 ) {
		voiceIdentifier = [[sender selectedItem] representedObject];
		NSSpeechSynthesizer *synth = [[NSSpeechSynthesizer alloc] initWithVoice:voiceIdentifier];
		[synth startSpeakingString:[[NSSpeechSynthesizer attributesForVoice:voiceIdentifier] objectForKey:NSVoiceDemoText]];
		[synth release];
	}

	[_buddy setSpeechVoice:voiceIdentifier];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) tableView {
	if( [tableView isEqual:identifiersTable] )
		return [[_buddy watchRules] count];
	if( [tableView isEqual:identifierDomainsTable] )
		return [_editDomains count];
	return 0;
}

- (id) tableView:(NSTableView *) tableView objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [tableView isEqual:identifiersTable] ) {
		NSMutableString *description = [NSMutableString string];
		MVChatUserWatchRule *rule = [[_buddy watchRules] objectAtIndex:row];
		unsigned count = 0;

		NSString *string = [rule nickname];
		if( [string length] ) {
			[description appendString:string];
			count++;
		}

		string = [rule realName];
		if( [string length] ) {
			if( ! count ) [description appendString:string];
			count++;
		}

		string = [rule username];
		if( [string length] ) {
			if( ! count ) [description appendString:string];
			count++;
		}

		string = [rule address];
		if( [string length] ) {
			if( ! count ) [description appendString:string];
			count++;
		}

		if( [[rule applicableServerDomains] count] )
			count++;

		count--; // exclude the first rule criterion in the count

		if( count == 1 )
			[description appendFormat:NSLocalizedString( @" (and 1 other criterion)", "one other buddy identifier criterion" ), count];
		else if( count > 1 )
			[description appendFormat:NSLocalizedString( @" (and %u other criteria)", "count of other buddy identifier criteria" ), count];

		return description;
	}

	if( [tableView isEqual:identifierDomainsTable] )
		return [_editDomains objectAtIndex:row];

	return nil;
}

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( [tableView isEqual:identifierDomainsTable] )
		[_editDomains replaceObjectAtIndex:row withObject:object];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	NSTableView *tableView = [notification object];
	if( [tableView isEqual:identifiersTable] ) {
		[removeIdentifier setEnabled:( [identifiersTable selectedRow] != -1 )];
		[editIdentifier setEnabled:( [identifiersTable selectedRow] != -1 )];
	} else if( [tableView isEqual:identifierDomainsTable] ) {
		[removeDomain setEnabled:( [identifierDomainsTable selectedRow] != -1 )];
	}
}
@end
