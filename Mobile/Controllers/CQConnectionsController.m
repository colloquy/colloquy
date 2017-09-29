#import "CQConnectionsController.h"

#import "CQAnalyticsController.h"
#import "CQBouncerSettings.h"
#import "CQBouncerConnection.h"
#import "CQBouncerCreationViewController.h"
#import "CQBouncerEditViewController.h"
#import "CQChatController.h"
#import "CQChatOrderingController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsNavigationController.h"
#import "CQConnectionCreationViewController.h"
#import "CQConnectionEditViewController.h"
#import "CQIgnoreRulesController.h"
#import "CQKeychain.h"

#import "dlfcn.h"
#import "tgmath.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatConnectionPrivate.h>
#import <ChatCore/MVChatRoom.h>

#import <CoreSpotlight/CoreSpotlight.h>
#import <MobileCoreServices/MobileCoreServices.h>

#if SYSTEM(MAC)
#import <SecurityInterface/SFCertificatePanel.h>
#endif

#import "UIApplicationAdditions.h"
#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

NSString *CQConnectionsControllerAddedConnectionNotification = @"CQConnectionsControllerAddedConnectionNotification";
NSString *CQConnectionsControllerChangedConnectionNotification = @"CQConnectionsControllerChangedConnectionNotification";
NSString *CQConnectionsControllerRemovedConnectionNotification = @"CQConnectionsControllerRemovedConnectionNotification";
NSString *CQConnectionsControllerMovedConnectionNotification = @"CQConnectionsControllerMovedConnectionNotification";
NSString *CQConnectionsControllerAddedBouncerSettingsNotification = @"CQConnectionsControllerAddedBouncerSettingsNotification";
NSString *CQConnectionsControllerRemovedBouncerSettingsNotification = @"CQConnectionsControllerRemovedBouncerSettingsNotification";

static NSString *const connectionInvalidSSLCertAction = nil;

@interface CQConnectionsController () <CQActionSheetDelegate,
#if !SYSTEM(TV)
CSSearchableIndexDelegate,
#endif
CQBouncerConnectionDelegate>
@end

@implementation CQConnectionsController {
	NSMapTable *_connectionToErrorToAlertMap;
	CQConnectionsNavigationController *_connectionsNavigationController;
	NSMutableSet *_connections;
	NSMutableArray *_directConnections;
	NSMutableArray *_bouncers;
	NSMutableSet *_bouncerConnections;
	NSMutableDictionary *_bouncerChatConnections;
	NSMutableDictionary *_ignoreControllers;
	BOOL _loadedConnections;
	NSUInteger _connectingCount;
	NSUInteger _connectedCount;
#if !SYSTEM(TV)
	UILocalNotification *_timeRemainingLocalNotifiction;
#endif
	UIBackgroundTaskIdentifier _backgroundTask;
	NSTimeInterval _allowedBackgroundTime;
	NSMutableSet *_automaticallySetConnectionAwayStatus;
	BOOL _shouldLogRawMessagesToConsole;
	NSMapTable *_activityTokens;
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

#pragma mark -

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_applicationNetworkStatusDidChange:) name:CQReachabilityStateDidChangeNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_willConnect:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didNotConnect:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_errorOccurred:) name:MVChatConnectionErrorNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_deviceTokenRecieved:) name:CQColloquyApplicationDidRecieveDeviceTokenNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
#if !SYSTEM(TV)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_batteryStateChanged) name:UIDeviceBatteryStateDidChangeNotification object:nil];
#endif
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_peerTrustFeedbackNotification:) name:MVChatConnectionNeedTLSPeerTrustFeedbackNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_nicknamePasswordRequested:) name:MVChatConnectionNeedNicknamePasswordNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_serverPasswordRequested:) name:MVChatConnectionNeedServerPasswordNotification object:nil];
//	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotConnectionError:) name:MVChatConnectionGotErrorNotification object:nil];

	if ([UIDevice currentDevice].multitaskingSupported) {
		_backgroundTask = UIBackgroundTaskInvalid;
		_activityTokens = [NSMapTable strongToStrongObjectsMapTable];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	}

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotRawConnectionMessage:) name:MVChatConnectionGotRawMessageNotification object:nil];

#if !SYSTEM(TV)
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
#endif

	_connectionsNavigationController = [[CQConnectionsNavigationController alloc] init];

	_connections = [[NSMutableSet alloc] initWithCapacity:10];
	_bouncers = [[NSMutableArray alloc] initWithCapacity:2];
	_directConnections = [[NSMutableArray alloc] initWithCapacity:5];
	_bouncerConnections = [[NSMutableSet alloc] initWithCapacity:2];
	_bouncerChatConnections = [[NSMutableDictionary alloc] initWithCapacity:2];
	_ignoreControllers = [[NSMutableDictionary alloc] initWithCapacity:2];
	_connectionToErrorToAlertMap = [NSMapTable strongToStrongObjectsMapTable];

	[self _loadConnectionList];

#if TARGET_IPHONE_SIMULATOR
	_shouldLogRawMessagesToConsole = YES;
#else
	_shouldLogRawMessagesToConsole = [[CQSettingsController settingsController] boolForKey:@"CQLogRawMessagesToConsole"];
#endif

#if !SYSTEM(TV)
	if (NSClassFromString(@"CSSearchableIndex"))
		[CSSearchableIndex defaultSearchableIndex].indexDelegate = self;
#endif

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) setShouldLogRawMessagesToConsole:(BOOL) shouldLogRawMessagesToConsole {
	_shouldLogRawMessagesToConsole = shouldLogRawMessagesToConsole;

	[[CQSettingsController settingsController] setBool:_shouldLogRawMessagesToConsole forKey:@"CQLogRawMessagesToConsole"];
}

#pragma mark -

- (BOOL) handleOpenURL:(NSURL *) url {
	if ((![url.scheme isCaseInsensitiveEqualToString:@"irc"] && ![url.scheme isCaseInsensitiveEqualToString:@"ircs"]) || !url.host.length)
		return NO;

	NSString *target = @"";
	if (url.fragment.length) target = [@"#" stringByAppendingString:[url.fragment stringByDecodingIllegalURLCharacters]];
	else if (url.path.length > 1) target = [[url.path substringFromIndex:1] stringByDecodingIllegalURLCharacters];

	NSArray <MVChatConnection *> *possibleConnections = [self connectionsForServerAddress:url.host];

	for (MVChatConnection *connection in possibleConnections) {
		if (url.user.length && (![url.user isEqualToString:connection.preferredNickname] || ![url.user isEqualToString:connection.nickname]))
			continue;
		if ([url.port unsignedShortValue] && [url.port unsignedShortValue] != connection.serverPort)
			continue;

		[connection connectAppropriately];

		if (target.length) {
			[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:target andConnection:connection];
			[connection joinChatRoomNamed:target];
		} else [[CQColloquyApplication sharedApplication] showConnections:nil];

		return YES;
	}

	if (url.user.length) {
		MVChatConnection *connection = [[MVChatConnection alloc] initWithURL:url];

		connection.multitaskingSupported = YES;

		[self addConnection:connection];

		[connection connect];

		if (target.length) {
			[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:target andConnection:connection];
			[connection joinChatRoomNamed:target];
		} else [[CQColloquyApplication sharedApplication] showConnections:nil];

		return YES;
	}

	[self showConnectionCreationViewForURL:url];

	return YES;
}

#pragma mark -

