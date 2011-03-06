#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"
#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#import "MVFileTransfer.h"
#import "MVChatUserWatchRule.h"
#import "NSStringAdditions.h"
#import "NSNotificationAdditions.h"
#import "MVUtilities.h"
#import "MVChatString.h"

#if USE(ATTRIBUTED_CHAT_STRING)
#import "NSAttributedStringAdditions.h"
#endif

#if ENABLE(SCRIPTING)
#import "NSScriptCommandAdditions.h"
#endif

#if ENABLE(PLUGINS)
#import "NSMethodSignatureAdditions.h"
#import "MVChatPluginManager.h"
#endif

#if ENABLE(ICB)
#import "MVICBChatConnection.h"
#endif

#if ENABLE(IRC)
#import "MVIRCChatConnection.h"
#endif

#if ENABLE(SILC)
#import "MVSILCChatConnection.h"
#endif

#if ENABLE(XMPP)
#import "MVXMPPChatConnection.h"
#endif

NSString *MVChatConnectionSASLFeature = @"MVChatConnectionSASLFeature";

NSString *MVChatConnectionWillConnectNotification = @"MVChatConnectionWillConnectNotification";
NSString *MVChatConnectionDidConnectNotification = @"MVChatConnectionDidConnectNotification";
NSString *MVChatConnectionDidNotConnectNotification = @"MVChatConnectionDidNotConnectNotification";
NSString *MVChatConnectionWillDisconnectNotification = @"MVChatConnectionWillDisconnectNotification";
NSString *MVChatConnectionDidDisconnectNotification = @"MVChatConnectionDidDisconnectNotification";
NSString *MVChatConnectionErrorNotification = @"MVChatConnectionErrorNotification";

NSString *MVChatConnectionNeedNicknamePasswordNotification = @"MVChatConnectionNeedNicknamePasswordNotification";
NSString *MVChatConnectionNeedCertificatePasswordNotification = @"MVChatConnectionNeedCertificatePasswordNotification";
NSString *MVChatConnectionNeedPublicKeyVerificationNotification = @"MVChatConnectionNeedPublicKeyVerificationNotification";

NSString *MVChatConnectionGotBeepNotification = @"MVChatConnectionGotBeepNotification";
NSString *MVChatConnectionGotImportantMessageNotification = @"MVChatConnectionGotInformationalMessageNotification";
NSString *MVChatConnectionGotInformationalMessageNotification = @"MVChatConnectionGotInformationalMessageNotification";
NSString *MVChatConnectionGotRawMessageNotification = @"MVChatConnectionGotRawMessageNotification";
NSString *MVChatConnectionGotPrivateMessageNotification = @"MVChatConnectionGotPrivateMessageNotification";
NSString *MVChatConnectionChatRoomListUpdatedNotification = @"MVChatConnectionChatRoomListUpdatedNotification";

NSString *MVChatConnectionSelfAwayStatusChangedNotification = @"MVChatConnectionSelfAwayStatusChangedNotification";

NSString *MVChatConnectionWatchedUserOnlineNotification = @"MVChatConnectionWatchedUserOnlineNotification";
NSString *MVChatConnectionWatchedUserOfflineNotification = @"MVChatConnectionWatchedUserOfflineNotification";

NSString *MVChatConnectionNicknameAcceptedNotification = @"MVChatConnectionNicknameAcceptedNotification";
NSString *MVChatConnectionNicknameRejectedNotification = @"MVChatConnectionNicknameRejectedNotification";

NSString *MVChatConnectionDidIdentifyWithServicesNotification = @"MVChatConnectionDidIdentifyWithServicesNotification";

NSString *MVChatConnectionSubcodeRequestNotification = @"MVChatConnectionSubcodeRequestNotification";
NSString *MVChatConnectionSubcodeReplyNotification = @"MVChatConnectionSubcodeReplyNotification";

NSString *MVChatConnectionErrorDomain = @"MVChatConnectionErrorDomain";

static const NSStringEncoding supportedEncodings[] = {
	NSUTF8StringEncoding,
	NSNonLossyASCIIStringEncoding,
	NSASCIIStringEncoding, 0
};

@implementation MVChatConnection
+ (BOOL) supportsURLScheme:(NSString *) scheme {
	if( ! scheme ) return NO;

	return
#if ENABLE(ICB)
		[scheme isEqualToString:@"icb"] ||
#endif
#if ENABLE(IRC)
		[scheme isEqualToString:@"irc"] ||
#endif
#if ENABLE(SILC)
		[scheme isEqualToString:@"silc"] ||
#endif
#if ENABLE(XMPP)
		[scheme isEqualToString:@"xmpp"] ||
#endif
		NO;
}

+ (NSArray *) defaultServerPortsForType:(MVChatConnectionType) type {
#if ENABLE(ICB)
	if( type == MVChatConnectionICBType )
		return [MVICBChatConnection defaultServerPorts];
#endif
#if ENABLE(IRC)
	if( type == MVChatConnectionIRCType )
		return [MVIRCChatConnection defaultServerPorts];
#endif
#if ENABLE(SILC)
	if( type == MVChatConnectionSILCType )
		return [MVSILCChatConnection defaultServerPorts];
#endif
#if ENABLE(XMPP)
	if( type == MVChatConnectionXMPPType )
		return [MVXMPPChatConnection defaultServerPorts];
#endif
	return nil;
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_alternateNicks = nil;
		_npassword = nil;
		_cachedDate = nil;
		_lastConnectAttempt = nil;
		_awayMessage = nil;
		_encoding = NSUTF8StringEncoding;
		_outgoingChatFormat = MVChatConnectionDefaultMessageFormat;
		_nextAltNickIndex = 0;
		_roomListDirty = NO;

		_requestsSASL = YES;

		_status = MVChatConnectionDisconnectedStatus;
		_proxy = MVChatConnectionNoProxy;
		_bouncer = MVChatConnectionNoBouncer;
		_roomsCache = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5000];
		_pendingRoomAdditions = [[NSMutableSet allocWithZone:nil] initWithCapacity:100];
		_pendingRoomUpdates = [[NSMutableSet allocWithZone:nil] initWithCapacity:100];
		_persistentInformation = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];
		_supportedFeatures = [[NSMutableSet allocWithZone:nil] initWithCapacity:10];
		_localUser = nil;

		_joinedRooms = [[NSMutableSet allocWithZone:nil] initWithCapacity:10];

		CFDictionaryValueCallBacks valueCallbacks = { 0, NULL, NULL, kCFTypeDictionaryValueCallBacks.copyDescription, kCFTypeDictionaryValueCallBacks.equal };
		_knownRooms = (NSMutableDictionary *)CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &valueCallbacks);

		_knownUsers = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:300];

