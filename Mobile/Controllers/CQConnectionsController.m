#import "CQConnectionsController.h"

#import "CQChatController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionCreationViewController.h"
#import "CQConnectionEditViewController.h"
#import "CQConnectionsViewController.h"
#import "CQKeychain.h"
#import "NSScannerAdditions.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>

@interface CQConnectionsController (CQConnectionsControllerPrivate)
- (void) _loadConnectionList;
@end

#pragma mark -

@implementation CQConnectionsController
+ (CQConnectionsController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQConnectionsController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	self.title = NSLocalizedString(@"Connections", @"Connections tab title");
	self.tabBarItem.image = [UIImage imageNamed:@"connections.png"];
	self.delegate = self;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willConnect:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnectOrDidNotConnect:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_errorOccurred:) name:MVChatConnectionErrorNotification object:nil];

	if (NSDebugEnabled)
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotRawConnectionMessage:) name:MVChatConnectionGotRawMessageNotification object:nil];

	_connections = [[NSMutableArray alloc] init];

	[self _loadConnectionList];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connections release];
	[_connectionsViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_connectionsViewController) {
		_connectionsViewController = [[CQConnectionsViewController alloc] init];

		for (MVChatConnection *connection in _connections)
			[_connectionsViewController addConnection:connection];
	}

	[self pushViewController:_connectionsViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[self popToRootViewControllerAnimated:NO];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	static BOOL offeredToCreate;
	if (!_connections.count && !offeredToCreate) {
		[self performSelector:@selector(showModalNewConnectionView) withObject:nil afterDelay:0.];
		offeredToCreate = YES;
	}
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return (UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

- (void) applicationWillTerminate {
	[self saveConnections];

	for (MVChatConnection *connection in _connections)
		[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
}

#pragma mark -

- (BOOL) handleOpenURL:(NSURL *) url {
	if ((![url.scheme isCaseInsensitiveEqualToString:@"irc"] && ![url.scheme isCaseInsensitiveEqualToString:@"ircs"]) || !url.host.length)
		return NO;

	NSString *target = @"";
	if (url.fragment.length) target = [@"#" stringByAppendingString:[url.fragment stringByDecodingIllegalURLCharacters]];
	else if (url.path.length > 1) target = [[url.path substringFromIndex:1] stringByDecodingIllegalURLCharacters];

	NSArray *possibleConnections = [self connectionsForServerAddress:url.host];

	for (MVChatConnection *connection in possibleConnections) {
		if (url.user.length && (![url.user isEqualToString:connection.preferredNickname] || ![url.user isEqualToString:connection.nickname]))
			continue;
		if ([url.port unsignedShortValue] && [url.port unsignedShortValue] != connection.serverPort)
			continue;

		[connection connect];

		if (target.length) {
			[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:target andConnection:connection];
			[connection joinChatRoomNamed:target];
		} else [CQColloquyApplication sharedApplication].tabBarController.selectedViewController = self;

		return YES;
	}

	if (url.user.length) {
		MVChatConnection *connection = [[MVChatConnection alloc] initWithURL:url];

		[self addConnection:connection];

		[connection connect];

		if (target.length) {
			[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:target andConnection:connection];
			[connection joinChatRoomNamed:target];
		} else [CQColloquyApplication sharedApplication].tabBarController.selectedViewController = self;

		[connection release];

		return YES;
	}

	[self showModalNewConnectionViewForURL:url];

	return YES;
}

- (void) showModalNewConnectionView {
	[self showModalNewConnectionViewForURL:nil];
}

- (void) showModalNewConnectionViewForURL:(NSURL *) url {
	CQConnectionCreationViewController *connectionCreationViewController = [[CQConnectionCreationViewController alloc] init];
	connectionCreationViewController.url = url;
	[self presentModalViewController:connectionCreationViewController animated:YES];
	[connectionCreationViewController release];
}

- (void) editConnection:(MVChatConnection *) connection {
	CQConnectionEditViewController *editViewController = [[CQConnectionEditViewController alloc] init];
	editViewController.connection = connection;

	_wasEditingConnection = YES;
	[self pushViewController:editViewController animated:YES];

	[editViewController release];
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == _connectionsViewController && _wasEditingConnection) {
		[self saveConnections];
		_wasEditingConnection = NO;
	}
}

#pragma mark -

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
- (void) _gotRawConnectionMessage:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	NSString *message = [[notification userInfo] objectForKey:@"message"];
	BOOL outbound = [[[notification userInfo] objectForKey:@"outbound"] boolValue];

	NSLog(@"%@: %@ %@", connection.server, (outbound ? @"<<" : @">>"), message);
}
#endif

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	++_connectingCount;

	[UIApplication sharedApplication].idleTimerDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQIdleTimerDisabled"];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	for (NSString *fullCommand in connection.automaticCommands) {
		NSScanner *scanner = [NSScanner scannerWithString:fullCommand];
		[scanner setCharactersToBeSkipped:nil];

		NSString *command = nil;
		NSString *arguments = nil;

		[scanner scanString:@"/" intoString:nil];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&command];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] maxLength:1 intoString:NULL];

		arguments = [fullCommand substringFromIndex:scanner.scanLocation];
		arguments = [arguments stringByReplacingOccurrencesOfString:@"%@" withString:connection.preferredNickname];

		[connection sendCommand:command withArguments:arguments];
	}

	NSMutableArray *rooms = [connection.automaticJoinedRooms mutableCopy];

	NSDictionary *persistentInformation = connection.persistentInformation;
	NSArray *previousRooms = [persistentInformation objectForKey:@"previousRooms"];

	if (previousRooms.count) {
		[rooms addObjectsFromArray:previousRooms];

		NSMutableDictionary *persistentInformation = [connection.persistentInformation mutableCopy];
		[persistentInformation removeObjectForKey:@"previousRooms"];
		connection.persistentInformation = persistentInformation;
		[persistentInformation release];
	}

	if (rooms.count)
		[connection joinChatRoomsNamed:rooms];

	[rooms release];
}

