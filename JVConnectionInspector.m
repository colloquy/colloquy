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
	[_connection autorelease];
	[_editingRooms autorelease];
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
	return NSMakeSize( 265., 290. );
}

- (NSString *) title {
	return [_connection server];
}

- (NSString *) type {
	return NSLocalizedString( @"Connection", "connection inspector type" );
}

- (void) willLoad {
	[editAutomatic setState:[[MVConnectionsController defaultManager] autoConnectForConnection:_connection]];
	[editAddress setObjectValue:[_connection server]];
	[editProxy selectItemAtIndex:[editProxy indexOfItemWithTag:(int)[_connection proxyType]]];
	[editPort setIntValue:[_connection serverPort]];
	[editNickname setObjectValue:[_connection nickname]];
	[editPassword setObjectValue:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[_connection server] securityDomain:[_connection server] account:[_connection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
	[editServerPassword setObjectValue:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[_connection server] securityDomain:[_connection server] account:nil path:nil port:[_connection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];

	[_editingRooms autorelease];
	_editingRooms = [[[MVConnectionsController defaultManager] joinRoomsForConnection:_connection] mutableCopy];
	if( ! _editingRooms ) _editingRooms = [[NSMutableArray array] retain];
	[editRooms reloadData];
}

- (void) didUnload {
	[[MVConnectionsController defaultManager] setJoinRooms:_editingRooms forConnection:_connection];
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
	} else if( sender == editPort ) {
		[_connection setServerPort:(unsigned short)[sender intValue]];
	}
}

- (IBAction) toggleAutoConnect:(id) sender {
	[[MVConnectionsController defaultManager] setAutoConnect:[sender state] forConnection:_connection];
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
@end
