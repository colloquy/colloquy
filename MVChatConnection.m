#import "MVChatConnection.h"
#import "MVIRCChatConnection.h"
#import "MVSILCChatConnection.h"
#import "MVFileTransfer.h"
#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSURLAdditions.h"
#import "NSStringAdditions.h"
#import "NSAttributedStringAdditions.h"
#import "NSMethodSignatureAdditions.h"

NSString *MVChatConnectionGotRawMessageNotification = @"MVChatConnectionGotRawMessageNotification";

NSString *MVChatConnectionWillConnectNotification = @"MVChatConnectionWillConnectNotification";
NSString *MVChatConnectionDidConnectNotification = @"MVChatConnectionDidConnectNotification";
NSString *MVChatConnectionDidNotConnectNotification = @"MVChatConnectionDidNotConnectNotification";
NSString *MVChatConnectionWillDisconnectNotification = @"MVChatConnectionWillDisconnectNotification";
NSString *MVChatConnectionDidDisconnectNotification = @"MVChatConnectionDidDisconnectNotification";
NSString *MVChatConnectionErrorNotification = @"MVChatConnectionErrorNotification";

NSString *MVChatConnectionNeedNicknamePasswordNotification = @"MVChatConnectionNeedNicknamePasswordNotification";
NSString *MVChatConnectionGotPrivateMessageNotification = @"MVChatConnectionGotPrivateMessageNotification";

NSString *MVChatConnectionBuddyIsOnlineNotification = @"MVChatConnectionBuddyIsOnlineNotification";
NSString *MVChatConnectionBuddyIsOfflineNotification = @"MVChatConnectionBuddyIsOfflineNotification";
NSString *MVChatConnectionBuddyIsAwayNotification = @"MVChatConnectionBuddyIsAwayNotification";
NSString *MVChatConnectionBuddyIsUnawayNotification = @"MVChatConnectionBuddyIsUnawayNotification";
NSString *MVChatConnectionBuddyIsIdleNotification = @"MVChatConnectionBuddyIsIdleNotification";

NSString *MVChatConnectionSelfAwayStatusNotification = @"MVChatConnectionSelfAwayStatusNotification";

NSString *MVChatConnectionGotUserWhoisNotification = @"MVChatConnectionGotUserWhoisNotification";
NSString *MVChatConnectionGotUserServerNotification = @"MVChatConnectionGotUserServerNotification";
NSString *MVChatConnectionGotUserChannelsNotification = @"MVChatConnectionGotUserChannelsNotification";
NSString *MVChatConnectionGotUserOperatorNotification = @"MVChatConnectionGotUserOperatorNotification";
NSString *MVChatConnectionGotUserIdleNotification = @"MVChatConnectionGotUserIdleNotification";
NSString *MVChatConnectionGotUserWhoisCompleteNotification = @"MVChatConnectionGotUserWhoisCompleteNotification";

NSString *MVChatConnectionGotRoomInfoNotification = @"MVChatConnectionGotRoomInfoNotification";

NSString *MVChatConnectionGotJoinWhoListNotification = @"MVChatConnectionGotJoinWhoListNotification";
NSString *MVChatConnectionRoomExistingMemberListNotification = @"MVChatConnectionRoomExistingMemberListNotification";
NSString *MVChatConnectionJoinedRoomNotification = @"MVChatConnectionJoinedRoomNotification";
NSString *MVChatConnectionLeftRoomNotification = @"MVChatConnectionLeftRoomNotification";
NSString *MVChatConnectionUserJoinedRoomNotification = @"MVChatConnectionUserJoinedRoomNotification";
NSString *MVChatConnectionUserLeftRoomNotification = @"MVChatConnectionUserLeftRoomNotification";
NSString *MVChatConnectionUserQuitNotification = @"MVChatConnectionUserQuitNotification";
NSString *MVChatConnectionUserNicknameChangedNotification = @"MVChatConnectionUserNicknameChangedNotification";
NSString *MVChatConnectionUserKickedFromRoomNotification = @"MVChatConnectionUserKickedFromRoomNotification";
NSString *MVChatConnectionUserAwayStatusNotification = @"MVChatConnectionUserAwayStatusNotification";
NSString *MVChatConnectionGotMemberModeNotification = @"MVChatConnectionGotMemberModeNotification";
NSString *MVChatConnectionGotRoomModeNotification = @"MVChatConnectionGotRoomModeNotification";
NSString *MVChatConnectionGotRoomMessageNotification = @"MVChatConnectionGotRoomMessageNotification";
NSString *MVChatConnectionGotRoomTopicNotification = @"MVChatConnectionGotRoomTopicNotification";

