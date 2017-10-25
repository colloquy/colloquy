#import "CQKeychain.h"
#import "JVConnectionInspector.h"
#import "MVConnectionsController.h"
#import "KAIgnoreRule.h"
#import "NSImageAdditions.h"

@implementation MVChatConnection (MVChatConnectionInspection)
- (id <JVInspector>) inspector {
	return [[JVConnectionInspector alloc] initWithConnection:self];
}
@end

#pragma mark -

@implementation JVChatConsolePanel (JVChatConsolePanelInspection)
- (id <JVInspector>) inspector {
	return [[JVConnectionInspector alloc] initWithConnection:[self connection]];
}
@end

#pragma mark -

@implementation JVConnectionInspector
- (instancetype) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [super init] ) )
		_connection = connection;
	return self;
}

- (void) dealloc {
	[editRooms setDataSource:nil];
	[editRooms setDelegate:nil];

	[editRules setDataSource:nil];
	[editRules setDelegate:nil];

	[editRuleRooms setDataSource:nil];
	[editRuleRooms setDelegate:nil];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVConnectionInspector" owner:self topLevelObjects:NULL];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 284., 338. );
}

- (NSString *) title {
	return [_connection server];
}

- (NSString *) type {
	return NSLocalizedString( @"Connection", "connection inspector type" );
}

- (void) willLoad {
	[self buildEncodingMenu];

	NSInteger tabViewIndex = [tabView indexOfTabViewItemWithIdentifier:@"Proxy"];
	if( tabViewIndex != NSNotFound ) {
		[tabView removeTabViewItem:[tabView tabViewItemAtIndex:tabViewIndex]];
		// Removing the tab view item will cause outlet connections below to become
		// invalid e.g. editProxy may be a zombie and crash when messaged.
		// So we'll zero out the outlet as well to avoid that ...
		editProxy = nil;
	}

	[editAutomatic setState:[[MVConnectionsController defaultController] autoConnectForConnection:_connection]];
	[editShowConsoleOnConnect setState:[[MVConnectionsController defaultController] showConsoleOnConnectForConnection:_connection]];
	[sslConnection setState:[_connection didConnectSecurely]];
	[attemptSASLCheckbox setState:_connection.requestsSASL];
	[roomsWaitForIdentificationCheckbox setState:_connection.roomsWaitForIdentification];
	[editAddress setObjectValue:[_connection server]];
	[editProxy selectItemAtIndex:[editProxy indexOfItemWithTag:[_connection proxyType]]];
	[editPort setIntValue:[_connection serverPort]];
	[editNickname setObjectValue:[_connection preferredNickname]];
	[editAltNicknames setObjectValue:[[_connection alternateNicknames] componentsJoinedByString:@" "]];
	[editPassword setObjectValue:[[CQKeychain standardKeychain] passwordForServer:_connection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", _connection.preferredNickname]]];
	[editServerPassword setObjectValue:[[CQKeychain standardKeychain] passwordForServer:_connection.uniqueIdentifier area:@"Server"]];
	[editRealName setObjectValue:[_connection realName]];
	[editUsername setObjectValue:[_connection username]];

	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	numberFormatter.numberStyle = NSNumberFormatterNoStyle;
	[editPort setFormatter:numberFormatter];

	[editPort removeAllItems];
	[editPort addItemsWithObjectValues:[MVChatConnection defaultServerPortsForType:_connection.type]];

	NSString *commands = [[MVConnectionsController defaultController] connectCommandsForConnection:_connection];
	if( commands) [connectCommands setString:commands];

	_editingRooms = [NSMutableArray arrayWithArray:[[MVConnectionsController defaultController] joinRoomsForConnection:_connection]];

	[editRooms reloadData];

	NSTableColumn *column = [editRules tableColumnWithIdentifier:@"icon"];
	NSImageCell *prototypeCell = [NSImageCell new];
	[prototypeCell setImageAlignment:NSImageAlignRight];
	[prototypeCell setImageFrameStyle:NSImageFrameNone];
	[prototypeCell setImageScaling:NSImageScaleNone];
	[column setDataCell:prototypeCell];

	[editRules setTarget:self];
	[editRules setDoubleAction:@selector( configureRule: )];

	_ignoreRules = [[MVConnectionsController defaultController] ignoreRulesForConnection:_connection];
}

- (BOOL) shouldUnload {
	[[view window] makeFirstResponder:view];
	return YES;
}

- (void) didUnload {
	[[MVConnectionsController defaultController] setJoinRooms:_editingRooms forConnection:_connection];
	[[MVConnectionsController defaultController] setConnectCommands:[connectCommands string] forConnection:_connection];
}

#pragma mark -

- (void) selectTabWithIdentifier:(NSString *) identifier {
	[tabView selectTabViewItemWithIdentifier:identifier];
}

#pragma mark -

- (void) buildEncodingMenu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *menuItem = nil;
	NSUInteger i = 0;
	NSStringEncoding defaultEncoding = [_connection encoding];
	if( ! encoding ) defaultEncoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	const NSStringEncoding *supportedEncodings = [_connection supportedStringEncodings];

	for( i = 0; supportedEncodings[i]; i++ ) {
/*		if( supportedEncodings[i] == (NSStringEncoding) -1 ) {
			[menu addItem:[NSMenuItem separatorItem]];
			continue;
		} */

		menuItem = [[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:supportedEncodings[i]] action:@selector( changeEncoding: ) keyEquivalent:@""];
		if( defaultEncoding == supportedEncodings[i] ) [menuItem setState:NSOnState];
		[menuItem setTag:supportedEncodings[i]];
		[menuItem setTarget:self];
		[menu addItem:menuItem];
	}

	[encoding setMenu:menu];
}

- (IBAction) changeEncoding:(id) sender {
	[_connection setEncoding:[sender tag]];
}

#pragma mark -

- (IBAction) openNetworkPreferences:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Network.prefPane"];
}

