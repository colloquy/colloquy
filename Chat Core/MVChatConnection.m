#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"
#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#import "MVIRCChatConnection.h"
#import "MVSILCChatConnection.h"
#import "MVFileTransfer.h"
#import "MVChatPluginManager.h"
#import "MVChatUserWatchRule.h"
#import "NSStringAdditions.h"
#import "NSAttributedStringAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSScriptCommandAdditions.h"
#import "NSNotificationAdditions.h"

NSString *MVChatConnectionWillConnectNotification = @"MVChatConnectionWillConnectNotification";
NSString *MVChatConnectionDidConnectNotification = @"MVChatConnectionDidConnectNotification";
NSString *MVChatConnectionDidNotConnectNotification = @"MVChatConnectionDidNotConnectNotification";
NSString *MVChatConnectionWillDisconnectNotification = @"MVChatConnectionWillDisconnectNotification";
NSString *MVChatConnectionDidDisconnectNotification = @"MVChatConnectionDidDisconnectNotification";
NSString *MVChatConnectionErrorNotification = @"MVChatConnectionErrorNotification";

NSString *MVChatConnectionNeedNicknamePasswordNotification = @"MVChatConnectionNeedNicknamePasswordNotification";
NSString *MVChatConnectionNeedCertificatePasswordNotification = @"MVChatConnectionNeedCertificatePasswordNotification";
NSString *MVChatConnectionNeedPublicKeyVerificationNotification = @"MVChatConnectionNeedPublicKeyVerificationNotification";

NSString *MVChatConnectionGotRawMessageNotification = @"MVChatConnectionGotRawMessageNotification";
NSString *MVChatConnectionGotPrivateMessageNotification = @"MVChatConnectionGotPrivateMessageNotification";
NSString *MVChatConnectionChatRoomListUpdatedNotification = @"MVChatConnectionChatRoomListUpdatedNotification";

NSString *MVChatConnectionSelfAwayStatusChangedNotification = @"MVChatConnectionSelfAwayStatusChangedNotification";

NSString *MVChatConnectionWatchedUserOnlineNotification = @"MVChatConnectionWatchedUserOnlineNotification";
NSString *MVChatConnectionWatchedUserOfflineNotification = @"MVChatConnectionWatchedUserOfflineNotification";

NSString *MVChatConnectionNicknameAcceptedNotification = @"MVChatConnectionNicknameAcceptedNotification";
NSString *MVChatConnectionNicknameRejectedNotification = @"MVChatConnectionNicknameRejectedNotification";

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
	return ( [scheme isEqualToString:@"irc"] || [scheme isEqualToString:@"silc"] );
}

+ (NSArray *) defaultServerPortsForType:(MVChatConnectionType) type {
	if( type == MVChatConnectionIRCType ) return [MVIRCChatConnection defaultServerPorts];
	else if( type == MVChatConnectionSILCType ) return [MVSILCChatConnection defaultServerPorts];
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

		_status = MVChatConnectionDisconnectedStatus;
		_proxy = MVChatConnectionNoProxy;
		_roomsCache = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:500];
		_persistentInformation = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];
		_joinedRooms = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:10];
		_localUser = nil;

		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _systemDidWake: ) name:NSWorkspaceDidWakeNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _systemWillSleep: ) name:NSWorkspaceWillSleepNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSWorkspaceWillPowerOffNotification object:[NSWorkspace sharedWorkspace]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (id) initWithType:(MVChatConnectionType) connectionType {
	[self release];

	if( connectionType == MVChatConnectionIRCType ) {
		self = [[MVIRCChatConnection allocWithZone:nil] init];
	} else if ( connectionType == MVChatConnectionSILCType ) {
		self = [[MVSILCChatConnection allocWithZone:nil] init];
	} else self = nil;

	return self;
}

