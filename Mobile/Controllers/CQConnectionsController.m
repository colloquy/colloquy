#import "CQConnectionsController.h"

#import "CQBouncerSettings.h"
#import "CQBouncerConnection.h"
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_deviceTokenRecieved:) name:CQColloquyApplicationDidRecieveDeviceTokenNotification object:nil];

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotRawConnectionMessage:) name:MVChatConnectionGotRawMessageNotification object:nil];
#endif

	_connections = [[NSMutableSet alloc] initWithCapacity:10];
	_bouncers = [[NSMutableArray alloc] initWithCapacity:2];
	_directConnections = [[NSMutableArray alloc] initWithCapacity:5];
	_bouncerConnections = [[NSMutableSet alloc] initWithCapacity:2];
	_bouncerChatConnections = [[NSMutableDictionary alloc] initWithCapacity:2];

	[self _loadConnectionList];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connections release];
	[_directConnections release];
	[_bouncerConnections release];
	[_bouncerChatConnections release];
	[_connectionsViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_connectionsViewController)
		return;

	_connectionsViewController = [[CQConnectionsViewController alloc] init];

	for (MVChatConnection *connection in _directConnections)
		[_connectionsViewController addConnection:connection];

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

- (void) bouncerConnection:(CQBouncerConnection *) connection didRecieveConnectionInfo:(NSDictionary *) info {
	NSMutableArray *connections = [_bouncerChatConnections objectForKey:connection.settings.identifier];
	if (!connections) {
		connections = [[NSMutableArray alloc] initWithCapacity:5];
		[_bouncerChatConnections setObject:connections forKey:connection.settings.identifier];
		[connections release];
	}

	NSString *connectionIdentifier = [info objectForKey:@"connectionIdentifier"];
	if (!connectionIdentifier.length)
		return;

	MVChatConnection *chatConnection = nil;
	for (MVChatConnection *currentChatConnection in connections) {
		if ([currentChatConnection.bouncerConnectionIdentifier isEqualToString:connectionIdentifier]) {
			chatConnection = currentChatConnection;
			break;
		}
	}

	if (!chatConnection) {
		chatConnection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];
		chatConnection.bouncerConnectionIdentifier = connectionIdentifier;

		[connections addObject:chatConnection];
		[_connections addObject:chatConnection];

		[_connectionsViewController addConnection:chatConnection forBouncerIdentifier:connection.settings.identifier];
	}

	chatConnection.bouncerSettings = connection.settings;

	chatConnection.server = [info objectForKey:@"serverAddress"];
	chatConnection.serverPort = [[info objectForKey:@"serverPort"] unsignedShortValue];
	chatConnection.preferredNickname = [info objectForKey:@"nickname"];
	chatConnection.nicknamePassword = [info objectForKey:@"nicknamePassword"];
	chatConnection.username = [info objectForKey:@"username"];
	chatConnection.password = [info objectForKey:@"password"];
	chatConnection.secure = [[info objectForKey:@"secure"] boolValue];
	chatConnection.alternateNicknames = [info objectForKey:@"alternateNicknames"];
	chatConnection.encoding = [[info objectForKey:@"encoding"] unsignedIntegerValue];
}

- (void) bouncerConnectionDidFinishConnectionList:(CQBouncerConnection *) connection {

}

- (void) bouncerConnectionDidDisconnect:(CQBouncerConnection *) connection {
	[_bouncerConnections removeObject:connection];
}