- (IBAction) editText:(id) sender {
	if( sender == editNickname ) {
		NSString *password = [[CQKeychain standardKeychain] passwordForServer:_connection.uniqueIdentifier area:@"Server"];
		if( password ) [editPassword setObjectValue:password];
		else [editPassword setObjectValue:@""];
		[_connection setPreferredNickname:[sender stringValue]];
	} else if( sender == editAltNicknames ) {
		[_connection setAlternateNicknames:[[sender stringValue] componentsSeparatedByString:@" "]];
	} else if( sender == editPassword ) {
		_connection.nicknamePassword = nil;
		[[CQKeychain standardKeychain] setPassword:[sender stringValue] forServer:_connection.uniqueIdentifier area:[[NSString alloc] initWithFormat:@"Nickname %@", _connection.preferredNickname] displayValue:_connection.server];
	} else if( sender == editServerPassword ) {
		_connection.password = [sender stringValue];
		[[CQKeychain standardKeychain] setPassword:[sender stringValue] forServer:_connection.uniqueIdentifier area:@"Server" displayValue:_connection.server];
	} else if( sender == editAddress ) {
		NSString *password = [[CQKeychain standardKeychain] passwordForServer:_connection.uniqueIdentifier area:@"Server"];
		if( password ) [editPassword setObjectValue:password];
		else [editPassword setObjectValue:@""];
		[_connection setServer:[sender stringValue]];
	} else if( sender == editRealName ) {
		[_connection setRealName:[sender stringValue]];
	} else if( sender == editUsername ) {
		[_connection setUsername:[sender stringValue]];
	} else if( sender == editPort ) {
		[_connection setServerPort:( (unsigned)[sender intValue] % 65536 )];
	}
}

- (void) controlTextDidEndEditing:(NSNotification *) notification {
	// Sends the new text to editText:
	[self editText:[notification object]];
}

- (IBAction) toggleAutoConnect:(id) sender {
	[[MVConnectionsController defaultController] setAutoConnect:[sender state] forConnection:_connection];
}

- (IBAction) toggleShowConsoleOnConnect:(id) sender {
	[[MVConnectionsController defaultController] setShowConsoleOnConnect:[sender state] forConnection:_connection];
}

- (IBAction) toggleSSLConnection:(id) sender {
	[_connection setSecure:[sender state]];
}

- (IBAction) toggleAttemptSASL:(id)sender
{
	_connection.requestsSASL = [sender state];
}

- (IBAction) toggleRoomsWaitForIdentification:(id)sender
{
	_connection.roomsWaitForIdentification = [sender state];
}

- (IBAction) changeProxy:(id) sender {
	[_connection setProxyType:(OSType)[[editProxy selectedItem] tag]];
}

- (IBAction) addRoom:(id) sender {
	[_editingRooms addObject:@""];
	[editRooms noteNumberOfRowsChanged];
	[editRooms selectRowIndexes:[NSIndexSet indexSetWithIndex:([_editingRooms count] - 1)] byExtendingSelection:NO];
	[editRooms editColumn:0 row:([_editingRooms count] - 1) withEvent:nil select:NO];
}