NSString *MVChatConnectionNewBanNotification = @"MVChatConnectionNewBanNotification";
NSString *MVChatConnectionRemovedBanNotification = @"MVChatConnectionRemovedBanNotification";
NSString *MVChatConnectionBanlistReceivedNotification = @"MVChatConnectionBanlistReceivedNotification";

NSString *MVChatConnectionKickedFromRoomNotification = @"MVChatConnectionKickedFromRoomNotification";
NSString *MVChatConnectionInvitedToRoomNotification = @"MVChatConnectionInvitedToRoomNotification";

NSString *MVChatConnectionNicknameAcceptedNotification = @"MVChatConnectionNicknameAcceptedNotification";
NSString *MVChatConnectionNicknameRejectedNotification = @"MVChatConnectionNicknameRejectedNotification";

NSString *MVChatConnectionSubcodeRequestNotification = @"MVChatConnectionSubcodeRequestNotification";
NSString *MVChatConnectionSubcodeReplyNotification = @"MVChatConnectionSubcodeReplyNotification";

BOOL MVChatApplicationQuitting = NO;

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
- (void) _scheduleReconnectAttemptEvery:(NSTimeInterval) seconds;
- (void) _cancelReconnectAttempts;
@end

#pragma mark -

@implementation MVChatConnection
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
		_roomsCache = [[NSMutableDictionary dictionary] retain];

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
	int type = 0;
	if( [[url scheme] isEqualToString:@"irc"] ) type = MVChatConnectionIRCType;
	else if( [[url scheme] isEqualToString:@"silc"] ) type = MVChatConnectionSILCType;

	if( ( self = [self initWithServer:[url host] type:type port:[[url port] unsignedShortValue] user:[url user]] ) ) {
		[self setNicknamePassword:[url password]];

		if( [url fragment] && [[url fragment] length] > 0 ) {
			[self joinChatRoom:[url fragment]];
		} else if( [url path] && [[url path] length] >= 2 && ( [[[url path] substringFromIndex:1] hasPrefix:@"&"] || [[[url path] substringFromIndex:1] hasPrefix:@"+"] || [[[url path] substringFromIndex:1] hasPrefix:@"!"] ) ) {
			[self joinChatRoom:[[url path] substringFromIndex:1]];
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
	[_lastConnectAttempt release];
	[_awayMessage release];

	_npassword = nil;
	_roomsCache = nil;
	_cachedDate = nil;
	_lastConnectAttempt = nil;
	_awayMessage = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatConnectionType) type {
	// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
}

- (void) connect {
	if( [self status] != MVChatConnectionDisconnectedStatus && [self status] != MVChatConnectionServerDisconnectedStatus && [self status] != MVChatConnectionSuspendedStatus ) return;

	if( _lastConnectAttempt && [_lastConnectAttempt timeIntervalSinceNow] > -15. ) {
		[self _scheduleReconnectAttemptEvery:20.];
		return;
	}
// subclass this method, call super
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
	if( [self status] != MVChatConnectionConnectedStatus ) return;
// subclass this method, call super
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
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) realName {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
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
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

#pragma mark -

- (void) setAlternateNicknames:(NSArray *) nicknames {
	[_alternateNicks autorelease];
	_alternateNicks = [nicknames retain];
	_nextAltNickIndex = 0;
}

- (NSArray *) alternateNicknames {
	return _alternateNicks;
}

- (NSString *) nextAlternateNickname {
	if( [_alternateNicks count] && _nextAltNickIndex < [_alternateNicks count] ) {
		NSString *nick = [_alternateNicks objectAtIndex:_nextAltNickIndex];
		_nextAltNickIndex++;
		return nick;
	}

	return nil;
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
	[_npassword autorelease];
	if( [password length] ) _npassword = [password copy];
	else _npassword = nil;
}

- (NSString *) nicknamePassword {
	return [[_npassword retain] autorelease];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) password {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

#pragma mark -

- (void) setUsername:(NSString *) username {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) username {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
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
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (BOOL) isSecure {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
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
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) proxyServer {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (unsigned short) proxyServerPort {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
}

#pragma mark -

- (void) setProxyUsername:(NSString *) username {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) proxyUsername {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *) proxyPassword {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return nil;
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

- (MVUploadFileTransfer *) sendFile:(NSString *) path toUser:(NSString *) user {
	return [self sendFile:path toUser:user passively:NO];
}

- (MVUploadFileTransfer *) sendFile:(NSString *) path toUser:(NSString *) user passively:(BOOL) passive {
	return [[MVUploadFileTransfer transferWithSourceFile:path toUser:user onConnection:self passively:passive] retain];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) sendSubcodeReply:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) joinChatRooms:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! [rooms count] ) return;

	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) )
		if( [room length] ) [self joinChatRoom:room];
}

- (void) joinChatRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) partChatRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
// subclass this method, if needed
	return nil;
}