#if (!defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE) && (!defined(COMMAND_LINE_UTILITY) || !COMMAND_LINE_UTILITY)
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _systemDidWake: ) name:NSWorkspaceDidWakeNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSWorkspaceWillPowerOffNotification object:[NSWorkspace sharedWorkspace]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
#endif
	}

	return self;
}

- (id) initWithType:(MVChatConnectionType) connectionType {
	[self release];

	switch(connectionType) {
#if ENABLE(ICB)
	case MVChatConnectionICBType:
		self = [[MVICBChatConnection allocWithZone:nil] init];
		break;
#endif
#if ENABLE(IRC)
	case MVChatConnectionIRCType:
		self = [[MVIRCChatConnection allocWithZone:nil] init];
		break;
#endif
#if ENABLE(SILC)
	case MVChatConnectionSILCType:
		self = [[MVSILCChatConnection allocWithZone:nil] init];
		break;
#endif
#if ENABLE(XMPP)
	case MVChatConnectionXMPPType:
		self = [[MVXMPPChatConnection allocWithZone:nil] init];
		break;
#endif
	default:
		self = nil;
	}

	[self setUniqueIdentifier:[NSString locallyUniqueString]];

	return self;
}

- (id) initWithURL:(NSURL *) serverURL {
	NSParameterAssert( [MVChatConnection supportsURLScheme:[serverURL scheme]] );

	NSUInteger connectionType = 0;

#if ENABLE(ICB)
	if( [[serverURL scheme] isEqualToString:@"icb"] )
		connectionType = MVChatConnectionICBType;
#endif
#if ENABLE(IRC)
	if( [[serverURL scheme] isEqualToString:@"irc"] )
		connectionType = MVChatConnectionIRCType;
#endif
#if ENABLE(SILC)
	if( [[serverURL scheme] isEqualToString:@"silc"] )
		connectionType = MVChatConnectionSILCType;
#endif
#if ENABLE(XMPP)
	if( [[serverURL scheme] isEqualToString:@"xmpp"] )
		connectionType = MVChatConnectionXMPPType;
#endif

	if( ( self = [self initWithServer:[serverURL host] type:connectionType port:( [[serverURL port] unsignedLongValue] % 65536 ) user:[serverURL user]] ) ) {
		[self setNicknamePassword:[serverURL password]];

		if( [serverURL fragment] && [[serverURL fragment] length] > 0 ) {
			[self joinChatRoomNamed:[serverURL fragment]];
		} else if( [serverURL path] && [[serverURL path] length] > 1 ) {
			[self joinChatRoomNamed:[[serverURL path] substringFromIndex:1]];
		}
	}

	return self;
}

- (id) initWithServer:(NSString *) serverAddress type:(MVChatConnectionType) serverType port:(unsigned short) port user:(NSString *) localNickname {
	if( ( self = [self initWithType:serverType] ) ) {
		if( localNickname.length ) [self setNickname:localNickname];
		if( serverAddress.length ) [self setServer:serverAddress];
		[self setServerPort:port];
	}

	return self;
}

- (void) finalize {
	[self cancelPendingReconnectAttempts];
	[super finalize];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

#if (!defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE) && (!defined(COMMAND_LINE_UTILITY) || !COMMAND_LINE_UTILITY)
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
#endif

	if (_reachability) {
		SCNetworkReachabilityUnscheduleFromRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
		CFRelease(_reachability);
	}

	[[_knownUsers allValues] makeObjectsPerformSelector:@selector(_connectionDestroyed)];
	[[_knownRooms allValues] makeObjectsPerformSelector:@selector(_connectionDestroyed)];
	[_joinedRooms makeObjectsPerformSelector:@selector(_connectionDestroyed)];
	[_localUser _connectionDestroyed];

	[_npassword release];
	[_roomsCache release];
	[_pendingRoomAdditions release];
	[_pendingRoomUpdates release];
	[_cachedDate release];
	[_knownRooms release];
	[_joinedRooms release];
	[_chatUserWatchRules release];
	[_localUser release];
	[_lastConnectAttempt release];
	[_awayMessage release];
	[_persistentInformation release];
	[_proxyServer release];
	[_proxyUsername release];
	[_proxyPassword release];
	[_supportedFeatures release];

	[super dealloc];
}

#pragma mark -

- (MVChatConnectionType) type {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
}

- (NSUInteger) hash {
	if( ! _hash ) _hash = ( [self type] ^ [[self server] hash] ^ [self serverPort] ^ [[self nickname] hash] );
	return _hash;
}

#pragma mark -

- (NSString *) uniqueIdentifier {
	return _uniqueIdentifier;
}

- (void) setUniqueIdentifier:(NSString *) uniqueIdentifier {
	NSParameterAssert( uniqueIdentifier != nil );
	NSParameterAssert( uniqueIdentifier.length > 0 );
	MVSafeCopyAssign( _uniqueIdentifier, uniqueIdentifier );
}

#pragma mark -

- (NSSet *) supportedFeatures {
	@synchronized( _supportedFeatures ) {
		return [NSSet setWithSet:_supportedFeatures];
	}
}

- (BOOL) supportsFeature:(NSString *) key {
	NSParameterAssert( key != nil );
	@synchronized( _supportedFeatures ) {
		return [_supportedFeatures containsObject:key];
	}
}

#pragma mark -

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

- (BOOL) supportsStringEncoding:(NSStringEncoding) supportedEncoding {
	const NSStringEncoding *encodings = [self supportedStringEncodings];
	NSUInteger i = 0;

	for( i = 0; encodings[i]; i++ )
		if( encodings[i] == supportedEncoding ) return YES;

	return NO;
}

#pragma mark -