#pragma mark -

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
- (void) _gotRawConnectionMessage:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	NSString *message = [[notification userInfo] objectForKey:@"message"];
	BOOL outbound = [[[notification userInfo] objectForKey:@"outbound"] boolValue];

	if (connection.bouncerType == MVChatConnectionColloquyBouncer)
		NSLog(@"%@ (via %@): %@ %@", connection.server, connection.bouncerServer, (outbound ? @"<<" : @">>"), message);
	else NSLog(@"%@: %@ %@", connection.server, (outbound ? @"<<" : @">>"), message);
}
#endif

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	++_connectingCount;

	[UIApplication sharedApplication].idleTimerDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQIdleTimerDisabled"];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	NSMutableArray *rooms = [connection.automaticJoinedRooms mutableCopy];

	NSArray *previousRooms = [connection persistentInformationObjectForKey:@"previousRooms"];
	if (previousRooms.count) {
		[rooms addObjectsFromArray:previousRooms];
		[connection removePersistentInformationObjectForKey:@"previousRooms"];
	}

	[connection sendPushNotificationCommands];

	if (connection.bouncerType == MVChatConnectionColloquyBouncer) {
		connection.bouncerDeviceIdentifier = [UIDevice currentDevice].uniqueIdentifier;

		[connection sendRawMessageWithFormat:@"BOUNCER set encoding %u", connection.encoding];

		if (connection.nicknamePassword.length)
			[connection sendRawMessageWithFormat:@"BOUNCER set nick-password :%@", connection.nicknamePassword];
		else [connection sendRawMessage:@"BOUNCER set nick-password"];

		if (connection.alternateNicknames.count) {
			NSString *nicks = [connection.alternateNicknames componentsJoinedByString:@" "];
			[connection sendRawMessageWithFormat:@"BOUNCER set alt-nicks %@", nicks];
		} else [connection sendRawMessage:@"BOUNCER set alt-nicks"];

		[connection sendRawMessage:@"BOUNCER autocommands clear"];

		if (connection.automaticCommands.count && rooms.count)
			[connection sendRawMessage:@"BOUNCER autocommands start"];
	}

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

	if (rooms.count)
		[connection joinChatRoomsNamed:rooms];

	if (connection.bouncerType == MVChatConnectionColloquyBouncer && connection.automaticCommands.count && rooms.count)
		[connection sendRawMessage:@"BOUNCER autocommands stop"];

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

- (void) _deviceTokenRecieved:(NSNotification *) notification {
	for (MVChatConnection *connection in _connections) {
		if (!connection.pushNotifications || !connection.connected)
			continue;
		[connection sendPushNotificationCommands]; 
	}
}

- (void) _errorOccurred:(NSNotification *) notification {
	NSError *error = [[notification userInfo] objectForKey:@"error"];

	NSString *errorTitle = nil;
	switch (error.code) {
		case MVChatConnectionRoomIsFullError:
		case MVChatConnectionInviteOnlyRoomError:
		case MVChatConnectionBannedFromRoomError:
		case MVChatConnectionRoomPasswordIncorrectError:
		case MVChatConnectionIdentifyToJoinRoomError:
			errorTitle = NSLocalizedString(@"Can't Join Room", @"Can't join room alert title");
			break;
		case MVChatConnectionCantSendToRoomError:
			errorTitle = NSLocalizedString(@"Can't Send Message", @"Can't send alert title");
			break;
		case MVChatConnectionCantChangeUsedNickError:
			errorTitle = NSLocalizedString(@"Nickname in use", "Nickname in use alert title");
			break;
		case MVChatConnectionCantChangeNickError:
			errorTitle = NSLocalizedString(@"Can't Change Nickname", "Can't change nickname alert title");
			break;
		case MVChatConnectionRoomDoesNotSupportModesError:
			errorTitle = NSLocalizedString(@"Room Modes Unsupported", "Room modes not supported alert title");
			break;
		case MVChatConnectionNickChangedByServicesError:
			errorTitle = NSLocalizedString(@"Nickname Changed", "Nick changed by server alert title");
			break;
	}

	if (!errorTitle) return;

	MVChatConnection *connection = notification.object;
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
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't send messages to \"%@\" due to some room restriction.", "Cant send message alert message"), room.displayName];
			break;
		case MVChatConnectionRoomDoesNotSupportModesError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The room \"%@\" on \"%@\" doesn't support modes.", "Room does not support modes alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionIdentifyToJoinRoomError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Identify with network services to join \"%@\" on \"%@\".", "Identify to join room alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionCantChangeNickError:
			if (room) errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't change your nickname while in \"%@\" on \"%@\". Leave the room and try again.", "Can't change nick because of room alert message" ), room.displayName, connection.displayName];
			else errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't change nicknames too fast on \"%@\", wait and try again.", "Can't change nick too fast alert message"), connection.displayName];
			break;
		case MVChatConnectionCantChangeUsedNickError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Services won't let you change your nickname to \"%@\" on \"%@\".", "Services won't let you change your nickname alert message"), [[error userInfo] objectForKey:@"newnickname"], connection.displayName];
			break;
		case MVChatConnectionNickChangedByServicesError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Your nickname is being changed on \"%@\" because you didn't identify.", "Username was changed by server alert message"), connection.displayName];
			break;
	}

	if (!errorMessage)
		errorMessage = error.localizedDescription;

	if (!errorMessage) return;

	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;
	alert.title = errorTitle;
	alert.message = errorMessage;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	[alert show];

	[alert release];
}