- (NSString *) displayNameForChatRoom:(NSString *) room {
// subclass this method, if needed
	return room;
}

- (NSString *) properNameForChatRoom:(NSString *) room {
	// subclass this method, if needed
	return room;
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) demoteMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) halfopMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) dehalfopMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) voiceMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) banMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) unbanMember:(NSString *) member inRoom:(NSString *) room {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) addUserToNotificationList:(NSString *) user {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) removeUserFromNotificationList:(NSString *) user {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) fetchInformationForUser:(NSString *) user withPriority:(BOOL) priority fromLocalServer:(BOOL) localOnly {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) fetchRoomList {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) fetchRoomListWithRooms:(NSArray *) rooms {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (void) stopFetchingRoomList {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
}

- (NSMutableDictionary *) roomListResults {
	return [[_roomsCache retain] autorelease];
}

#pragma mark -

- (NSAttributedString *) awayStatusMessage {
	return _awayMessage;
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

- (BOOL) waitingToReconnect {
	return ( ! [self isConnected] && _reconnectTimer ? YES : NO );
}

- (unsigned int) lag {
// subclass this method
	[self doesNotRecognizeSelector:_cmd];
	return 0;
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
	[self disconnect];
}

#pragma mark -

- (void) _willConnect {
	_nextAltNickIndex = 0;
	_status = MVChatConnectionConnectingStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillConnectNotification object:self];
}

- (void) _didConnect {
	[self _cancelReconnectAttempts];

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
	[self _scheduleReconnectAttemptEvery:30.];
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

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidDisconnectNotification object:self];
}

#pragma mark -

- (void) _scheduleReconnectAttemptEvery:(NSTimeInterval) seconds {
	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = [[NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector( connect ) userInfo:nil repeats:YES] retain];
}

- (void) _cancelReconnectAttempts {
	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = nil;
}

#pragma mark -