- (void) _didConnectOrDidNotConnect:(NSNotification *) notification {
	if (_connectingCount)
		--_connectingCount;
	if (!_connectingCount)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	if (!_connectedCount && !_connectingCount)
		[UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void) _didConnect:(NSNotification *) notification {
	++_connectedCount;

	[self _didConnectOrDidNotConnect:notification];
}

- (void) _didDisconnect:(NSNotification *) notification {
	if (_connectedCount)
		--_connectedCount;
	if (!_connectedCount && !_connectingCount)
		[UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void) _errorOccurred:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	NSError *error = [[notification userInfo] objectForKey:@"error"];

	NSString *errorTitle = nil;
	switch (error.code) {
		case MVChatConnectionRoomIsFullError:
		case MVChatConnectionInviteOnlyRoomError:
		case MVChatConnectionBannedFromRoomError:
		case MVChatConnectionRoomPasswordIncorrectError:
			errorTitle = NSLocalizedString(@"Can't Join Room", @"Can't join room alert title");
			break;
		case MVChatConnectionCantSendToRoomError:
			errorTitle = NSLocalizedString(@"Can't Send Message", @"Can't send message title");
			break;
	}

	NSString *roomName = [[error userInfo] objectForKey:@"room"];
	MVChatRoom *room = (roomName ? [connection chatRoomWithName:roomName] : nil);

	NSString *errorMessage = nil;
	switch (error.code) {
		case MVChatConnectionRoomIsFullError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The room \"%@\" on \"%@\" is full.", "Room is full alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionInviteOnlyRoomError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The room \"%@\" on \"%@\" is invite-only.", "Room is invite-only alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionBannedFromRoomError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"You are banned from \"%@\" on \"%@\".", "Banned from room alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionRoomPasswordIncorrectError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The room \"%@\" on \"%@\" is password protected, and you didn't supply the correct password.", "Room is full alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionCantSendToRoomError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't send messages to \"%@\" due to some room restriction.", "Cant send message alert"), room.displayName];
			break;
	}

	if (!errorMessage)
		errorMessage = error.localizedDescription;

	if (!errorTitle || !errorMessage) return;

	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;
	alert.title = errorTitle;
	alert.message = errorMessage;
	alert.cancelButtonIndex = 0;

	[alert addButtonWithTitle:NSLocalizedString(@"Close", @"Close alert button title")];

	[alert show];

	[alert release];
}