#pragma mark -

- (MVChatConnection *) _chatConnectionWithDictionaryRepresentation:(NSDictionary *) info {
	MVChatConnection *connection = nil;

	MVChatConnectionType type = MVChatConnectionIRCType;
	if ([[info objectForKey:@"type"] isEqualToString:@"icb"])
		type = MVChatConnectionICBType;
	else if ([[info objectForKey:@"type"] isEqualToString:@"irc"])
		type = MVChatConnectionIRCType;
	else if ([[info objectForKey:@"type"] isEqualToString:@"silc"])
		type = MVChatConnectionSILCType;
	else if ([[info objectForKey:@"type"] isEqualToString:@"xmpp"])
		type = MVChatConnectionXMPPType;

	if ([info objectForKey:@"url"])
		connection = [[MVChatConnection alloc] initWithURL:[NSURL URLWithString:[info objectForKey:@"url"]]];
	else connection = [[MVChatConnection alloc] initWithServer:[info objectForKey:@"server"] type:type port:[[info objectForKey:@"port"] unsignedShortValue] user:[info objectForKey:@"nickname"]];

	if (!connection)
		return nil;

	if ([info objectForKey:@"uniqueIdentifier"]) connection.uniqueIdentifier = [info objectForKey:@"uniqueIdentifier"];

	NSMutableDictionary *persistentInformation = [[NSMutableDictionary alloc] init];
	[persistentInformation addEntriesFromDictionary:[info objectForKey:@"persistentInformation"]];

	if ([info objectForKey:@"automatic"])
		[persistentInformation setObject:[info objectForKey:@"automatic"] forKey:@"automatic"];
	if ([info objectForKey:@"push"])
		[persistentInformation setObject:[info objectForKey:@"push"] forKey:@"push"];
	if ([info objectForKey:@"rooms"])
		[persistentInformation setObject:[info objectForKey:@"rooms"] forKey:@"rooms"];
	if ([info objectForKey:@"previousRooms"])
		[persistentInformation setObject:[info objectForKey:@"previousRooms"] forKey:@"previousRooms"];
	if ([info objectForKey:@"description"])
		[persistentInformation setObject:[info objectForKey:@"description"] forKey:@"description"];
	if ([info objectForKey:@"commands"] && ((NSString *)[info objectForKey:@"commands"]).length)
		[persistentInformation setObject:[[info objectForKey:@"commands"] componentsSeparatedByString:@"\n"] forKey:@"commands"];
	if ([info objectForKey:@"bouncer"])
		[persistentInformation setObject:[info objectForKey:@"bouncer"] forKey:@"bouncerIdentifier"];

	connection.persistentInformation = persistentInformation;

	[persistentInformation release];

	connection.proxyType = [[info objectForKey:@"proxy"] unsignedLongValue];
	connection.secure = [[info objectForKey:@"secure"] boolValue];

	if ([[info objectForKey:@"encoding"] unsignedLongValue])
		connection.encoding = [[info objectForKey:@"encoding"] unsignedLongValue];
	else connection.encoding = [MVChatConnection defaultEncoding];

	if (!CFStringIsEncodingAvailable(CFStringConvertNSStringEncodingToEncoding(connection.encoding)))
		connection.encoding = [MVChatConnection defaultEncoding];

	if ([info objectForKey:@"realName"]) connection.realName = [info objectForKey:@"realName"];
	if ([info objectForKey:@"nickname"]) connection.nickname = [info objectForKey:@"nickname"];
	if ([info objectForKey:@"username"]) connection.username = [info objectForKey:@"username"];
	if ([info objectForKey:@"alternateNicknames"])
		connection.alternateNicknames = [info objectForKey:@"alternateNicknames"];

	NSString *password = nil;
	if ((password = [info objectForKey:@"nicknamePassword"]))
		[[CQKeychain standardKeychain] setPassword:password forServer:connection.server account:connection.preferredNickname];

	if ((password = [info objectForKey:@"password"]))
		[[CQKeychain standardKeychain] setPassword:password forServer:connection.server account:@"<<server password>>"];

	if ((password = [[CQKeychain standardKeychain] passwordForServer:connection.server account:connection.preferredNickname]) && password.length)
		connection.nicknamePassword = password;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:connection.server account:@"<<server password>>"]) && password.length)
		connection.password = password;

	CQBouncerSettings *bouncerSettings = [self bouncerSettingsForIdentifier:connection.bouncerIdentifier];
	if (bouncerSettings) {
		connection.bouncerType = bouncerSettings.type;
		connection.bouncerServer = bouncerSettings.server;
		connection.bouncerServerPort = bouncerSettings.serverPort;
		connection.bouncerUsername = bouncerSettings.username;
		connection.bouncerPassword = bouncerSettings.password;
	}

	return [connection autorelease];
}

