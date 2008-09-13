#import "CQConnectionsController.h"
#import "CQConnectionsViewController.h"
#import "CQConnectionEditViewController.h"
#import "CQChatController.h"

#import <ChatCore/MVChatConnection.h>

@interface CQConnectionsController (CQConnectionsControllerPrivate)
- (void) _loadConnectionList;
- (void) _saveConnectionList;
@end

@implementation CQConnectionsController
+ (CQConnectionsController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQConnectionsController *sharedInstance = nil;

	if( !sharedInstance && !creatingSharedInstance ) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

- (id) init {
	if( ! ( self = [super init] ) )
		return nil;

	self.title = NSLocalizedString(@"Connections", @"Connections tab title");
	self.tabBarItem.image = [UIImage imageNamed:@"connections.png"];

	_connections = [[NSMutableArray alloc] init];

	connectionsViewController = [[CQConnectionsViewController alloc] init];
	[self pushViewController:connectionsViewController animated:NO];

	[self _loadConnectionList];

	return self;
}

- (void) dealloc {
	[_connections release];
	[connectionsViewController release];
	[editViewController release];
	[super dealloc];
}

#pragma mark -

- (void) didReceiveMemoryWarning {
	if( !editViewController.view.superview ) {
		[editViewController release];
		editViewController = nil;
	}

	[super didReceiveMemoryWarning];
}

#pragma mark -

- (void) editConnection:(MVChatConnection *) connection {
	if( !editViewController )
		editViewController = [[CQConnectionEditViewController alloc] init];
	[editViewController setConnection:connection];
	[self pushViewController:editViewController animated:YES];
}

#pragma mark -

/*
- (void) _createPreferenceCellsIfNeeded {
	if( _autoConnectCell )
		return;

	// Create all of our cells for the first time.

	_autoConnectCell = [[UIPreferencesControlTableCell alloc] init];
	[_autoConnectCell setTitle:@"Connect on Launch"];

	UISwitchControl *switchControl = [[UISwitchControl alloc] initWithFrame:CGRectMake(200., 10., 50., 20.)];
	[_autoConnectCell setControl:switchControl];
	[switchControl release];

	_serverCell = [[UIPreferencesTextTableCell alloc] init];
	[_serverCell setTitle:@"Host Name"];
	[_serverCell setPlaceHolderValue:@"irc.example.com"];
	[[_serverCell textField] setAutoCapsType:0]; // no inital caps
	[[_serverCell textField] setAutoCorrectionType:1]; // no correction
	[[_serverCell textField] setPreferredKeyboardType:3]; // url keyboard

	_serverPortCell = [[UIPreferencesTextTableCell alloc] init];
	[_serverPortCell setTitle:@"Port"];
	[_serverPortCell setPlaceHolderValue:@"6667"];
	[[_serverPortCell textField] setAutoCorrectionType:1]; // no correction
	[[_serverPortCell textField] setPreferredKeyboardType:2]; // number keypad

	_sslCell = [[UIPreferencesControlTableCell alloc] init];
	[_sslCell setTitle:@"Uses SSL"];

	switchControl = [[UISwitchControl alloc] initWithFrame:CGRectMake(200., 10., 50., 20.)];
	[_sslCell setControl:switchControl];
	[switchControl release];

	_nicknameCell = [[UIPreferencesTextTableCell alloc] init];
	[_nicknameCell setTitle:@"Nickname"];
	[_nicknameCell setPlaceHolderValue:@"Required"];
	[[_nicknameCell textField] setAutoCapsType:0]; // no inital caps

	_nicknamePasswordCell = [[UIPreferencesTextTableCell alloc] init];
	[_nicknamePasswordCell setTitle:@"Password"];
	[_nicknamePasswordCell setPlaceHolderValue:@"Optional"];
	[[_nicknamePasswordCell textField] setSecureTextEntry:YES];
	[[_nicknamePasswordCell textField] setSecure:YES];

	_alternateNicknamesCell = [[UIPreferencesTextTableCell alloc] init];
	[_alternateNicknamesCell setTitle:@"Alternates"];
	[_alternateNicknamesCell setPlaceHolderValue:@"First Second..."];
	[[_alternateNicknamesCell textField] setAutoCapsType:0]; // no inital caps
	[[_alternateNicknamesCell textField] setAutoCorrectionType:1]; // no correction

	_usernameCell = [[UIPreferencesTextTableCell alloc] init];
	[_usernameCell setTitle:@"User Name"];
	[_usernameCell setPlaceHolderValue:@"Optional"];
	[[_usernameCell textField] setAutoCapsType:0]; // no inital caps

	_serverPasswordCell = [[UIPreferencesTextTableCell alloc] init];
	[_serverPasswordCell setTitle:@"Password"];
	[_serverPasswordCell setPlaceHolderValue:@"Optional"];
	[[_serverPasswordCell textField] setSecureTextEntry:YES];
	[[_serverPasswordCell textField] setSecure:YES];

	_realNameCell = [[UIPreferencesTextTableCell alloc] init];
	[_realNameCell setTitle:@"Real Name"];
	[_realNameCell setPlaceHolderValue:@"Optional"];

	_autoRoomsCell = [[UIPreferencesTextTableCell alloc] init];
	[_autoRoomsCell setTitle:@"Join Rooms"];
	[_autoRoomsCell setPlaceHolderValue:@"First Second..."];
	[[_autoRoomsCell textField] setAutoCapsType:0]; // no inital caps
	[[_autoRoomsCell textField] setAutoCorrectionType:1]; // no correction
}

- (void) table:(UITableView *) table disclosureClickedForRow:(int) row {
	[_editingConnection release];
	_editingConnection = [[_connections objectAtIndex:row] retain];

	UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@"Edit"];
	[_navigationBar pushNavigationItem:navigationItem];
	[navigationItem release];

	[self _createPreferenceCellsIfNeeded];

	NSDictionary *extraInfo = [[_editingConnection persistentInformation] objectForKey:@"CQConnectionsControllerExtraInfo"];

	NSNumber *automatic = [extraInfo objectForKey:@"automatic"];
	[(UISwitchControl *)[_autoConnectCell control] setValue:( [automatic boolValue] ? 1. : 0. )];

	[_serverCell setValue:[_editingConnection server]];
	[_serverPortCell setValue:[NSString stringWithFormat:@"%hu", [_editingConnection serverPort]]];
	[(UISwitchControl *)[_sslCell control] setValue:( [_editingConnection isSecure] ? 1. : 0. )];
	[_nicknameCell setValue:[_editingConnection preferredNickname]];
	[_nicknamePasswordCell setValue:[_editingConnection nicknamePassword]];
	[_alternateNicknamesCell setValue:[[_editingConnection alternateNicknames] componentsJoinedByString:@" "]];
	[_usernameCell setValue:[_editingConnection username]];
	[_serverPasswordCell setValue:[_editingConnection password]];
	[_realNameCell setValue:[_editingConnection realName]];

	NSArray *autoRooms = [extraInfo objectForKey:@"rooms"];
	[_autoRoomsCell setValue:[autoRooms componentsJoinedByString:@" "]];

	[_settingsTable setKeyboardVisible:NO animated:NO];
	[_settingsTable setBottomBufferHeight:5.];
	[_settingsTable reloadData];		

	[_connectionsTable highlightRow:row];
	[_navigationBar showLeftButton:nil withStyle:0 rightButton:@"Delete" withStyle:1];
	[_transitionView transition:1 toView:_settingsTable];
}

- (void) navigationBar:(UINavigationBar *) bar poppedItem:(UINavigationItem *) item {
	[_settingsTable setKeyboardVisible:NO animated:NO];
	[_settingsTable setBottomBufferHeight:5.];

	[_connectionsTable selectRow:-1 byExtendingSelection:NO withFade:NO scrollingToVisible:NO];
	[_navigationBar showLeftButton:[UIImage imageNamed:@"plus.png"] withStyle:0 rightButton:@"Done" withStyle:3];
	[_transitionView transition:2 toView:_connectionsTable];

	if( _newConnection )
		_editingConnection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];

	if( _editingConnection ) {
		NSMutableDictionary *persistentInformation = [[_editingConnection persistentInformation] mutableCopy];
		NSMutableDictionary *extraInfo = [[persistentInformation objectForKey:@"CQConnectionsControllerExtraInfo"] mutableCopy];
		if( ! extraInfo ) extraInfo = [[NSMutableDictionary alloc] init];

		NSNumber *automatic = [NSNumber numberWithBool:( [(UISwitchControl *)[_autoConnectCell control] value] > 0. )];
		[extraInfo setObject:automatic forKey:@"automatic"];

		if( [[_serverCell value] length] )
			[_editingConnection setServer:[_serverCell value]];

		[_editingConnection setServerPort:[[_serverPortCell value] intValue]];
		[_editingConnection setSecure:( [(UISwitchControl *)[_sslCell control] value] > 0. )];

		if( [[_nicknameCell value] length] )
			[_editingConnection setNickname:[_nicknameCell value]];

		if( [[_alternateNicknamesCell value] length] )
			[_editingConnection setAlternateNicknames:[[_alternateNicknamesCell value] componentsSeparatedByString:@" "]];
		else [_editingConnection setAlternateNicknames:[NSArray array]];

		if( [[_usernameCell value] length] )
			[_editingConnection setUsername:[_usernameCell value]];

		[_editingConnection setNicknamePassword:[[_nicknamePasswordCell value] length] ? [_nicknamePasswordCell value] : nil];
		[_editingConnection setPassword:[[_serverPasswordCell value] length] ? [_serverPasswordCell value] : nil];
		[_editingConnection setRealName:[_realNameCell value] ? [_realNameCell value] : @""];

		if( [[_editingConnection nicknamePassword] length] )
			[PSKeychainUtilities setPassword:[_editingConnection nicknamePassword] forHost:[_editingConnection server] username:[_editingConnection preferredNickname] port:0 protocol:[_editingConnection urlScheme]];
		else [PSKeychainUtilities removePasswordForHost:[_editingConnection server] username:[_editingConnection preferredNickname] port:0 protocol:[_editingConnection urlScheme]];

		if( [[_editingConnection password] length] )
			[PSKeychainUtilities setPassword:[_editingConnection password] forHost:[_editingConnection server] username:[_editingConnection username] port:[_editingConnection serverPort] protocol:[_editingConnection urlScheme]];
		else [PSKeychainUtilities removePasswordForHost:[_editingConnection server] username:[_editingConnection username] port:[_editingConnection serverPort] protocol:[_editingConnection urlScheme]];

		NSArray *autoRooms = [[_autoRoomsCell value] componentsSeparatedByString:@" "];
		if( autoRooms ) [extraInfo setValue:autoRooms forKey:@"rooms"];
		else [extraInfo removeObjectForKey:@"rooms"];

		[persistentInformation setObject:extraInfo forKey:@"CQConnectionsControllerExtraInfo"];
		[extraInfo release];

		[_editingConnection setPersistentInformation:persistentInformation];
		[persistentInformation release];

		if( _newConnection && [[_serverCell value] length] && [[_nicknameCell value] length] ) {
			[self addConnection:_editingConnection];
		} else {
			[self _saveConnectionList];

			unsigned index = [_connections indexOfObjectIdenticalTo:_editingConnection];
			if( index != NSNotFound )
				[_connectionsTable reloadCellAtRow:index column:0 animated:NO];
			else [_connectionsTable reloadData];
		}

		[_editingConnection release];
		_editingConnection = nil;
	}

	_newConnection = NO;
}

- (UIPreferencesTableCell *) preferencesTable:(UIPreferencesTable *) table cellForRow:(int) row inGroup:(int) group {
	[self _createPreferenceCellsIfNeeded];

	if( group == 0 ) {
		switch( row ) {
			case 0: return _serverCell;
			case 1: return _serverPortCell;
			case 2: return _sslCell;
			default: return nil;
		}
	}

	if( group == 1 ) {
		switch( row ) {
			case 0: return _realNameCell;
			case 1: return _nicknameCell;
			case 2: return _nicknamePasswordCell;
			case 3: return _alternateNicknamesCell;
			default: return nil;
		}
	}

	if( group == 2 ) {
		UIPreferencesTableCell *cell = [[UIPreferencesTableCell alloc] init];
		[cell setTitle:@"The nickname password is used to authenicate with NickServ."];
		return [cell autorelease];
	}

	if( group == 3 ) {
		switch( row ) {
			case 0: return _usernameCell;
			case 1: return _serverPasswordCell;
			default: return nil;
		}
	}

	if( group == 4 ) {
		switch( row ) {
			case 0: return _autoConnectCell;
			case 1: return _autoRoomsCell;
			default: return nil;
		}
	}

	return nil;  
}
*/

#pragma mark -

- (void) _loadConnectionList {
	if( [_connections count] )
		return; // already loaded connections

	NSArray *list = [[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatBookmarks"];
	for( NSMutableDictionary *info in list ) {
		MVChatConnectionType type = MVChatConnectionIRCType;
		if( [[info objectForKey:@"type"] isEqualToString:@"icb"] )
			type = MVChatConnectionICBType;
		else if( [[info objectForKey:@"type"] isEqualToString:@"irc"] )
			type = MVChatConnectionIRCType;
		else if( [[info objectForKey:@"type"] isEqualToString:@"silc"] )
			type = MVChatConnectionSILCType;
		else if( [[info objectForKey:@"type"] isEqualToString:@"xmpp"] )
			type = MVChatConnectionXMPPType;

		MVChatConnection *connection = nil;
		if( [info objectForKey:@"url"] )
			connection = [[MVChatConnection alloc] initWithURL:[NSURL URLWithString:[info objectForKey:@"url"]]];
		else connection = [[MVChatConnection alloc] initWithServer:[info objectForKey:@"server"] type:type port:[[info objectForKey:@"port"] unsignedShortValue] user:[info objectForKey:@"nickname"]];

		if( ! connection ) continue;

		NSMutableDictionary *persistentInformation = [[NSMutableDictionary alloc] init];
		if( [[info objectForKey:@"persistentInformation"] count] )
			[persistentInformation addEntriesFromDictionary:[info objectForKey:@"persistentInformation"]];

		NSMutableDictionary *extraInfo = [[NSMutableDictionary alloc] init];
		if( [info objectForKey:@"automatic"] )
			[extraInfo setObject:[info objectForKey:@"automatic"] forKey:@"automatic"];
		if( [info objectForKey:@"rooms"] )
			[extraInfo setObject:[info objectForKey:@"rooms"] forKey:@"rooms"];
		[persistentInformation setObject:extraInfo forKey:@"CQConnectionsControllerExtraInfo"];
		[extraInfo release];

		[connection setPersistentInformation:persistentInformation];
		[persistentInformation release];

		[connection setProxyType:[[info objectForKey:@"proxy"] unsignedLongValue]];
		[connection setSecure:[[info objectForKey:@"secure"] boolValue]];

		if( [[info objectForKey:@"encoding"] longValue] )
			[connection setEncoding:[[info objectForKey:@"encoding"] longValue]];
		else [connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];

		if( [info objectForKey:@"realName"] ) [connection setRealName:[info objectForKey:@"realName"]];
		if( [info objectForKey:@"nickname"] ) [connection setNickname:[info objectForKey:@"nickname"]];
		if( [info objectForKey:@"username"] ) [connection setUsername:[info objectForKey:@"username"]];
		if( [info objectForKey:@"alternateNicknames"] )
			[connection setAlternateNicknames:[info objectForKey:@"alternateNicknames"]];

/*
		NSString *password = nil;
		if( ( password = [info objectForKey:@"nicknamePassword"] ) )
			[PSKeychainUtilities setPassword:password forHost:[connection server] username:[connection preferredNickname] port:0 protocol:[connection urlScheme]];

		if( ( password = [info objectForKey:@"password"] ) )
			[PSKeychainUtilities setPassword:password forHost:[connection server] username:[connection username] port:[connection serverPort] protocol:[connection urlScheme]];

		if( ( password = [PSKeychainUtilities passwordForHost:[connection server] username:[connection preferredNickname] port:0 protocol:[connection urlScheme]] ) && [password length] )
			[connection setNicknamePassword:password];

		if( ( password = [PSKeychainUtilities passwordForHost:[connection server] username:[connection username] port:[connection serverPort] protocol:[connection urlScheme]] ) && [password length] )
			[connection setPassword:password];
*/

		[_connections addObject:connection];

		[connectionsViewController addConnection:connection];

		if( [[info objectForKey:@"automatic"] boolValue] )
			[connection connect];

		[connection release];
	}
}

- (void) _saveConnectionList {
	if( ! [_connections count] )
		return; // we have nothing to save

	NSMutableArray *saveList = [[NSMutableArray alloc] initWithCapacity:[_connections count]];

	for( MVChatConnection *connection in _connections ) {
		NSMutableDictionary *info = [NSMutableDictionary dictionary];

		NSDictionary *extraInfo = [[connection persistentInformation] objectForKey:@"CQConnectionsControllerExtraInfo"];
		[info addEntriesFromDictionary:extraInfo];

		[info setObject:[connection server] forKey:@"server"];
		[info setObject:[connection urlScheme] forKey:@"type"];
		[info setObject:[NSNumber numberWithBool:[connection isSecure]] forKey:@"secure"];
		[info setObject:[NSNumber numberWithLong:[connection proxyType]] forKey:@"proxy"];
		[info setObject:[NSNumber numberWithLong:[connection encoding]] forKey:@"encoding"];
		[info setObject:[NSNumber numberWithUnsignedShort:[connection serverPort]] forKey:@"port"];
		if( [connection realName] ) [info setObject:[connection realName] forKey:@"realName"];
		if( [connection username] ) [info setObject:[connection username] forKey:@"username"];
		if( [connection preferredNickname] ) [info setObject:[connection preferredNickname] forKey:@"nickname"];
		if( [[connection alternateNicknames] count] )
			[info setObject:[connection alternateNicknames] forKey:@"alternateNicknames"];

		if( [[connection persistentInformation] count] ) {
			NSMutableDictionary *persistentInformation = [[connection persistentInformation] mutableCopy];
			[persistentInformation removeObjectForKey:@"CQConnectionsControllerExtraInfo"];
			if( [persistentInformation count] )
				[info setObject:persistentInformation forKey:@"persistentInformation"];
			[persistentInformation release];
		}

		[saveList addObject:info];
	}

	[[NSUserDefaults standardUserDefaults] setObject:saveList forKey:@"MVChatBookmarks"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	[saveList release];
}

#pragma mark -

@synthesize connections = _connections;

- (NSArray *) connectedConnections {
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[_connections count]];

	for( MVChatConnection *connection in _connections )
		if( [connection isConnected] )
			[result addObject:connection];

	return result;
}

- (MVChatConnection *) connectionForServerAddress:(NSString *) address {
	NSArray *connections = [self connectionsForServerAddress:address];
	if( [connections count] )
		return [connections objectAtIndex:0];
	return nil;
}

- (NSArray *) connectionsForServerAddress:(NSString *) address {
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[_connections count]];

	address = [address stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". \t\n"]];

	for( MVChatConnection *connection in _connections ) {
		NSString *server = [connection server];
		NSRange range = [server rangeOfString:address options:( NSCaseInsensitiveSearch | NSLiteralSearch | NSBackwardsSearch | NSAnchoredSearch ) range:NSMakeRange( 0, [server length] )];
		if( range.location != NSNotFound && ( range.location == 0 || [server characterAtIndex:( range.location - 1 )] == '.' ) )
			[result addObject:connection];
	}

	return result;
}

- (BOOL) managesConnection:(MVChatConnection *) connection {
	return [_connections containsObject:connection];
}

#pragma mark -

- (void) addConnection:(MVChatConnection *) connection {
	[self insertConnection:connection atIndex:[_connections count]];
}

- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index {
    if( ! connection ) return;

	[_connections insertObject:connection atIndex:index];

	[connectionsViewController addConnection:connection];

	[self _saveConnectionList];
}

- (void) moveConnection:(MVChatConnection *) connection toIndex:(NSUInteger) newIndex {
	NSUInteger oldIndex = [_connections indexOfObjectIdenticalTo:connection];
	[self moveConnectionAtIndex:oldIndex toIndex:newIndex];
}

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	MVChatConnection *connection = [[_connections objectAtIndex:oldIndex] retain];

	[_connections removeObjectAtIndex:oldIndex];
	[_connections insertObject:connection atIndex:newIndex];

	[connection release];
}