- (void) showNewConnectionPromptFromPoint:(CGPoint) point {
	CQActionSheet *sheet = [[CQActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = 1;

	[sheet addButtonWithTitle:NSLocalizedString(@"IRC Connection", @"IRC Connection button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Colloquy Bouncer", @"Colloquy Bouncer button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet fromPoint:point];
}

- (void) showBouncerCreationView:(__nullable id) sender {
	CQBouncerCreationViewController *bouncerCreationViewController = [[CQBouncerCreationViewController alloc] init];
	[[CQColloquyApplication sharedApplication] presentModalViewController:bouncerCreationViewController animated:YES];
}

- (void) showConnectionCreationView:(__nullable id) sender {
	[self showConnectionCreationViewForURL:nil];
}

- (void) showConnectionCreationViewForURL:(NSURL *__nullable) url {
	CQConnectionCreationViewController *connectionCreationViewController = [[CQConnectionCreationViewController alloc] init];
	connectionCreationViewController.url = url;
	[[CQColloquyApplication sharedApplication] presentModalViewController:connectionCreationViewController animated:YES];
}

#pragma mark -

- (void) actionSheet:(CQActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (buttonIndex == 0)
		[self showConnectionCreationView:nil];
	else if (buttonIndex == 1)
		[self showBouncerCreationView:nil];
}

#pragma mark -

#if !SYSTEM(TV)
- (void) searchableIndex:(CSSearchableIndex *) searchableIndex reindexSearchableItemsWithIdentifiers:(NSArray <NSString *> *) identifiers acknowledgementHandler:(void (^)(void)) acknowledgementHandler {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQIndexInSpotlight"])
		[self indexConnectionsInSpotlight];
	acknowledgementHandler();
}

- (void) searchableIndex:(CSSearchableIndex *) searchableIndex reindexAllSearchableItemsWithAcknowledgementHandler:(void (^)(void)) acknowledgementHandler {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQIndexInSpotlight"])
		[self indexConnectionsInSpotlight];
	acknowledgementHandler();
}
#endif

#pragma mark -

- (void) _peerTrustFeedbackNotification:(NSNotification *) notification {
	void (^completionHandler)(BOOL shouldTrustPeer) = notification.userInfo[@"completionHandler"];
	if (!completionHandler) {
		return;
	}

	// Intentionally not implemented due to the lack of any secure settings; if a device is compromised, it
	// could be set to "deny" without someone knowing.
	if ([connectionInvalidSSLCertAction isEqualToString:@"Deny"]) {
		completionHandler(NO);
	} else if ([connectionInvalidSSLCertAction isEqualToString:@"Allow"]) {
		completionHandler(YES);
	} else { // Ask people what to do
#if SYSTEM(IOS)
		SecTrustRef trust = (__bridge SecTrustRef)notification.userInfo[@"trust"];
		SecCertificateRef certificate = NULL;
		NSString *certificateSubject = nil;
		CFIndex certificateCount = SecTrustGetCertificateCount(trust);
		if (certificateCount == 0)
			certificateSubject = @"Unknown";
		else {
			// In the event that SecTrustAddException() starts working, we will have different results, but, it won't matter
			// because the initial trust evaluation will succeed and we will not get to this point.
			certificate = SecTrustGetCertificateAtIndex(trust, 0);
			certificateSubject = (__bridge_transfer NSString *)SecCertificateCopySubjectSummary(certificate);
			SecTrustResultType result = [notification.userInfo[@"result"] intValue];
			SecTrustResultType existingResult = [[[CQKeychain standardKeychain] passwordForServer:certificateSubject area:@"Trust"] intValue];
			BOOL isSameResult = (result == existingResult);
			BOOL isSameData = NO;

			if (isSameResult) {
				NSData *certificateData = (__bridge_transfer NSData *)SecCertificateCopyData(certificate);
				NSData *savedCertificateData = [[CQKeychain standardKeychain] dataForServer:certificateSubject area:@"Certificate"];
				isSameData = [certificateData isEqualToData:savedCertificateData];
			}

			if (isSameResult && isSameData) {
				completionHandler(YES);
				return;
			} else {
				[[CQKeychain standardKeychain] removeDataForServer:certificateSubject area:@"Certificate"];
				[[CQKeychain standardKeychain] removePasswordForServer:certificateSubject area:@"Trust"];
			}
		}

		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
		alert.title = NSLocalizedString(@"Cannot Verify Server Identity" , @"Cannot Verify Server Identity alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"The identity of \"%@\" cannot be verified by Colloquy. Please decide how to continue.", @"Identity cannot be verified message"), certificateSubject];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel alert button") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
			completionHandler(NO);
		}]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Continue", @"Continue alert button") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			completionHandler(YES);
		}]];
		if (certificate) {
			[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Always Continue", @"Always Continue alert button") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				completionHandler(YES);

				// • The correct way to handle this is by creating an exception with SecTrustSetExceptions().
				// This doesn't seem to work on iOS 8; the trust result isn't the same for across multiple SecTrustRef's.
				// (That is:
				//		Connect -> Evaluate Trust and get initial state -> Add Exception. Evaluate Trust and get .Proceed.
				//		Reconnect -> Evaluate Trust and get the initial state again.)
				// But, it doesn't hurt to try setting an exception, anyway.
				SecTrustSetExceptions(trust, CFAutorelease(SecTrustCopyExceptions(trust)));

				// • To work around this, copy the certificate data to the keychain (along with the current trust
				// result. If it changes in the future, we will force a re-evaluation of trust on the next connection.
				// • If we do not have any certificate data, we will force a re-evaluation of trust on the next connection.
				if (certificateCount == 0) {
					return;
				}

				NSData *certificateData = (__bridge_transfer NSData *)SecCertificateCopyData(certificate);

				[[CQKeychain standardKeychain] setData:certificateData forServer:certificateSubject area:@"Certificate"];
				[[CQKeychain standardKeychain] setPassword:notification.userInfo[@"result"] forServer:certificateSubject area:@"Trust"];
			}]];
		}

		NSMapTable *errorToAlertMappingsForConnection = [_connectionToErrorToAlertMap objectForKey:notification.object];
		if (!errorToAlertMappingsForConnection) {
			errorToAlertMappingsForConnection = [NSMapTable strongToStrongObjectsMapTable];
			[_connectionToErrorToAlertMap setObject:errorToAlertMappingsForConnection forKey:notification.object];
		}

		UIAlertController *previousAlert = [errorToAlertMappingsForConnection objectForKey:@"peerTrust"];
		if (previousAlert) {
			[previousAlert dismissViewControllerAnimated:NO completion:^{
				[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:NO completion:NULL];
			}];
		} else {
			[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:NULL];
		}
		[errorToAlertMappingsForConnection setObject:alert forKey:@"peerTrust"];

#elif SYSTEM(MAC)
		// Ask people what to do
		SFCertificateTrustPanel *panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
		panel.showsHelp = YES;

		[panel setDefaultButtonTitle:NSLocalizedString(@"Continue", @"Continue button")];
		[panel setAlternateButtonTitle:NSLocalizedString(@"Cancel", @"Cancel button")];

		SecTrustRef trust = (__bridge SecTrustRef)notification.userInfo[@"trust"];
		NSInteger shouldTrust = [panel runModalForTrust:trust showGroup:YES];

		completionHandler(shouldTrust == NSModalResponseOK);
#else
		completionHandler(NO);
#endif
	}
}

- (void) bouncerConnection:(CQBouncerConnection *) connection didRecieveConnectionInfo:(NSDictionary *) info {
	NSMutableArray *connections = _bouncerChatConnections[connection.settings.identifier];
	if (!connections) {
		connections = [[NSMutableArray alloc] initWithCapacity:5];
		_bouncerChatConnections[connection.settings.identifier] = connections;
	}

	NSString *connectionIdentifier = info[@"connectionIdentifier"];
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

		chatConnection.multitaskingSupported = YES;
		chatConnection.pushNotifications = YES;

		newConnection = YES;

		[connections addObject:chatConnection];
		[_connections addObject:chatConnection];
	}

	[chatConnection setPersistentInformationObject:@(YES) forKey:@"stillExistsOnBouncer"];

	chatConnection.server = info[@"serverAddress"];
	chatConnection.serverPort = [info[@"serverPort"] unsignedShortValue];
	chatConnection.preferredNickname = info[@"nickname"];
	if ([info[@"nicknamePassword"] length])
		chatConnection.nicknamePassword = info[@"nicknamePassword"];
	chatConnection.username = info[@"username"];
	if ([info[@"password"] length])
		chatConnection.password = info[@"password"];
	chatConnection.secure = [info[@"secure"] boolValue];
	chatConnection.requestsSASL = [info[@"requestsSASL"] boolValue];
	chatConnection.alternateNicknames = info[@"alternateNicknames"];
	chatConnection.encoding = [info[@"encoding"] unsignedIntegerValue];

	NSDictionary *notificationInfo = @{@"connection": chatConnection};
	if (newConnection)
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQConnectionsControllerAddedConnectionNotification object:self userInfo:notificationInfo];
	else [[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQConnectionsControllerChangedConnectionNotification object:self userInfo:notificationInfo];
}

- (void) bouncerConnectionDidFinishConnectionList:(CQBouncerConnection *) connection {
	NSMutableArray *connections = _bouncerChatConnections[connection.settings.identifier];
	if (!connections.count)
		return;

	NSMutableArray *deletedConnections = [[NSMutableArray alloc] init];

	for (MVChatConnection *chatConnection in connections) {
		if (![[chatConnection persistentInformationObjectForKey:@"stillExistsOnBouncer"] boolValue])
			[deletedConnections addObject:chatConnection];
		[chatConnection removePersistentInformationObjectForKey:@"stillExistsOnBouncer"];
	}

	for (MVChatConnection *chatConnection in deletedConnections) {
		NSUInteger index = [connections indexOfObjectIdenticalTo:chatConnection];
		[connections removeObjectAtIndex:index];

		NSDictionary *notificationInfo = @{@"connection": chatConnection, @"index": @(index)};
		[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerRemovedConnectionNotification object:self userInfo:notificationInfo];
	}
}

- (void) bouncerConnectionDidDisconnect:(CQBouncerConnection *) connection withError:(NSError *) error {
	NSMutableArray *connections = _bouncerChatConnections[connection.settings.identifier];

	if (error && (!connections.count || [connection.userInfo isEqual:@"manual-refresh"])) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
		alert.title = NSLocalizedString(@"Can't Connect to Bouncer", @"Can't Connect to Bouncer alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Can't connect to the bouncer \"%@\". Check the bouncer settings and try again.", @"Can't connect to bouncer alert message"), connection.settings.displayName];

		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", @"Settings alert button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//			[_connectionsNavigationController editBouncer:connection.settings];
			[[CQColloquyApplication sharedApplication] showConnections:nil];
		}]];

		[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:NULL];
	}

	connection.delegate = nil;

	[_bouncerConnections removeObject:connection];
}

#pragma mark -

- (void) _applicationDidReceiveMemoryWarning {
	for (MVChatConnection *connection in _connections)
		[connection purgeCaches];
}