- (NSMutableDictionary *) _dictionaryRepresentationForConnection:(MVChatConnection *) connection {
	NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:15];

	NSMutableDictionary *persistentInformation = [connection.persistentInformation mutableCopy];
	if ([persistentInformation objectForKey:@"automatic"])
		[info setObject:[persistentInformation objectForKey:@"automatic"] forKey:@"automatic"];
	if ([persistentInformation objectForKey:@"push"])
		[info setObject:[persistentInformation objectForKey:@"push"] forKey:@"push"];
	if ([[persistentInformation objectForKey:@"rooms"] count])
		[info setObject:[persistentInformation objectForKey:@"rooms"] forKey:@"rooms"];
	if ([[persistentInformation objectForKey:@"description"] length])
		[info setObject:[persistentInformation objectForKey:@"description"] forKey:@"description"];
	if ([[persistentInformation objectForKey:@"commands"] count])
		[info setObject:[[persistentInformation objectForKey:@"commands"] componentsJoinedByString:@"\n"] forKey:@"commands"];
	if ([persistentInformation objectForKey:@"bouncerIdentifier"])
		[info setObject:[persistentInformation objectForKey:@"bouncerIdentifier"] forKey:@"bouncer"];

	[persistentInformation removeObjectForKey:@"automatic"];
	[persistentInformation removeObjectForKey:@"push"];
	[persistentInformation removeObjectForKey:@"rooms"];
	[persistentInformation removeObjectForKey:@"previousRooms"];
	[persistentInformation removeObjectForKey:@"description"];
	[persistentInformation removeObjectForKey:@"commands"];
	[persistentInformation removeObjectForKey:@"bouncerIdentifier"];

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
			if (room && room.name && !(room.modes & MVChatRoomInviteOnlyMode))
				[previousJoinedRooms addObject:room.name];
		}

		[previousJoinedRooms removeObjectsInArray:[info objectForKey:@"rooms"]];

		if (previousJoinedRooms.count)
			[info setObject:previousJoinedRooms forKey:@"previousRooms"];

		[previousJoinedRooms release];
	}

	[info setObject:connection.uniqueIdentifier forKey:@"uniqueIdentifier"];
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

	return [info autorelease];
}