- (void) connect {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) connectToServer:(NSString *) address onPort:(unsigned short) port asUser:(NSString *) nick {
	if( nick.length ) [self setNickname:nick];
	if( address.length ) [self setServer:address];
	[self setServerPort:port];
	[self disconnect];
	[self connect];
}

- (void) disconnect {
	[self disconnectWithReason:nil];
}

- (void) disconnectWithReason:(MVChatString *) reason {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (NSError *) lastError {
	return _lastError;
}

#pragma mark -

- (NSString *) urlScheme {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return @"chat";
}

- (NSURL *) url {
	NSString *urlString = [NSString stringWithFormat:@"%@://%@@%@:%hu", [self urlScheme], [[self preferredNickname] stringByEncodingIllegalURLCharacters], [[self server] stringByEncodingIllegalURLCharacters], [self serverPort]];
	if( urlString ) return [NSURL URLWithString:urlString];
	return nil;
}

#pragma mark -

- (void) setEncoding:(NSStringEncoding) newEncoding {
	if( [self supportsStringEncoding:newEncoding] )
		_encoding = newEncoding;
}

- (NSStringEncoding) encoding {
	return _encoding;
}

#pragma mark -

- (void) setRealName:(NSString *) name {
// subclass this method, if needed
}

- (NSString *) realName {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) nickname {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (void) setPreferredNickname:(NSString *) nickname {
// subclass this method, if needed
	[self setNickname:nickname];
}

- (NSString *) preferredNickname {
// subclass this method, if needed
	return [self nickname];
}

#pragma mark -

- (void) setAlternateNicknames:(NSArray *) nicknames {
	MVSafeCopyAssign( _alternateNicks, nicknames );
	_nextAltNickIndex = 0;
}

- (NSArray *) alternateNicknames {
	return [NSArray arrayWithArray:_alternateNicks];
}

- (NSString *) nextAlternateNickname {
	if( [[self alternateNicknames] count] && _nextAltNickIndex < [[self alternateNicknames] count] )
		return [[self alternateNicknames] objectAtIndex:_nextAltNickIndex++];
	return nil;
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) newPassword {
	MVSafeCopyAssign( _npassword, newPassword );
}

- (NSString *) nicknamePassword {
	return _npassword;
}

#pragma mark -

- (NSString *) certificateServiceName {
// subclass this method, if needed
	return nil;
}

- (BOOL) authenticateCertificateWithPassword:(NSString *) password {
// subclass this method. if needed
	return NO;
}

- (NSString *) certificatePassword {
// subclass this method. if needed
	return nil;
}

#pragma mark -

- (void) setPassword:(NSString *) password {
// subclass this method, if needed
}

- (NSString *) password {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (void) setUsername:(NSString *) username {
// subclass this method, if needed
}

- (NSString *) username {
// subclass this method, if needed
	return nil;
}

#pragma mark -

static void reachabilityCallback( SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void *context ) {
	MVChatConnection *connection = (MVChatConnection *)context;

	BOOL reachable = ( flags & kSCNetworkFlagsReachable );
	BOOL connectionRequired = ( flags & kSCNetworkFlagsConnectionRequired );

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
	if( flags & kSCNetworkReachabilityFlagsIsWWAN ) connectionRequired = NO;
#endif

	if( ! reachable || connectionRequired )
		return;

	if( ! [connection isWaitingToReconnect] || [connection status] != MVChatConnectionServerDisconnectedStatus )
		return;

	[connection performSelector:@selector(connect) withObject:nil afterDelay:3.];
}

- (void) setServer:(NSString *) server {
// subclass this method, call super

	if( _reachability ) {
		SCNetworkReachabilityUnscheduleFromRunLoop( _reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode );
		CFRelease( _reachability );
		_reachability = NULL;
	}

	if( ! server.length )
		return;

	SCNetworkReachabilityContext context = { 0, self, NULL, NULL, NULL };
	_reachability = SCNetworkReachabilityCreateWithName( NULL, [server UTF8String] );
	if( ! _reachability )
		return;

	if( ! SCNetworkReachabilitySetCallback( _reachability, reachabilityCallback, &context ) )
		return;

	SCNetworkReachabilityScheduleWithRunLoop( _reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode );
}

- (NSString *) server {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (unsigned short) serverPort {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
}

#pragma mark -

- (void) setOutgoingChatFormat:(MVChatMessageFormat) format {
	if( ! format ) format = MVChatConnectionDefaultMessageFormat;
	_outgoingChatFormat = format;
}

- (MVChatMessageFormat) outgoingChatFormat {
	return _outgoingChatFormat;
}

#pragma mark -

- (void) setSecure:(BOOL) ssl {
	_secure = ssl;
}

- (BOOL) isSecure {
	return _secure;
}

#pragma mark -

- (void) setRequestsSASL:(BOOL) sasl {
	_requestsSASL = sasl;
}

- (BOOL) requestsSASL {
	return _requestsSASL;
}

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) newType {
	_proxy = newType;
}

- (MVChatConnectionProxy) proxyType {
	return _proxy;
}

#pragma mark -

- (void) setProxyServer:(NSString *) address {
	MVSafeCopyAssign( _proxyServer, address );
}

- (NSString *) proxyServer {
	return _proxyServer;
}

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port {
	_proxyServerPort = port;
}

- (unsigned short) proxyServerPort {
	return _proxyServerPort;
}

#pragma mark -

- (void) setProxyUsername:(NSString *) newUsername {
	MVSafeCopyAssign( _proxyUsername, newUsername );
}

- (NSString *) proxyUsername {
	return _proxyUsername;
}

#pragma mark -

- (void) setProxyPassword:(NSString *) newPassword {
	MVSafeCopyAssign( _proxyPassword, newPassword );
}

- (NSString *) proxyPassword {
	return _proxyPassword;
}

#pragma mark -

- (void) setBouncerType:(MVChatConnectionBouncer) newType {
	_bouncer = newType;
}

- (MVChatConnectionBouncer) bouncerType {
	return _bouncer;
}

#pragma mark -

- (void) setBouncerServer:(NSString *) address {
	MVSafeCopyAssign( _bouncerServer, address );
}

- (NSString *) bouncerServer {
	return _bouncerServer;
}

#pragma mark -

- (void) setBouncerServerPort:(unsigned short) port {
	_bouncerServerPort = port;
}

- (unsigned short) bouncerServerPort {
	return _bouncerServerPort;
}

#pragma mark -

- (void) setBouncerUsername:(NSString *) newUsername {
	MVSafeCopyAssign( _bouncerUsername, newUsername );
}

- (NSString *) bouncerUsername {
	return _bouncerUsername;
}

#pragma mark -

- (void) setBouncerPassword:(NSString *) newPassword {
	MVSafeCopyAssign( _bouncerPassword, newPassword );
}

- (NSString *) bouncerPassword {
	return _bouncerPassword;
}

#pragma mark -

- (void) setBouncerDeviceIdentifier:(NSString *) newIdentifier {
	MVSafeCopyAssign( _bouncerDeviceIdentifier, newIdentifier );
}

- (NSString *) bouncerDeviceIdentifier {
	return _bouncerDeviceIdentifier;
}

#pragma mark -

- (void) setBouncerConnectionIdentifier:(NSString *) newIdentifier {
	MVSafeCopyAssign( _bouncerConnectionIdentifier, newIdentifier );
}

- (NSString *) bouncerConnectionIdentifier {
	return _bouncerConnectionIdentifier;
}

#pragma mark -

- (void) setPersistentInformation:(NSDictionary *) information {
	@synchronized( _persistentInformation ) {
		if( information.count ) [_persistentInformation setDictionary:information];
		else [_persistentInformation removeAllObjects];
	}
}

- (NSDictionary *) persistentInformation {
	return [NSDictionary dictionaryWithDictionary:_persistentInformation];
}

- (id) persistentInformationObjectForKey:(id) key {
	@synchronized( _persistentInformation ) {
		return [_persistentInformation objectForKey:key];
	}
}

- (void) removePersistentInformationObjectForKey:(id) key {
	@synchronized( _persistentInformation ) {
		[_persistentInformation removeObjectForKey:key];
	}
}

- (void) setPersistentInformationObject:(id) object forKey:(id) key {
	@synchronized( _persistentInformation ) {
		[_persistentInformation setObject:object forKey:key];
	}
}

#pragma mark -

- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept {
// subclass this method, if needed
}

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments {
	// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) sendRawMessage:(id) raw {
	[self sendRawMessage:raw immediately:NO];
}

- (void) sendRawMessage:(id) raw immediately:(BOOL) now {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) sendRawMessageWithFormat:(NSString *) format, ... {
	NSParameterAssert( format != nil );

	va_list ap;
	va_start( ap, format );

	NSString *command = [[NSString allocWithZone:nil] initWithFormat:format arguments:ap];

	va_end( ap );

	[self sendRawMessage:command immediately:NO];
	[command release];
}

- (void) sendRawMessageImmediatelyWithFormat:(NSString *) format, ... {
	NSParameterAssert( format != nil );

	va_list ap;
	va_start( ap, format );

	NSString *command = [[NSString allocWithZone:nil] initWithFormat:format arguments:ap];

	va_end( ap );

	[self sendRawMessage:command immediately:YES];
	[command release];
}

- (void) sendRawMessageWithComponents:(id) firstComponent, ... {
	NSParameterAssert( firstComponent != nil );

	NSMutableData *data = [[NSMutableData allocWithZone:nil] initWithCapacity:512];
	id object = firstComponent;

	va_list ap;
	va_start( ap, firstComponent );

	do {
		if( [object isKindOfClass:[NSData class]] ) {
			[data appendData:object];
		} else if( [firstComponent isKindOfClass:[NSString class]] ) {
			NSData *stringData = [object dataUsingEncoding:[self encoding] allowLossyConversion:YES];
			[data appendData:stringData];
		} else {
			NSData *stringData = [[object description] dataUsingEncoding:[self encoding] allowLossyConversion:YES];
			[data appendData:stringData];
		}
	} while( ( object = va_arg( ap, void * ) ) );

	va_end( ap );

	[self sendRawMessage:data immediately:NO];
	[data release];
}

- (void) sendRawMessageImmediatelyWithComponents:(id) firstComponent, ... {
	NSParameterAssert( firstComponent != nil );

	NSMutableData *data = [[NSMutableData allocWithZone:nil] initWithCapacity:512];
	id object = firstComponent;

	va_list ap;
	va_start( ap, firstComponent );

	do {
		if( [object isKindOfClass:[NSData class]] ) {
			[data appendData:object];
		} else if( [firstComponent isKindOfClass:[NSString class]] ) {
			NSData *stringData = [object dataUsingEncoding:[self encoding] allowLossyConversion:YES];
			[data appendData:stringData];
		} else {
			NSData *stringData = [[object description] dataUsingEncoding:[self encoding] allowLossyConversion:YES];
			[data appendData:stringData];
		}
	} while( ( object = va_arg( ap, void * ) ) );

	va_end( ap );

	[self sendRawMessage:data immediately:YES];
	[data release];
}

#pragma mark -

- (void) processIncomingMessage:(id) raw {
	[self processIncomingMessage:raw fromServer:YES];
}

- (void) processIncomingMessage:(id) raw fromServer:(BOOL) fromServer {
	// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! rooms.count ) return;

	for( NSString *room in rooms )
		if( room.length ) [self joinChatRoomNamed:room];
}

- (void) joinChatRoomNamed:(NSString *) room {
	[self joinChatRoomNamed:room withPassphrase:nil];
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (NSSet *) knownChatRooms {
	@synchronized( _knownRooms ) {
		return [NSSet setWithArray:[_knownRooms allValues]];
	}
}

- (NSSet *) joinedChatRooms {
	@synchronized( _joinedRooms ) {
		return [NSSet setWithSet:_joinedRooms];
	}
}

- (MVChatRoom *) joinedChatRoomWithUniqueIdentifier:(id) identifier {
	@synchronized( _joinedRooms ) {
		MVChatRoom *room = [_knownRooms objectForKey:identifier];
		return ([room isJoined] ? [[room retain] autorelease] : nil);
	}
}

- (MVChatRoom *) joinedChatRoomWithName:(NSString *) name {
	@synchronized( _joinedRooms ) {
		for( MVChatRoom *room in _joinedRooms )
			if( [[room name] isEqualToString:name] )
				return [[room retain] autorelease];
	}

	return nil;
}

#pragma mark -

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier {
	@synchronized( _knownRooms ) {
		return [[[_knownRooms objectForKey:identifier] retain] autorelease];
	}
}

- (MVChatRoom *) chatRoomWithName:(NSString *) name {
	@synchronized( _knownRooms ) {
		for( id key in _knownRooms ) {
			MVChatRoom *room = [_knownRooms objectForKey:key];
			if( [[room name] isEqualToString:name] )
				return [[room retain] autorelease];
		}
	}

	return nil;
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return nil;
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	return room;
}

- (NSString *) displayNameForChatRoomNamed:(NSString *) room {
	return room;
}

#pragma mark -

- (NSSet *) knownChatUsers {
	@synchronized( _knownUsers ) {
		return [NSSet setWithArray:[_knownUsers allValues]];
	}
}

- (NSSet *) chatUsersWithNickname:(NSString *) nickname {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSSet *) chatUsersWithFingerprint:(NSString *) fingerprint {
// subclass this method, if needed
	return nil;
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	if( [identifier isEqual:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	@synchronized( _knownUsers ) {
		return [[[_knownUsers objectForKey:identifier] retain] autorelease];
	}
}

- (MVChatUser *) localUser {
	return _localUser;
}

#pragma mark -

- (void) addChatUserWatchRule:(MVChatUserWatchRule *) rule {
	NSParameterAssert( rule != nil );

	if( ! _chatUserWatchRules )
		_chatUserWatchRules = [[NSMutableSet allocWithZone:nil] initWithCapacity:10];

	@synchronized( _chatUserWatchRules ) {
		if( ! [_chatUserWatchRules containsObject:rule] )
			[_chatUserWatchRules addObject:rule];
	}
}

- (void) removeChatUserWatchRule:(MVChatUserWatchRule *) rule {
	NSParameterAssert( rule != nil );

	[rule removeMatchedUsersForConnection:self];

	@synchronized( _chatUserWatchRules ) {
		[_chatUserWatchRules removeObject:rule];
	}
}

- (NSSet *) chatUserWatchRules {
	@synchronized( _chatUserWatchRules ) {
		return [NSSet setWithSet:_chatUserWatchRules];
	}
}

#pragma mark -

- (void) fetchChatRoomList {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) stopFetchingChatRoomList {
// subclass this method, if needed
}

- (NSMutableDictionary *) chatRoomListResults {
	return _roomsCache;
}

#pragma mark -

- (MVChatString *) awayStatusMessage {
	return _awayMessage;
}

- (void) setAwayStatusMessage:(MVChatString *) message {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (NSDate *) connectedDate {
	return _connectedDate;
}

- (BOOL) isConnected {
	return ( _status == MVChatConnectionConnectedStatus );
}

- (MVChatConnectionStatus) status {
	return _status;
}

- (NSUInteger) lag {
// subclass this method, if needed
	return 0;
}

#pragma mark -

- (void) attemptReconnect {
	++_reconnectAttemptCount;

	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = [[NSTimer scheduledTimerWithTimeInterval:(60. * _reconnectAttemptCount) target:self selector:@selector( attemptReconnect ) userInfo:nil repeats:NO] retain];

	[self connect];
}

- (void) scheduleReconnectAttempt {
	if (_reconnectTimer)
		return;
	_reconnectTimer = [[NSTimer scheduledTimerWithTimeInterval:30. target:self selector:@selector( attemptReconnect ) userInfo:nil repeats:NO] retain];
}

- (void) cancelPendingReconnectAttempts {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( connect ) object:nil];

	_reconnectAttemptCount = 0;

	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = nil;
}

- (NSDate *) nextReconnectAttemptDate {
	return [_reconnectTimer fireDate];
}

- (BOOL) isWaitingToReconnect {
	return ( ! [self isConnected] && _reconnectTimer ? YES : NO );
}

- (unsigned short) reconnectAttemptCount {
	return _reconnectAttemptCount;
}

- (void) purgeCaches {
	id old = _cachedDate;
	_cachedDate = nil;
	[old release];

	[_roomsCache removeAllObjects];
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionPrivate)
- (void) _systemWillSleep:(NSNotification *) notification {
	if( [self isConnected] ) {
		[self disconnect];
		_status = MVChatConnectionSuspendedStatus;
	}
}

- (void) _systemDidWake:(NSNotification *) notification {
	if( [self status] == MVChatConnectionSuspendedStatus )
		[self connect];
}

- (void) _applicationWillTerminate:(NSNotification *) notification {
	if( [self isConnected] ) [self disconnect];
}

#pragma mark -

- (void) _willConnect {
	MVAssertMainThreadRequired();
	MVSafeAdoptAssign( _lastError, nil );

	_nextAltNickIndex = 0;
	_status = MVChatConnectionConnectingStatus;

	[[self localUser] _setIdentified:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillConnectNotification object:self];
}

- (void) _didConnect {
	[self cancelPendingReconnectAttempts];

	[[self localUser] _setStatus:MVChatUserAvailableStatus];
	[[self localUser] _setDateConnected:[NSDate date]];
	[[self localUser] _setDateDisconnected:nil];

	MVSafeAdoptAssign(_connectedDate, [[NSDate alloc] init]);

	_status = MVChatConnectionConnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidConnectNotification object:self];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( connected: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif
}

- (void) _didNotConnect {
	_status = MVChatConnectionDisconnectedStatus;

	if (_reconnectAttemptCount <= 30 && !_userDisconnected)
		[self scheduleReconnectAttempt];
	else [self cancelPendingReconnectAttempts];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidNotConnectNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:_userDisconnected] forKey:@"userDisconnected"]];

	_userDisconnected = NO;
}

- (void) _willDisconnect {
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionWillDisconnectNotification object:self];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( disconnecting: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif
}

- (void) _didDisconnect {
	BOOL wasConnected = ( _status == MVChatConnectionConnectedStatus || _status == MVChatConnectionSuspendedStatus || _status == MVChatConnectionServerDisconnectedStatus );

	[[self localUser] _setStatus:MVChatUserOfflineStatus];
	[[self localUser] _setDateDisconnected:[NSDate date]];

	MVSafeAdoptAssign(_connectedDate, nil);

	if( _status != MVChatConnectionSuspendedStatus && _status != MVChatConnectionServerDisconnectedStatus )
		_status = MVChatConnectionDisconnectedStatus;

	for( MVChatRoom *room in [self joinedChatRooms] ) {
		if( ! [room isJoined] ) continue;
		[room _setDateParted:[NSDate date]];
	}

	if( wasConnected ) [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidDisconnectNotification object:self];

	[self _pruneKnownUsers];
}

- (void) _postError:(NSError *) error {
	MVSafeCopyAssign( _lastError, error );
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionErrorNotification object:self userInfo:[NSDictionary dictionaryWithObject:_lastError forKey:@"error"]];
}

- (void) _setStatus:(MVChatConnectionStatus) newStatus {
	_status = newStatus;
}

#pragma mark -

- (void) _addRoomToCache:(NSMutableDictionary *) info {
	NSString *room = [info objectForKey:@"room"];
	if (![_roomsCache objectForKey:room])
		[_pendingRoomAdditions addObject:room];
	else [_pendingRoomUpdates addObject:room];
	[_roomsCache setObject:info forKey:room];
	[info removeObjectForKey:@"room"];

	if( _roomListDirty ) return; // already queued to send notification
	_roomListDirty = YES;

	[self performSelector:@selector( _sendRoomListUpdatedNotification ) withObject:nil afterDelay:( 1. / 3. )];
}

- (void) _sendRoomListUpdatedNotification {
	_roomListDirty = NO;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionChatRoomListUpdatedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSSet setWithSet:_pendingRoomAdditions], @"added", [NSSet setWithSet:_pendingRoomUpdates], @"updated", nil]];
	[_pendingRoomAdditions removeAllObjects];
	[_pendingRoomUpdates removeAllObjects];
}