- (void) _applicationWillResignActive {
	[self saveConnections];

	for (MVChatConnection *connection in _connections)
		[connection purgeCaches];
}

- (void) _applicationWillTerminate {
	[self saveConnections];

	for (MVChatConnection *connection in _connections) {
		NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
		[connection disconnectWithReason:quitMessageString];
	}
}

- (void) _applicationNetworkStatusDidChange:(NSNotification *) notification {
	CQReachabilityState newState = [notification.userInfo[CQReachabilityNewStateKey] intValue];
	CQReachabilityState oldState = [notification.userInfo[CQReachabilityOldStateKey] intValue];

	// Happens on app launch if we don't have an available network to connect over
	if (oldState == newState)
		return;

	if (!_automaticallySetConnectionAwayStatus)
		_automaticallySetConnectionAwayStatus = [[NSMutableSet alloc] init];

	if (newState == CQReachabilityStateNotReachable) {
		[self performSelector:@selector(_networkConnectionLost) withObject:nil afterDelay:2.];
	} else if (oldState == CQReachabilityStateNotReachable) {
		[self performSelector:@selector(_networkConnectionFound) withObject:nil afterDelay:2.];
	}
}

- (void) _networkConnectionLost {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_networkConnectionFound) object:nil];

	if (self._anyConnectedOrConnectingConnections) {
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
			UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
			alertView.title = NSLocalizedString(@"Disconnected", @"Disconnected alert title");
			alertView.message = NSLocalizedString(@"You have been disconnected due to the loss of network connectivity", @"Disconnected due to network alert message");

			[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];

			[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertView animated:YES completion:NULL];
		} else {
#if !SYSTEM(TV)
			UILocalNotification *notification = [[UILocalNotification alloc] init];

			notification.alertBody = NSLocalizedString(@"You have been disconnected due to the loss of network connectivity", @"Disconnected due to network local notification body");
			notification.soundName = UILocalNotificationDefaultSoundName;
			notification.hasAction = NO;

			[[CQColloquyApplication sharedApplication] presentLocalNotificationNow:notification];
#endif
		}
	}

	for (MVChatConnection *connection in _connections) {
		BOOL wasConnected = connection.connected || connection.status == MVChatConnectionConnectingStatus;
		[connection forceDisconnect];
		if (wasConnected)
			[connection _setStatus:MVChatConnectionSuspendedStatus];

		if (connection.awayStatusMessage.length)
			[_automaticallySetConnectionAwayStatus addObject:connection];
	}
}

- (void) _networkConnectionFound {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_networkConnectionLost) object:nil];

	for (MVChatConnection *connection in _connections) {
		if (connection.status == MVChatConnectionSuspendedStatus)
			[connection connectAppropriately];
	}
}

- (BOOL) _anyConnectedOrConnectingConnections {
	for (MVChatConnection *connection in _connections)
		if (connection.status == MVChatConnectionConnectedStatus || connection.status == MVChatConnectionConnectingStatus)
			return YES;
	return NO;
}

- (BOOL) _anyConnectingConnections {
	for (MVChatConnection *connection in _connections)
		if (connection.status == MVChatConnectionConnectingStatus)
			return YES;
	return NO;
}

- (BOOL) _anyReconnectingConnections {
	for (MVChatConnection *connection in _connections)
		if (connection.waitingToReconnect)
			return YES;
	return NO;
}

- (void) _possiblyEndBackgroundTaskSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_possiblyEndBackgroundTask) object:nil];
	[self performSelector:@selector(_possiblyEndBackgroundTask) withObject:nil afterDelay:5.];
}

- (void) _possiblyEndBackgroundTask {
	if (![UIDevice currentDevice].multitaskingSupported)
		return;

	if ([self _anyConnectedOrConnectingConnections] || [self _anyReconnectingConnections] || _backgroundTask == UIBackgroundTaskInvalid)
		return;

	[[CQColloquyApplication sharedApplication] submitRunTime];

	[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
	_backgroundTask = UIBackgroundTaskInvalid;
}

- (void) _showNoTimeRemainingAlert {
	if (![UIDevice currentDevice].multitaskingSupported)
		return;

	if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
		return;

	if (![[CQSettingsController settingsController] boolForKey:@"CQBackgroundTimeRemainingAlert"])
		return;

	if (![self _anyConnectedOrConnectingConnections])
		return;

#if !SYSTEM(TV)
	UILocalNotification *notification = [[UILocalNotification alloc] init];

	notification.alertBody = NSLocalizedString(@"No multitasking time remaining, so you have been disconnected.", "No multitasking time remaining alert message");
	notification.alertAction = NSLocalizedString(@"Open", "Open button title");
	notification.soundName = UILocalNotificationDefaultSoundName;

	[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
#endif
}

- (void) _showDisconnectedAlert {
	if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
		return;

	if (![[CQSettingsController settingsController] boolForKey:@"CQShowDisconnectedInBackgroundAlert"])
		return;

	if (![[CQSettingsController settingsController] doubleForKey:@"CQMultitaskingTimeout"])
		return;

	if (![self _anyConnectedOrConnectingConnections])
		return;

#if !SYSTEM(TV)
	UILocalNotification *notification = [[UILocalNotification alloc] init];

	NSUInteger minutes = ceil(_allowedBackgroundTime / 60.);

	if (minutes == 1)
		notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"You have been disconnected due to 1 minute of inactivity.", "Disconnected due to 1 minute of inactivity alert message"), minutes];
	else if (minutes > 1)
		notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"You have been disconnected due to %u minutes of inactivity.", "Disconnected due to inactivity alert message"), minutes];
	else notification.alertBody = NSLocalizedString(@"You have been disconnected.", "Disconnected alert message");

	notification.alertAction = NSLocalizedString(@"Open", "Open button title");
	notification.soundName = UILocalNotificationDefaultSoundName;

	[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
#endif
}

- (void) _showRemainingTimeAlert {
	if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
		return;

	if (![[CQSettingsController settingsController] boolForKey:@"CQBackgroundTimeRemainingAlert"])
		return;

	if (![self _anyConnectedOrConnectingConnections])
		return;

#if !SYSTEM(TV)
	if (_timeRemainingLocalNotifiction) {
		[[UIApplication sharedApplication] cancelLocalNotification:_timeRemainingLocalNotifiction];
	}

	UILocalNotification *notification = [[UILocalNotification alloc] init];

	notification.alertBody = NSLocalizedString(@"You will be disconnected in less than a minute due to inactivity.", "Disconnected in less than a minute alert message");
	notification.alertAction = NSLocalizedString(@"Open", "Open button title");
	notification.soundName = UILocalNotificationDefaultSoundName;

	[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
	_timeRemainingLocalNotifiction = notification;
#endif
}

- (void) _disconnectNonMultitaskingConnections {
	for (MVChatConnection *connection in _connections) {
		if (connection.multitaskingSupported)
			continue;

		BOOL wasConnected = connection.connected || connection.status == MVChatConnectionConnectingStatus;
		NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
		[connection disconnectWithReason:attributedString];
		if (wasConnected)
			[connection _setStatus:MVChatConnectionSuspendedStatus];
	}
}

- (void) _disconnectForSuspend {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

#if !SYSTEM(TV)
	if (_timeRemainingLocalNotifiction) {
		[[UIApplication sharedApplication] cancelLocalNotification:_timeRemainingLocalNotifiction];
		_timeRemainingLocalNotifiction = nil;
	}
#endif

	[self _showDisconnectedAlert];

	[self saveConnections];

	for (MVChatConnection *connection in _connections) {
		BOOL wasConnected = connection.connected || connection.status == MVChatConnectionConnectingStatus;
		NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
		[connection disconnectWithReason:attributedString];
		if (wasConnected)
			[connection _setStatus:MVChatConnectionSuspendedStatus];
	}
}

- (void) _didEnterBackground {
	if (!_automaticallySetConnectionAwayStatus)
		_automaticallySetConnectionAwayStatus = [[NSMutableSet alloc] init];

	NSTimeInterval remainingTime = [UIApplication sharedApplication].backgroundTimeRemaining;
	NSTimeInterval multitaskingTimeout = [[CQSettingsController settingsController] doubleForKey:@"CQMultitaskingTimeout"];

	remainingTime = fmin(remainingTime, multitaskingTimeout);

	_allowedBackgroundTime = remainingTime;

	[self _disconnectNonMultitaskingConnections];

	if (remainingTime <= 10.) {
		if (multitaskingTimeout > 10.)
			[self _showNoTimeRemainingAlert];
		[self _disconnectForSuspend];
		return;
	}

	remainingTime -= 10.;
	[self performSelector:@selector(_disconnectForSuspend) withObject:nil afterDelay:remainingTime];

	if (_allowedBackgroundTime >= 90.) {
		remainingTime -= 60.;
		[self performSelector:@selector(_showRemainingTimeAlert) withObject:nil afterDelay:remainingTime];
	}

	NSString *defaultAwayMessage = [[CQSettingsController settingsController] stringForKey:@"CQAwayStatus"];
	if ([[CQSettingsController settingsController] boolForKey:@"CQAutoAwayWhenMultitasking"] && defaultAwayMessage.length) {
		for (MVChatConnection *connection in _connections) {
			if (!connection.awayStatusMessage.length) {
				connection.awayStatusMessage = [[NSAttributedString alloc] initWithString:defaultAwayMessage];
				[_automaticallySetConnectionAwayStatus addObject:connection];
			}
		}
	}
}

- (void) _willEnterForeground {
	if (_backgroundTask == UIBackgroundTaskInvalid)
		[CQColloquyApplication sharedApplication].resumeDate = [NSDate date];

	for (MVChatConnection *connection in _connections) {
		if (connection.status == MVChatConnectionSuspendedStatus)
			[connection connectAppropriately];

		if ([_automaticallySetConnectionAwayStatus containsObject:connection])
			connection.awayStatusMessage = nil;
	}

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_disconnectForSuspend) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_showRemainingTimeAlert) object:nil];

