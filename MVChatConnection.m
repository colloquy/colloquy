#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"
#import "MVIRCChatConnection.h"
#import "MVSILCChatConnection.h"
#import "MVFileTransfer.h"
#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSStringAdditions.h"
#import "NSAttributedStringAdditions.h"
#import "NSMethodSignatureAdditions.h"

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
NSString *MVChatConnectionChatRoomlistUpdatedNotification = @"MVChatConnectionChatRoomlistUpdatedNotification";

NSString *MVChatConnectionSelfAwayStatusChangedNotification = @"MVChatConnectionSelfAwayStatusChangedNotification";

NSString *MVChatConnectionNicknameAcceptedNotification = @"MVChatConnectionNicknameAcceptedNotification";
NSString *MVChatConnectionNicknameRejectedNotification = @"MVChatConnectionNicknameRejectedNotification";

NSString *MVChatConnectionSubcodeRequestNotification = @"MVChatConnectionSubcodeRequestNotification";
NSString *MVChatConnectionSubcodeReplyNotification = @"MVChatConnectionSubcodeReplyNotification";

BOOL MVChatApplicationQuitting = NO;

static const NSStringEncoding supportedEncodings[] = {
	NSUTF8StringEncoding,
	NSNonLossyASCIIStringEncoding,
	NSASCIIStringEncoding, 0
};

@interface MVChatRoom (MVChatRoomPrivate)
- (void) _setDateParted:(NSDate *) date;
@end

#pragma mark -

@implementation MVChatConnection
+ (BOOL) supportsURLScheme:(NSString *) scheme {
	if( ! scheme ) return NO;
	return ( [scheme isEqualToString:@"irc"] || [scheme isEqualToString:@"silc"] );
}

+ (NSArray *) defaultServerPortsForType:(MVChatConnectionType) type {
	if( type == MVChatConnectionIRCType ) return [MVIRCChatConnection defaultServerPorts];
	else if( type == MVChatConnectionSILCType ) return [MVSILCChatConnection defaultServerPorts];
	return [NSArray array];
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
		_nextAltNickIndex = 0;

		_status = MVChatConnectionDisconnectedStatus;
		_proxy = MVChatConnectionNoProxy;
		_roomsCache = [[NSMutableDictionary dictionaryWithCapacity:250] retain];
		_persistentInformation = [[NSMutableDictionary dictionaryWithCapacity:2] retain];
		_joinedRooms = [[NSMutableSet setWithCapacity:5] retain];
		_localUser = nil;

		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _systemDidWake: ) name:NSWorkspaceDidWakeNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _systemWillSleep: ) name:NSWorkspaceWillSleepNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSWorkspaceWillPowerOffNotification object:[NSWorkspace sharedWorkspace]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (id) initWithType:(MVChatConnectionType) type {
	NSZone *zone = [self zone];
	[self release];

	if( type == MVChatConnectionIRCType ) {
		self = [[MVIRCChatConnection allocWithZone:zone] init];
	} else if ( type == MVChatConnectionSILCType ) {
		self = [[MVSILCChatConnection allocWithZone:zone] init];
	} else self = nil;

	return self;
}

- (id) initWithURL:(NSURL *) url {
	NSParameterAssert( [MVChatConnection supportsURLScheme:[url scheme]] );

	int type = 0;
	if( [[url scheme] isEqualToString:@"irc"] ) type = MVChatConnectionIRCType;
	else if( [[url scheme] isEqualToString:@"silc"] ) type = MVChatConnectionSILCType;

	if( ( self = [self initWithServer:[url host] type:type port:[[url port] unsignedShortValue] user:[url user]] ) ) {
		[self setNicknamePassword:[url password]];

		if( [url fragment] && [[url fragment] length] > 0 ) {
			[self joinChatRoomNamed:[url fragment]];
		} else if( [url path] && [[url path] length] > 1 ) {
			[self joinChatRoomNamed:[[url path] substringFromIndex:1]];
		}
	}

	return self;
}