#pragma mark -

- (void) _loadConnectionList {
	if (_connections.count)
		return; // already loaded connections

	NSArray *list = [[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatBookmarks"];
	for (NSMutableDictionary *info in list) {
		MVChatConnectionType type = MVChatConnectionIRCType;
		if ([[info objectForKey:@"type"] isEqualToString:@"icb"])
			type = MVChatConnectionICBType;
		else if ([[info objectForKey:@"type"] isEqualToString:@"irc"])
			type = MVChatConnectionIRCType;
		else if ([[info objectForKey:@"type"] isEqualToString:@"silc"])
			type = MVChatConnectionSILCType;
		else if ([[info objectForKey:@"type"] isEqualToString:@"xmpp"])
			type = MVChatConnectionXMPPType;

		MVChatConnection *connection = nil;
		if ([info objectForKey:@"url"])
			connection = [[MVChatConnection alloc] initWithURL:[NSURL URLWithString:[info objectForKey:@"url"]]];
		else connection = [[MVChatConnection alloc] initWithServer:[info objectForKey:@"server"] type:type port:[[info objectForKey:@"port"] unsignedShortValue] user:[info objectForKey:@"nickname"]];

		if (!connection) continue;

		NSMutableDictionary *persistentInformation = [[NSMutableDictionary alloc] init];
		[persistentInformation addEntriesFromDictionary:[info objectForKey:@"persistentInformation"]];

		if ([info objectForKey:@"automatic"])
			[persistentInformation setObject:[info objectForKey:@"automatic"] forKey:@"automatic"];
		if ([info objectForKey:@"rooms"])
			[persistentInformation setObject:[info objectForKey:@"rooms"] forKey:@"rooms"];
		if ([info objectForKey:@"previousRooms"])
			[persistentInformation setObject:[info objectForKey:@"previousRooms"] forKey:@"previousRooms"];
		if ([info objectForKey:@"description"])
			[persistentInformation setObject:[info objectForKey:@"description"] forKey:@"description"];
		if ([info objectForKey:@"commands"] && ((NSString *)[info objectForKey:@"commands"]).length)
			[persistentInformation setObject:[[info objectForKey:@"commands"] componentsSeparatedByString:@"\n"] forKey:@"commands"];

		connection.persistentInformation = persistentInformation;

		[persistentInformation release];

		connection.proxyType = [[info objectForKey:@"proxy"] unsignedLongValue];
		connection.secure = [[info objectForKey:@"secure"] boolValue];

		connection.encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

		if ([info objectForKey:@"realName"]) connection.realName = [info objectForKey:@"realName"];
		if ([info objectForKey:@"nickname"]) connection.nickname = [info objectForKey:@"nickname"];
		if ([info objectForKey:@"username"]) connection.username = [info objectForKey:@"username"];
		if ([info objectForKey:@"alternateNicknames"])
			connection.alternateNicknames = [info objectForKey:@"alternateNicknames"];

		NSString *password = nil;
		if ((password = [info objectForKey:@"nicknamePassword"]))
			[[CQKeychain standardKeychain] setPassword:password forServer:connection.server account:connection.preferredNickname];

		if ((password = [info objectForKey:@"password"]))
			[[CQKeychain standardKeychain] setPassword:password forServer:connection.server account:nil];

		if ((password = [[CQKeychain standardKeychain] passwordForServer:connection.server account:connection.preferredNickname]) && password.length)
			connection.nicknamePassword = password;

		if ((password = [[CQKeychain standardKeychain] passwordForServer:connection.server account:nil]) && password.length)
			connection.password = password;

		[_connections addObject:connection];

		if ([info objectForKey:@"chatState"])
			[[CQChatController defaultController] restorePersistentState:[info objectForKey:@"chatState"] forConnection:connection];

		if ([[info objectForKey:@"automatic"] boolValue] || [[info objectForKey:@"wasConnected"] boolValue])
			[connection connect];

		[connection release];
	}
}

- (void) saveConnections {
	NSMutableArray *saveList = [[NSMutableArray alloc] initWithCapacity:_connections.count];

	for (MVChatConnection *connection in _connections) {
		NSMutableDictionary *info = [NSMutableDictionary dictionary];

		NSMutableDictionary *persistentInformation = [connection.persistentInformation mutableCopy];
		if ([persistentInformation objectForKey:@"automatic"])
			[info setObject:[persistentInformation objectForKey:@"automatic"] forKey:@"automatic"];
		if ([[persistentInformation objectForKey:@"rooms"] count])
			[info setObject:[persistentInformation objectForKey:@"rooms"] forKey:@"rooms"];
		if ([[persistentInformation objectForKey:@"description"] length])
			[info setObject:[persistentInformation objectForKey:@"description"] forKey:@"description"];
		if ([[persistentInformation objectForKey:@"commands"] count])
			[info setObject:[[persistentInformation objectForKey:@"commands"] componentsJoinedByString:@"\n"] forKey:@"commands"];

		[persistentInformation removeObjectForKey:@"rooms"];
		[persistentInformation removeObjectForKey:@"previousRooms"];
		[persistentInformation removeObjectForKey:@"commands"];
		[persistentInformation removeObjectForKey:@"description"];
		[persistentInformation removeObjectForKey:@"automatic"];

		NSDictionary *chatState = [[CQChatController defaultController] persistentStateForConnection:connection];
		if (chatState.count)
			[info setObject:chatState forKey:@"chatState"];

		if (persistentInformation.count)
			[info setObject:persistentInformation forKey:@"persistentInformation"];

		[persistentInformation release];

		[info setObject:[NSNumber numberWithBool:connection.connected] forKey:@"wasConnected"];

		NSSet *joinedRooms = connection.joinedChatRooms;
		if (connection.connected && joinedRooms.count) {
			NSMutableArray *previousJoinedRooms = [[NSMutableArray alloc] init];

			for (MVChatRoom *room in joinedRooms) {
				if (room && room.name)
					[previousJoinedRooms addObject:room.name];
			}

			[previousJoinedRooms removeObjectsInArray:[info objectForKey:@"rooms"]];

			if (previousJoinedRooms.count)
				[info setObject:previousJoinedRooms forKey:@"previousRooms"];

			[previousJoinedRooms release];
		}

		[info setObject:connection.server forKey:@"server"];
		[info setObject:connection.urlScheme forKey:@"type"];
		[info setObject:[NSNumber numberWithBool:connection.secure] forKey:@"secure"];
		[info setObject:[NSNumber numberWithLong:connection.proxyType] forKey:@"proxy"];
		[info setObject:[NSNumber numberWithLong:connection.encoding] forKey:@"encoding"];
		[info setObject:[NSNumber numberWithUnsignedShort:connection.serverPort] forKey:@"port"];
		if (connection.realName) [info setObject:connection.realName forKey:@"realName"];
		if (connection.username) [info setObject:connection.username forKey:@"username"];
		if (connection.preferredNickname) [info setObject:connection.preferredNickname forKey:@"nickname"];

		if (connection.alternateNicknames.count)
			[info setObject:connection.alternateNicknames forKey:@"alternateNicknames"];

		[saveList addObject:info];
	}

	[[NSUserDefaults standardUserDefaults] setObject:saveList forKey:@"MVChatBookmarks"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	[saveList release];
}

#pragma mark -

@synthesize connections = _connections;

- (NSArray *) connectedConnections {
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:_connections.count];

	for (MVChatConnection *connection in _connections)
		if (connection.connected)
			[result addObject:connection];

	return result;
}

- (MVChatConnection *) connectionForServerAddress:(NSString *) address {
	NSArray *connections = [self connectionsForServerAddress:address];
	if (connections.count)
		return [connections objectAtIndex:0];
	return nil;
}

- (NSArray *) connectionsForServerAddress:(NSString *) address {
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:_connections.count];

	address = [address stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". \t\n"]];

	for (MVChatConnection *connection in _connections) {
		NSString *server = connection.server;
		NSRange range = [server rangeOfString:address options:(NSCaseInsensitiveSearch | NSLiteralSearch | NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, server.length)];
		if (range.location != NSNotFound && (range.location == 0 || [server characterAtIndex:(range.location - 1)] == '.'))
			[result addObject:connection];
	}

	return result;
}