#if !SYSTEM(TV)
	_timeRemainingLocalNotifiction = nil;
#endif

	_automaticallySetConnectionAwayStatus = nil;
}

- (void) _backgroundTaskExpired {
	[[CQColloquyApplication sharedApplication] submitRunTime];

	[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
	_backgroundTask = UIBackgroundTaskInvalid;
}

- (void) _gotRawConnectionMessage:(NSNotification *) notification {
	if (!_shouldLogRawMessagesToConsole)
		return;

	MVChatConnection *connection = notification.object;
	NSString *message = [notification userInfo][@"message"];
	BOOL outbound = [[notification userInfo][@"outbound"] boolValue];

	if (connection.bouncerType == MVChatConnectionColloquyBouncer)
		NSLog(@"%@ (via %@): %@ %@", connection.server, connection.bouncerServer, (outbound ? @"<<" : @">>"), message);
	else NSLog(@"%@: %@ %@", connection.server, (outbound ? @"<<" : @">>"), message);
}

- (BOOL) _shouldDisableIdleTimer {
#if !SYSTEM(TV)
	if ([UIDevice currentDevice].batteryState >= UIDeviceBatteryStateCharging)
		return YES;
	return ([self _anyConnectedOrConnectingConnections] && [[CQSettingsController settingsController] boolForKey:@"CQIdleTimerDisabled"]);
#else
	return YES;
#endif
}

- (void) _gotConnectionError:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
	alertView.title = connection.displayName;
	alertView.message = notification.userInfo[@"message"];

	[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Okay", @"Okay button title") style:UIAlertActionStyleCancel handler:NULL]];

	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertView animated:YES completion:NULL];
}

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	if (connection.consoleOnLaunch)
		(void)[[CQChatOrderingController defaultController] consoleViewControllerForConnection:connection ifExists:NO];

	[UIApplication sharedApplication].idleTimerDisabled = [self _shouldDisableIdleTimer];
#if !SYSTEM(TV)
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
#endif

	if ([UIDevice currentDevice].multitaskingSupported) {
		if (_backgroundTask == UIBackgroundTaskInvalid)
			_backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{ [self _backgroundTaskExpired]; }];
	}

	[connection removePersistentInformationObjectForKey:@"pushState"];

	NSMutableArray <NSString *> *rooms = [connection.automaticJoinedRooms mutableCopy];
	if (!rooms)
		rooms = [[NSMutableArray alloc] init];

	NSArray <NSString *> *previousRooms = [connection persistentInformationObjectForKey:@"previousRooms"];
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
		connection.bouncerDeviceIdentifier = [CQAnalyticsController defaultController].uniqueIdentifier;

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

		[connection sendCommand:command withArguments:[[NSAttributedString alloc] initWithString:arguments]];
	}

	for (NSUInteger i = 0; i < rooms.count; i++) {
		NSString *room = [connection properNameForChatRoomNamed:rooms[i]];
		NSString *password = [[CQKeychain standardKeychain] passwordForServer:connection.uniqueIdentifier area:room];

		if (password.length) {
			room = [NSString stringWithFormat:@"%@ %@", room, password];
			rooms[i] = room;
		}
	}

	[connection joinChatRoomsNamed:rooms];

	if (connection.bouncerType == MVChatConnectionColloquyBouncer && connection.automaticCommands.count && rooms.count)
		[connection sendRawMessage:@"BOUNCER autocommands stop"];
}

- (void) _didConnectOrDidNotConnect:(NSNotification *) notification {
#if !SYSTEM(TV)
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[[CQColloquyApplication sharedApplication] updateAppShortcuts];
#endif
}

- (void) _didNotConnect:(NSNotification *) notification {
	[self _didConnectOrDidNotConnect:notification];

	MVChatConnection *connection = notification.object;
	BOOL userDisconnected = [notification.userInfo[@"userDisconnected"] boolValue];
	BOOL tryBouncerFirst = [[connection persistentInformationObjectForKey:@"tryBouncerFirst"] boolValue];

	[connection removePersistentInformationObjectForKey:@"tryBouncerFirst"];

	if (!userDisconnected && tryBouncerFirst) {
		[connection connect];
		return;
	}

	if ([UIDevice currentDevice].multitaskingSupported && connection.waitingToReconnect) {
		if (ABS([connection.nextReconnectAttemptDate timeIntervalSinceNow]) >= [UIApplication sharedApplication].backgroundTimeRemaining) {
			[connection cancelPendingReconnectAttempts];
			[connection _setStatus:MVChatConnectionSuspendedStatus];
		}
	}

	[UIApplication sharedApplication].idleTimerDisabled = [self _shouldDisableIdleTimer];

	[self _possiblyEndBackgroundTaskSoon];

	if (connection.server.length && (connection.reconnectAttemptCount > 0 || userDisconnected || connection.serverError.domain == MVChatConnectionErrorDomain))
		return;

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];

	if (!connection.server.length) {
		alert.title = connection.displayName;
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"No server found for %@.", @"No server found for %@. alert message"), connection.displayName];

		[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = NSLocalizedString(@"irc.server.com", @"irc.server.com placeholder text");
		}];

		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			connection.server = alert.textFields.firstObject.text;

			[connection cancelPendingReconnectAttempts];
			[connection connect];
		}]];
	} else if (connection.directConnection) {
		alert.title = NSLocalizedString(@"Can't Connect to Server", @"Can't Connect to Server alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Can't connect to the server \"%@\".", @"Cannot connect alert message"), connection.displayName];

		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Help", @"Help button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[CQColloquyApplication sharedApplication] showHelp:nil];
		}]];
	} else {
		alert.title = NSLocalizedString(@"Can't Connect to Bouncer", @"Can't Connect to Bouncer alert title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Can't connect to the server \"%@\" via \"%@\". Would you like to connect directly?", @"Connect directly alert message"), connection.displayName, connection.bouncerSettings.displayName];

		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[connection connectDirectly];
		}]];
	}

	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:NULL];
}

- (void) _didConnect:(NSNotification *) notification {
	[self _didConnectOrDidNotConnect:notification];

	MVChatConnection *connection = notification.object;
	[connection removePersistentInformationObjectForKey:@"tryBouncerFirst"];

#if !TARGET_IPHONE_SIMULATOR
	id <NSObject> activityToken = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated reason:[NSString stringWithFormat:@"%@ is open and connected", connection.displayName]];
	[_activityTokens setObject:activityToken forKey:connection];
#endif

	if (!connection.directConnection)
		connection.temporaryDirectConnection = NO;

	// re-set the away status to be sent after connect; this only occurs in cases where we lose device connectivity
	// (because we go into a tunnel or something).
	if (connection.awayStatusMessage.length) {
		connection.awayStatusMessage = connection.awayStatusMessage;

		[_automaticallySetConnectionAwayStatus removeObject:self];
	}
}

- (void) _didDisconnect:(NSNotification *) notification {
	[UIApplication sharedApplication].idleTimerDisabled = [self _shouldDisableIdleTimer];
	[[CQColloquyApplication sharedApplication] updateAppShortcuts];

	MVChatConnection *connection = notification.object;
	[connection removePersistentInformationObjectForKey:@"tryBouncerFirst"];

#if !TARGET_IPHONE_SIMULATOR
	id <NSObject> activityToken = [_activityTokens objectForKey:connection];
	[[NSProcessInfo processInfo] endActivity:activityToken];
	[_activityTokens removeObjectForKey:connection];
#endif

	[self _possiblyEndBackgroundTaskSoon];
}

- (void) _userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	[UIApplication sharedApplication].idleTimerDisabled = [self _shouldDisableIdleTimer];

#if !SYSTEM(TV)
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQIndexInSpotlight"])
		[self indexConnectionsInSpotlight];
	else [self removeConnectionsIndexfromSpotlight];
#endif
}

- (void) _batteryStateChanged {
	[UIApplication sharedApplication].idleTimerDisabled = [self _shouldDisableIdleTimer];
}

- (void) _deviceTokenRecieved:(NSNotification *) notification {
	for (MVChatConnection *connection in _connections)
		[connection sendPushNotificationCommands]; 
}

- (void) _nicknamePasswordRequested:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
	alertView.title = NSLocalizedString(@"Serivces Password", @"Serivces Password alert title");
	alertView.message = connection.displayName;

	[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
	[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Identify", @"Identify button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSString *password = alertView.textFields.firstObject.text;
		connection.nicknamePassword = password;
		[connection savePasswordsToKeychain];
	}]];

	[alertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = NSLocalizedString(@"Password", @"Password placeholder");
		textField.secureTextEntry = YES;
	}];

	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertView animated:YES completion:NULL];
}

