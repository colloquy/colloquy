#import "CQConnectionsController.h"

#import "CQAlertView.h"
#import "CQAnalyticsController.h"
#import "CQBouncerSettings.h"
#import "CQBouncerConnection.h"
#import "CQBouncerCreationViewController.h"
#import "CQBouncerEditViewController.h"
#import "CQChatController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionCreationViewController.h"
#import "CQConnectionEditViewController.h"
#import "CQConnectionsViewController.h"
#import "CQKeychain.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>

#if ENABLE(SECRETS)
typedef void (*IOServiceInterestCallback)(void *context, mach_port_t service, uint32_t messageType, void *messageArgument);

mach_port_t IORegisterForSystemPower(void *context, void *notificationPort, IOServiceInterestCallback callback, mach_port_t *notifier);
CFRunLoopSourceRef IONotificationPortGetRunLoopSource(void *notify);
int IOAllowPowerChange(mach_port_t kernelPort, long notification);
int IOCancelPowerChange(mach_port_t kernelPort, long notification);

#define kIOMessageSystemWillSleep 0xe0000280
#define kIOMessageCanSystemSleep 0xe0000270

static mach_port_t rootPowerDomainPort;
#endif

@interface CQConnectionsController (CQConnectionsControllerPrivate)
- (void) _loadConnectionList;
#if ENABLE(SECRETS)
- (void) _powerStateMessageReceived:(natural_t) messageType withArgument:(long) messageArgument;
#endif
@end

#pragma mark -

#if ENABLE(SECRETS)
static void powerStateChange(void *context, mach_port_t service, natural_t messageType, void *messageArgument) {       
	CQConnectionsController *self = context;
	[self _powerStateMessageReceived:messageType withArgument:(long)messageArgument];
}
#endif

#pragma mark -

#define CannotConnectToBouncerConnectionTag 1
#define CannotConnectToBouncerTag 2
#define HelpAlertTag 3

@implementation CQConnectionsController
+ (void) userDefaultsChanged {
	[UIApplication sharedApplication].idleTimerDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQIdleTimerDisabled"];
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

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

	self.navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willConnect:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didNotConnect:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_errorOccurred:) name:MVChatConnectionErrorNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_deviceTokenRecieved:) name:CQColloquyApplicationDidRecieveDeviceTokenNotification object:nil];

#if TARGET_IPHONE_SIMULATOR
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotRawConnectionMessage:) name:MVChatConnectionGotRawMessageNotification object:nil];
#endif

#if ENABLE(SECRETS)
	mach_port_t powerNotifier = 0;
	void *notificationPort = NULL;
	rootPowerDomainPort = IORegisterForSystemPower(self, &notificationPort, powerStateChange, &powerNotifier);

	CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort), kCFRunLoopCommonModes);
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

	[self pushViewController:_connectionsViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[self popToRootViewControllerAnimated:NO];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];

	for (MVChatConnection *connection in _connections)
		[connection purgeCaches];
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

		[connection connectAppropriately];

		if (target.length) {
			[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:target andConnection:connection];
			[connection joinChatRoomNamed:target];
		} else [[CQColloquyApplication sharedApplication] showConnections];

		return YES;
	}

	if (url.user.length) {
		MVChatConnection *connection = [[MVChatConnection alloc] initWithURL:url];

		[self addConnection:connection];

		[connection connect];

		if (target.length) {
			[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:target andConnection:connection];
			[connection joinChatRoomNamed:target];
		} else [[CQColloquyApplication sharedApplication] showConnections];

		[connection release];

		return YES;
	}

	[self showModalNewConnectionViewForURL:url];

	return YES;
}

#pragma mark -