#pragma mark -

- (void) _addKnownUser:(MVChatUser *) user {
	@synchronized( _knownUsers ) {
		if( [user uniqueIdentifier] ) [_knownUsers setObject:user forKey:[user uniqueIdentifier]];
	}
}

- (void) _removeKnownUser:(MVChatUser *) user {
	@synchronized( _knownRooms ) {
		if( [user uniqueIdentifier] ) [_knownUsers removeObjectForKey:[user uniqueIdentifier]];
	}
}

- (void) _pruneKnownUsers {
	@synchronized( _knownUsers ) {
		NSMutableArray *removeList = [[NSMutableArray allocWithZone:nil] initWithCapacity:_knownUsers.count];

		for( id key in _knownUsers ) {
			id object = [_knownUsers objectForKey:key];
			if( [object retainCount] == 1 ) [removeList addObject:key];
		}

		[_knownUsers removeObjectsForKeys:removeList];
		[removeList release];
	}
}

- (void) _addKnownRoom:(MVChatRoom *) room {
	@synchronized( _knownRooms ) {
		if( [room uniqueIdentifier] ) [_knownRooms setObject:room forKey:[room uniqueIdentifier]];
	}
}

- (void) _removeKnownRoom:(MVChatRoom *) room {
	@synchronized( _knownRooms ) {
		if( [room uniqueIdentifier] ) [_knownRooms removeObjectForKey:[room uniqueIdentifier]];
	}
}