- (void) removeConnection:(MVChatConnection *) connection {
	NSUInteger index = [_connections indexOfObjectIdenticalTo:connection];
	[self removeConnectionAtIndex:index];
}

- (void) removeConnectionAtIndex:(NSUInteger) index {
	MVChatConnection *connection = [[_connections objectAtIndex:index] retain];
    if( ! connection ) return;

	[connection disconnectWithReason:nil];

	[connectionsViewController removeConnection:connection];

	[connection release];

	[_connections removeObjectAtIndex:index];

	[self _saveConnectionList];
}

- (void) replaceConnection:(MVChatConnection *) previousConnection withConnection:(MVChatConnection *) newConnection {
	NSUInteger index = [_connections indexOfObjectIdenticalTo:previousConnection];
	[self replaceConnectionAtIndex:index withConnection:newConnection];	
}

- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection {
    if( ! connection ) return;

	MVChatConnection *oldConnection = [[_connections objectAtIndex:index] retain];
    if( ! oldConnection ) return;

	[oldConnection disconnectWithReason:nil];

	[connectionsViewController removeConnection:oldConnection];

	[oldConnection release];

	[_connections replaceObjectAtIndex:index withObject:connection];

	[connectionsViewController addConnection:connection];

	[self _saveConnectionList];
}
@end