- (void) _serverPasswordRequested:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
	alertView.title = NSLocalizedString(@"Serivces Password", @"Serivces Password alert title");
	alertView.message = connection.displayName;
	
	[alertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = NSLocalizedString(@"Username", @"Username connection setting label");
		textField.text = connection.username;
	}];
	[alertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = NSLocalizedString(@"Password", @"Password placeholder");
		textField.secureTextEntry = YES;
	}];

	[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
	[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Identify", @"Identify button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSString *username = alertView.textFields.firstObject.text;
		NSString *password = alertView.textFields.lastObject.text;

		BOOL shouldSendUserInPass = username.length && connection.username.length && ![connection.username isEqualToString:username];
		if (shouldSendUserInPass) {
			connection.username = username;
			[connection sendRawMessageImmediatelyWithFormat:@"PASS %@:%@", username, password];
		} else [connection sendRawMessageImmediatelyWithFormat:@"PASS %@", password];

		[connection savePasswordsToKeychain];
	}]];
	
	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertView animated:YES completion:NULL];
}

- (void) _errorOccurred:(NSNotification *) notification {
	NSError *error = notification.userInfo[@"error"];

	MVChatConnection *connection = notification.object;
	NSMapTable *errorToAlertMappingsForConnection = [_connectionToErrorToAlertMap objectForKey:connection];
	if (!errorToAlertMappingsForConnection) {
		errorToAlertMappingsForConnection = [NSMapTable strongToStrongObjectsMapTable];
		[_connectionToErrorToAlertMap setObject:errorToAlertMappingsForConnection forKey:connection];
	}
	
	UIAlertController *alert = [errorToAlertMappingsForConnection objectForKey:@(error.code)];
	if (alert) return;
	
	NSString *errorTitle = nil;
	switch (error.code) {
		case MVChatConnectionRoomIsFullError:
		case MVChatConnectionInviteOnlyRoomError:
		case MVChatConnectionBannedFromRoomError:
		case MVChatConnectionIdentifyToJoinRoomError:
			errorTitle = NSLocalizedString(@"Can't Join Room", @"Can't join room alert title");
			break;
		case MVChatConnectionRoomPasswordIncorrectError:
			errorTitle = NSLocalizedString(@"Room Password", @"Room Password alert title");
			break;
		case MVChatConnectionCantSendToRoomError:
			errorTitle = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");
			break;
		case MVChatConnectionCantChangeUsedNickError:
			errorTitle = NSLocalizedString(@"Nickname in use", "Nickname in use alert title");
			break;
		case MVChatConnectionCantChangeNickError:
		case MVChatConnectionErroneusNicknameError:
			errorTitle = NSLocalizedString(@"Can't Change Nickname", "Can't change nickname alert title");
			break;
		case MVChatConnectionRoomDoesNotSupportModesError:
			errorTitle = NSLocalizedString(@"Room Modes Unsupported", "Room modes not supported alert title");
			break;
		case MVChatConnectionNickChangedByServicesError:
			errorTitle = NSLocalizedString(@"Nickname Changed", "Nick changed by server alert title");
			break;
		case MVChatConnectionTLSError:
			errorTitle = NSLocalizedString(@"TLS Error", @"TLS Error");
			break;
		case MVChatConnectionServerPasswordIncorrectError:
			errorTitle = NSLocalizedString(@"Server Password", @"Server Password alert title");
	}

	if (!errorTitle) return;

	NSString *roomName = error.userInfo[@"room"];
	MVChatRoom *room = (roomName ? [connection chatRoomWithName:roomName] : nil);

	NSString *errorMessage = nil;
	BOOL addedDefaultAction = NO;

	alert = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];

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
			addedDefaultAction = YES;
			errorMessage = [NSString stringWithFormat:@"%@ - %@", room.displayName, connection.displayName];

			[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"Password", @"Password placeholder");
				textField.secureTextEntry = YES;
			}];

			[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Join", @"Join button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				NSString *password = alert.textFields.firstObject.text;

				[[CQKeychain standardKeychain] setPassword:password forServer:connection.uniqueIdentifier area:roomName];
				
				[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:room.name andConnection:connection];
				
				if (password.length)
					[connection joinChatRoomNamed:roomName withPassphrase:password];
				else [connection joinChatRoomNamed:roomName];
			}]];
			
			break;
		case MVChatConnectionCantSendToRoomError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't send messages to \"%@\" due to some room restriction.", "Cant send message alert message"), room.displayName];
			break;
		case MVChatConnectionRoomDoesNotSupportModesError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The room \"%@\" on \"%@\" doesn't support modes.", "Room does not support modes alert message"), room.displayName, connection.displayName];
			break;
		case MVChatConnectionIdentifyToJoinRoomError:
			addedDefaultAction = YES;
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Identify with network services to join \"%@\" on \"%@\".", "Identify to join room alert message"), room.displayName, connection.displayName];

			[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Identify", @"Identify button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				UIAlertController *nextAlertView = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
				nextAlertView.title = NSLocalizedString(@"Serivces Password", @"Serivces Password alert title");
				nextAlertView.message = connection.displayName;

				[nextAlertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
					textField.placeholder = NSLocalizedString(@"Password", @"Password placeholder");
					textField.secureTextEntry = YES;
				}];

				[nextAlertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:NULL]];
				[nextAlertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Identify", @"Identify button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *nextAction) {
					NSString *password = nextAlertView.textFields.firstObject.text;
					connection.nicknamePassword = password;
					[connection savePasswordsToKeychain];
				}]];
			}]];

			break;
		case MVChatConnectionCantChangeNickError:
			if (room) errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't change your nickname while in \"%@\" on \"%@\". Leave the room and try again.", "Can't change nick because of room alert message" ), room.displayName, connection.displayName];
			else errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Can't change nicknames too fast on \"%@\", wait and try again.", "Can't change nick too fast alert message"), connection.displayName];
			break;
		case MVChatConnectionCantChangeUsedNickError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Services won't let you change your nickname to \"%@\" on \"%@\".", "Services won't let you change your nickname alert message"), error.userInfo[@"newnickname"], connection.displayName];
			break;
		case MVChatConnectionNickChangedByServicesError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Your nickname is being changed on \"%@\" because you didn't identify.", "Username was changed by server alert message"), connection.displayName];
			break;
		case MVChatConnectionTLSError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to securely connect to \"%@\".", @"Unable to connect to server over TLS message"), connection.displayName];
			break;
		case MVChatConnectionServerPasswordIncorrectError:
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Invalid password for \"%@\".", "Invalid password for server alert message"), connection.displayName];
			break;
	}

	if (!errorMessage)
		errorMessage = error.localizedDescription;

	if (!errorMessage) return;

	alert.title = errorTitle;
	alert.message = errorMessage;

	[errorToAlertMappingsForConnection setObject:alert forKey:@(error.code)];

	if (!addedDefaultAction) {
		[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Help", @"Help button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[CQColloquyApplication sharedApplication] showHelp:nil];
		}]];
	}

	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:NULL];
}

#pragma mark -

- (MVChatConnection *__nullable) _chatConnectionWithDictionaryRepresentation:(NSDictionary *) info {
	MVChatConnection *connection = nil;

	MVChatConnectionType type = MVChatConnectionIRCType;
	if ([info[@"type"] isEqualToString:@"icb"])
		type = MVChatConnectionICBType;
	else if ([info[@"type"] isEqualToString:@"irc"])
		type = MVChatConnectionIRCType;
	else if ([info[@"type"] isEqualToString:@"silc"])
		type = MVChatConnectionSILCType;
	else if ([info[@"type"] isEqualToString:@"xmpp"])
		type = MVChatConnectionXMPPType;

	if (info[@"url"])
		connection = [[MVChatConnection alloc] initWithURL:[NSURL URLWithString:info[@"url"]]];
	else connection = [[MVChatConnection alloc] initWithServer:info[@"server"] type:type port:[info[@"port"] unsignedShortValue] user:info[@"nickname"]];

	if (!connection)
		return nil;

	if (info[@"uniqueIdentifier"]) connection.uniqueIdentifier = info[@"uniqueIdentifier"];

	NSMutableDictionary *persistentInformation = [[NSMutableDictionary alloc] init];
	[persistentInformation addEntriesFromDictionary:info[@"persistentInformation"]];

	if (info[@"automatic"])
		persistentInformation[@"automatic"] = info[@"automatic"];
	if (info[@"multitasking"])
		persistentInformation[@"multitasking"] = info[@"multitasking"];
	else persistentInformation[@"multitasking"] = @(YES);
	if (info[@"push"])
		persistentInformation[@"push"] = info[@"push"];
	if (info[@"rooms"])
		persistentInformation[@"rooms"] = info[@"rooms"];
	if (info[@"previousRooms"])
		persistentInformation[@"previousRooms"] = info[@"previousRooms"];
	if (info[@"description"])
		persistentInformation[@"description"] = info[@"description"];
	if (info[@"commands"] && ((NSString *)info[@"commands"]).length)
		persistentInformation[@"commands"] = [info[@"commands"] componentsSeparatedByString:@"\n"];
	if (info[@"bouncer"])
		persistentInformation[@"bouncerIdentifier"] = info[@"bouncer"];

	connection.persistentInformation = persistentInformation;

	connection.proxyType = [info[@"proxy"] unsignedLongValue];
	connection.secure = [info[@"secure"] boolValue];

	if (info[@"requestsSASL"])
		connection.requestsSASL = [info[@"requestsSASL"] boolValue];

	if ([info[@"encoding"] unsignedLongValue])
		connection.encoding = [info[@"encoding"] unsignedLongValue];
	else connection.encoding = [MVChatConnection defaultEncoding];

	if (!CFStringIsEncodingAvailable(CFStringConvertNSStringEncodingToEncoding(connection.encoding)))
		connection.encoding = [MVChatConnection defaultEncoding];

	if (info[@"realName"]) connection.realName = info[@"realName"];
	if (info[@"nickname"]) connection.nickname = info[@"nickname"];
	if (info[@"username"]) connection.username = info[@"username"];
	if (info[@"alternateNicknames"])
		connection.alternateNicknames = info[@"alternateNicknames"];

	[connection loadPasswordsFromKeychain];

	if (info[@"nicknamePassword"]) connection.nicknamePassword = info[@"nicknamePassword"];
	if (info[@"password"]) connection.password = info[@"password"];

	if (info[@"bouncerConnectionIdentifier"]) connection.bouncerConnectionIdentifier = info[@"bouncerConnectionIdentifier"];

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

#if !SYSTEM(TV)
	if ((!bouncerSettings || bouncerSettings.pushNotifications) && connection.pushNotifications)
		[[CQColloquyApplication sharedApplication] registerForPushNotifications];
#endif

	return connection;
}