- (void) showCreationActionSheet {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = 1;

	[sheet addButtonWithTitle:NSLocalizedString(@"IRC Connection", @"IRC Connection button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Colloquy Bouncer", @"Colloquy Bouncer button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];	
}

- (void) showModalNewBouncerView {
	CQBouncerCreationViewController *bouncerCreationViewController = [[CQBouncerCreationViewController alloc] init];
	[self presentModalViewController:bouncerCreationViewController animated:YES];
	[bouncerCreationViewController release];
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

#pragma mark -

- (void) editConnection:(MVChatConnection *) connection {
	CQConnectionEditViewController *editViewController = [[CQConnectionEditViewController alloc] init];
	editViewController.connection = connection;

	_wasEditing = YES;
	[self pushViewController:editViewController animated:YES];

	[editViewController release];
}

- (void) editBouncer:(CQBouncerSettings *) settings {
	CQBouncerEditViewController *editViewController = [[CQBouncerEditViewController alloc] init];
	editViewController.settings = settings;

	_wasEditing = YES;
	[self pushViewController:editViewController animated:YES];

	[editViewController release];
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == _connectionsViewController && _wasEditing) {
		[self saveConnections];
		_wasEditing = NO;
	}
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (buttonIndex == 0)
		[self showModalNewConnectionView];
	else if (buttonIndex == 1)
		[self showModalNewBouncerView];
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;

	if (alertView.tag == CannotConnectToBouncerConnectionTag) {
		MVChatConnection *connection = ((CQAlertView *)alertView).userInfo;
		[connection connectDirectly];
		return;
	}

	if (alertView.tag == CannotConnectToBouncerTag) {
		CQBouncerSettings *settings = ((CQAlertView *)alertView).userInfo;
		[self editBouncer:settings];

		[[CQColloquyApplication sharedApplication] showConnections];
	}

	if (alertView.tag == HelpAlertTag) {
		if ([self modalViewController]) {
			[self dismissModalViewControllerAnimated:YES];

			[[CQColloquyApplication sharedApplication] performSelector:@selector(showHelp) withObject:nil afterDelay:0.5];
		} else [[CQColloquyApplication sharedApplication] showHelp];
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

	BOOL newConnection = NO;
	if (!chatConnection) {
		chatConnection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];

		chatConnection.bouncerIdentifier = connection.settings.identifier;
		chatConnection.bouncerConnectionIdentifier = connectionIdentifier;

		chatConnection.bouncerType = connection.settings.type;
		chatConnection.bouncerServer = connection.settings.server;
		chatConnection.bouncerServerPort = connection.settings.serverPort;
		chatConnection.bouncerUsername = connection.settings.username;
		chatConnection.bouncerPassword = connection.settings.password;

		chatConnection.pushNotifications = YES;

		newConnection = YES;

		[connections addObject:chatConnection];
		[_connections addObject:chatConnection];

		[chatConnection release];
	}

	[chatConnection setPersistentInformationObject:[NSNumber numberWithBool:YES] forKey:@"stillExistsOnBouncer"];

	chatConnection.server = [info objectForKey:@"serverAddress"];
	chatConnection.serverPort = [[info objectForKey:@"serverPort"] unsignedShortValue];
	chatConnection.preferredNickname = [info objectForKey:@"nickname"];
	if ([[info objectForKey:@"nicknamePassword"] length])
		chatConnection.nicknamePassword = [info objectForKey:@"nicknamePassword"];
	chatConnection.username = [info objectForKey:@"username"];
	if ([[info objectForKey:@"password"] length])
		chatConnection.password = [info objectForKey:@"password"];
	chatConnection.secure = [[info objectForKey:@"secure"] boolValue];
	chatConnection.alternateNicknames = [info objectForKey:@"alternateNicknames"];
	chatConnection.encoding = [[info objectForKey:@"encoding"] unsignedIntegerValue];

	if (newConnection)
		[_connectionsViewController connectionAdded:chatConnection];
	else [_connectionsViewController updateConnection:chatConnection];
}

- (void) bouncerConnectionDidFinishConnectionList:(CQBouncerConnection *) connection {
	NSMutableArray *connections = [_bouncerChatConnections objectForKey:connection.settings.identifier];
	if (!connections.count)
		return;

	NSMutableArray *deletedConnections = [[NSMutableArray alloc] init];

	for (MVChatConnection *chatConnection in connections) {
		if (![[chatConnection persistentInformationObjectForKey:@"stillExistsOnBouncer"] boolValue])
			[deletedConnections addObject:chatConnection];
		[chatConnection removePersistentInformationObjectForKey:@"stillExistsOnBouncer"];
	}

	for (MVChatConnection *chatConnection in deletedConnections) {
		NSIndexPath *indexPath = [_connectionsViewController indexPathForConnection:chatConnection];

		[connections removeObjectIdenticalTo:chatConnection];

		if (indexPath)
			[_connectionsViewController connectionRemovedAtIndexPath:indexPath];
	}

	[deletedConnections release];
}

- (void) bouncerConnectionDidDisconnect:(CQBouncerConnection *) connection withError:(NSError *) error {
	NSMutableArray *connections = [_bouncerChatConnections objectForKey:connection.settings.identifier];

	if (error && (!connections.count || [connection.userInfo isEqual:@"manual-refresh"])) {
		CQAlertView *alert = [[CQAlertView alloc] init];

		alert.tag = CannotConnectToBouncerTag;
		alert.userInfo = connection.settings;
		alert.delegate = self;
		alert.title = NSLocalizedString(@"Can't Connect to Bouncer", @"Can't Connect to Bouncer alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Can't connect to the bouncer \"%@\". Check the bouncer settings and try again.", @"Can't connect to bouncer alert message"), connection.settings.displayName];

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

		[alert addButtonWithTitle:NSLocalizedString(@"Settings", @"Settings alert button title")];

		[alert show];

		[alert release];
	}

	[_bouncerConnections removeObject:connection];
}

#pragma mark -

#if TARGET_IPHONE_SIMULATOR
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

	[connection removePersistentInformationObjectForKey:@"pushState"];

	NSMutableArray *rooms = [connection.automaticJoinedRooms mutableCopy];

	NSArray *previousRooms = [connection persistentInformationObjectForKey:@"previousRooms"];
	if (previousRooms.count) {
		[rooms addObjectsFromArray:previousRooms];
		[connection removePersistentInformationObjectForKey:@"previousRooms"];
	}

	CQBouncerSettings *bouncerSettings = connection.bouncerSettings;
	if (bouncerSettings) {
		connection.bouncerType = bouncerSettings.type;
		connection.bouncerServer = bouncerSettings.server;
		connection.bouncerServerPort = bouncerSettings.serverPort;
		connection.bouncerUsername = bouncerSettings.username;
		connection.bouncerPassword = bouncerSettings.password;
	}

	if (connection.temporaryDirectConnection && ![[connection persistentInformationObjectForKey:@"tryBouncerFirst"] boolValue])
		connection.bouncerType = MVChatConnectionNoBouncer;

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
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	if (!_connectedCount && !_connectingCount)
		[UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void) _didNotConnect:(NSNotification *) notification {
	[self _didConnectOrDidNotConnect:notification];

	MVChatConnection *connection = notification.object;
	BOOL userDisconnected = [[notification.userInfo objectForKey:@"userDisconnected"] boolValue];
	BOOL tryBouncerFirst = [[connection persistentInformationObjectForKey:@"tryBouncerFirst"] boolValue];

	[connection removePersistentInformationObjectForKey:@"tryBouncerFirst"];

	if (!userDisconnected && tryBouncerFirst) {
		[connection connect];
		return;
	}

	if (connection.reconnectAttemptCount > 0 || userDisconnected)
		return;

	CQAlertView *alert = [[CQAlertView alloc] init];

	if (connection.directConnection) {
		alert.tag = HelpAlertTag;
		alert.delegate = self;

		alert.title = NSLocalizedString(@"Can't Connect to Server", @"Can't Connect to Server alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Can't connect to the server \"%@\".", @"Cannot connect alert message"), connection.displayName];

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

		[alert addButtonWithTitle:NSLocalizedString(@"Help", @"Help button title")];
	} else {
		alert.tag = CannotConnectToBouncerConnectionTag;
		alert.userInfo = connection;
		alert.delegate = self;

		alert.title = NSLocalizedString(@"Can't Connect to Bouncer", @"Can't Connect to Bouncer alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Can't connect to the server \"%@\" via \"%@\". Would you like to connect directly?", @"Connect directly alert message"), connection.displayName, connection.bouncerSettings.displayName];

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

		[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];
	}

	[alert show];

	[alert release];
}