- (id) initWithServer:(NSString *) server type:(MVChatConnectionType) type port:(unsigned short) port user:(NSString *) nickname {
	if( ( self = [self initWithType:type] ) ) {
		if( [nickname length] ) [self setNickname:nickname];
		if( [server length] ) [self setServer:server];
		[self setServerPort:port];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

	[_npassword release];
	[_roomsCache release];
	[_cachedDate release];
	[_joinedRooms release];
	[_localUser release];
	[_lastConnectAttempt release];
	[_awayMessage release];
	[_persistentInformation release];

	_npassword = nil;
	_roomsCache = nil;
	_cachedDate = nil;
	_joinedRooms = nil;
	_localUser = nil;
	_lastConnectAttempt = nil;
	_awayMessage = nil;
	_persistentInformation = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatConnectionType) type {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
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

- (BOOL) supportsStringEncoding:(NSStringEncoding) encoding {
	const NSStringEncoding *encodings = [self supportedStringEncodings];
	unsigned i = 0;

	for( i = 0; encodings[i]; i++ )
		if( encodings[i] == encoding ) return YES;

	return NO;
}

#pragma mark -

- (void) connect {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname {
	if( [nickname length] ) [self setNickname:nickname];
	if( [server length] ) [self setServer:server];
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

- (NSString *) urlScheme {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return @"chat";
}

- (NSURL *) url {
	NSString *url = [NSString stringWithFormat:@"%@://%@@%@:%hu", [self urlScheme], [[self preferredNickname] stringByEncodingIllegalURLCharacters], [[self server] stringByEncodingIllegalURLCharacters], [self serverPort]];
	if( url ) return [NSURL URLWithString:url];
	return nil;
}

#pragma mark -

- (void) setEncoding:(NSStringEncoding) encoding {
	NSParameterAssert( [self supportsStringEncoding:encoding] );
	_encoding = encoding;
}

- (NSStringEncoding) encoding {
	return _encoding;
}

- (NSString *) stringWithEncodedBytes:(const char *) bytes {
	return [NSString stringWithBytes:bytes encoding:[self encoding]];
}

- (const char *) encodedBytesWithString:(NSString *) string {
	return [string bytesUsingEncoding:[self encoding] allowLossyConversion:YES];
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
	[_alternateNicks autorelease];
	_alternateNicks = [nicknames copyWithZone:[self zone]];
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

- (void) setNicknamePassword:(NSString *) password {
	[_npassword autorelease];
	if( [password length] ) _npassword = [password copyWithZone:[self zone]];
	else _npassword = nil;
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

- (void) setSecure:(BOOL) ssl {
// subclass this method, if needed
}

- (BOOL) isSecure {
// subclass this method, if needed
	return NO;
}

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) type {
	_proxy = type;
}

- (MVChatConnectionProxy) proxyType {
	return _proxy;
}

#pragma mark -

- (void) setProxyServer:(NSString *) address {
// subclass this method, if needed
}

- (NSString *) proxyServer {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port {
// subclass this method, if needed
}

- (unsigned short) proxyServerPort {
// subclass this method, if needed
	return 0;
}

#pragma mark -

- (void) setProxyUsername:(NSString *) username {
// subclass this method, if needed
}

- (NSString *) proxyUsername {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
// subclass this method, if needed
}

- (NSString *) proxyPassword {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (void) setPersistentInformation:(NSDictionary *) information {
	if( [information count] ) [_persistentInformation setDictionary:information];
	else [_persistentInformation removeAllObjects];
}

- (NSDictionary *) persistentInformation {
	return [NSDictionary dictionaryWithDictionary:_persistentInformation];
}

#pragma mark -

- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept {
// subclass this method, if needed
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action {
// subclass this method, if used
	[self doesNotRecognizeSelector:_cmd];
}

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toUser:(NSString *) user asAction:(BOOL) action {
// subclass this method, if needed
	[self sendMessage:message withEncoding:encoding toTarget:user asAction:action];
}

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toChatRoom:(NSString *) room asAction:(BOOL) action {
// subclass this method, if needed
	[self sendMessage:message withEncoding:encoding toTarget:[room lowercaseString] asAction:action];
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw {
	[self sendRawMessage:raw immediately:NO];
}

- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) sendRawMessageWithFormat:(NSString *) format, ... {
	NSParameterAssert( format != nil );

	va_list ap;
	va_start( ap, format );

	NSString *command = [[[NSString alloc] initWithFormat:format arguments:ap] autorelease];
	[self sendRawMessage:command immediately:NO];

	va_end( ap );
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
	NSSet *ret = nil;
	@synchronized( _joinedRooms ) {
		ret = [NSSet setWithSet:_joinedRooms];
	} return ret;
}

- (MVChatRoom *) joinedChatRoomWithName:(NSString *) name {
	MVChatRoom *room = nil;

	@synchronized( _joinedRooms ) {
		NSEnumerator *enumerator = [_joinedRooms objectEnumerator];
		while( ( room = [enumerator nextObject] ) )
			if( [name caseInsensitiveCompare:[room name]] == NSOrderedSame )
				break;
	}

	return [[room retain] autorelease];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return nil;
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	return room;
}

#pragma mark -

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

- (void) addUserToNotificationList:(MVChatUser *) user {
// subclass this method, if needed
}

- (void) removeUserFromNotificationList:(MVChatUser *) user {
// subclass this method, if needed
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

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) clearAwayStatus {
	[self setAwayStatusWithMessage:nil];
}

#pragma mark -

- (BOOL) isConnected {
	return (BOOL) ( _status == MVChatConnectionConnectedStatus );
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
	extern BOOL MVChatApplicationQuitting;
	MVChatApplicationQuitting = YES;
	if ( [self isConnected] )
		[self disconnect];
}

#pragma mark -

- (void) _willConnect {
	_nextAltNickIndex = 0;
	_status = MVChatConnectionConnectingStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillConnectNotification object:self];
}

- (void) _didConnect {
	[self cancelPendingReconnectAttempts];

	_status = MVChatConnectionConnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidConnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( connected: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didNotConnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidNotConnectNotification object:self];
	[self scheduleReconnectAttemptEvery:30.];
}

- (void) _willDisconnect {
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillDisconnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( disconnecting: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didDisconnect {
	if( _status != MVChatConnectionSuspendedStatus && _status != MVChatConnectionServerDisconnectedStatus ) {
		_status = MVChatConnectionDisconnectedStatus;
	}

	NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
	MVChatRoom *room = nil;

	while( ( room = [enumerator nextObject] ) ) {
		if( ! [room isJoined] ) continue;
		[room _setDateParted:[NSDate date]];	
	}

	[_localUser release];
	_localUser = nil;

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidDisconnectNotification object:self];
}

#pragma mark -

- (void) _addRoomToCache:(NSMutableDictionary *) info {
	[_roomsCache setObject:info forKey:[info objectForKey:@"room"]];
	[info removeObjectForKey:@"room"];

	NSNotification *notification = [NSNotification notificationWithName:MVChatConnectionChatRoomlistUpdatedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

#pragma mark -

- (void) _addJoinedRoom:(MVChatRoom *) room {
	@synchronized( _joinedRooms ) {
		[_joinedRooms addObject:room];
	}
}

- (void) _removeJoinedRoom:(MVChatRoom *) room {
	@synchronized( _joinedRooms ) {
		[_joinedRooms removeObject:room];
	}
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (void) connectScriptCommand:(NSScriptCommand *) command {
	[self connect];
}

- (void) disconnectScriptCommand:(NSScriptCommand *) command {
	[self disconnect];
}

- (void) sendRawMessageScriptCommand:(NSScriptCommand *) command {
	NSString *msg = [[command evaluatedArguments] objectForKey:@"message"];

	if( ! [msg isKindOfClass:[NSString class]] || ! [msg length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid raw message."];
		return;
	}

	[self sendRawMessage:[[command evaluatedArguments] objectForKey:@"message"]];
}

- (void) returnFromAwayStatusScriptCommand:(NSScriptCommand *) command {
	[self clearAwayStatus];
}

- (void) joinChatRoomScriptCommand:(NSScriptCommand *) command {
	id rooms = [[command evaluatedArguments] objectForKey:@"room"];

	if( rooms && ! [rooms isKindOfClass:[NSString class]] && ! [rooms isKindOfClass:[NSArray class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid chat room to join."];
		return;
	}

	NSArray *rms = nil;
	if( [rooms isKindOfClass:[NSString class]] )
		rms = [NSArray arrayWithObject:rooms];
	else rms = rooms;

	[self joinChatRoomsNamed:rms];
}

- (NSString *) urlString {
	return [[self url] absoluteString];
}

- (NSTextStorage *) scriptTypedAwayMessage {
	return [[[NSTextStorage alloc] initWithAttributedString:_awayMessage] autorelease];
}

- (void) setScriptTypedAwayMessage:(NSString *) message {
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	[self setAwayStatusWithMessage:attributeMsg];
}
@end

#pragma mark -

@implementation MVChatScriptPlugin (MVChatScriptPluginConnectionSupport)
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psR1", user, @"psR2", [user connection], @"psR3", nil];
	id result = [self callScriptHandler:'psRX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psL1", user, @"psL2", [user connection], @"psL3", nil];
	id result = [self callScriptHandler:'psLX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	[self callScriptHandler:'cTsX' withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	[self callScriptHandler:'dFsX' withArguments:args forSelector:_cmd];
}
@end