- (NSMutableDictionary *) _dictionaryRepresentationForConnection:(MVChatConnection *) connection {
	NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:15];

	NSMutableDictionary *persistentInformation = [connection.persistentInformation mutableCopy];
	if (persistentInformation[@"automatic"])
		info[@"automatic"] = persistentInformation[@"automatic"];
	if (persistentInformation[@"multitasking"])
		info[@"multitasking"] = persistentInformation[@"multitasking"];
	if (persistentInformation[@"push"])
		info[@"push"] = persistentInformation[@"push"];
	if ([persistentInformation[@"rooms"] count])
		info[@"rooms"] = persistentInformation[@"rooms"];
	if ([persistentInformation[@"description"] length])
		info[@"description"] = persistentInformation[@"description"];
	if ([persistentInformation[@"commands"] count])
		info[@"commands"] = [persistentInformation[@"commands"] componentsJoinedByString:@"\n"];
	if (persistentInformation[@"bouncerIdentifier"])
		info[@"bouncer"] = persistentInformation[@"bouncerIdentifier"];

	[persistentInformation removeObjectForKey:@"automatic"];
	[persistentInformation removeObjectForKey:@"multitasking"];
	[persistentInformation removeObjectForKey:@"push"];
	[persistentInformation removeObjectForKey:@"pushState"];
	[persistentInformation removeObjectForKey:@"rooms"];
	[persistentInformation removeObjectForKey:@"previousRooms"];
	[persistentInformation removeObjectForKey:@"description"];
	[persistentInformation removeObjectForKey:@"commands"];
	[persistentInformation removeObjectForKey:@"bouncerIdentifier"];

	NSDictionary *chatState = [[CQChatController defaultController] persistentStateForConnection:connection];
	if (chatState.count)
		info[@"chatState"] = chatState;

	if (persistentInformation.count)
		info[@"persistentInformation"] = persistentInformation;

	info[@"wasConnected"] = @(connection.connected);

	NSSet *joinedRooms = connection.joinedChatRooms;
	if (connection.connected && joinedRooms.count) {
		NSMutableArray *previousJoinedRooms = [[NSMutableArray alloc] init];

		for (MVChatRoom *room in joinedRooms) {
			if (room && room.name && !(room.modes & MVChatRoomInviteOnlyMode))
				[previousJoinedRooms addObject:room.name];
		}

		[previousJoinedRooms removeObjectsInArray:info[@"rooms"]];

		if (previousJoinedRooms.count)
			info[@"previousRooms"] = previousJoinedRooms;
	}

	info[@"uniqueIdentifier"] = connection.uniqueIdentifier;
	if (connection.server) info[@"server"] = connection.server;
	info[@"type"] = connection.urlScheme;
	info[@"secure"] = @(connection.secure);
	info[@"requestsSASL"] = @(connection.requestsSASL);
	info[@"proxy"] = @(connection.proxyType);
	info[@"encoding"] = @(connection.encoding);
	info[@"port"] = @(connection.serverPort);
	if (connection.realName) info[@"realName"] = connection.realName;
	if (connection.username) info[@"username"] = connection.username;
	if (connection.preferredNickname) info[@"nickname"] = connection.preferredNickname;
	if (connection.bouncerConnectionIdentifier) info[@"bouncerConnectionIdentifier"] = connection.bouncerConnectionIdentifier;

	if (connection.alternateNicknames.count)
		info[@"alternateNicknames"] = connection.alternateNicknames;

	return info;
}

- (void) _loadConnectionList {
	if (_loadedConnections)
		return;

	_loadedConnections = YES;

#if !defined(CQ_GENERATING_SCREENSHOTS)
	NSArray <NSDictionary *> *bouncers = [[CQSettingsController settingsController] arrayForKey:@"CQChatBouncers"];
#else
	NSArray <NSDictionary *> *bouncers = nil; // don't show any bouncers in app store screenshots
#endif
	for (NSDictionary *info in bouncers) {
		CQBouncerSettings *settings = [[CQBouncerSettings alloc] initWithDictionaryRepresentation:info];
		if (!settings)
			continue;

		[_bouncers addObject:settings];

		NSMutableArray *bouncerChatConnections = [[NSMutableArray alloc] initWithCapacity:10];
		_bouncerChatConnections[settings.identifier] = bouncerChatConnections;

		NSArray <MVChatConnection *> *connections = info[@"connections"];
		for (NSDictionary *connectionInfo in connections) {
			MVChatConnection *connection = [self _chatConnectionWithDictionaryRepresentation:connectionInfo];
			if (!connection)
				continue;

			[bouncerChatConnections addObject:connection];
			[_connections addObject:connection];

			if (info[@"chatState"])
				[[CQChatController defaultController] restorePersistentState:info[@"chatState"] forConnection:connection];
		}
	}

#if !defined(CQ_GENERATING_SCREENSHOTS)
	NSArray <NSDictionary *> *connections = [[CQSettingsController settingsController] arrayForKey:@"MVChatBookmarks"];
#else
	static NSString *const demoText = @"[{\"automatic\": 1,\"chatState\": {\"chatControllers\": [{\"active\": true,\"class\": \"CQChatRoomController\",\"joined\": true,\"messages\": [{\"identifier\": \"3\",\"message\": \"hi colloquyUser\",\"type\": \"message\",\"user\": \"kijiro\",},{\"identifier\": \"4\",\"message\": \"Hello!\",\"type\": \"message\",\"user\": \"colloquyUser\",}],\"room\": \"#colloquy-mobile\",},{\"active\": false,\"class\": \"CQChatRoomController\",\"joined\": false,\"messages\": [{\"identifier\": \"5\",\"message\": \"[#colloquy] Welcome to\",\"type\": \"message\",\"user\": \"ChanServ\",}],\"room\": \"#colloquy\",},{\"class\": \"CQDirectChatController\",\"user\": \"jane\"}],},\"description\": \"Freenode\",\"encoding\": 4,\"multitasking\": true,\"nickname\": \"colloquyUser\",\"persistentInformation\": {\"tryBouncerFirst\": false,},\"port\": 6667,\"previousRooms\": [\"#colloquy-mobile\"],\"proxy\": 1852796485,\"realName\": \"Colloquy User\",\"requestsSASL\": false,\"secure\": 0,\"server\": \"localhost\",\"type\": \"irc\",\"uniqueIdentifier\": \"SNJNFA95N55\",\"username\": \"colloquyUser\",\"wasConnected\": true,},{\"automatic\": 1,\"chatState\": {\"chatControllers\": [{\"active\": true,\"class\": \"CQChatRoomController\",\"joined\": true,\"messages\": [{\"identifier\": \"7\",\"message\": \"Everyone: I'm doing this thing...\",\"type\": \"message\",\"user\": \"Someone\",},{\"identifier\": \"8\",\"message\": \"Someone: uh\",\"type\": \"message\",\"user\": \"Everyone\",},],\"room\": \"#chris\",},{\"active\": false,\"class\": \"CQChatRoomController\",\"joined\": false,\"messages\": [],\"room\": \"#theshed\",},],},\"description\": \"GeekShed\",\"encoding\": 4,\"multitasking\": true,\"nickname\": \"colloquyUser\",\"persistentInformation\": {\"tryBouncerFirst\": false,},\"port\": 6667,\"previousRooms\": [\"#chris\",\"theshed\"],\"proxy\": 1852796485,\"realName\": \"Colloquy User\",\"requestsSASL\": false,\"secure\": 0,\"server\": \"localhost\",\"type\": \"irc\",\"uniqueIdentifier\": \"SNJNFA95N55\",\"username\": \"colloquyUser\",\"wasConnected\": true,}]";
	NSArray <NSDictionary *> *connections = [NSJSONSerialization JSONObjectWithData:[demoText dataUsingEncoding:4] options:0 error:nil];
#endif
	for (NSDictionary *info in connections) {
		MVChatConnection *connection = [self _chatConnectionWithDictionaryRepresentation:info];
		if (!connection)
			continue;

		if (connection.bouncerIdentifier.length)
			continue;

		[_directConnections addObject:connection];
		[_connections addObject:connection];

		if (info[@"chatState"])
			[[CQChatController defaultController] restorePersistentState:info[@"chatState"] forConnection:connection];
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
	}
}