- (void) _loadConnectionList {
	if (_loadedConnections)
		return;

	_loadedConnections = YES;

	NSArray *bouncers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"CQChatBouncers"];
	for (NSDictionary *info in bouncers) {
		CQBouncerSettings *settings = [[CQBouncerSettings alloc] initWithDictionaryRepresentation:info];
		if (settings) [_bouncers addObject:settings];
		[settings release];
	}

	NSArray *list = [[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatBookmarks"];
	for (NSDictionary *info in list) {
		MVChatConnection *connection = [self _chatConnectionWithDictionaryRepresentation:info];
		if (!connection)
			continue;

		[_directConnections addObject:connection];
		[_connections addObject:connection];

		if ([info objectForKey:@"chatState"])
			[[CQChatController defaultController] restorePersistentState:[info objectForKey:@"chatState"] forConnection:connection];

		[connection release];
	}

	[self performSelector:@selector(_connectAutomaticConnections) withObject:nil afterDelay:2.];

	if (_bouncers.count)
		[self performSelector:@selector(_refreshBouncerConnectionLists) withObject:nil afterDelay:2.];
}

- (void) _connectAutomaticConnections {
	for (MVChatConnection *connection in _connections)
		if (connection.automaticallyConnect)
			[connection connect];
}

- (void) _refreshBouncerConnectionLists {
	[_bouncerConnections removeAllObjects];

	for (CQBouncerSettings *settings in _bouncers) {
		CQBouncerConnection *connection = [[CQBouncerConnection alloc] initWithBouncerSettings:settings];
		[_bouncerConnections addObject:connection];

		connection.delegate = self;
		[connection connect];

		[connection release];
	}
}

- (void) saveConnections {
	if (!_loadedConnections)
		return;

	NSMutableArray *connections = [[NSMutableArray alloc] initWithCapacity:_directConnections.count];
	for (MVChatConnection *connection in _directConnections) {
		NSMutableDictionary *info = [self _dictionaryRepresentationForConnection:connection];
		if (info) [connections addObject:info];
	}

	NSMutableArray *bouncers = [[NSMutableArray alloc] initWithCapacity:_bouncers.count];
	for (CQBouncerSettings *settings in _bouncers) {
		NSMutableDictionary *info = [settings dictionaryRepresentation];
		if (!info)
			continue;

		NSMutableArray *bouncerConnections = [[NSMutableArray alloc] initWithCapacity:10];
		for (MVChatConnection *connection in [self bouncerChatConnectionsForIdentifier:settings.identifier]) {
			NSMutableDictionary *connectionInfo = [self _dictionaryRepresentationForConnection:connection];
			if (connectionInfo) [bouncerConnections addObject:connectionInfo];
		}

		if (bouncerConnections.count) [info setObject:bouncerConnections forKey:@"connections"];
		[bouncerConnections release];

		[bouncers addObject:info];
	}

	[[NSUserDefaults standardUserDefaults] setObject:bouncers forKey:@"CQChatBouncers"];
	[[NSUserDefaults standardUserDefaults] setObject:connections forKey:@"MVChatBookmarks"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	[bouncers release];
	[connections release];
}

#pragma mark -

@synthesize connections = _connections;
@synthesize directConnections = _directConnections;
@synthesize bouncers = _bouncers;

- (NSSet *) connectedConnections {
	NSMutableSet *result = [[NSMutableSet alloc] initWithCapacity:_connections.count];

	for (MVChatConnection *connection in _connections)
		if (connection.connected)
			[result addObject:connection];

	return [result autorelease];
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
		if (!connection.connected)
			continue;
		NSString *server = connection.server;
		NSRange range = [server rangeOfString:address options:(NSCaseInsensitiveSearch | NSLiteralSearch | NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, server.length)];
		if (range.location != NSNotFound && (range.location == 0 || [server characterAtIndex:(range.location - 1)] == '.'))
			[result addObject:connection];
	}

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
	[self insertConnection:connection atIndex:_directConnections.count];
}

- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index {
	if (!connection) return;

	if (!_directConnections.count) {
		[[NSUserDefaults standardUserDefaults] setObject:connection.nickname forKey:@"CQDefaultNickname"];
		[[NSUserDefaults standardUserDefaults] setObject:connection.realName forKey:@"CQDefaultRealName"];
	}

	[_directConnections insertObject:connection atIndex:index];
	[_connections addObject:connection];

	[_connectionsViewController addConnection:connection];

	[self saveConnections];
}

- (void) moveConnection:(MVChatConnection *) connection toIndex:(NSUInteger) newIndex {
	NSUInteger oldIndex = [_directConnections indexOfObjectIdenticalTo:connection];
	if (oldIndex != NSNotFound)
		[self moveConnectionAtIndex:oldIndex toIndex:newIndex];
}

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	MVChatConnection *connection = [[_directConnections objectAtIndex:oldIndex] retain];

	[_directConnections removeObjectAtIndex:oldIndex];
	[_directConnections insertObject:connection atIndex:newIndex];

	[connection release];

	[self saveConnections];
}