- (BOOL) managesConnection:(MVChatConnection *) connection {
	return [_connections containsObject:connection];
}

#pragma mark -

- (void) addConnection:(MVChatConnection *) connection {
	[self insertConnection:connection atIndex:_connections.count];
}

- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index {
	if (!connection) return;

	if (!_connections.count) {
		[[NSUserDefaults standardUserDefaults] setObject:connection.nickname forKey:@"CQDefaultNickname"];
		[[NSUserDefaults standardUserDefaults] setObject:connection.realName forKey:@"CQDefaultRealName"];
	}

	[_connections insertObject:connection atIndex:index];

	[_connectionsViewController addConnection:connection];

	[self saveConnections];
}

- (void) moveConnection:(MVChatConnection *) connection toIndex:(NSUInteger) newIndex {
	NSUInteger oldIndex = [_connections indexOfObjectIdenticalTo:connection];
	if (oldIndex != NSNotFound)
		[self moveConnectionAtIndex:oldIndex toIndex:newIndex];
}

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	MVChatConnection *connection = [[_connections objectAtIndex:oldIndex] retain];

	[_connections removeObjectAtIndex:oldIndex];
	[_connections insertObject:connection atIndex:newIndex];

	[connection release];

	[self saveConnections];
}

- (void) removeConnection:(MVChatConnection *) connection {
	NSUInteger index = [_connections indexOfObjectIdenticalTo:connection];
	if (index != NSNotFound)
		[self removeConnectionAtIndex:index];
}