- (void) _addRoomToCache:(NSMutableDictionary *) info {
	[_roomsCache setObject:info forKey:[info objectForKey:@"room"]];
	[info removeObjectForKey:@"room"];
	
	NSNotification *notification = [NSNotification notificationWithName:MVChatConnectionGotRoomInfoNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
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

- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSString *message = [[command evaluatedArguments] objectForKey:@"message"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];
	NSString *room = [[command evaluatedArguments] objectForKey:@"room"];
	BOOL action = [[[command evaluatedArguments] objectForKey:@"action"] boolValue];
	unsigned long enc = [[[command evaluatedArguments] objectForKey:@"encoding"] unsignedLongValue];
	NSStringEncoding encoding = NSUTF8StringEncoding;

	if( ! [message isKindOfClass:[NSString class]] || ! [message length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid message."];
		return;
	}

	if( ! user && ( ! [room isKindOfClass:[NSString class]] || ! [room length] ) ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid room."];
		return;
	}

	if( ! room && ( ! [user isKindOfClass:[NSString class]] || ! [user length] ) ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user."];
		return;
	}

	switch( enc ) {
		default:
		case 'utF8': encoding = NSUTF8StringEncoding; break;
		case 'ascI': encoding = NSASCIIStringEncoding; break;
		case 'nlAs': encoding = NSNonLossyASCIIStringEncoding; break;

		case 'isL1': encoding = NSISOLatin1StringEncoding; break;
		case 'isL2': encoding = NSISOLatin2StringEncoding; break;
		case 'isL3': encoding = (NSStringEncoding) 0x80000203; break;
		case 'isL4': encoding = (NSStringEncoding) 0x80000204; break;
		case 'isL5': encoding = (NSStringEncoding) 0x80000205; break;
		case 'isL9': encoding = (NSStringEncoding) 0x8000020F; break;

		case 'cp50': encoding = NSWindowsCP1250StringEncoding; break;
		case 'cp51': encoding = NSWindowsCP1251StringEncoding; break;
		case 'cp52': encoding = NSWindowsCP1252StringEncoding; break;

		case 'mcRo': encoding = NSMacOSRomanStringEncoding; break;
		case 'mcEu': encoding = (NSStringEncoding) 0x8000001D; break;
		case 'mcCy': encoding = (NSStringEncoding) 0x80000007; break;
		case 'mcJp': encoding = (NSStringEncoding) 0x80000001; break;
		case 'mcSc': encoding = (NSStringEncoding) 0x80000019; break;
		case 'mcTc': encoding = (NSStringEncoding) 0x80000002; break;
		case 'mcKr': encoding = (NSStringEncoding) 0x80000003; break;

		case 'ko8R': encoding = (NSStringEncoding) 0x80000A02; break;

		case 'wnSc': encoding = (NSStringEncoding) 0x80000421; break;
		case 'wnTc': encoding = (NSStringEncoding) 0x80000423; break;
		case 'wnKr': encoding = (NSStringEncoding) 0x80000422; break;

		case 'jpUC': encoding = NSJapaneseEUCStringEncoding; break;
		case 'sJiS': encoding = (NSStringEncoding) 0x80000A01; break;

		case 'krUC': encoding = (NSStringEncoding) 0x80000940; break;

		case 'scUC': encoding = (NSStringEncoding) 0x80000930; break;
		case 'tcUC': encoding = (NSStringEncoding) 0x80000931; break;
		case 'gb30': encoding = (NSStringEncoding) 0x80000632; break;
		case 'gbKK': encoding = (NSStringEncoding) 0x80000631; break;
		case 'biG5': encoding = (NSStringEncoding) 0x80000A03; break;
		case 'bG5H': encoding = (NSStringEncoding) 0x80000A06; break;
	}

	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	if( [user length] ) [self sendMessage:attributeMsg withEncoding:encoding toUser:user asAction:action];
	else if( [room length] ) [self sendMessage:attributeMsg withEncoding:encoding toChatRoom:room asAction:action];
}

- (void) sendRawMessageScriptCommand:(NSScriptCommand *) command {
	NSString *msg = [[command evaluatedArguments] objectForKey:@"message"];

	if( ! [msg isKindOfClass:[NSString class]] || ! [msg length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid raw message."];
		return;
	}

	[self sendRawMessage:[[command evaluatedArguments] objectForKey:@"message"]];
}

- (void) sendSubcodeMessageScriptCommand:(NSScriptCommand *) command {
	NSString *cmd = [[command evaluatedArguments] objectForKey:@"command"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];
	id arguments = [[command evaluatedArguments] objectForKey:@"arguments"];
	unsigned long type = [[[command evaluatedArguments] objectForKey:@"type"] unsignedLongValue];

	if( ! [cmd isKindOfClass:[NSString class]] || ! [cmd length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode command."];
		return;
	}

	if( ! [user isKindOfClass:[NSString class]] || ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode user."];
		return;
	}

	if( [arguments isKindOfClass:[NSNull class]] ) arguments = nil;

	if( arguments && ! [arguments isKindOfClass:[NSString class]] && ! [arguments isKindOfClass:[NSArray class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode arguments."];
		return;
	}

	NSString *argumnentsString = nil;
	if( [arguments isKindOfClass:[NSArray class]] ) {
		NSEnumerator *enumerator = [arguments objectEnumerator];
		id arg = nil;

		argumnentsString = [NSMutableString stringWithFormat:@"%@", [enumerator nextObject]];

		while( ( arg = [enumerator nextObject] ) )
			[(NSMutableString *)argumnentsString appendFormat:@" %@", arg];
	} else argumnentsString = arguments;

	if( type == 'srpL' ) [self sendSubcodeReply:cmd toUser:user withArguments:argumnentsString];
	else [self sendSubcodeRequest:cmd toUser:user withArguments:argumnentsString];
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

	[self joinChatRooms:rms];
}

- (void) sendFileScriptCommand:(NSScriptCommand *) command {
	NSString *path = [[command evaluatedArguments] objectForKey:@"path"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];

	if( ! [path isKindOfClass:[NSString class]] || ! [path length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid file path."];
		return;
	}

	if( ! [user isKindOfClass:[NSString class]] || ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user."];
		return;
	}

	[self sendFile:path toUser:user];
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
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psR1", user, @"psR2", connection, @"psR3", nil];
	id result = [self callScriptHandler:'psRX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psL1", user, @"psL2", connection, @"psL3", nil];
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