- (void) removeConnection:(MVChatConnection *) connection {
	NSUInteger index = [_directConnections indexOfObjectIdenticalTo:connection];
	if (index != NSNotFound)
		[self removeConnectionAtIndex:index];
}

- (void) removeConnectionAtIndex:(NSUInteger) index {
	MVChatConnection *connection = [[_directConnections objectAtIndex:index] retain];
	if (!connection) return;

	[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];

	[_connectionsViewController removeConnection:connection];

	[_directConnections removeObjectAtIndex:index];
	[_connections removeObject:connection];

	[connection release];

	[self saveConnections];
}

- (void) replaceConnection:(MVChatConnection *) previousConnection withConnection:(MVChatConnection *) newConnection {
	NSUInteger index = [_directConnections indexOfObjectIdenticalTo:previousConnection];
	if (index != NSNotFound)
		[self replaceConnectionAtIndex:index withConnection:newConnection];
}

- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection {
	if (!connection) return;

	MVChatConnection *oldConnection = [[_directConnections objectAtIndex:index] retain];
	if (!oldConnection) return;

	[oldConnection disconnectWithReason:[MVChatConnection defaultQuitMessage]];

	[_connectionsViewController removeConnection:oldConnection];

	[_directConnections replaceObjectAtIndex:index withObject:connection];
	[_connections removeObject:oldConnection];
	[_connections addObject:connection];

	[_connectionsViewController addConnection:connection];

	[oldConnection release];

	[self saveConnections];
}

#pragma mark -

- (CQBouncerSettings *) bouncerSettingsForIdentifier:(NSString *) identifier {
	for (CQBouncerSettings *bouncer in _bouncers)
		if ([bouncer.identifier isEqualToString:identifier])
			return bouncer;
	return nil;
}

- (NSArray *) bouncerChatConnectionsForIdentifier:(NSString *) identifier {
	return [_bouncerChatConnections objectForKey:identifier];
}

- (void) addBouncerSettings:(CQBouncerSettings *) bouncer {
	NSParameterAssert(bouncer != nil);
	[_bouncers addObject:bouncer];
}

- (void) removeBouncerSettings:(CQBouncerSettings *) settings {
	[self removeBouncerSettingsAtIndex:[_bouncers indexOfObjectIdenticalTo:settings]];
}

- (void) removeBouncerSettingsAtIndex:(NSUInteger) index {
	[_bouncers removeObjectAtIndex:index];
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
		NSCharacterSet *badCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"] invertedSet];
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
			generatedNickname = [[compontent stringByReplacingCharactersInSet:badCharacters withString:@""] copy];
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

+ (NSString *) defaultUsernameWithNickname:(NSString *) nickname {
	NSCharacterSet *badCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz"] invertedSet];
	NSString *username = [[nickname lowercaseString] stringByReplacingCharactersInSet:badCharacters withString:@""];
	if (username.length)
		return username;
	return @"mobile";
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

	if ([name isEqualToString:self.displayName])
		return;

	[self setPersistentInformationObject:name forKey:@"description"];
}

- (NSString *) displayName {
	NSString *name = [self persistentInformationObjectForKey:@"description"];
	if (!name.length)
		return self.server;
	return name;
}

#pragma mark -

- (void) setAutomaticJoinedRooms:(NSArray *) rooms {
	NSParameterAssert(rooms != nil);

	[self setPersistentInformationObject:rooms forKey:@"rooms"];
}

- (NSArray *) automaticJoinedRooms {
	return [self persistentInformationObjectForKey:@"rooms"];
}

#pragma mark -

- (void) setAutomaticCommands:(NSArray *) commands {
	NSParameterAssert(commands != nil);

	[self setPersistentInformationObject:commands forKey:@"commands"];
}

- (NSArray *) automaticCommands {
	return [self persistentInformationObjectForKey:@"commands"];
}

#pragma mark -

- (void) setAutomaticallyConnect:(BOOL) autoConnect {
	if (autoConnect == self.automaticallyConnect)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:autoConnect] forKey:@"automatic"];
}