- (void) _addJoinedRoom:(MVChatRoom *) room {
	@synchronized( _joinedRooms ) {
		if( room ) [_joinedRooms addObject:room];
	}
}

- (void) _removeJoinedRoom:(MVChatRoom *) room {
	@synchronized( _joinedRooms ) {
		if( room ) [_joinedRooms removeObject:room];
	}
}

#pragma mark -

- (NSUInteger) _watchRulesMatchingUser:(MVChatUser *) user {
	NSUInteger count = 0;
	@synchronized( _chatUserWatchRules ) {
		for( MVChatUserWatchRule *rule in _chatUserWatchRules) {
			if( [rule matchChatUser:user] )
				count++;
		}
	}

	return count;
}

- (void) _markUserAsOnline:(MVChatUser *) user {
	[user _setDateDisconnected:nil];

	if( ! [user dateConnected] )
		[user _setDateConnected:[NSDate date]];

	if( [user status] != MVChatUserAwayStatus )
		[user _setStatus:MVChatUserAvailableStatus];

	[self _watchRulesMatchingUser:user];
}

- (void) _markUserAsOffline:(MVChatUser *) user {
	if( ! [user dateDisconnected] && [user dateConnected] )
		[user _setDateDisconnected:[NSDate date]];

	if( [user status] != MVChatUserOfflineStatus ) {
		[user retain]; // retain since removeMatchedUser might hold the last reference

		@synchronized( _chatUserWatchRules ) {
			for( MVChatUserWatchRule *rule in _chatUserWatchRules)
				[rule removeMatchedUser:user];
		}

		[user _setStatus:MVChatUserOfflineStatus];

		[user release];
	}
}
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@implementation MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) scriptUniqueIdentifier {
	return [NSNumber numberWithUnsignedLong:(intptr_t)self];
}

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The connection id %@ doesn't have the \"%@\" property.", [self scriptUniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of connection id %@ is read only.", key, [self scriptUniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}