#pragma mark -

- (void) openAllConnections {
	for (MVChatConnection *connection in self.connections) {
		if (!(connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus))
			[connection connect];
	}
}

- (void) closeAllConnections {
	for (MVChatConnection *connection in self.connections) {
		if ((connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus))
			[connection disconnect];
	}
}

- (void) saveConnections {
	if (!_loadedConnections)
		return;

	NSUInteger pushConnectionCount = 0;
	NSUInteger roomCount = 0;

	NSMutableArray *connections = [[NSMutableArray alloc] initWithCapacity:_directConnections.count];
	for (MVChatConnection *connection in _directConnections) {
#if !SYSTEM(TV)
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQIndexInSpotlight"])
			[self _indexConnetionInSpotlight:connection];
#endif

		NSMutableDictionary *connectionInfo = [self _dictionaryRepresentationForConnection:connection];
		if (!connectionInfo)
			continue;

		if (connection.pushNotifications)
			++pushConnectionCount;

		roomCount += connection.knownChatRooms.count;

		[connections addObject:connectionInfo];
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
		}

		if (bouncerConnections.count)
			info[@"connections"] = bouncerConnections;

		[bouncers addObject:info];
	}

	[[CQSettingsController settingsController] setObject:bouncers forKey:@"CQChatBouncers"];
	[[CQSettingsController settingsController] setObject:connections forKey:@"MVChatBookmarks"];
	[[CQSettingsController settingsController] synchronize];

	[[CQAnalyticsController defaultController] setObject:@(roomCount) forKey:@"total-rooms"];
	[[CQAnalyticsController defaultController] setObject:@(pushConnectionCount) forKey:@"total-push-connections"];
	[[CQAnalyticsController defaultController] setObject:@(_connections.count) forKey:@"total-connections"];
	[[CQAnalyticsController defaultController] setObject:@(_bouncers.count) forKey:@"total-bouncers"];
}

- (void) saveConnectionPasswordsToKeychain {
	for (MVChatConnection *connection in _directConnections)
		[connection savePasswordsToKeychain];

	for (CQBouncerSettings *settings in _bouncers) {
		for (MVChatConnection *connection in [self bouncerChatConnectionsForIdentifier:settings.identifier])
			[connection savePasswordsToKeychain];
	}
}

#pragma mark -

#if !SYSTEM(TV)
- (void) _indexConnetionInSpotlight:(MVChatConnection *) connection {
	if (NSClassFromString(@"CSSearchableIndex") == nil)
		return;

	CSSearchableItemAttributeSet *connectionAttributeSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"IRC Server"];
	connectionAttributeSet.identifier = connection.uniqueIdentifier;
	if (connection.displayName.length || connection.server.length)
		connectionAttributeSet.displayName = connectionAttributeSet.title = [NSString stringWithFormat:@"%@ — %@", connection.displayName ?: connection.server, connection.nickname];
	else connectionAttributeSet.displayName = connectionAttributeSet.title = connection.nickname;
	if (connection.displayName.length && connection.server.length)
		connectionAttributeSet.alternateNames = @[ connection.server ];
	connectionAttributeSet.contentType = (__bridge NSString *)kUTTypeMessage;
	connectionAttributeSet.contentTypeTree = @[ (__bridge id)kUTTypeItem, (__bridge id)kUTTypeURL, (__bridge NSString *)kUTTypeMessage ];

	NSMutableArray *items = [NSMutableArray array];
	NSMutableArray *keywords = [@[ @"irc", connection.displayName ?: connection.server ?: @"", connection.nickname ?: @"", connection.username ?: @"", connection.realName ?: @"" ] mutableCopy];
	for (MVChatRoom *chatRoom in connection.knownChatRooms) {
		[keywords addObject:chatRoom.displayName];

		CSSearchableItemAttributeSet *roomAttributeSet = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"IRC Room"];
		roomAttributeSet.identifier = chatRoom.displayName;
		if (connection.displayName.length || connection.server.length)
			roomAttributeSet.displayName = roomAttributeSet.title = [NSString stringWithFormat:@"%@ — %@", connection.displayName ?: connection.server, chatRoom.displayName];
		else roomAttributeSet.displayName = roomAttributeSet.title = chatRoom.displayName;
		roomAttributeSet.contentType = (__bridge NSString *)kUTTypeURL;

		CSSearchableItem *roomItem = [[CSSearchableItem alloc] initWithUniqueIdentifier:chatRoom.uniqueIdentifier domainIdentifier:connection.server attributeSet:roomAttributeSet];
		[items addObject:roomItem];
	}
	connectionAttributeSet.keywords = keywords;

	CSSearchableItem *connectionItem = [[CSSearchableItem alloc] initWithUniqueIdentifier:connection.uniqueIdentifier domainIdentifier:connection.server attributeSet:connectionAttributeSet];
	[items addObject:connectionItem];

	[[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:items completionHandler:nil];
}

- (void) indexConnectionsInSpotlight {
	for (MVChatConnection *connection in _directConnections)
		[self _indexConnetionInSpotlight:connection];
}

- (void) removeConnectionsIndexfromSpotlight {
	if (NSClassFromString(@"CSSearchableIndex") == nil)
		return;

	[[CSSearchableIndex defaultSearchableIndex] deleteAllSearchableItemsWithCompletionHandler:^(NSError * _Nullable error) {
		if (error) {
			NSString *title = NSLocalizedString(@"Unknown Error", @"Unknown Error error title");
			NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Unable to remove index from Spotlight: %@", @"search deletion failed error message"), error.localizedDescription];
			if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
				UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
				alertView.title = title;
				alertView.message = message;
				
				[alertView addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Okay", @"Okay") style:UIAlertActionStyleCancel handler:NULL]];

				[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertView animated:YES completion:NULL];
			} else {
				UILocalNotification *notification = [[UILocalNotification alloc] init];
				notification.alertTitle = title;
				notification.alertBody = message;

				[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
			}
		}
	}];
}
#endif

#pragma mark -

- (NSSet *) connectedConnections {
	NSMutableSet *result = [[NSMutableSet alloc] initWithCapacity:_connections.count];

	for (MVChatConnection *connection in _connections)
		if (connection.connected)
			[result addObject:connection];

	return result;
}

- (MVChatConnection *__nullable) connectionForUniqueIdentifier:(NSString *) identifier {
	for (MVChatConnection *connection in _connections)
		if ([connection.uniqueIdentifier isEqualToString:identifier])
			return connection;
	return nil;
}

- (MVChatConnection *__nullable) connectionForServerAddress:(NSString *) address {
	NSArray <MVChatConnection *> *connections = [self connectionsForServerAddress:address];
	return connections.firstObject;
}

- (NSArray <MVChatConnection *> *) connectionsForServerAddress:(NSString *) address {
	NSMutableArray <MVChatConnection *> *result = [NSMutableArray arrayWithCapacity:_connections.count];

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
		[[CQSettingsController settingsController] setObject:connection.nickname forKey:@"CQDefaultNickname"];
		[[CQSettingsController settingsController] setObject:connection.realName forKey:@"CQDefaultRealName"];
	}

	[_directConnections insertObject:connection atIndex:index];
	[_connections addObject:connection];

	NSDictionary *notificationInfo = @{@"connection": connection};
	[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerAddedConnectionNotification object:self userInfo:notificationInfo];

	[self saveConnections];
}

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	MVChatConnection *connection = _directConnections[oldIndex];

	[_directConnections removeObjectAtIndex:oldIndex];
	[_directConnections insertObject:connection atIndex:newIndex];

	NSDictionary *notificationInfo = @{@"connection": connection, @"index": @(newIndex), @"oldIndex": @(oldIndex)};
	[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerMovedConnectionNotification object:self userInfo:notificationInfo];
																																																																																																																																																																																																																																																	
	[self saveConnections];
}

- (void) removeConnection:(MVChatConnection *) connection {
	NSUInteger index = [_directConnections indexOfObjectIdenticalTo:connection];
	if (index != NSNotFound)
		[self removeConnectionAtIndex:index];
}

- (void) removeConnectionAtIndex:(NSUInteger) index {
	MVChatConnection *connection = _directConnections[index];
	if (!connection) return;

	NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
	[connection disconnectWithReason:quitMessageString];

	[_directConnections removeObjectAtIndex:index];
	[_connections removeObject:connection];

	NSDictionary *notificationInfo = @{@"connection": connection, @"index": @(index)};
	[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerRemovedConnectionNotification object:self userInfo:notificationInfo];

	[self saveConnections];
}

