#import "JVConnectionInspector.h"
#import <Cocoa/Cocoa.h>
#import "MVConnectionsController.h"
#import "MVKeyChain.h"

@implementation MVChatConnection (MVChatConnectionInspection)
- (id <JVInspector>) inspector {
	return [[[JVConnectionInspector alloc] initWithConnection:self] autorelease];
}
@end

#pragma mark -

@implementation JVConnectionInspector
- (id) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = [connection retain];
		_editingRooms = nil;
	}
	return self;
}

- (void) dealloc {
	[_connection release];
	[_editingRooms release];
	_connection = nil;
	_editingRooms = nil;
	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVConnectionInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 275., 338. );
}

- (NSString *) title {
	return [_connection server];
}

- (NSString *) type {
	return NSLocalizedString( @"Connection", "connection inspector type" );
}

- (void) willLoad {
	[self buildEncodingMenu];

	[editAutomatic setState:[[MVConnectionsController defaultManager] autoConnectForConnection:_connection]];
	[sslConnection setState:[_connection isSecure]];
	[editAddress setObjectValue:[_connection server]];
	[editProxy selectItemAtIndex:[editProxy indexOfItemWithTag:(int)[_connection proxyType]]];
	[editPort setIntValue:[_connection serverPort]];
	[editNickname setObjectValue:[_connection preferredNickname]];
	[editAltNicknames setObjectValue:[[_connection alternateNicknames] componentsJoinedByString:@" "]];
	[editPassword setObjectValue:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[_connection server] securityDomain:[_connection server] account:[_connection preferredNickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
	[editServerPassword setObjectValue:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[_connection server] securityDomain:[_connection server] account:nil path:nil port:[_connection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
	[editRealName setObjectValue:[_connection realName]];
	[editUsername setObjectValue:[_connection username]];

	NSString *commands = [[MVConnectionsController defaultManager] connectCommandsForConnection:_connection];
	if( commands) [connectCommands setString:commands];

	[_editingRooms autorelease];
	_editingRooms = [[NSMutableArray arrayWithArray:[[MVConnectionsController defaultManager] joinRoomsForConnection:_connection]] retain];

	[editRooms reloadData];
}

- (void) didUnload {
	[[MVConnectionsController defaultManager] setJoinRooms:_editingRooms forConnection:_connection];
	[[MVConnectionsController defaultManager] setConnectCommands:[connectCommands string] forConnection:_connection];
}

#pragma mark -

- (void) buildEncodingMenu {
	extern const NSStringEncoding JVAllowedTextEncodings[];
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *menuItem = nil;
	unsigned int i = 0;
	NSStringEncoding defaultEncoding = [_connection encoding];
	if( ! encoding ) defaultEncoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	for( i = 0; JVAllowedTextEncodings[i]; i++ ) {
		if( JVAllowedTextEncodings[i] == (NSStringEncoding) -1 ) {
			[menu addItem:[NSMenuItem separatorItem]];
			continue;
		}

		menuItem = [[[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:JVAllowedTextEncodings[i]] action:@selector( changeEncoding: ) keyEquivalent:@""] autorelease];
		if( defaultEncoding == JVAllowedTextEncodings[i] ) [menuItem setState:NSOnState];
		[menuItem setTag:JVAllowedTextEncodings[i]];
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
		NSString *password = [[MVKeyChain defaultKeyChain] internetPasswordForServer:[editAddress stringValue] securityDomain:[editAddress stringValue] account:[sender stringValue] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
		if( password ) [editPassword setObjectValue:password];
		else [editPassword setObjectValue:@""];
		[_connection setNickname:[sender stringValue]];
	} else if( sender == editAltNicknames ) {
		[_connection setAlternateNicknames:[[sender stringValue] componentsSeparatedByString:@" "]];
	} else if( sender == editPassword ) {
		[_connection setNicknamePassword:[sender stringValue]];
		[[MVKeyChain defaultKeyChain] setInternetPassword:[sender stringValue] forServer:[editAddress stringValue] securityDomain:[editAddress stringValue] account:[editNickname stringValue] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
	} else if( sender == editServerPassword ) {
		[_connection setPassword:[sender stringValue]];
		[[MVKeyChain defaultKeyChain] setInternetPassword:[sender stringValue] forServer:[editAddress stringValue] securityDomain:[editAddress stringValue] account:nil path:nil port:(unsigned short)[editPort intValue] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
	} else if( sender == editAddress ) {
		NSString *password = [[MVKeyChain defaultKeyChain] internetPasswordForServer:[sender stringValue] securityDomain:[sender stringValue] account:[editNickname stringValue] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
		if( password ) [editPassword setObjectValue:password];
		else [editPassword setObjectValue:@""];
		[_connection setServer:[sender stringValue]];
	} else if( sender == editRealName ) {
		[_connection setRealName:[sender stringValue]];
	} else if( sender == editUsername ) {
		[_connection setUsername:[sender stringValue]];
	} else if( sender == editUsername ) {
		[_connection setServerPort:(unsigned short)[sender intValue]];
	}
}

- (IBAction) toggleAutoConnect:(id) sender {
	[[MVConnectionsController defaultManager] setAutoConnect:[sender state] forConnection:_connection];
}

- (IBAction) toggleSSLConnection:(id) sender {
	[_connection setSecure:[sender state]];
}

- (IBAction) changeProxy:(id) sender {
	[_connection setProxyType:[[editProxy selectedItem] tag]];
}

- (IBAction) addRoom:(id) sender {
	[_editingRooms addObject:@""];
	[editRooms noteNumberOfRowsChanged];
	[editRooms selectRow:([_editingRooms count] - 1) byExtendingSelection:NO];
	[editRooms editColumn:0 row:([_editingRooms count] - 1) withEvent:nil select:NO];
}

- (IBAction) removeRoom:(id) sender {
	if( [editRooms selectedRow] == -1 || [editRooms editedRow] != -1 ) return;
	[_editingRooms removeObjectAtIndex:[editRooms selectedRow]];
	[editRooms noteNumberOfRowsChanged];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_editingRooms count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	return [_editingRooms objectAtIndex:row];
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	[_editingRooms replaceObjectAtIndex:row withObject:object];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	[editRemoveRoom setTransparent:( [editRooms selectedRow] == -1 )];
	[editRemoveRoom highlight:NO];
}

#pragma mark -

- (int) numberOfItemsInComboBox:(NSComboBox *) comboBox {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] count];
}

- (id) comboBox:(NSComboBox *) comboBox objectValueForItemAtIndex:(int) index {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] objectAtIndex:index];
}

- (unsigned int) comboBox:(NSComboBox *) comboBox indexOfItemWithStringValue:(NSString *) string {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] indexOfObject:string];
}

- (NSString *) comboBox:(NSComboBox *) comboBox completedString:(NSString *) substring {
	NSEnumerator *enumerator = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] objectEnumerator];
	NSString *server = nil;
	while( ( server = [enumerator nextObject] ) )
		if( [server hasPrefix:substring] ) return server;
	return nil;
}
@end