- (void) _didConnect:(NSNotification *) notification {
	++_connectedCount;

	[self _didConnectOrDidNotConnect:notification];

	MVChatConnection *connection = notification.object;
	[connection removePersistentInformationObjectForKey:@"tryBouncerFirst"];

	if (!connection.directConnection)
		connection.temporaryDirectConnection = NO;
}

- (void) _didDisconnect:(NSNotification *) notification {
	if (_connectedCount)
		--_connectedCount;
	if (!_connectedCount && !_connectingCount)
		[UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void) _deviceTokenRecieved:(NSNotification *) notification {
	for (MVChatConnection *connection in _connections)
		[connection sendPushNotificationCommands]; 
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
			errorTitle = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");
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
	alert.tag = HelpAlertTag;
	alert.delegate = self;
	alert.title = errorTitle;
	alert.message = errorMessage;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	[alert addButtonWithTitle:NSLocalizedString(@"Help", @"Help button title")];

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

	[connection loadPasswordsFromKeychain];

	if ([info objectForKey:@"nicknamePassword"]) connection.nicknamePassword = [info objectForKey:@"nicknamePassword"];
	if ([info objectForKey:@"password"]) connection.password = [info objectForKey:@"password"];

	if ([info objectForKey:@"bouncerConnectionIdentifier"]) connection.bouncerConnectionIdentifier = [info objectForKey:@"bouncerConnectionIdentifier"];

	CQBouncerSettings *bouncerSettings = [self bouncerSettingsForIdentifier:connection.bouncerIdentifier];
	if (bouncerSettings) {
		connection.bouncerType = bouncerSettings.type;
		connection.bouncerServer = bouncerSettings.server;
		connection.bouncerServerPort = bouncerSettings.serverPort;
		connection.bouncerUsername = bouncerSettings.username;
		connection.bouncerPassword = bouncerSettings.password;
	}

	if (connection.temporaryDirectConnection)
		connection.bouncerType = MVChatConnectionNoBouncer;

	if ((!bouncerSettings || bouncerSettings.pushNotifications) && connection.pushNotifications)
		[[CQColloquyApplication sharedApplication] registerForRemoteNotifications];

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
	[persistentInformation removeObjectForKey:@"pushState"];
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
	if (connection.bouncerConnectionIdentifier) [info setObject:connection.bouncerConnectionIdentifier forKey:@"bouncerConnectionIdentifier"];

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
		if (!settings)
			continue;

		[_bouncers addObject:settings];

		// TEMP: read the bouncer password from the old account scheme using in the first beta.
		if (!settings.password.length)
			settings.password = [[CQKeychain standardKeychain] passwordForServer:settings.server account:settings.username];

		NSMutableArray *bouncerChatConnections = [[NSMutableArray alloc] initWithCapacity:10];
		[_bouncerChatConnections setObject:bouncerChatConnections forKey:settings.identifier];

		NSArray *connections = [info objectForKey:@"connections"];
		for (NSDictionary *info in connections) {
			MVChatConnection *connection = [self _chatConnectionWithDictionaryRepresentation:info];
			if (!connection)
				continue;

			[bouncerChatConnections addObject:connection];
			[_connections addObject:connection];

			if ([info objectForKey:@"chatState"])
				[[CQChatController defaultController] restorePersistentState:[info objectForKey:@"chatState"] forConnection:connection];
		}

		[bouncerChatConnections release];
		[settings release];
	}

	NSArray *connections = [[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatBookmarks"];
	for (NSDictionary *info in connections) {
		MVChatConnection *connection = [self _chatConnectionWithDictionaryRepresentation:info];
		if (!connection)
			continue;

		// TEMP: skip any direct connections that have bouncer identifiers.
		if (connection.bouncerIdentifier.length)
			continue;

		[_directConnections addObject:connection];
		[_connections addObject:connection];

		if ([info objectForKey:@"chatState"])
			[[CQChatController defaultController] restorePersistentState:[info objectForKey:@"chatState"] forConnection:connection];
	}

	[self performSelector:@selector(_connectAutomaticConnections) withObject:nil afterDelay:0.5];

	if (_bouncers.count)
		[self performSelector:@selector(_refreshBouncerConnectionLists) withObject:nil afterDelay:1.];
}

- (void) _connectAutomaticConnections {
	for (MVChatConnection *connection in _connections)
		if (connection.automaticallyConnect)
			[connection connectAppropriately];
}

- (void) _refreshBouncerConnectionLists {
	[_bouncerConnections makeObjectsPerformSelector:@selector(disconnect)];
	[_bouncerConnections removeAllObjects];

	for (CQBouncerSettings *settings in _bouncers) {
		CQBouncerConnection *connection = [[CQBouncerConnection alloc] initWithBouncerSettings:settings];
		connection.delegate = self;

		[_bouncerConnections addObject:connection];

		[connection connect];

		[connection release];
	}
}

#if ENABLE(SECRETS)
- (void) _powerStateMessageReceived:(natural_t) messageType withArgument:(long) messageArgument {
	switch (messageType) {
	case kIOMessageSystemWillSleep:
		// System will go to sleep, we can't prevent it.
		for (MVChatConnection *connection in _connections)
			[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
		break;
	case kIOMessageCanSystemSleep:
		// System wants to go to sleep, but we can cancel it if we have connected connections.
		if (_connectedCount || _connectingCount)
			IOCancelPowerChange(rootPowerDomainPort, messageArgument);
		else IOAllowPowerChange(rootPowerDomainPort, messageArgument);
		break;
	}
}
#endif

#pragma mark -

- (void) saveConnections {
	if (!_loadedConnections)
		return;

	NSUInteger pushConnectionCount = 0;
	NSUInteger roomCount = 0;

	NSMutableArray *connections = [[NSMutableArray alloc] initWithCapacity:_directConnections.count];
	for (MVChatConnection *connection in _directConnections) {
		NSMutableDictionary *connectionInfo = [self _dictionaryRepresentationForConnection:connection];
		if (!connectionInfo)
			continue;

		if (connection.pushNotifications)
			++pushConnectionCount;

		roomCount += connection.knownChatRooms.count;

		[connections addObject:connectionInfo];
		[connection savePasswordsToKeychain];
	}

	NSMutableArray *bouncers = [[NSMutableArray alloc] initWithCapacity:_bouncers.count];
	for (CQBouncerSettings *settings in _bouncers) {
		NSMutableDictionary *info = [settings dictionaryRepresentation];
		if (!info)
			continue;

		NSMutableArray *bouncerConnections = [[NSMutableArray alloc] initWithCapacity:10];
		for (MVChatConnection *connection in [self bouncerChatConnectionsForIdentifier:settings.identifier]) {
			NSMutableDictionary *connectionInfo = [self _dictionaryRepresentationForConnection:connection];
			if (!connectionInfo)
				continue;

			if (settings.pushNotifications && connection.pushNotifications)
				++pushConnectionCount;

			roomCount += connection.knownChatRooms.count;

			[bouncerConnections addObject:connectionInfo];
			[connection savePasswordsToKeychain];
		}

		if (bouncerConnections.count)
			[info setObject:bouncerConnections forKey:@"connections"];
		[bouncerConnections release];

		[bouncers addObject:info];
	}

	[[NSUserDefaults standardUserDefaults] setObject:bouncers forKey:@"CQChatBouncers"];
	[[NSUserDefaults standardUserDefaults] setObject:connections forKey:@"MVChatBookmarks"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	[[CQAnalyticsController defaultController] setObject:[NSNumber numberWithUnsignedInteger:roomCount] forKey:@"total-rooms"];
	[[CQAnalyticsController defaultController] setObject:[NSNumber numberWithUnsignedInteger:pushConnectionCount] forKey:@"total-push-connections"];
	[[CQAnalyticsController defaultController] setObject:[NSNumber numberWithUnsignedInteger:_connections.count] forKey:@"total-connections"];
	[[CQAnalyticsController defaultController] setObject:[NSNumber numberWithUnsignedInteger:_bouncers.count] forKey:@"total-bouncers"];

	[bouncers release];
	[connections release];
}

#pragma mark -

@synthesize connections = _connections;
@synthesize directConnections = _directConnections;
@synthesize bouncers = _bouncers;

#pragma mark -

- (NSSet *) connectedConnections {
	NSMutableSet *result = [[NSMutableSet alloc] initWithCapacity:_connections.count];

	for (MVChatConnection *connection in _connections)
		if (connection.connected)
			[result addObject:connection];

	return [result autorelease];
}

- (MVChatConnection *) connectionForUniqueIdentifier:(NSString *) identifier {
	for (MVChatConnection *connection in _connections)
		if ([connection.uniqueIdentifier isEqualToString:identifier])
			return connection;
	return nil;
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

	[self saveConnections];
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

	[_directConnections replaceObjectAtIndex:index withObject:connection];
	[_connections removeObject:oldConnection];
	[_connections addObject:connection];

	[oldConnection release];

	[self saveConnections];
}

#pragma mark -

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex forBouncerIdentifier:(NSString *) identifier {
	NSMutableArray *connections = [_bouncerChatConnections objectForKey:identifier];
	MVChatConnection *connection = [[connections objectAtIndex:oldIndex] retain];

	[connections removeObjectAtIndex:oldIndex];
	[connections insertObject:connection atIndex:newIndex];

	[connection release];

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

#pragma mark -

- (void) refreshBouncerConnectionsWithBouncerSettings:(CQBouncerSettings *) settings {
	CQBouncerConnection *connection = [[CQBouncerConnection alloc] initWithBouncerSettings:settings];
	connection.delegate = self;
	connection.userInfo = @"manual-refresh";

	[_bouncerConnections addObject:connection];

	[connection connect];

	[connection release];
}

#pragma mark -

- (void) addBouncerSettings:(CQBouncerSettings *) bouncer {
	NSParameterAssert(bouncer != nil);
	[_bouncers addObject:bouncer];
	[self refreshBouncerConnectionsWithBouncerSettings:bouncer];
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
			if ([compontent isCaseInsensitiveEqualToString:@"iPhone"] || [compontent isCaseInsensitiveEqualToString:@"iPod"] || [compontent isCaseInsensitiveEqualToString:@"iPad"])
				continue;
			if ([compontent isEqualToString:@"3G"] || [compontent isEqualToString:@"3GS"] || [compontent isEqualToString:@"S"] || [compontent isCaseInsensitiveEqualToString:@"Touch"])
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
	
	[self sendPushNotificationCommands];
}

- (BOOL) pushNotifications {
	return [[self persistentInformationObjectForKey:@"push"] boolValue];
}

#pragma mark -

- (BOOL) isTemporaryDirectConnection {
	return [[self persistentInformationObjectForKey:@"direct"] boolValue];
}

- (void) setTemporaryDirectConnection:(BOOL) direct {
	if (direct == self.temporaryDirectConnection)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:direct] forKey:@"direct"];
}

- (BOOL) isDirectConnection {
	return (self.bouncerType == MVChatConnectionNoBouncer);
}

#pragma mark -

- (void) setBouncerSettings:(CQBouncerSettings *) settings {
	self.bouncerIdentifier = settings.identifier;
}

- (CQBouncerSettings *) bouncerSettings {
	return [[CQConnectionsController defaultController] bouncerSettingsForIdentifier:self.bouncerIdentifier];
}

#pragma mark -

- (void) setBouncerIdentifier:(NSString *) identifier {
	if ([identifier isEqualToString:self.bouncerIdentifier])
		return;

	if (identifier.length)
		[self setPersistentInformationObject:identifier forKey:@"bouncerIdentifier"];
	else [self removePersistentInformationObjectForKey:@"bouncerIdentifier"];
}

- (NSString *) bouncerIdentifier {
	return [self persistentInformationObjectForKey:@"bouncerIdentifier"];
}

#pragma mark -

- (void) savePasswordsToKeychain {
	// Remove old passwords using the previous account naming scheme.
	[[CQKeychain standardKeychain] removePasswordForServer:self.server account:self.preferredNickname];
	[[CQKeychain standardKeychain] removePasswordForServer:self.server account:@"<<server password>>"];

	// Store passwords using the new account naming scheme.
	[[CQKeychain standardKeychain] setPassword:self.nicknamePassword forServer:self.uniqueIdentifier account:[NSString stringWithFormat:@"Nickname %@", self.preferredNickname]];
	[[CQKeychain standardKeychain] setPassword:self.password forServer:self.uniqueIdentifier account:@"Server"];
}

- (void) loadPasswordsFromKeychain {
	NSString *password = nil;

	// Try reading passwords using the old account naming scheme.
	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.server account:self.preferredNickname]) && password.length)
		self.nicknamePassword = password;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.server account:@"<<server password>>"]) && password.length)
		self.password = password;

	// Try reading password using the name account naming scheme.
	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier account:[NSString stringWithFormat:@"Nickname %@", self.preferredNickname]]) && password.length)
		self.nicknamePassword = password;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier account:@"Server"]) && password.length)
		self.password = password;
}

