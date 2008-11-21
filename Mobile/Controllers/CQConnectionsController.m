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

	[self _loadConnectionList];

	return self;
}

- (void) dealloc {
	[_connections release];
	[_connectionsViewController release];
	[_editViewController release];
	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	if (!_connectionsViewController)
		_connectionsViewController = [[CQConnectionsViewController alloc] init];
	[self pushViewController:_connectionsViewController animated:NO];

	for (MVChatConnection *connection in _connections)
		[_connectionsViewController addConnection:connection];
}

#pragma mark -

- (void) didReceiveMemoryWarning {
	if( !_editViewController.view.superview ) {
		[_editViewController release];
		_editViewController = nil;
	}

	[super didReceiveMemoryWarning];
}

#pragma mark -

- (void) editConnection:(MVChatConnection *) connection {
	if( !_editViewController )
		_editViewController = [[CQConnectionEditViewController alloc] init];
	[_editViewController setConnection:connection];
	[self pushViewController:_editViewController animated:YES];
}

#pragma mark -

- (void) _deregisterNotificationsForConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionWillConnectNotification object:connection];
}

- (void) _registerNotificationsForConnection:(MVChatConnection *) connection {
	// Remove any previous observers, to prevent registering twice.
	[self _deregisterNotificationsForConnection:connection];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willConnect:) name:MVChatConnectionWillConnectNotification object:connection];
}

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	NSDictionary *extraInfo = [connection.persistentInformation objectForKey:@"CQConnectionsControllerExtraInfo"];

	NSArray *rooms = [extraInfo objectForKey:@"rooms"];
	if ([rooms count])
		[connection joinChatRoomsNamed:rooms];
}

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

		[self _registerNotificationsForConnection:connection];

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

	[_connectionsViewController addConnection:connection];

	[self _registerNotificationsForConnection:connection];

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

	[_connectionsViewController removeConnection:connection];

	[self _deregisterNotificationsForConnection:connection];

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

	[_connectionsViewController removeConnection:oldConnection];

	[self _deregisterNotificationsForConnection:oldConnection];

	[oldConnection release];

	[_connections replaceObjectAtIndex:index withObject:connection];

	[_connectionsViewController addConnection:connection];

	[self _registerNotificationsForConnection:connection];

	[self _saveConnectionList];
}
@end