#pragma mark -

- (void) connectScriptCommand:(NSScriptCommand *) command {
	[self connect];
}

- (void) disconnectScriptCommand:(NSScriptCommand *) command {
	[self disconnect];
}

#pragma mark -

- (NSString *) urlString {
	return [[self url] absoluteString];
}

#pragma mark -

- (NSTextStorage *) scriptTypedAwayMessage {
#if USE(ATTRIBUTED_CHAT_STRING)
	return [[[NSTextStorage allocWithZone:nil] initWithAttributedString:(NSAttributedString *)_awayMessage] autorelease];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	return [[[NSTextStorage allocWithZone:nil] initWithString:(NSString *)_awayMessage] autorelease];
#endif
}

- (void) setScriptTypedAwayMessage:(id) message {
#if USE(ATTRIBUTED_CHAT_STRING)
	NSString *msg = message;
	if( [message isKindOfClass:[NSTextStorage class]] ) msg = [message string];
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:msg baseURL:nil];
	[self setAwayStatusMessage:attributeMsg];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	if( [message isKindOfClass:[NSString class]] );
		[self setAwayStatusMessage:message];
#endif
}

#pragma mark -

- (NSUInteger) scriptTypedEncoding {
	return [NSString scriptTypedEncodingFromStringEncoding:[self encoding]];
}