- (IBAction) addRoomToRule:(id) sender {
	[_editingRuleRooms addObject:@""];
	[editRuleRooms noteNumberOfRowsChanged];
	[editRuleRooms selectRowIndexes:[NSIndexSet indexSetWithIndex:([_editingRuleRooms count] - 1)] byExtendingSelection:NO];
	[editRuleRooms editColumn:0 row:([_editingRuleRooms count] - 1) withEvent:nil select:NO];
}

- (IBAction) removeRoom:(id) sender {
	if( [editRooms selectedRow] == -1 || [editRooms editedRow] != -1 ) return;
	[_editingRooms removeObjectAtIndex:[editRooms selectedRow]];
	[editRooms noteNumberOfRowsChanged];
}

- (IBAction) removeRoomFromRule:(id) sender {
	if( [editRuleRooms selectedRow] == -1 || [editRuleRooms editedRow] != -1 ) return;
	[_editingRuleRooms removeObjectAtIndex:[editRuleRooms selectedRow]];
	[editRuleRooms noteNumberOfRowsChanged];
}

- (IBAction) removeRule:(id) sender {
	if( [editRules selectedRow] == -1 || [editRules editedRow] != -1 ) return;
	[_ignoreRules removeObjectAtIndex:[editRules selectedRow]];
	[editRules noteNumberOfRowsChanged];
}

- (IBAction) addRule:(id) sender {
	_editingRuleRooms = [[NSMutableArray alloc] init];

	[editRuleName setStringValue:@""];
	[makeRulePermanent setState:NSOnState];
	[ruleUsesSender setState:NSOnState];
	[ruleUsesMessage setState:NSOffState];
	[ruleUsesRooms setState:NSOffState];
	[senderType selectItemAtIndex:0];
	[messageType selectItemAtIndex:0];
	[editRuleSender setStringValue:@""];
	[editRuleMessage setStringValue:@""];
	[editRuleRooms reloadData];

	_ignoreRuleIsNew = YES;
	[view.window beginSheet:ruleSheet completionHandler:^(NSModalResponse returnCode) {
		[self ruleSheetDidEnd:ruleSheet returnCode:returnCode];
	}];
}

- (IBAction) configureRule:(id) sender {
	KAIgnoreRule *rule = _ignoreRules[[editRules selectedRow]];

	_editingRuleRooms = [[rule rooms] mutableCopy];

	NSString *user = [rule user];
	NSString *message = [rule message];
	BOOL regexUser = NO;
	BOOL regexMessage = NO;

	if( user ) {
		if( [user length] > 2 && [user hasPrefix:@"/"] && [user hasSuffix:@"/"] ) {
			user = [user substringWithRange:NSMakeRange( 1, [user length] - 2 )];
			regexUser = YES;
		}
	}

	if( message) {
		if( [message length] > 2 && [message hasPrefix:@"/"] && [message hasSuffix:@"/"] ) {
			message = [message substringWithRange:NSMakeRange(1,[message length]-2)];
			regexMessage = YES;
		}
	}

	[editRuleName setStringValue:[rule friendlyName]];
	[makeRulePermanent setState:( [rule isPermanent] ? NSOnState : NSOffState )];
	[ruleUsesSender setState:( ! [[rule user] length] ? NSOffState : NSOnState )];
	[ruleUsesMessage setState:( ! [[rule message] length] ? NSOffState : NSOnState )];
	[ruleUsesRooms setState:( ! [[rule rooms] count] ? NSOffState : NSOnState )];
	[senderType selectItemAtIndex:( regexUser ? 1 : 0 )];
	[messageType selectItemAtIndex:( regexMessage ? 1 : 0 )];
	[editRuleSender setStringValue:( user ? user : @"" )];
	[editRuleMessage setStringValue:( message ? message: @"" )];
	[editRuleRooms reloadData];

	_ignoreRuleIsNew = NO;
	[view.window beginSheet:ruleSheet completionHandler:^(NSModalResponse returnCode) {
		[self ruleSheetDidEnd:ruleSheet returnCode:returnCode];
	}];
}

- (IBAction) saveRule:(id) sender {
	[view.window endSheet:ruleSheet returnCode:NSModalResponseOK];
}

- (IBAction) discardChangesToRule:(id) sender {
	[view.window endSheet:ruleSheet returnCode:NSModalResponseCancel];
}