#pragma mark -

- (void) connectAppropriately {
	[self setPersistentInformationObject:[NSNumber numberWithBool:YES] forKey:@"tryBouncerFirst"];

	[self connect];
}

- (void) connectDirectly {
	self.temporaryDirectConnection = YES;

	[self connect];
}

#pragma mark -

- (void) sendPushNotificationCommands {
	if (!self.connected && self.status != MVChatConnectionConnectingStatus)
		return;

	NSString *deviceToken = [CQColloquyApplication sharedApplication].deviceToken;
	if (!deviceToken.length)
		return;

	NSNumber *currentState = [self persistentInformationObjectForKey:@"pushState"];

	CQBouncerSettings *settings = self.bouncerSettings;
	if ((!settings || settings.pushNotifications) && self.pushNotifications && (!currentState || ![currentState boolValue])) {
		[self setPersistentInformationObject:[NSNumber numberWithBool:YES] forKey:@"pushState"];

		[self sendRawMessageWithFormat:@"PUSH add-device %@ :%@", deviceToken, [UIDevice currentDevice].name];

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
	} else if ((!currentState || [currentState boolValue])) {
		[self setPersistentInformationObject:[NSNumber numberWithBool:NO] forKey:@"pushState"];

		[self sendRawMessageWithFormat:@"PUSH remove-device :%@", deviceToken];
	}
}
@end