- (id) initWithURL:(NSURL *) serverURL {
	NSParameterAssert( [MVChatConnection supportsURLScheme:[serverURL scheme]] );

	int connectionType = 0;
	if( [[serverURL scheme] isEqualToString:@"irc"] ) connectionType = MVChatConnectionIRCType;
	else if( [[serverURL scheme] isEqualToString:@"silc"] ) connectionType = MVChatConnectionSILCType;

	if( ( self = [self initWithServer:[serverURL host] type:connectionType port:[[serverURL port] unsignedShortValue] user:[serverURL user]] ) ) {
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
		if( [localNickname length] ) [self setNickname:localNickname];
		if( [serverAddress length] ) [self setServer:serverAddress];
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
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

	[_npassword release];
	[_roomsCache release];
	[_cachedDate release];
	[_joinedRooms release];
	[_chatUserWatchRules release];
	[_localUser release];
	[_lastConnectAttempt release];
	[_awayMessage release];
	[_persistentInformation release];
	[_proxyServer release];
	[_proxyUsername release];
	[_proxyPassword release];

	_npassword = nil;
	_roomsCache = nil;
	_cachedDate = nil;
	_joinedRooms = nil;
	_chatUserWatchRules = nil;
	_localUser = nil;
	_lastConnectAttempt = nil;
	_awayMessage = nil;
	_persistentInformation = nil;
	_proxyServer = nil;
	_proxyUsername = nil;
	_proxyPassword = nil;
	
	[super dealloc];
}

#pragma mark -

- (MVChatConnectionType) type {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
}

- (unsigned) hash {
	if( ! _hash ) _hash = ( [self type] ^ [[self server] hash] ^ [self serverPort] ^ [[self nickname] hash] );
	return _hash;
}

#pragma mark -

- (NSSet *) supportedFeatures {
// subclass this method, if needed
	return nil;
}

- (BOOL) supportsFeature:(NSString *) key {
	NSParameterAssert( key != nil );
	return [[self supportedFeatures] containsObject:key];
}

#pragma mark -

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

- (BOOL) supportsStringEncoding:(NSStringEncoding) supportedEncoding {
	const NSStringEncoding *encodings = [self supportedStringEncodings];
	unsigned i = 0;

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
	if( [nick length] ) [self setNickname:nick];
	if( [address length] ) [self setServer:address];
	[self setServerPort:port];
	[self disconnect];
	[self connect];
}

- (void) disconnect {
	[self disconnectWithReason:nil];
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
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

- (NSString *) preferredNickname {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (void) setAlternateNicknames:(NSArray *) nicknames {
	id old = _alternateNicks;
	_alternateNicks = [nicknames copyWithZone:nil];
	[old release];
	_nextAltNickIndex = 0;
}

- (NSArray *) alternateNicknames {
	return [NSArray arrayWithArray:_alternateNicks];
}

- (NSString *) nextAlternateNickname {
	if( [[self alternateNicknames] count] && _nextAltNickIndex < [[self alternateNicknames] count] ) {
		NSString *nick = [[self alternateNicknames] objectAtIndex:_nextAltNickIndex];
		_nextAltNickIndex++;
		return [[nick retain] autorelease];
	}

	return nil;
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) newPassword {
	id old = _npassword;
	if( [newPassword length] ) _npassword = [newPassword copyWithZone:nil];
	else _npassword = nil;
	[old release];
}

- (NSString *) nicknamePassword {
	return [[_npassword retain] autorelease];
}

#pragma mark -

- (NSString *) certificateServiceName {
// subclass this method, if needed
	return nil;
}

- (BOOL) setCertificatePassword:(NSString *) password {
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

- (void) setServer:(NSString *) server {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
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

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(getter=isSecure, setter=setSecure:) BOOL secure;
#endif

- (BOOL) isSecure {
	return _secure;
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
	id old = _proxyServer;
	_proxyServer = [address copyWithZone:nil];
	[old release];
}

- (NSString *) proxyServer {
	return [[_proxyServer retain] autorelease];
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
	id old = _proxyUsername;
	_proxyUsername = [newUsername copyWithZone:nil];
	[old release];
}

- (NSString *) proxyUsername {
	return [[_proxyUsername retain] autorelease];
}

#pragma mark -

- (void) setProxyPassword:(NSString *) newPassword {
	id old = _proxyPassword;
	_proxyPassword = [newPassword copyWithZone:nil];
	[old release];
}

- (NSString *) proxyPassword {
	return [[_proxyPassword retain] autorelease];
}

#pragma mark -

- (void) setPersistentInformation:(NSDictionary *) information {
	@synchronized( _persistentInformation ) {
		if( [information count] ) [_persistentInformation setDictionary:information];
		else [_persistentInformation removeAllObjects];
	}
}

- (NSDictionary *) persistentInformation {
	return [NSDictionary dictionaryWithDictionary:_persistentInformation];
}

#pragma mark -

- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept {
// subclass this method, if needed
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

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! [rooms count] ) return;

	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) )
		if( [room length] ) [self joinChatRoomNamed:room withPassphrase:nil];
}

- (void) joinChatRoomNamed:(NSString *) room {
	[self joinChatRoomNamed:room withPassphrase:nil];
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (NSSet *) joinedChatRooms {
	@synchronized( _joinedRooms ) {
		return [NSSet setWithArray:[_joinedRooms allValues]];
	} return nil;
}

- (MVChatRoom *) joinedChatRoomWithName:(NSString *) name {
	@synchronized( _joinedRooms ) {
		return [_joinedRooms objectForKey:[name lowercaseString]];
	} return nil;
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return nil;
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	return room;
}

#pragma mark -

- (NSSet *) knownChatUsers {
	// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
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
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (MVChatUser *) localUser {
	return [[_localUser retain] autorelease];
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
	@synchronized( _chatUserWatchRules ) {
		[_chatUserWatchRules removeObject:rule];
	}
}

- (NSSet *) chatUserWatchRules {
	@synchronized( _chatUserWatchRules ) {
		return [NSSet setWithSet:_chatUserWatchRules];
	} return nil;
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
	return [[_roomsCache retain] autorelease];
}

#pragma mark -

- (NSAttributedString *) awayStatusMessage {
	return [[_awayMessage retain] autorelease];
}

- (void) setAwayStatusMessage:(NSAttributedString *) message {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly, getter=isConnected) BOOL connected;
#endif

- (BOOL) isConnected {
	return ( _status == MVChatConnectionConnectedStatus );
}

- (MVChatConnectionStatus) status {
	return _status;
}

- (unsigned int) lag {
// subclass this method, if needed
	return 0;
}

#pragma mark -

- (void) scheduleReconnectAttemptEvery:(NSTimeInterval) seconds {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( connect ) object:nil];
	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = [[NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector( connect ) userInfo:nil repeats:YES] retain];
}

- (void) cancelPendingReconnectAttempts {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( connect ) object:nil];
	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = nil;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly, getter=isWaitingToReconnect) BOOL waitingToReconnect;
#endif

- (BOOL) isWaitingToReconnect {
	return ( ! [self isConnected] && _reconnectTimer ? YES : NO );
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
	id old = _lastError;
	_lastError = nil;
	[old release];

	_nextAltNickIndex = 0;
	_status = MVChatConnectionConnectingStatus;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionWillConnectNotification object:self];
}

- (void) _didConnect {
	[self cancelPendingReconnectAttempts];

	[[self localUser] _setStatus:MVChatUserAvailableStatus];
	[[self localUser] _setDateConnected:[NSDate date]];
	[[self localUser] _setDateDisconnected:nil];

	_status = MVChatConnectionConnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidConnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( connected: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didNotConnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidNotConnectNotification object:self];
	[self scheduleReconnectAttemptEvery:30.];
}

- (void) _willDisconnect {
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionWillDisconnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( disconnecting: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didDisconnect {
	BOOL wasConnected = ( _status == MVChatConnectionConnectedStatus || _status == MVChatConnectionSuspendedStatus || _status == MVChatConnectionServerDisconnectedStatus );

	[[self localUser] _setStatus:MVChatUserOfflineStatus];
	[[self localUser] _setDateDisconnected:[NSDate date]];

	if( _status != MVChatConnectionSuspendedStatus && _status != MVChatConnectionServerDisconnectedStatus )
		_status = MVChatConnectionDisconnectedStatus;

	NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
	MVChatRoom *room = nil;

	while( ( room = [enumerator nextObject] ) ) {
		if( ! [room isJoined] ) continue;
		[room _setDateParted:[NSDate date]];
	}

	[_roomsCache removeAllObjects];

	id old = _localUser;
	_localUser = nil;
	[old release];

	old = _cachedDate;
	_cachedDate = nil;
	[old release];

	if( wasConnected ) [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidDisconnectNotification object:self];
}

- (void) _postError:(NSError *) error {
	id old = _lastError;
	_lastError = [error copyWithZone:nil];
	[old release];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionErrorNotification object:self userInfo:[NSDictionary dictionaryWithObject:_lastError forKey:@"error"]];
}

- (void) _setStatus:(MVChatConnectionStatus) newStatus {
	_status = newStatus;
}

#pragma mark -

- (void) _addRoomToCache:(NSMutableDictionary *) info {
	[_roomsCache setObject:info forKey:[info objectForKey:@"room"]];
	[info removeObjectForKey:@"room"];

	if( _roomListDirty ) return; // already queued to send notification
	_roomListDirty = YES;

	[self performSelector:@selector( _sendRoomListUpdatedNotification ) withObject:nil afterDelay:( 1. / 3. )];
}

- (void) _sendRoomListUpdatedNotification {
	_roomListDirty = NO;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionChatRoomListUpdatedNotification object:self];
}

#pragma mark -

- (void) _addJoinedRoom:(MVChatRoom *) room {
	@synchronized( _joinedRooms ) {
		[_joinedRooms setObject:room forKey:[[room name] lowercaseString]];
	}
}

- (void) _removeJoinedRoom:(MVChatRoom *) room {
	@synchronized( _joinedRooms ) {
		[_joinedRooms removeObjectForKey:[[room name] lowercaseString]];
	}
}

#pragma mark -

- (unsigned int) _watchRulesMatchingUser:(MVChatUser *) user {
	unsigned int count = 0;
	@synchronized( _chatUserWatchRules ) {
		NSEnumerator *enumerator = [_chatUserWatchRules objectEnumerator];
		MVChatUserWatchRule *rule = nil;
		while( ( rule = [enumerator nextObject] ) ) {
			if( [rule matchChatUser:user] )
				count++;
		}
	}

	return count;
}

- (void) _sendPossibleOnlineNotificationForUser:(MVChatUser *) user {
	if( [user _onlineNotificationSent] ) return;
	if( [user isWatched] || [self _watchRulesMatchingUser:user] ) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionWatchedUserOnlineNotification object:user userInfo:nil];
		[user _setOnlineNotificationSent:YES];
		[user _setDateDisconnected:nil];
		if( [user status] != MVChatUserAwayStatus )
			[user _setStatus:MVChatUserAvailableStatus];
		if( ! [user dateDisconnected] )
			[user _setDateConnected:[NSDate date]];
	}
}