- (void) ruleSheetDidEnd:(NSWindow *) sheet returnCode:(NSModalResponse) returnCode {
	if( returnCode == NSModalResponseOK ) {
		NSString *user = nil;
		if( [ruleUsesSender state] == NSOnState ) {
			if( [senderType indexOfSelectedItem] == 0 ) user = [editRuleSender stringValue];
			else user = [NSString stringWithFormat:@"/%@/",[editRuleSender stringValue]];
		}

		NSString *message = nil;
		if( [ruleUsesMessage state] == NSOnState ) {
			if( [messageType indexOfSelectedItem] == 0 ) message = [editRuleMessage stringValue];
			else message = [NSString stringWithFormat:@"/%@/",[editRuleMessage stringValue]];
		}

		NSString *friendlyName = [editRuleName stringValue];
		if( [friendlyName isEqualToString:@""] ) friendlyName = nil;

		BOOL isPermanent = ( [makeRulePermanent state] == NSOnState );

		if( _ignoreRuleIsNew ) {
			KAIgnoreRule *rule = nil;
			if ( [user isValidIRCMask] )
				rule = [KAIgnoreRule ruleForUser:nil mask:user message:message inRooms:_editingRuleRooms isPermanent:isPermanent friendlyName:friendlyName];
			else rule = [KAIgnoreRule ruleForUser:user message:message inRooms:_editingRuleRooms isPermanent:isPermanent friendlyName:friendlyName];
			[_ignoreRules addObject:rule];
			[editRules noteNumberOfRowsChanged];
		} else {
			KAIgnoreRule *rule = _ignoreRules[[editRules selectedRow]];
			if ( [message isValidIRCMask] ) {
				[rule setMask:user];
				[rule setUser:nil];
			} else {
				[rule setUser:user];
				[rule setMask:user];
			}
			[rule setMessage:message];
			[rule setRooms:_editingRuleRooms];
			[rule setPermanent:isPermanent];
			[rule setFriendlyName:friendlyName];
			[editRules reloadData];
		}
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) tableView {
	if( tableView == editRooms ) return [_editingRooms count];
	else if( tableView == editRules ) return [_ignoreRules count];
	else if( tableView == editRuleRooms ) return [_editingRuleRooms count];
	else return 0;
}

- (id) tableView:(NSTableView *) tableView objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( tableView == editRooms ) return _editingRooms[row];
	else if( tableView == editRules ) {
		KAIgnoreRule *rule = _ignoreRules[row];
		if( [[column identifier] isEqualToString:@"icon"] ) {
			if( [rule user] && [rule message] ) return [NSImage imageNamed:@"privateChatTab"];
			else if( [rule user] ) {
				NSImage *image = [[NSImage imageNamed:@"person"] copy];
				image.size = NSMakeSize(14., 14.);
				return image;
			}
			else return [NSImage imageNamed:@"roomTabNewMessage"];
		} else {
			if( ! [rule isPermanent] ) return [[NSAttributedString alloc] initWithString:[rule friendlyName] attributes:@{NSForegroundColorAttributeName: [[NSColor blackColor] colorWithAlphaComponent:0.67]}];
			else return [rule friendlyName];
		}
	} else if( tableView == editRuleRooms ) return _editingRuleRooms[row];
	else return nil;
}

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( tableView == editRooms ) _editingRooms[row] = object;
	else if( tableView == editRuleRooms ) _editingRuleRooms[row] = object;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	if( [notification object] == editRooms ) {
		[editRemoveRoom setEnabled:( [editRooms selectedRow] != -1 )];
	} else if( [notification object] == editRules ) {
		[deleteRule setEnabled:( [editRules selectedRow] != -1 )];
		[editRule setEnabled:( [editRules selectedRow] != -1 )];
	} else if( [notification object] == editRuleRooms ) {
		[deleteRoomFromRule setEnabled:( [editRuleRooms selectedRow] != -1 )];
	}
}

#pragma mark -

- (NSInteger) numberOfItemsInComboBox:(NSComboBox *) comboBox {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] count];
}

- (id) comboBox:(NSComboBox *) comboBox objectValueForItemAtIndex:(NSInteger) index {
	return [[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"][index];
}

- (NSUInteger) comboBox:(NSComboBox *) comboBox indexOfItemWithStringValue:(NSString *) string {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] indexOfObject:string];
}

- (NSString *) comboBox:(NSComboBox *) comboBox completedString:(NSString *) substring {
	for( NSString *server in [[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] )
		if( [server hasPrefix:substring] ) return server;
	return nil;
}
@end