- (void) setScriptTypedEncoding:(NSUInteger) newEncoding {
	[self setEncoding:[NSString stringEncodingFromScriptTypedEncoding:newEncoding]];
}

#pragma mark -

- (NSArray *) knownChatUsersArray {
	return [_knownUsers allValues];
}

- (MVChatUser *) valueInKnownChatUsersArrayAtIndex:(NSUInteger) index {
	return [[self knownChatUsersArray] objectAtIndex:index];
}

- (MVChatUser *) valueInKnownChatUsersArrayWithUniqueID:(id) identifier {
	return [self chatUserWithUniqueIdentifier:identifier];
}

- (MVChatUser *) valueInKnownChatUsersArrayWithName:(NSString *) name {
	for( MVChatUser *user in [self knownChatUsers] )
		if( [[user nickname] isCaseInsensitiveEqualToString:name] )
			return user;

	return nil;
}

#pragma mark -

- (NSArray *) joinedChatRoomsArray {
	return [[self joinedChatRooms] allObjects];
}

- (MVChatRoom *) valueInJoinedChatRoomsArrayAtIndex:(NSUInteger) index {
	return [[self joinedChatRoomsArray] objectAtIndex:index];
}

- (MVChatRoom *) valueInJoinedChatRoomsArrayWithUniqueID:(id) identifier {
	for( MVChatRoom *room in [self joinedChatRooms] )
		if( [[room scriptUniqueIdentifier] isEqual:identifier] )
			return room;

	return nil;
}

- (MVChatRoom *) valueInJoinedChatRoomsArrayWithName:(NSString *) name {
	return [self joinedChatRoomWithName:name];
}
@end

#pragma mark -

@interface MVSendMessageScriptCommand : NSScriptCommand {}
@end

@implementation MVSendMessageScriptCommand
- (id) performDefaultImplementation {
	// check if the subject responds to the command directly, if so execute that implementation
	if( [self subjectSupportsCommand] ) return [self executeCommandOnSubject];

	// the subject didn't respond to the command, so do our default implementation
	NSDictionary *args = [self evaluatedArguments];
	id message = [self evaluatedDirectParameter];
	id target = [args objectForKey:@"target"];
	id action = [args objectForKey:@"action"];
	id localEcho = [args objectForKey:@"echo"];
	id encoding = [args objectForKey:@"encoding"];

	if( [message isKindOfClass:[MVChatConnection class]] ) {
		// old compatability mode; flip some parameters
		MVChatConnection *connection = message;
		message = [args objectForKey:@"message"];

		if( ! [connection isConnected] ) return nil;

		target = [[connection chatUsersWithNickname:[target description]] allObjects];

		if( ! target || ( target && [target isKindOfClass:[NSArray class]] && ! [target count] ) )
			return nil; // silently fail like normal tell blocks do when the target is nil or an empty list
	}

	if( ! message ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The message was missing."];
		return nil;
	}

	if( ! [message isKindOfClass:[NSString class]] ) {
		message = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:message toClass:[NSString class]];
		if( ! [message isKindOfClass:[NSString class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The message was not a string value and coercion failed."];
			return nil;
		}
	}

	if( ! [(NSString *)message length] ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The message can't be blank."];
		return nil;
	}

	if( ! target ) {
		target = [self subjectParameter];
		if( ! target || ( target && [target isKindOfClass:[NSArray class]] && ! [target count] ) )
			return nil; // silently fail like normal tell blocks do when the target is nil or an empty list

		if( ! [target isKindOfClass:[NSArray class]] && ! [target isKindOfClass:[MVChatUser class]] && ! [target isKindOfClass:[MVChatRoom class]] ) {
			[self setScriptErrorNumber:-1703]; // errAEWrongDataType
			[self setScriptErrorString:@"The nearest enclosing tell block target is not a chat user nor a chat room specifier."];
			return nil;
		}
	}

	if( ! target || ( ! [target isKindOfClass:[NSArray class]] && ! [target isKindOfClass:[MVChatUser class]] && ! [target isKindOfClass:[MVChatRoom class]] ) ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The \"to\" parameter was missing, not a chat user nor a chat room specifier."];
		return nil;
	}

	if( [target isKindOfClass:[MVChatUser class]] && [(MVChatUser *)target type] == MVChatWildcardUserType ) {
		[self setScriptErrorNumber:-1703]; // errAEWrongDataType
		[self setScriptErrorString:@"The \"to\" parameter cannot be a wildcard user."];
		return nil;
	}

	if( action && ! [action isKindOfClass:[NSNumber class]] ) {
		action = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:action toClass:[NSNumber class]];
		if( ! [action isKindOfClass:[NSNumber class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The action tense parameter was not a boolean value and coercion failed."];
			return nil;
		}
	}

	if( localEcho && ! [localEcho isKindOfClass:[NSNumber class]] ) {
		localEcho = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:localEcho toClass:[NSNumber class]];
		if( ! [localEcho isKindOfClass:[NSNumber class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The local echo parameter was not a boolean value and coercion failed."];
			return nil;
		}
	}

	if( encoding && ! [encoding isKindOfClass:[NSNumber class]] ) {
		[self setScriptErrorNumber:-1703]; // errAEWrongDataType
		[self setScriptErrorString:@"The encoding was an invalid type."];
		return nil;
	}

#if USE(ATTRIBUTED_CHAT_STRING)
	NSAttributedString *realMessage = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	NSString *realMessage = message;
#endif

	NSStringEncoding realEncoding = NSUTF8StringEncoding;
	BOOL realAction = ( action ? [action boolValue] : NO );
	BOOL realLocalEcho = ( localEcho ? [localEcho boolValue] : YES );

	NSArray *targets = nil;
	if( [target isKindOfClass:[NSArray class]] ) targets = target;
	else targets = [NSArray arrayWithObject:target];

	for( target in targets ) {
		if( ! [target isKindOfClass:[MVChatUser class]] && ! [target isKindOfClass:[MVChatRoom class]] )
			continue;

		if( encoding ) {
			realEncoding = [NSString stringEncodingFromScriptTypedEncoding:[encoding unsignedLongValue]];
		} else if( [target isKindOfClass:[MVChatRoom class]] ) {
			realEncoding = [(MVChatRoom *)target encoding];
		} else {
			realEncoding = [[(MVChatRoom *)target connection] encoding];
		}

		[target sendMessage:realMessage withEncoding:realEncoding asAction:realAction];

		if( realLocalEcho ) {
#if USE(ATTRIBUTED_CHAT_STRING)
			NSString *cformat = nil;

			switch( [[(MVChatRoom *)target connection] outgoingChatFormat] ) {
				case MVChatConnectionDefaultMessageFormat: // we can't really support the connection default, assume what it is
				case MVChatWindowsIRCMessageFormat:
					cformat = NSChatWindowsIRCFormatType;
					break;
				case MVChatCTCPTwoMessageFormat:
					cformat = NSChatCTCPTwoFormatType;
					break;
				default:
				case MVChatNoMessageFormat:
					cformat = nil;
			}

			NSDictionary *options = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithUnsignedLong:realEncoding], @"StringEncoding", cformat, @"FormatType", nil];
			NSData *msgData = [realMessage chatFormatWithOptions:options];
			[options release];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
			NSData *msgData = [realMessage dataUsingEncoding:realEncoding];
#endif

			if( [target isKindOfClass:[MVChatRoom class]] ) {
				NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:[[(MVChatRoom *)target connection] localUser], @"user", msgData, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:realAction], @"action", nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomGotMessageNotification object:target userInfo:info];
				[info release];
			} // we can't really echo a private message with our current notifications
		}
	}

	return nil;
}
@end