- (void) _sendPossibleOfflineNotificationForUser:(MVChatUser *) user {
	if( ! [user _onlineNotificationSent] ) return;
	if( [user isWatched] ) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionWatchedUserOfflineNotification object:user userInfo:nil];
		[user _setOnlineNotificationSent:NO];
		[user _setWatched:NO];

		if( ! [user dateDisconnected] )
			[user _setDateDisconnected:[NSDate date]];
		[user _setStatus:MVChatUserOfflineStatus];

		@synchronized( _chatUserWatchRules ) {
			NSEnumerator *enumerator = [_chatUserWatchRules objectEnumerator];
			MVChatUserWatchRule *rule = nil;
			while( ( rule = [enumerator nextObject] ) )
				[rule removeMatchedUser:user];
		}
	}
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The connection id %@ doesn't have the \"%@\" property.", [self uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of connection id %@ is read only.", key, [self uniqueIdentifier]]];
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
	return [[[NSTextStorage allocWithZone:nil] initWithAttributedString:_awayMessage] autorelease];
}

- (void) setScriptTypedAwayMessage:(id) message {
	NSString *msg = message;
	if( [message isKindOfClass:[NSTextStorage class]] ) msg = [message string];
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:msg baseURL:nil];
	[self setAwayStatusMessage:attributeMsg];
}