- (void) removeConnectionAtIndex:(NSUInteger) index {
	MVChatConnection *connection = [[_connections objectAtIndex:index] retain];
	if (!connection) return;

	[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];

	[_connectionsViewController removeConnection:connection];

	[connection release];

	[_connections removeObjectAtIndex:index];

	[self saveConnections];
}

- (void) replaceConnection:(MVChatConnection *) previousConnection withConnection:(MVChatConnection *) newConnection {
	NSUInteger index = [_connections indexOfObjectIdenticalTo:previousConnection];
	if (index != NSNotFound)
		[self replaceConnectionAtIndex:index withConnection:newConnection];
}

- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection {
	if (!connection) return;

	MVChatConnection *oldConnection = [[_connections objectAtIndex:index] retain];
	if (!oldConnection) return;

	[oldConnection disconnectWithReason:[MVChatConnection defaultQuitMessage]];

	[_connectionsViewController removeConnection:oldConnection];

	[oldConnection release];

	[_connections replaceObjectAtIndex:index withObject:connection];

	[_connectionsViewController addConnection:connection];

	[self saveConnections];
}
@end

#pragma mark -

@implementation MVChatConnection (CQConnectionsControllerAdditions)
+ (NSString *) defaultNickname {
	NSString *defaultNickname = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQDefaultNickname"];
	if (defaultNickname.length)
		return defaultNickname;

#if TARGET_IPHONE_SIMULATOR
	return NSUserName();
#else
	static NSString *generatedNickname;
	if (!generatedNickname) {
		NSArray *components = [[UIDevice currentDevice].name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		for (NSString *compontent in components) {
			if ([compontent isCaseInsensitiveEqualToString:@"iPhone"] || [compontent isCaseInsensitiveEqualToString:@"iPod"])
				continue;
			if ([compontent isEqualToString:@"3G"] || [compontent isCaseInsensitiveEqualToString:@"Touch"])
				continue;
			if ([compontent hasCaseInsensitiveSuffix:@"'s"])
				compontent = [compontent substringWithRange:NSMakeRange(0, (compontent.length - 2))];
			if (!compontent.length)
				continue;
			generatedNickname = [compontent copy];
			break;
		}
	}

	if (generatedNickname.length)
		return generatedNickname;

	return NSLocalizedString(@"ColloquyUser", @"Default nickname");
#endif
}

+ (NSString *) defaultRealName {
	NSString *defaultRealName = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQDefaultRealName"];
	if (defaultRealName.length)
		return defaultRealName;

#if TARGET_IPHONE_SIMULATOR
	return NSFullUserName();
#else
	static NSString *generatedRealName;
	if (!generatedRealName) {
		// This might only work for English users, but it is fine for now.
		NSString *deviceName = [UIDevice currentDevice].name;
		NSRange range = [deviceName rangeOfString:@"'s" options:NSLiteralSearch];
		if (range.location != NSNotFound)
			generatedRealName = [[deviceName substringToIndex:range.location] copy];
	}

	if (generatedRealName.length)
		return generatedRealName;
#endif

	return NSLocalizedString(@"Colloquy User", @"Default real name");
}

+ (NSString *) defaultQuitMessage {
	return [[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"];
}

+ (NSStringEncoding) defaultEncoding {
	return [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
}

#pragma mark -

- (void) setDisplayName:(NSString *) name {
	NSParameterAssert(name != nil);

	NSMutableDictionary *persistentInformation = [self.persistentInformation mutableCopy];
	[persistentInformation setObject:name forKey:@"description"];
	self.persistentInformation = persistentInformation;
	[persistentInformation release];
}

- (NSString *) displayName {
	NSString *name = [self.persistentInformation objectForKey:@"description"];
	if (!name.length)
		return self.server;
	return [self.persistentInformation objectForKey:@"description"];
}

#pragma mark -

- (void) setAutomaticJoinedRooms:(NSArray *) rooms {
	NSParameterAssert(rooms != nil);

	NSMutableDictionary *persistentInformation = [self.persistentInformation mutableCopy];
	[persistentInformation setObject:rooms forKey:@"rooms"];
	self.persistentInformation = persistentInformation;
	[persistentInformation release];
}

- (NSArray *) automaticJoinedRooms {
	return [self.persistentInformation objectForKey:@"rooms"];
}

#pragma mark -

- (void) setAutomaticCommands:(NSArray *) commands {
	NSParameterAssert(commands != nil);

	NSMutableDictionary *persistentInformation = [self.persistentInformation mutableCopy];
	[persistentInformation setObject:commands forKey:@"commands"];
	self.persistentInformation = persistentInformation;
	[persistentInformation release];
}

- (NSArray *) automaticCommands {
	return [self.persistentInformation objectForKey:@"commands"];
}

#pragma mark -

- (void) setAutomaticallyConnect:(BOOL) autoConnect {
	NSMutableDictionary *persistentInformation = [self.persistentInformation mutableCopy];
	[persistentInformation setObject:[NSNumber numberWithBool:autoConnect] forKey:@"automatic"];
	self.persistentInformation = persistentInformation;
	[persistentInformation release];
}

- (BOOL) automaticallyConnect {
	return [[self.persistentInformation objectForKey:@"automatic"] boolValue];
}
@end