#pragma mark -

@interface MVSendRawMessageScriptCommand : NSScriptCommand {}
@end

@implementation MVSendRawMessageScriptCommand
- (id) performDefaultImplementation {
	// check if the subject responds to the command directly, if so execute that implementation
	if( [self subjectSupportsCommand] ) return [self executeCommandOnSubject];

	// the subject didn't respond to the command, so do our default implementation
	NSDictionary *args = [self evaluatedArguments];
	id message = [self evaluatedDirectParameter];
	id connection = [args objectForKey:@"connection"];
	id priority = [args objectForKey:@"priority"];

	if( ! message ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The message was missing."];
		return nil;
	}

	if( ! [message isKindOfClass:[NSString class]] ) {
		message = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:message toClass:[NSString class]];
		if( ! [message isKindOfClass:[NSString class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The message was not a string value and coercion failed."];
			return nil;
		}
	}

	if( ! [(NSString *)message length] ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The message can't be blank."];
		return nil;
	}

	if( ! connection ) {
		connection = [self subjectParameter];
		if( ! connection || ( connection && [connection isKindOfClass:[NSArray class]] && ! [connection count] ) )
			return nil; // silently fail like normal tell blocks do when the target is nil or an empty list

		if( ! [connection isKindOfClass:[NSArray class]] && ! [connection isKindOfClass:[MVChatConnection class]] ) {
			[self setScriptErrorNumber:-1703]; // errAEWrongDataType
			[self setScriptErrorString:@"The nearest enclosing tell block target is not a connection specifier."];
			return nil;
		}
	}

	if( ! connection || ( ! [connection isKindOfClass:[NSArray class]] && ! [connection isKindOfClass:[MVChatConnection class]] ) ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The \"to\" parameter was missing or not a connection specifier."];
		return nil;
	}

	if( priority && ! [priority isKindOfClass:[NSNumber class]] ) {
		priority = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:priority toClass:[NSNumber class]];
		if( ! [priority isKindOfClass:[NSNumber class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The priority parameter was not a boolean value and coercion failed."];
			return nil;
		}
	}

	BOOL realPriority = ( priority ? [priority boolValue] : NO );

	NSArray *targets = nil;
	if( [connection isKindOfClass:[NSArray class]] ) targets = connection;
	else targets = [NSArray arrayWithObject:connection];

	for( connection in targets ) {
		if( ! [connection isKindOfClass:[MVChatConnection class]] ) continue;
		[connection sendRawMessage:message immediately:realPriority];
	}

	return nil;
}
@end

#pragma mark -

@interface MVJoinChatRoomScriptCommand : NSScriptCommand {}
@end

@implementation MVJoinChatRoomScriptCommand
- (id) performDefaultImplementation {
	// check if the subject responds to the command directly, if so execute that implementation
	if( [self subjectSupportsCommand] ) return [self executeCommandOnSubject];

	// the subject didn't respond to the command, so do our default implementation
	NSDictionary *args = [self evaluatedArguments];
	id room = [self evaluatedDirectParameter];
	id connection = [args objectForKey:@"connection"];

	if( ! room || ( ! [room isKindOfClass:[NSString class]] && ! [room isKindOfClass:[NSArray class]] ) ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The room was missing, not a string value nor a list of strings."];
		return nil;
	}

	if( ! connection ) {
		connection = [self subjectParameter];
		if( ! connection || ( connection && [connection isKindOfClass:[NSArray class]] && ! [connection count] ) )
			return nil; // silently fail like normal tell blocks do when the target is nil or an empty list

		if( ! [connection isKindOfClass:[NSArray class]] && ! [connection isKindOfClass:[MVChatConnection class]] ) {
			[self setScriptErrorNumber:-1703]; // errAEWrongDataType
			[self setScriptErrorString:@"The nearest enclosing tell block target is not a connection specifier."];
			return nil;
		}
	}

	if( ! connection || ( ! [connection isKindOfClass:[NSArray class]] && ! [connection isKindOfClass:[MVChatConnection class]] ) ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The \"on\" parameter was missing or not a connection specifier."];
		return nil;
	}

	NSArray *targets = nil;
	if( [connection isKindOfClass:[NSArray class]] ) targets = connection;
	else targets = [NSArray arrayWithObject:connection];

	for( connection in targets ) {
		if( ! [connection isKindOfClass:[MVChatConnection class]] ) continue;
		if( [room isKindOfClass:[NSArray class]] ) [connection joinChatRoomsNamed:room];
		else [connection joinChatRoomNamed:room];
	}

	return nil;
}
@end
#endif