#pragma mark -

- (unsigned long) scriptTypedEncoding {
	return [NSString scriptTypedEncodingFromStringEncoding:[self encoding]];
}

- (void) setScriptTypedEncoding:(unsigned long) newEncoding {
	[self setEncoding:[NSString stringEncodingFromScriptTypedEncoding:newEncoding]];
}

#pragma mark -

- (NSArray *) knownChatUsersArray {
	return [[self knownChatUsers] allObjects];
}

- (MVChatUser *) valueInKnownChatUsersArrayAtIndex:(unsigned) index {
	return [[self knownChatUsersArray] objectAtIndex:index];
}

- (MVChatUser *) valueInKnownChatUsersArrayWithUniqueID:(id) identifier {
	return [self chatUserWithUniqueIdentifier:identifier];
}

- (MVChatUser *) valueInKnownChatUsersArrayWithName:(NSString *) name {
	NSEnumerator *enumerator = [[self knownChatUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
		if( [[user nickname] caseInsensitiveCompare:name] == NSOrderedSame )
			return user;

	return nil;
}

#pragma mark -

- (NSArray *) joinedChatRoomsArray {
	return [[self joinedChatRooms] allObjects];
}

- (MVChatRoom *) valueInJoinedChatRoomsArrayAtIndex:(unsigned) index {
	return [[self joinedChatRoomsArray] objectAtIndex:index];
}

- (MVChatRoom *) valueInJoinedChatRoomsArrayWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
	MVChatRoom *room = nil;

	while( ( room = [enumerator nextObject] ) )
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

	NSAttributedString *realMessage = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	NSStringEncoding realEncoding = NSUTF8StringEncoding;
	BOOL realAction = ( action ? [action boolValue] : NO );
	BOOL realLocalEcho = ( localEcho ? [localEcho boolValue] : YES );

	NSArray *targets = nil;
	if( [target isKindOfClass:[NSArray class]] ) targets = target;
	else targets = [NSArray arrayWithObject:target];

	NSEnumerator *enumerator = [targets objectEnumerator];
	while( ( target = [enumerator nextObject] ) ) {
		if( ! [target isKindOfClass:[MVChatUser class]] && ! [target isKindOfClass:[MVChatRoom class]] )
			continue;

		if( encoding ) {
			realEncoding = [NSString stringEncodingFromScriptTypedEncoding:[encoding unsignedIntValue]];
		} else if( [target isKindOfClass:[MVChatRoom class]] ) {
			realEncoding = [(MVChatRoom *)target encoding];
		} else {
			realEncoding = [[(MVChatRoom *)target connection] encoding];
		}

		[target sendMessage:realMessage withEncoding:realEncoding asAction:realAction];

		if( realLocalEcho ) {
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

			NSDictionary *options = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:realEncoding], @"StringEncoding", cformat, @"FormatType", nil];
			NSData *msgData = [realMessage chatFormatWithOptions:options];
			[options release];

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

	NSEnumerator *enumerator = [targets objectEnumerator];
	while( ( connection = [enumerator nextObject] ) ) {
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

	NSEnumerator *enumerator = [targets objectEnumerator];
	while( ( connection = [enumerator nextObject] ) ) {
		if( ! [connection isKindOfClass:[MVChatConnection class]] ) continue;
		if( [room isKindOfClass:[NSArray class]] ) [connection joinChatRoomsNamed:room];
		else [connection joinChatRoomNamed:room];
	}

	return nil;
}
@end