- (BOOL) automaticallyConnect {
	return [[self persistentInformationObjectForKey:@"automatic"] boolValue];
}

#pragma mark -

- (void) setPushNotifications:(BOOL) push {
	if (push == self.pushNotifications)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:push] forKey:@"push"];

	if (!self.connected && self.status != MVChatConnectionConnectingStatus)
		return;

	[self sendPushNotificationCommands];
}

- (BOOL) pushNotifications {
	return [[self persistentInformationObjectForKey:@"push"] boolValue];
}

#pragma mark -

- (void) setBouncerSettings:(CQBouncerSettings *) settings {
	if (settings.identifier == self.bouncerIdentifier)
		return;
	self.bouncerIdentifier = settings.identifier;
}

- (CQBouncerSettings *) bouncerSettings {
	return [[CQConnectionsController defaultController] bouncerSettingsForIdentifier:self.bouncerIdentifier];
}

#pragma mark -

- (void) setBouncerIdentifier:(NSString *) identifier {
	self.bouncerType = MVChatConnectionNoBouncer;

	if (identifier) {
		CQBouncerSettings *bouncerSettings = [[CQConnectionsController defaultController] bouncerSettingsForIdentifier:identifier];
		if (bouncerSettings) {
			self.bouncerType = bouncerSettings.type;
			self.bouncerServer = bouncerSettings.server;
			self.bouncerServerPort = bouncerSettings.serverPort;
			self.bouncerUsername = bouncerSettings.username;
			self.bouncerPassword = bouncerSettings.password;

			[self setPersistentInformationObject:identifier forKey:@"bouncerIdentifier"];
		}
	} else {
		[self removePersistentInformationObjectForKey:@"bouncerIdentifier"];
	}
}

- (NSString *) bouncerIdentifier {
	return [self persistentInformationObjectForKey:@"bouncerIdentifier"];
}

#pragma mark -

- (void) sendPushNotificationCommands {
	NSString *deviceToken = [CQColloquyApplication sharedApplication].deviceToken;
	if (!deviceToken.length)
		return;

	if (self.pushNotifications) {
		[self sendRawMessageWithFormat:@"PUSH add-device %@ :%@", [UIDevice currentDevice].name, deviceToken];

		[self sendRawMessage:@"PUSH service colloquy.mobi 7906"];

		[self sendRawMessageWithFormat:@"PUSH connection %@ :%@", self.uniqueIdentifier, self.displayName];

		NSArray *highlightWords = [CQColloquyApplication sharedApplication].highlightWords;
		for (NSString *highlightWord in highlightWords)
			[self sendRawMessageWithFormat:@"PUSH highlight-word :%@", highlightWord];

		NSString *sound = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnHighlight"];
		if (sound.length && ![sound isEqualToString:@"None"])
			[self sendRawMessageWithFormat:@"PUSH highlight-sound :%@.aiff", sound];
		else [self sendRawMessageWithFormat:@"PUSH highlight-sound none"];

		sound = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnPrivateMessage"];
		if (sound.length && ![sound isEqualToString:@"None"])
			[self sendRawMessageWithFormat:@"PUSH message-sound :%@.aiff", sound];
		else [self sendRawMessageWithFormat:@"PUSH message-sound none"];

		[self sendRawMessage:@"PUSH end-device"];
	} else {
		[self sendRawMessageWithFormat:@"PUSH remove-device :%@", deviceToken];
	}
}
@end