#pragma mark -

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex forBouncerIdentifier:(NSString *) identifier {
	NSMutableArray *connections = _bouncerChatConnections[identifier];
	MVChatConnection *connection = connections[oldIndex];

	[connections removeObjectAtIndex:oldIndex];
	[connections insertObject:connection atIndex:newIndex];

	NSDictionary *notificationInfo = @{@"connection": connection, @"index": @(newIndex)};
	[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerMovedConnectionNotification object:self userInfo:notificationInfo];

	[self saveConnections];
}

#pragma mark -

- (CQIgnoreRulesController *) ignoreControllerForConnection:(MVChatConnection *) connection {
	CQIgnoreRulesController *ignoreController = _ignoreControllers[connection.uniqueIdentifier];
	if (ignoreController)
		return ignoreController;

	ignoreController = [[CQIgnoreRulesController alloc] initWithConnection:connection];

	_ignoreControllers[connection.uniqueIdentifier] = ignoreController;

	return ignoreController;
}

#pragma mark -

- (CQBouncerSettings *__nullable) bouncerSettingsForIdentifier:(NSString *) identifier {
	for (CQBouncerSettings *bouncer in _bouncers)
		if ([bouncer.identifier isEqualToString:identifier])
			return bouncer;
	return nil;
}

- (NSArray <MVChatConnection *> *) bouncerChatConnectionsForIdentifier:(NSString *) identifier {
	return _bouncerChatConnections[identifier] ?: @[];
}

#pragma mark -

- (void) refreshBouncerConnectionsWithBouncerSettings:(CQBouncerSettings *) settings {
	CQBouncerConnection *connection = [[CQBouncerConnection alloc] initWithBouncerSettings:settings];
	connection.delegate = self;
	connection.userInfo = @"manual-refresh";

	[_bouncerConnections addObject:connection];

	[connection connect];
}

#pragma mark -

- (void) addBouncerSettings:(CQBouncerSettings *) bouncer {
	NSParameterAssert(bouncer != nil);

	[_bouncers addObject:bouncer];

	NSDictionary *notificationInfo = @{@"bouncerSettings": bouncer};
	[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerAddedBouncerSettingsNotification object:self userInfo:notificationInfo];

	[self refreshBouncerConnectionsWithBouncerSettings:bouncer];
}

- (void) removeBouncerSettings:(CQBouncerSettings *) settings {
	[self removeBouncerSettingsAtIndex:[_bouncers indexOfObjectIdenticalTo:settings]];
}

- (void) removeBouncerSettingsAtIndex:(NSUInteger) index {
	CQBouncerSettings *bouncer = _bouncers[index];

	NSArray <MVChatConnection *> *connections = [self bouncerChatConnectionsForIdentifier:bouncer.identifier];
	for (MVChatConnection *connection in connections) {
		NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
		[connection disconnectWithReason:quitMessageString];
	}

	[_bouncers removeObjectAtIndex:index];
	[_bouncerChatConnections removeObjectForKey:bouncer.identifier];

	NSDictionary *notificationInfo = @{@"bouncerSettings": bouncer, @"index": @(index)};
	[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerRemovedBouncerSettingsNotification object:self userInfo:notificationInfo];

	for (NSInteger i = (connections.count - 1); i >= 0; --i) {
		MVChatConnection *connection = connections[i];
		notificationInfo = @{@"connection": connection, @"index": @(i)};
		[[NSNotificationCenter chatCenter] postNotificationName:CQConnectionsControllerRemovedConnectionNotification object:self userInfo:notificationInfo];
	}
}
@end

NS_ASSUME_NONNULL_END

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@implementation MVChatConnection (CQConnectionsControllerAdditions)
+ (NSString *) defaultNickname {
	NSString *defaultNickname = [[CQSettingsController settingsController] stringForKey:@"CQDefaultNickname"];
	if (defaultNickname.length)
		return defaultNickname;

	static NSString *generatedNickname;
	if (!generatedNickname) {
		NSCharacterSet *badCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"] invertedSet];
		NSArray <NSString *> *components = [[UIDevice currentDevice].name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		for (__strong NSString *compontent in components) {
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
}

+ (NSString *) defaultRealName {
	NSString *defaultRealName = [[CQSettingsController settingsController] stringForKey:@"CQDefaultRealName"];
	if (defaultRealName.length)
		return defaultRealName;

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
	return [[CQSettingsController settingsController] stringForKey:@"JVQuitMessage"];
}

+ (NSStringEncoding) defaultEncoding {
	return [[CQSettingsController settingsController] integerForKey:@"JVChatEncoding"];
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

- (void) setAutomaticJoinedRooms:(NSArray <NSString *> *) rooms {
	NSParameterAssert(rooms != nil);

	[self setPersistentInformationObject:rooms forKey:@"rooms"];
}

- (NSArray <NSString *> *) automaticJoinedRooms {
	return [self persistentInformationObjectForKey:@"rooms"];
}

#pragma mark -

- (void) setAutomaticCommands:(NSArray <NSString *> *) commands {
	NSParameterAssert(commands != nil);

	[self setPersistentInformationObject:commands forKey:@"commands"];
}

- (NSArray <NSString *> *) automaticCommands {
	return [self persistentInformationObjectForKey:@"commands"];
}

#pragma mark -

- (void) setAutomaticallyConnect:(BOOL) autoConnect {
	if (autoConnect == self.automaticallyConnect)
		return;

	[self setPersistentInformationObject:@(autoConnect) forKey:@"automatic"];
}

- (BOOL) automaticallyConnect {
	return [[self persistentInformationObjectForKey:@"automatic"] boolValue];
}

#pragma mark -

- (void) setConsoleOnLaunch:(BOOL) consoleOnLaunch {
	if (consoleOnLaunch == self.consoleOnLaunch)
		return;

	[self setPersistentInformationObject:@(consoleOnLaunch) forKey:@"console-on-launch"];
}

- (BOOL) consoleOnLaunch {
	return [[self persistentInformationObjectForKey:@"console-on-launch"] boolValue];
}

#pragma mark -

- (void) setMultitaskingSupported:(BOOL) multitaskingSupported {
	if (multitaskingSupported == self.multitaskingSupported)
		return;

	[self setPersistentInformationObject:@(multitaskingSupported) forKey:@"multitasking"];
}

- (BOOL) multitaskingSupported {
	return [[self persistentInformationObjectForKey:@"multitasking"] boolValue];
}

#pragma mark -

- (void) setPushNotifications:(BOOL) push {
	if (push == self.pushNotifications)
		return;

	[self setPersistentInformationObject:@(push) forKey:@"push"];
	
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

	[self setPersistentInformationObject:@(direct) forKey:@"direct"];
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

- (CQIgnoreRulesController *) ignoreController {
	return [[CQConnectionsController defaultController] ignoreControllerForConnection:self];
}

#pragma mark -

- (void) savePasswordsToKeychain {
	[[CQKeychain standardKeychain] setPassword:self.nicknamePassword forServer:self.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", self.preferredNickname]];
	[[CQKeychain standardKeychain] setPassword:self.password forServer:self.uniqueIdentifier area:@"Server"];
}

- (void) loadPasswordsFromKeychain {
	NSString *password = nil;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", self.preferredNickname]]) && password.length)
		self.nicknamePassword = password;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier area:@"Server"]) && password.length)
		self.password = password;
}

#pragma mark -

- (void) connectAppropriately {
	[self setPersistentInformationObject:@(YES) forKey:@"tryBouncerFirst"];

	[self connect];
}

- (void) connectDirectly {
	[self removePersistentInformationObjectForKey:@"tryBouncerFirst"];

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
		[self setPersistentInformationObject:@(YES) forKey:@"pushState"];

		[self sendRawMessageWithFormat:@"PUSH add-device %@ :%@", deviceToken, [UIDevice currentDevice].name];

		[self sendRawMessage:@"PUSH service colloquy.mobi 7906"];

		[self sendRawMessageWithFormat:@"PUSH connection %@ :%@", self.uniqueIdentifier, self.displayName];

		NSArray <NSString *> *highlightWords = [CQColloquyApplication sharedApplication].highlightWords;
		for (NSString *highlightWord in highlightWords)
			[self sendRawMessageWithFormat:@"PUSH highlight-word :%@", highlightWord];

		NSString *sound = [[CQSettingsController settingsController] stringForKey:@"CQSoundOnHighlight"];
		if (sound.length && ![sound isEqualToString:@"None"])
			[self sendRawMessageWithFormat:@"PUSH highlight-sound :%@.aiff", sound];
		else [self sendRawMessageWithFormat:@"PUSH highlight-sound none"];

		sound = [[CQSettingsController settingsController] stringForKey:@"CQSoundOnPrivateMessage"];
		if (sound.length && ![sound isEqualToString:@"None"])
			[self sendRawMessageWithFormat:@"PUSH message-sound :%@.aiff", sound];
		else [self sendRawMessageWithFormat:@"PUSH message-sound none"];

		[self sendRawMessage:@"PUSH end-device"];
	} else if ((!currentState || [currentState boolValue])) {
		[self setPersistentInformationObject:@(NO) forKey:@"pushState"];

		[self sendRawMessageWithFormat:@"PUSH remove-device :%@", deviceToken];
	}
}
@end

NS_ASSUME_NONNULL_END
