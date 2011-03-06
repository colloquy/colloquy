#import "MVIRCChatConnection.h"
#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCFileTransfer.h"
#import "MVIRCNumerics.h"
#import "MVDirectChatConnectionPrivate.h"
#import "MVChatString.h"

#import "AsyncSocket.h"
#import "InterThreadMessaging.h"
#import "MVChatuserWatchRule.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "NSScannerAdditions.h"
#import "NSDataAdditions.h"
#import "MVUtilities.h"

#if USE(ATTRIBUTED_CHAT_STRING)
#import "NSAttributedStringAdditions.h"
#endif

#if ENABLE(PLUGINS)
#import "NSMethodSignatureAdditions.h"
#import "MVChatPluginManager.h"
#endif

#import "RegexKitLite.h"

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#define JVQueueWaitBeforeConnected 120.
#define JVPingServerInterval 120.
#define JVPeriodicEventsInterval 600.
#define JVWatchedUserWHOISDelay 300.
#define JVWatchedUserISONDelay 60.
#define JVEndCapabilityTimeoutDelay 45.
#define JVMaximumCommandLength 510
#define JVMaximumISONCommandLength JVMaximumCommandLength
#define JVMaximumWatchCommandLength JVMaximumCommandLength
#define JVMaximumMembersForWhoRequest 40
#define JVFirstViableTimestamp 631138520
#define JVFallbackEncoding NSISOLatin1StringEncoding

static const NSStringEncoding supportedEncodings[] = {
	/* Universal */
	NSUTF8StringEncoding,
	/* Western */
	NSASCIIStringEncoding,
	NSISOLatin1StringEncoding,			// ISO Latin 1
	(NSStringEncoding) 0x80000203,		// ISO Latin 3
	(NSStringEncoding) 0x8000020F,		// ISO Latin 9
	NSMacOSRomanStringEncoding,			// Mac
	NSWindowsCP1252StringEncoding,		// Windows
	/* Baltic */
	(NSStringEncoding) 0x8000020D,		// ISO Latin 7
	(NSStringEncoding) 0x80000507,		// Windows
	/* Central European */
	NSISOLatin2StringEncoding,			// ISO Latin 2
	(NSStringEncoding) 0x80000204,		// ISO Latin 4
	(NSStringEncoding) 0x8000001D,		// Mac
	NSWindowsCP1250StringEncoding,		// Windows
	/* Cyrillic */
	(NSStringEncoding) 0x80000A02,		// KOI8-R
	(NSStringEncoding) 0x80000205,		// ISO Latin 5
	(NSStringEncoding) 0x80000007,		// Mac
	NSWindowsCP1251StringEncoding,		// Windows
	/* Greek */
	(NSStringEncoding) 0x80000207,		// ISO Latin 7
	(NSStringEncoding) 0x80000006,		// Mac
	NSWindowsCP1253StringEncoding,		// Windows
	/* Japanese */
	(NSStringEncoding) 0x80000A01,		// ShiftJIS
	NSISO2022JPStringEncoding,			// ISO-2022-JP
	NSJapaneseEUCStringEncoding,		// EUC
	(NSStringEncoding) 0x80000001,		// Mac
	NSShiftJISStringEncoding,			// Windows
	/* Simplified Chinese */
	(NSStringEncoding) 0x80000632,		// GB 18030
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
	(NSStringEncoding) 0x80000631,		// GBK
#endif
	(NSStringEncoding) 0x80000930,		// EUC
	(NSStringEncoding) 0x80000019,		// Mac
	(NSStringEncoding) 0x80000421,		// Windows
	/* Traditional Chinese */
	(NSStringEncoding) 0x80000A03,		// Big5
	(NSStringEncoding) 0x80000A06,		// Big5 HKSCS
	(NSStringEncoding) 0x80000931,		// EUC
	(NSStringEncoding) 0x80000002,		// Mac
	(NSStringEncoding) 0x80000423,		// Windows
	/* Korean */
	(NSStringEncoding) 0x80000940,		// EUC
	(NSStringEncoding) 0x80000003,		// Mac
	(NSStringEncoding) 0x80000422,		// Windows
	/* Thai */
	(NSStringEncoding) 0x8000020b,		// ISO-8859-11
	(NSStringEncoding) 0x80000015,		// Mac
	(NSStringEncoding) 0x8000041d,		// Windows
	/* Hebrew */
	(NSStringEncoding) 0x80000208,		// ISO-8859-8
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
	(NSStringEncoding) 0x80000005,		// Mac
#endif
	(NSStringEncoding) 0x80000505,		// Windows
	/* Arabic */
	(NSStringEncoding) 0x80000206,		// ISO-8859-6
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
	(NSStringEncoding) 0x80000004,		// Mac
#endif
	(NSStringEncoding) 0x80000506,		// Windows
	0
};

@implementation MVIRCChatConnection
+ (NSArray *) defaultServerPorts {
	return [NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:6667],[NSNumber numberWithUnsignedShort:6660],[NSNumber numberWithUnsignedShort:6669],[NSNumber numberWithUnsignedShort:7000],[NSNumber numberWithUnsignedShort:994], nil];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_serverPort = 6667;
		_server = @"irc.freenode.net";
		_username = [NSUserName() retain];
		_nickname = [_username retain];
		_currentNickname = [_nickname retain];
		_realName = [NSFullUserName() retain];
		_localUser = [[MVIRCChatUser allocWithZone:nil] initLocalUserWithConnection:self];
		[self _resetSupportedFeatures];
	}

	return self;
}

- (void) dealloc {
	[_chatConnection setDelegate:nil];

	[_chatConnection release];
	[_directClientConnections release];
	[_server release];
	[_realServer release];
	[_currentNickname release];
	[_nickname release];
	[_username release];
	[_password release];
	[_realName release];
	[_lastSentIsonNicknames release];
	[_sendQueue release];
	[_queueWait release];
	[_lastCommand release];
	[_pendingJoinRoomNames release];
	[_pendingWhoisUsers release];
	[_roomPrefixes release];
	[_serverInformation release];
	[_uniqueIdentifier release];
	[_umichNoIdentdCaptcha release];
	[_failedNickname release];

	[super dealloc];
}

#pragma mark -

- (NSString *) urlScheme {
	return @"irc";
}

- (MVChatConnectionType) type {
	return MVChatConnectionIRCType;
}

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

#pragma mark -

- (void) connect {
	if( _status != MVChatConnectionDisconnectedStatus && _status != MVChatConnectionServerDisconnectedStatus && _status != MVChatConnectionSuspendedStatus ) return;

	MVSafeAdoptAssign( _lastConnectAttempt, [[NSDate allocWithZone:nil] init] );
	MVSafeRetainAssign( _queueWait, [NSDate dateWithTimeIntervalSinceNow:JVQueueWaitBeforeConnected] );

	if( [_connectionThread respondsToSelector:@selector( cancel )] )
		[_connectionThread cancel];
	_connectionThread = nil;

	[self _willConnect]; // call early so other code has a chance to change our info

	[NSThread detachNewThreadSelector:@selector( _ircRunloop ) toTarget:self withObject:nil];
}

- (void) disconnectWithReason:(MVChatString *) reason {
	[self performSelectorOnMainThread:@selector( cancelPendingReconnectAttempts ) withObject:nil waitUntilDone:YES];

	if( _status == MVChatConnectionConnectedStatus ) {
		_userDisconnected = YES;
		if( reason.length ) {
			NSData *msg = [[self class] _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
			[self sendRawMessageImmediatelyWithComponents:@"QUIT :", msg, nil];
		} else [self sendRawMessage:@"QUIT" immediately:YES];
	} else if( _status == MVChatConnectionConnectingStatus ) {
		_userDisconnected = YES;
		if( _connectionThread )
			[[self _chatConnection] performSelector:@selector( disconnect ) inThread:_connectionThread waitUntilDone:NO];
	}
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	NSParameterAssert( name != nil );
	MVSafeCopyAssign( _realName, name );
}

- (NSString *) realName {
	return _realName;
}

#pragma mark -

- (void) setNickname:(NSString *) newNickname {
	NSParameterAssert( newNickname != nil );
	NSParameterAssert( newNickname.length > 0 );

	BOOL connectiongOrConnected = ( _status == MVChatConnectionConnectedStatus || _status == MVChatConnectionConnectingStatus );

	if( ! _nickname || ! connectiongOrConnected )
		MVSafeCopyAssign( _nickname, newNickname );

	if( [newNickname isEqualToString:_currentNickname] )
		return;

	if( ! _currentNickname || ! connectiongOrConnected )
		[self _setCurrentNickname:newNickname];

	if( connectiongOrConnected )
		[self sendRawMessageImmediatelyWithFormat:@"NICK %@", newNickname];
}

- (NSString *) nickname {
	return _currentNickname;
}

- (void) setPreferredNickname:(NSString *) newNickname {
	NSParameterAssert( newNickname != nil );
	NSParameterAssert( newNickname.length > 0 );

	MVSafeCopyAssign( _nickname, newNickname );

	[self setNickname:newNickname];
}

- (NSString *) preferredNickname {
	return _nickname;
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) newPassword {
	[super setNicknamePassword:newPassword];
	_pendingIdentificationAttempt = NO;
	if( [self isConnected] )
		[self _identifyWithServicesUsingNickname:[self nickname]]; // new password for the current nick -> current nickname
}

#pragma mark -

- (void) setPassword:(NSString *) newPassword {
	MVSafeCopyAssign( _password, newPassword );
}

- (NSString *) password {
	return _password;
}

#pragma mark -

- (void) setUsername:(NSString *) newUsername {
	NSParameterAssert( newUsername != nil );
	NSParameterAssert( newUsername.length > 0 );
	MVSafeCopyAssign( _username, newUsername );
}

- (NSString *) username {
	return _username;
}

#pragma mark -

- (void) setServer:(NSString *) newServer {
	if( newServer.length >= 6 && [newServer hasPrefix:@"irc://"] )
		newServer = [newServer substringFromIndex:6];
	else if( newServer.length >= 7 && [newServer hasPrefix:@"ircs://"] )
		newServer = [newServer substringFromIndex:7];
	NSParameterAssert( newServer != nil );
	NSParameterAssert( newServer.length > 0 );
	MVSafeCopyAssign( _server, newServer );

	[super setServer:newServer];
}

- (NSString *) server {
	return _server;
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	_serverPort = ( port ? port : 6667 );
}

- (unsigned short) serverPort {
	return _serverPort;
}

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments {
	NSParameterAssert( command != nil );
	[self _sendCommand:command withArguments:arguments withEncoding:[self encoding] toTarget:nil];
}

#pragma mark -

- (BOOL) recentlyConnected {
	return (([NSDate timeIntervalSinceReferenceDate] - [_connectedDate timeIntervalSinceReferenceDate]) > 10.);
}

- (double) minimumSendQueueDelay {
	return self.recentlyConnected ? .5 : .25;
}

- (double) maximumSendQueueDelay {
	return self.recentlyConnected ? 1.5 : 2.;
}

- (double) sendQueueDelayIncrement {
	return self.recentlyConnected ? .25 : .1;
}

#pragma mark -

- (void) sendRawMessage:(id) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );
	NSParameterAssert( [raw isKindOfClass:[NSData class]] || [raw isKindOfClass:[NSString class]] );

	if( ! now ) {
		@synchronized( _sendQueue ) {
			now = ! _sendQueue.count;
		}

		if( now ) now = ( ! _queueWait || [_queueWait timeIntervalSinceNow] <= 0. );
		if( now ) now = ( ! _lastCommand || [_lastCommand timeIntervalSinceNow] <= (-[self minimumSendQueueDelay]) );
	}

	if( now && _connectionThread ) {
		MVSafeAdoptAssign( _lastCommand, [[NSDate allocWithZone:nil] init] );

		[self performSelector:@selector( _writeDataToServer: ) withObject:raw inThread:_connectionThread waitUntilDone:NO];
	} else {
		if( ! _sendQueue )
			_sendQueue = [[NSMutableArray allocWithZone:nil] initWithCapacity:20];

		@synchronized( _sendQueue ) {
			[_sendQueue addObject:raw];
		}

		if( ! _sendQueueProcessing && _connectionThread )
			[self performSelector:@selector( _startSendQueue ) withObject:nil inThread:_connectionThread waitUntilDone:NO];
	}
}

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! rooms.count ) return;

	if( !_pendingJoinRoomNames )
		_pendingJoinRoomNames = [[NSMutableSet allocWithZone:nil] initWithCapacity:10];

	NSMutableArray *roomList = [[NSMutableArray allocWithZone:nil] initWithCapacity:rooms.count];

	for( NSString *room in rooms ) {
		room = [room stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		if( !room.length )
			continue;

		if( [room rangeOfString:@" "].location == NSNotFound ) { // join non-password rooms in bulk
			room = [self properNameForChatRoomNamed:room];
			if( [self joinedChatRoomWithUniqueIdentifier:room] || [_pendingJoinRoomNames containsObject:room] )
				continue;
			[roomList addObject:room];
			[_pendingJoinRoomNames addObject:room];
		} else { // has a password, join separately
			if( roomList.count ) {
				// join all requested rooms before this one so we do things in order
				[self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
				[roomList removeAllObjects]; // clear list since we joined them
			}

			NSString *password = nil;
			NSArray *components = [room componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet] limit:1 remainingString:&password];
			if( !components.count)
				continue;

			room = [self properNameForChatRoomNamed:[components objectAtIndex:0]];

			[self joinChatRoomNamed:room withPassphrase:password];

			continue;
		}

		if( roomList.count >= 10 ) {
			// join all requested rooms up to this point so we don't send too long of a list
			[self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
			[roomList removeAllObjects]; // clear list since we joined them
		}
	}

	if( roomList.count ) [self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];

	[roomList release];
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( room.length > 0 );

	if( !_pendingJoinRoomNames )
		_pendingJoinRoomNames = [[NSMutableSet allocWithZone:nil] initWithCapacity:10];

	room = [self properNameForChatRoomNamed:room];

	if( !room.length )
		return;

	MVChatRoom *chatRoom = [self chatRoomWithUniqueIdentifier:room];
	if( [chatRoom isJoined] )
		return;

	if( passphrase.length ) {
		NSString *previousPassphrase = [chatRoom attributeForMode:MVChatRoomPassphraseToJoinMode];
		if( ![previousPassphrase isEqualToString:passphrase] )
			[_pendingJoinRoomNames removeObject:room];
	}

	if( [_pendingJoinRoomNames containsObject:room] )
		return;

	[_pendingJoinRoomNames addObject:room];

	if( passphrase.length ) {
		[chatRoom _setMode:MVChatRoomPassphraseToJoinMode withAttribute:passphrase];
		[self sendRawMessageWithFormat:@"JOIN %@ %@", room, passphrase];
	} else {
		[chatRoom _removeMode:MVChatRoomPassphraseToJoinMode];
		[self sendRawMessageWithFormat:@"JOIN %@", room];
	}
}

- (MVChatRoom *) joinedChatRoomWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );
	return [super joinedChatRoomWithUniqueIdentifier:[(NSString *)identifier lowercaseString]];
}

- (MVChatRoom *) joinedChatRoomWithName:(NSString *) name {
	return [self joinedChatRoomWithUniqueIdentifier:[self properNameForChatRoomNamed:name]];
}

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );
	MVChatRoom *room = [super chatRoomWithUniqueIdentifier:[identifier lowercaseString]];
	if( ! room ) room = [[[MVIRCChatRoom allocWithZone:nil] initWithName:identifier andConnection:self] autorelease];
	return room;
}

- (MVChatRoom *) chatRoomWithName:(NSString *) name {
	return [self chatRoomWithUniqueIdentifier:[self properNameForChatRoomNamed:name]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	static NSCharacterSet *defaultPrefixes = nil;
	if( ! _roomPrefixes && ! defaultPrefixes )
		defaultPrefixes = [[NSCharacterSet characterSetWithCharactersInString:@"#&+!"] retain];
	if( ! _roomPrefixes ) return defaultPrefixes;
	return _roomPrefixes;
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	if( ! room.length ) return room;
	room = [room stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return ( [[self chatRoomNamePrefixes] characterIsMember:[room characterAtIndex:0]] ? room : [@"#" stringByAppendingString:room] );
}

- (NSString *) displayNameForChatRoomNamed:(NSString *) room {
	room = [room stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (room.length > 2 && [room characterAtIndex:1] == '#')
		return [room substringFromIndex:2];
	if (room.length > 1 && [room characterAtIndex:1] != '#')
		return [room substringFromIndex:1];
	return room;
}

#pragma mark -

- (NSSet *) chatUsersWithNickname:(NSString *) name {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:name]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );
	MVChatUser *user = [super chatUserWithUniqueIdentifier:[identifier lowercaseString]];
	if( ! user ) user = [[[MVIRCChatUser allocWithZone:nil] initWithNickname:identifier andConnection:self] autorelease];
	return user;
}

#pragma mark -

- (void) addChatUserWatchRule:(MVChatUserWatchRule *) rule {
	@synchronized( _chatUserWatchRules ) {
		if( [_chatUserWatchRules containsObject:rule] ) return;
	}

	[super addChatUserWatchRule:rule];

	if( [rule nickname] && ! [rule nicknameIsRegularExpression] ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[rule nickname]];
		[rule matchChatUser:user];
		if( [self isConnected] ) {
			if( _watchCommandSupported ) [self sendRawMessageWithFormat:@"WATCH +%@", [rule nickname]];
			else [self sendRawMessageWithFormat:@"ISON %@", [rule nickname]];
		}
	} else {
		@synchronized( _knownUsers ) {
			for( id key in _knownUsers ) {
				MVChatUser *user = [_knownUsers objectForKey:key];
				[rule matchChatUser:user];
			}
		}
	}
}

- (void) removeChatUserWatchRule:(MVChatUserWatchRule *) rule {
	[super removeChatUserWatchRule:rule];

	if( [self isConnected] && _watchCommandSupported && [rule nickname] && ! [rule nicknameIsRegularExpression] )
		[self sendRawMessageWithFormat:@"WATCH -%@", [rule nickname]];
}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 300. ) {
		[self sendRawMessage:@"LIST"];
		MVSafeAdoptAssign( _cachedDate, [[NSDate allocWithZone:nil] init] );
	}
}

- (void) stopFetchingChatRoomList {
	if( _cachedDate && ABS( [_cachedDate timeIntervalSinceNow] ) < 600. )
		[self sendRawMessage:@"LIST STOP" immediately:YES];
}

#pragma mark -

- (void) setAwayStatusMessage:(MVChatString *) message {
	if( message.length ) {
		MVSafeCopyAssign( _awayMessage, message );

		NSData *msg = [[self class] _flattenedIRCDataForMessage:message withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
		[self sendRawMessageImmediatelyWithComponents:@"AWAY :", msg, nil];

		[[self localUser] _setAwayStatusMessage:msg];
		[[self localUser] _setStatus:MVChatUserAwayStatus];
	} else {
		MVSafeAdoptAssign( _awayMessage, nil );

		[self sendRawMessage:@"AWAY" immediately:YES];

		[[self localUser] _setAwayStatusMessage:nil];
		[[self localUser] _setStatus:MVChatUserAvailableStatus];
	}
}

#pragma mark -

- (void) purgeCaches {
	[super purgeCaches];

	[self _pruneKnownUsers];
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionPrivate)
- (AsyncSocket *) _chatConnection {
	return _chatConnection;
}

- (void) _connect {
	MVAssertCorrectThreadRequired( _connectionThread );

	id old = _chatConnection;
	_chatConnection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];
	[old setDelegate:nil];
	[old disconnect];
	[old release];

	[_chatConnection enablePreBuffering];

	_pendingIdentificationAttempt = NO;
	_sentEndCapabilityCommand = NO;
	_userDisconnected = NO;

	_failedNickname = nil;
	_failedNicknameCount = 1;
	_nicknameShortened = NO;

	NSString *server = (_bouncer != MVChatConnectionNoBouncer && _bouncerServer.length ? _bouncerServer : _server);
	unsigned short serverPort = (_bouncer != MVChatConnectionNoBouncer ? (_bouncerServerPort ? _bouncerServerPort : 6667) : _serverPort);

	if( ! [_chatConnection connectToHost:server onPort:serverPort error:NULL] )
		[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:NO];
	else [self _resetSendQueueInterval];
}

- (oneway void) _ircRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];

	[NSThread prepareForInterThreadMessages];

	_connectionThread = [NSThread currentThread];
	if( [_connectionThread respondsToSelector:@selector( setName: )] )
		[_connectionThread setName:[[self url] absoluteString]];

	[self _connect];

	[pool drain];
	pool = nil;

	while( _status == MVChatConnectionConnectedStatus || _status == MVChatConnectionConnectingStatus ) {
		pool = [[NSAutoreleasePool allocWithZone:nil] init];
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:5.]];
		[pool drain];
	}

	pool = [[NSAutoreleasePool allocWithZone:nil] init];

	// make sure the connection has sent all the delegate calls it has scheduled
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.]];

	if( _connectionThread == [NSThread currentThread] )
		_connectionThread = nil;

	[pool drain];
}

#pragma mark -

- (void) _willConnect {
	[self _resetSupportedFeatures];

	[super _willConnect];
}

- (void) _didDisconnect {
	MVAssertMainThreadRequired();

	if( _status == MVChatConnectionServerDisconnectedStatus ) {
		if( ABS( [_lastConnectAttempt timeIntervalSinceNow] ) > 300. )
			[self performSelector:@selector( connect ) withObject:nil afterDelay:5.];
		[self scheduleReconnectAttempt];
	}

	[_failedNickname release];
	_failedNickname = nil;
	_failedNicknameCount = 1;
	_nicknameShortened = NO;

	[super _didDisconnect];
}

#pragma mark -

- (BOOL) socketWillConnect:(AsyncSocket *) sock {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( [[self proxyServer] length] && [self proxyServerPort] ) {
		if( _proxy == MVChatConnectionHTTPSProxy || _proxy == MVChatConnectionHTTPProxy ) {
			NSMutableDictionary *settings = [[NSMutableDictionary allocWithZone:nil] init];
			if( _proxy == MVChatConnectionHTTPSProxy ) {
				[settings setObject:[self proxyServer] forKey:(NSString *)kCFStreamPropertyHTTPSProxyHost];
				[settings setObject:[NSNumber numberWithUnsignedShort:[self proxyServerPort]] forKey:(NSString *)kCFStreamPropertyHTTPSProxyPort];
			} else {
				[settings setObject:[self proxyServer] forKey:(NSString *)kCFStreamPropertyHTTPProxyHost];
				[settings setObject:[NSNumber numberWithUnsignedShort:[self proxyServerPort]] forKey:(NSString *)kCFStreamPropertyHTTPProxyPort];
			}

			CFReadStreamSetProperty( [sock getCFReadStream], kCFStreamPropertyHTTPProxy, (CFDictionaryRef) settings );
			CFWriteStreamSetProperty( [sock getCFWriteStream], kCFStreamPropertyHTTPProxy, (CFDictionaryRef) settings );
			[settings release];
		} else if( _proxy == MVChatConnectionSOCKS4Proxy || _proxy == MVChatConnectionSOCKS5Proxy ) {
			NSMutableDictionary *settings = [[NSMutableDictionary allocWithZone:nil] init];

			[settings setObject:[self proxyServer] forKey:(NSString *)kCFStreamPropertySOCKSProxyHost];
			[settings setObject:[NSNumber numberWithUnsignedShort:[self proxyServerPort]] forKey:(NSString *)kCFStreamPropertySOCKSProxyPort];

			if( [[self proxyUsername] length] )
				[settings setObject:[self proxyUsername] forKey:(NSString *)kCFStreamPropertySOCKSUser];
			if( [[self proxyPassword] length] )
				[settings setObject:[self proxyPassword] forKey:(NSString *)kCFStreamPropertySOCKSPassword];

			if( _proxy == MVChatConnectionSOCKS4Proxy )
				[settings setObject:(NSString *)kCFStreamSocketSOCKSVersion4 forKey:(NSString *)kCFStreamPropertySOCKSVersion];

			CFReadStreamSetProperty( [sock getCFReadStream], kCFStreamPropertySOCKSProxy, (CFDictionaryRef) settings );
			CFWriteStreamSetProperty( [sock getCFWriteStream], kCFStreamPropertySOCKSProxy, (CFDictionaryRef) settings );
			[settings release];
		}
	}

	BOOL secure = _secure;
	if( _bouncer == MVChatConnectionColloquyBouncer )
		secure = NO; // This should always be YES in the future when the bouncer supports secure connections.

	if( secure ) {
		CFReadStreamSetProperty( [sock getCFReadStream], kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL );
		CFWriteStreamSetProperty( [sock getCFWriteStream], kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL );

		NSMutableDictionary *settings = [[NSMutableDictionary allocWithZone:nil] init];
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
		[settings setObject:[NSNumber numberWithBool:NO] forKey:(NSString *)kCFStreamSSLValidatesCertificateChain];

		CFReadStreamSetProperty( [sock getCFReadStream], kCFStreamPropertySSLSettings, (CFDictionaryRef) settings );
		CFWriteStreamSetProperty( [sock getCFWriteStream], kCFStreamPropertySSLSettings, (CFDictionaryRef) settings );

		[settings release];
	}

	return YES;
}

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( sock != _chatConnection ) return;

	MVSafeRetainAssign( _lastError, error );
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( sock != _chatConnection ) return;

	[self retain];

	id old = _chatConnection;
	_chatConnection = nil;
	[old setDelegate:nil];
	[old release];

	[self _stopSendQueue];

	@synchronized( _sendQueue ) {
		[_sendQueue removeAllObjects];
	}

	[self _setCurrentNickname:_nickname];

	MVSafeAdoptAssign( _lastCommand, nil );
	MVSafeAdoptAssign( _queueWait, nil );
	MVSafeAdoptAssign( _lastSentIsonNicknames, nil );
	MVSafeAdoptAssign( _pendingWhoisUsers, nil );
	MVSafeAdoptAssign( _pendingJoinRoomNames, nil );

	_isonSentCount = 0;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _pingServer ) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _periodicEvents ) object:nil];
//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _whoisWatchedUsers ) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _checkWatchedUsers ) object:nil];

	if( _status == MVChatConnectionConnectingStatus ) {
		[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:NO];
	} else {
		if( _lastError && !_userDisconnected )
			_status = MVChatConnectionServerDisconnectedStatus;
		[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:NO];
	}

	@synchronized( _knownUsers ) {
		for( id key in _knownUsers ) {
			MVChatUser *user = [_knownUsers objectForKey:key];
			[user _setStatus:MVChatUserUnknownStatus];
		}
	}

	@synchronized( _chatUserWatchRules ) {
		for( MVChatUserWatchRule *rule in _chatUserWatchRules )
			[rule removeMatchedUsersForConnection:self];
	}

	[self release];
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	MVAssertCorrectThreadRequired( _connectionThread );

	NSString *password = _password;
	NSString *username = ( _username.length ? _username : @"anonymous" );

	if( _bouncer == MVChatConnectionGenericBouncer ) {
		if( _bouncerPassword ) password = _bouncerPassword;
		if( _bouncerUsername.length ) username = _bouncerUsername;
	} else if( _bouncer == MVChatConnectionColloquyBouncer ) {
		// PASS <account> [ '~' <device-identifier> ] ':' <account-pass> [ ':' <server-pass> ]
		NSMutableString *mutablePassword = [NSMutableString string];

		[mutablePassword appendString:( _bouncerUsername.length ? _bouncerUsername : @"anonymous" )];
		if( _bouncerDeviceIdentifier.length ) [mutablePassword appendFormat:@"~%@", _bouncerDeviceIdentifier];
		[mutablePassword appendFormat:@":%@", ( _bouncerPassword.length ? _bouncerPassword : @"" )];
		if( password.length ) [mutablePassword appendFormat:@":%@", password];

		password = mutablePassword;

		// USER <connection-identifier> | ([ ('irc' | 'ircs') '://' ] <username> '@' <server> [ ':' <server-port> ])
		if( _bouncerConnectionIdentifier.length ) {
			username = _bouncerConnectionIdentifier;
		} else {
			NSMutableString *mutableUsername = [NSMutableString string];

			if( _secure ) [mutableUsername appendString:@"ircs://"];
			[mutableUsername appendFormat:@"%@@%@", username, _server];
			if( _serverPort && _serverPort != 6667 ) [mutableUsername appendFormat:@":%u", _serverPort];

			username = mutableUsername;
		}
	}

	if( _requestsSASL ) {
		// Schedule an end to the capability negotiation in case it stalls the connection.
		[self _sendEndCapabilityCommandAfterTimeout];

		[self sendRawMessageImmediatelyWithFormat:@"CAP REQ :sasl"];
	}

	if( password.length ) [self sendRawMessageImmediatelyWithFormat:@"PASS %@", password];
	[self sendRawMessageImmediatelyWithFormat:@"NICK %@", [self preferredNickname]];
	[self sendRawMessageImmediatelyWithFormat:@"USER %@ 0 * :%@", username, ( _realName.length ? _realName : @"Anonymous User" )];

	[self performSelector:@selector( _periodicEvents ) withObject:nil afterDelay:JVPeriodicEventsInterval];
	[self performSelector:@selector( _pingServer ) withObject:nil afterDelay:JVPingServerInterval];

	[self _readNextMessageFromServer];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _processIncomingMessage:data fromServer:YES];

	[self _readNextMessageFromServer];
}

#pragma mark -

- (void) processIncomingMessage:(id) raw fromServer:(BOOL) fromServer {
	NSParameterAssert([raw isKindOfClass:[NSData class]]);
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:raw, @"message", [NSNumber numberWithBool:fromServer], @"fromServer", nil];
	[self performSelector:@selector(_processIncomingMessageWithInfo:) withObject:info inThread:_connectionThread waitUntilDone:NO];
}

- (void) _processIncomingMessageWithInfo:(NSDictionary *) info {
	NSData *message	= [info objectForKey:@"message"];
	NSNumber *fromServer = [info objectForKey:@"fromServer"];
	[self _processIncomingMessage:message fromServer:[fromServer boolValue]];
}

- (void) _processIncomingMessage:(NSData *) data fromServer:(BOOL) fromServer {
	MVAssertCorrectThreadRequired( _connectionThread );

	NSString *rawString = [self _newStringWithBytes:[data bytes] length:data.length];

	const char *line = (const char *)[data bytes];
	NSUInteger len = data.length;
	const char *end = line + len - 2; // minus the line endings

	if( *end != '\x0D' )
		end = line + len - 1; // this server only uses \x0A for the message line ending, lets work with it

	const char *sender = NULL;
	NSUInteger senderLength = 0;
	const char *user = NULL;
	NSUInteger userLength = 0;
	const char *host = NULL;
	NSUInteger hostLength = 0;
	const char *command = NULL;
	NSUInteger commandLength = 0;

	NSMutableArray *parameters = [[NSMutableArray allocWithZone:nil] initWithCapacity:15];

	// Parsing as defined in 2.3.1 at http://www.irchelp.org/irchelp/rfc/rfc2812.txt

	if( len <= 2 )
		goto end; // bad message

#define checkAndMarkIfDone() if( line == end ) done = YES
#define consumeWhitespace() while( *line == ' ' && line != end && ! done ) line++
#define notEndOfLine() line != end && ! done

	BOOL done = NO;
	if( notEndOfLine() ) {
		if( *line == ':' ) {
			// prefix: ':' <sender> [ '!' <user> ] [ '@' <host> ] ' ' { ' ' }
			sender = ++line;
			while( notEndOfLine() && *line != ' ' && *line != '!' && *line != '@' ) line++;
			senderLength = (line - sender);
			checkAndMarkIfDone();

			if( ! done && *line == '!' ) {
				user = ++line;
				while( notEndOfLine() && *line != ' ' && *line != '@' ) line++;
				userLength = (line - user);
				checkAndMarkIfDone();
			}

			if( ! done && *line == '@' ) {
				host = ++line;
				while( notEndOfLine() && *line != ' ' ) line++;
				hostLength = (line - host);
				checkAndMarkIfDone();
			}

			if( ! done ) line++;
			consumeWhitespace();
		}

		if( notEndOfLine() ) {
			// command: <letter> { <letter> } | <number> <number> <number>
			// letter: 'a' ... 'z' | 'A' ... 'Z'
			// number: '0' ... '9'
			command = line;
			while( notEndOfLine() && *line != ' ' ) line++;
			commandLength = (line - command);
			checkAndMarkIfDone();

			if( ! done ) line++;
			consumeWhitespace();
		}

		while( notEndOfLine() ) {
			// params: [ ':' <trailing data> | <letter> { <letter> } ] [ ' ' { ' ' } ] [ <params> ]
			const char *currentParameter = NULL;
			id param = nil;
			if( *line == ':' ) {
				currentParameter = ++line;
				param = [[NSMutableData allocWithZone:nil] initWithBytes:currentParameter length:(end - currentParameter)];
				done = YES;
			} else {
				currentParameter = line;
				while( notEndOfLine() && *line != ' ' ) line++;
				param = [self _newStringWithBytes:currentParameter length:(line - currentParameter)];
				checkAndMarkIfDone();
				if( ! done ) line++;
			}

			if( param ) [parameters addObject:param];
			[param release];

			consumeWhitespace();
		}
	}

#undef checkAndMarkIfDone
#undef consumeWhitespace
#undef notEndOfLine

end:
	{
		NSString *senderString = [self _newStringWithBytes:sender length:senderLength];
		NSString *commandString = ((command && commandLength) ? [[NSString allocWithZone:nil] initWithBytes:command length:commandLength encoding:NSASCIIStringEncoding] : nil);

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:rawString, @"message", data, @"messageData", (senderString ? senderString : @""), @"sender", (commandString ? commandString : @""), @"command", parameters, @"parameters", [NSNumber numberWithBool:NO], @"outbound", [NSNumber numberWithBool:fromServer], @"fromServer", nil]];

		NSString *selectorString = [[NSString allocWithZone:nil] initWithFormat:@"_handle%@WithParameters:fromSender:", (commandString ? [commandString capitalizedString] : @"Unknown")];
		SEL selector = NSSelectorFromString( selectorString );

		[selectorString release];
		[commandString release];
		[senderString release];

		if( [self respondsToSelector:selector] ) {
			MVChatUser *chatUser = nil;
			// if user is not null that shows it was a user not a server sender.
			// the sender was also a user if senderString equals the current local nickname (some bouncers will do this).
			if( ( senderString.length && user && userLength ) || [senderString isEqualToString:_currentNickname] ) {
				chatUser = [self chatUserWithUniqueIdentifier:senderString];
				if( ! [chatUser address] && host && hostLength ) {
					NSString *hostString = [self _newStringWithBytes:host length:hostLength];
					[chatUser _setAddress:hostString];
					[hostString release];
				}

				if( ! [chatUser username] ) {
					NSString *userString = [self _newStringWithBytes:user length:userLength];
					[chatUser _setUsername:userString];
					[userString release];
				}
			}

			[self performSelector:selector withObject:parameters withObject:( chatUser ? (id) chatUser : (id) senderString )];
		}
	}

	[rawString release];
	[parameters release];
}

#pragma mark -

- (void) _writeDataToServer:(id) raw {
	MVAssertCorrectThreadRequired( _connectionThread );

	NSMutableData *data = nil;
	NSString *string = [[self _stringFromPossibleData:raw] retain];

	if( [raw isKindOfClass:[NSMutableData class]] ) {
		data = [raw retain];
	} else if( [raw isKindOfClass:[NSData class]] ) {
		data = [raw mutableCopyWithZone:nil];
	} else if( [raw isKindOfClass:[NSString class]] ) {
		data = [[raw dataUsingEncoding:[self encoding] allowLossyConversion:YES] mutableCopyWithZone:nil];
	}

	// IRC messages are always lines of characters terminated with a CR-LF
	// (Carriage Return - Line Feed) pair, and these messages SHALL NOT
	// exceed 512 characters in length, counting all characters including
	// the trailing CR-LF. Thus, there are 510 characters maximum allowed
	// for the command and its parameters.

	if( data.length > JVMaximumCommandLength ) [data setLength:JVMaximumCommandLength];

	if ([data hasSuffixBytes:"\x0D" length:1]) {
		[data appendBytes:"\x0A" length:1];
	} else if (![data hasSuffixBytes:"\x0D\x0A" length:2]) {
		if ([data hasSuffixBytes:"\x0A" length:1])
			[data replaceBytesInRange:NSMakeRange((data.length - 1), 1) withBytes:"\x0D\x0A" length:2];
		else [data appendBytes:"\x0D\x0A" length:2];
	}

	[_chatConnection writeData:data withTimeout:-1. tag:0];

	NSString *stringWithPasswordsHidden = [string stringByReplacingOccurrencesOfRegex:@"(^PASS |IDENTIFY (?:[^ ]+ )?|(?:LOGIN|AUTH|JOIN) [^ ]+ )[^ ]+$" withString:@"$1********" options:RKLCaseless range:NSMakeRange(0, string.length) error:NULL];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:stringWithPasswordsHidden, @"message", data, @"messageData", [NSNumber numberWithBool:YES], @"outbound", nil]];

	[string release];
	[data release];
}

- (void) _readNextMessageFromServer {
	MVAssertCorrectThreadRequired( _connectionThread );

	static NSData *delimiter = nil;
	// IRC messages end in \x0D\x0A, but some non-compliant servers only use \x0A during the connecting phase
	if( ! delimiter ) delimiter = [[NSData allocWithZone:nil] initWithBytes:"\x0A" length:1];
	[_chatConnection readDataToData:delimiter withTimeout:-1. tag:0];
}

#pragma mark -

#if USE(ATTRIBUTED_CHAT_STRING)
+ (NSData *) _flattenedIRCDataForMessage:(MVChatString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format {
	NSString *cformat = nil;

	switch( format ) {
	case MVChatConnectionDefaultMessageFormat:
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

	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:enc], @"StringEncoding", cformat, @"FormatType", nil];
	return [message chatFormatWithOptions:options];
}
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
+ (NSData *) _flattenedIRCDataForMessage:(MVChatString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format {
	return [message dataUsingEncoding:enc allowLossyConversion:YES];
}
#endif

- (void) _sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) msgEncoding toTarget:(id) target withTargetPrefix:(NSString *) targetPrefix withAttributes:(NSDictionary *) attributes localEcho:(BOOL) echo {
	MVAssertMainThreadRequired();
	NSParameterAssert( [target isKindOfClass:[MVChatUser class]] || [target isKindOfClass:[MVChatRoom class]] );

	NSMutableData *msg = [[[self class] _flattenedIRCDataForMessage:message withEncoding:msgEncoding andChatFormat:[self outgoingChatFormat]] mutableCopyWithZone:nil];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( id ), @encode( NSDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processOutgoingMessageAsData:to:attributes: )];
	[invocation setArgument:&msg atIndex:2];
	[invocation setArgument:&target atIndex:3];
	[invocation setArgument:&attributes atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	if( ! msg.length ) {
		[msg release];
		return;
	}

	if( echo ) {
		MVChatRoom *room = ([target isKindOfClass:[MVChatRoom class]] ? target : nil);
		NSNumber *action = ([[attributes objectForKey:@"action"] boolValue] ? [attributes objectForKey:@"action"] : [NSNumber numberWithBool:NO]);
		NSMutableDictionary *privmsgInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:msg, @"message", [self localUser], @"user", [NSString locallyUniqueString], @"identifier", action, @"action", target, @"target", room, @"room", nil];
#if ENABLE(PLUGINS)
		[self performSelector:@selector( _handlePrivmsg: ) withObject:privmsgInfo];
#else
		[self performSelector:@selector( _handlePrivmsg: ) withObject:privmsgInfo inThread:_connectionThread waitUntilDone:NO];
#endif
	}

	NSString *targetName = [target isKindOfClass:[MVChatRoom class]] ? [target name] : [target nickname];

	if( !targetPrefix )
		targetPrefix = @"";

	if( [[attributes objectForKey:@"action"] boolValue] ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@%@ :\001ACTION ", targetPrefix, targetName];
		NSUInteger bytesLeft = [self bytesRemainingForMessage:[[self localUser] nickname] withUsername:[[self localUser] username] withAddress:[[self localUser] address] withPrefix:prefix withEncoding:msgEncoding];

		if ( msg.length > bytesLeft ) [self sendBrokenDownMessage:msg withPrefix:prefix withEncoding:msgEncoding withMaximumBytes:bytesLeft];
		else [self sendRawMessageWithComponents:prefix, msg, @"\001", nil];
		[prefix release];
	} else {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@%@ :", targetPrefix, targetName];
		NSUInteger bytesLeft = [self bytesRemainingForMessage:[[self localUser] nickname] withUsername:[[self localUser] username] withAddress:[[self localUser] address] withPrefix:prefix withEncoding:msgEncoding];

		if ( msg.length > bytesLeft )	[self sendBrokenDownMessage:msg withPrefix:prefix withEncoding:msgEncoding withMaximumBytes:bytesLeft];
		else [self sendRawMessageWithComponents:prefix, msg, nil];

		[prefix release];
	}

	[msg release];
}

- (void) sendBrokenDownMessage:(NSMutableData *) msg withPrefix:(NSString *) prefix withEncoding:(NSStringEncoding) msgEncoding withMaximumBytes:(NSUInteger) bytesLeft {
	NSUInteger bytesRemainingForMessage = bytesLeft;
	BOOL hasWhitespaceInString = YES;

	while ( msg.length ) {
		NSMutableData *msgCutDown = [[msg subdataWithRange:NSMakeRange( 0, bytesRemainingForMessage )] mutableCopy];

		for ( ; ! [self validCharacterToSend:(((char *)[msgCutDown bytes]) + bytesRemainingForMessage - 1) whitespaceInString:hasWhitespaceInString] ; bytesRemainingForMessage-- ) {
			if ( ! msgCutDown.length ) {
				hasWhitespaceInString = NO;
				bytesRemainingForMessage = bytesLeft;
				[msgCutDown release];
				msgCutDown = [[msg subdataWithRange:NSMakeRange( 0, bytesRemainingForMessage )] mutableCopy];
			}
			else if ( msg.length < bytesLeft ) break;
			else [msgCutDown setLength:msgCutDown.length - 1];
		}

		if ( [prefix hasCaseInsensitiveSubstring:@"\001ACTION"]	) [self sendRawMessageWithComponents:prefix, msgCutDown, @"\001", nil];
		else [self sendRawMessageWithComponents:prefix, msgCutDown, nil];
		[msg replaceBytesInRange:NSMakeRange(0, bytesRemainingForMessage) withBytes:NULL length:0];

		[msgCutDown release];

		if ( msg.length >= bytesRemainingForMessage ) bytesRemainingForMessage = bytesLeft;
		else bytesRemainingForMessage = msg.length;
	}
}

- (NSUInteger) bytesRemainingForMessage:(NSString *) nickname withUsername:(NSString *) username withAddress:(NSString *) address withPrefix:(NSString *) prefix withEncoding:(NSStringEncoding) msgEncoding {
	return ( sizeof(char) * 512 ) - [nickname lengthOfBytesUsingEncoding:msgEncoding] - [username lengthOfBytesUsingEncoding:msgEncoding] - [address lengthOfBytesUsingEncoding:msgEncoding] - [prefix lengthOfBytesUsingEncoding:msgEncoding];
}

- (BOOL) validCharacterToSend:(char *) lastCharacter whitespaceInString:(BOOL) hasWhitespaceInString {
	NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	if ( is7Bit(*lastCharacter) || isUTF8Tupel(*lastCharacter) || isUTF8LongTupel(*lastCharacter) || isUTF8Triple(*lastCharacter) || isUTF8Quartet(*lastCharacter) || isUTF8Quintet(*lastCharacter) || isUTF8Sextet(*lastCharacter) || isUTF8Cont(*lastCharacter) ) {
		if ( hasWhitespaceInString ) {
			if ( [whitespaceCharacters characterIsMember:*lastCharacter] ) return YES;
			else return NO;
		} else return YES;
	} else return NO;
}

- (void) _sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding toTarget:(id) target {
	MVAssertMainThreadRequired();

	BOOL isRoom = [target isKindOfClass:[MVChatRoom class]];
	BOOL isUser = ([target isKindOfClass:[MVChatUser class]] || [target isKindOfClass:[MVDirectChatConnection class]]);

	NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSScanner *argumentsScanner = [NSScanner scannerWithString:MVChatStringAsString(arguments)];
	[argumentsScanner setCharactersToBeSkipped:nil];

	if( isUser || isRoom ) {
		if( [command isCaseInsensitiveEqualToString:@"me"] || [command isCaseInsensitiveEqualToString:@"action"] ) {
			[self _sendMessage:arguments withEncoding:encoding toTarget:target withTargetPrefix:nil withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"action"] localEcho:YES];
			return;
		} else if( [command isCaseInsensitiveEqualToString:@"say"] ) {
			[self _sendMessage:arguments withEncoding:encoding toTarget:target withTargetPrefix:nil withAttributes:[NSDictionary dictionary] localEcho:YES];
			return;
		}
	}

	if( isRoom ) {
		MVChatRoom *room = (MVChatRoom *)target;
		if( [command isCaseInsensitiveEqualToString:@"cycle"] || [command isCaseInsensitiveEqualToString:@"hop"] ) {
			[room retain];
			[room part];

			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomPartedNotification object:room];

			[room join];
			[room release];
			return;
		} else if( [command isCaseInsensitiveEqualToString:@"invite"] ) {
			NSString *nick = nil;
			NSString *roomName = nil;

			[argumentsScanner scanUpToCharactersFromSet:whitespaceCharacters intoString:&nick];
			if( !nick.length ) return;
			if( ![argumentsScanner isAtEnd] ) [argumentsScanner scanUpToCharactersFromSet:whitespaceCharacters intoString:&roomName];

			[self sendRawMessage:[NSString stringWithFormat:@"INVITE %@ %@", nick, ( roomName.length ? roomName : [room name] )]];
			return;
		} else if( [command isCaseInsensitiveEqualToString:@"topic"] || [command isCaseInsensitiveEqualToString:@"t"] ) {
			if( arguments.length ) {
				[room changeTopic:arguments];
				return;
			}
		} else if( [command isCaseInsensitiveEqualToString:@"kick"] ) {
			NSString *member = nil;
			[argumentsScanner scanUpToCharactersFromSet:whitespaceCharacters intoString:&member];

			if( member.length ) {
				MVChatString *reason = nil;
				if( arguments.length >= [argumentsScanner scanLocation] + 1 )
#if USE(ATTRIBUTED_CHAT_STRING)
					reason = [arguments attributedSubstringFromRange:NSMakeRange( [argumentsScanner scanLocation] + 1, ( arguments.length - [argumentsScanner scanLocation] - 1 ) )];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
					reason = [arguments	substringFromIndex:( [argumentsScanner scanLocation] + 1 )];
#endif

				MVChatUser *user = [[room memberUsersWithNickname:member] anyObject];
				if( user ) [room kickOutMemberUser:user forReason:reason];
				return;
			}
		} else if( [command isCaseInsensitiveEqualToString:@"kickban"] || [command isCaseInsensitiveEqualToString:@"bankick"] ) {
			NSString *member = nil;
			[argumentsScanner scanUpToCharactersFromSet:whitespaceCharacters intoString:&member];

			if( member.length ) {
				MVChatString *reason = nil;
				if( arguments.length >= [argumentsScanner scanLocation] + 1 )
#if USE(ATTRIBUTED_CHAT_STRING)
					reason = [arguments attributedSubstringFromRange:NSMakeRange( [argumentsScanner scanLocation] + 1, ( arguments.length - [argumentsScanner scanLocation] - 1 ) )];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
					reason = [arguments	substringFromIndex:( [argumentsScanner scanLocation] + 1 )];
#endif

				MVChatUser *user = nil;
				if ( [member hasCaseInsensitiveSubstring:@"!"] || [member hasCaseInsensitiveSubstring:@"@"] ) {
					if ( ! [member hasCaseInsensitiveSubstring:@"!"] && [member hasCaseInsensitiveSubstring:@"@"] )
						member = [NSString stringWithFormat:@"*!*%@", member];
					user = [MVChatUser wildcardUserFromString:member];
				} else user = [[room memberUsersWithNickname:member] anyObject];

				if( user ) {
					[room addBanForUser:user];
					[room kickOutMemberUser:user forReason:reason];
				}
				return;
			}
		} else if( [command isCaseInsensitiveEqualToString:@"op"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];
			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"deop"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"halfop"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"dehalfop"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"voice"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"devoice"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"quiet"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberQuietedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"dequiet"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberQuietedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"ban"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = nil;
					if ( [userString hasCaseInsensitiveSubstring:@"!"] || [userString hasCaseInsensitiveSubstring:@"@"] ) {
						if ( ! [userString hasCaseInsensitiveSubstring:@"!"] && [userString hasCaseInsensitiveSubstring:@"@"] )
							userString = [NSString stringWithFormat:@"*!*%@", userString];
						user = [MVChatUser wildcardUserFromString:userString];
					} else user = [[room memberUsersWithNickname:userString] anyObject];

					if( user ) [room addBanForUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"unban"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters limit:0];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = nil;
					if ( [userString hasCaseInsensitiveSubstring:@"!"] || [userString hasCaseInsensitiveSubstring:@"@"] ) {
						if ( ! [userString hasCaseInsensitiveSubstring:@"!"] && [userString hasCaseInsensitiveSubstring:@"@"] )
							userString = [NSString stringWithFormat:@"*!*%@", userString];
						user = [MVChatUser wildcardUserFromString:userString];
					} else user = [[room memberUsersWithNickname:userString] anyObject];

					if( user ) [room removeBanForUser:user];
				}
			}

			if( users.count )
				return;
		}
	}

	if( [command isCaseInsensitiveEqualToString:@"msg"] || [command isCaseInsensitiveEqualToString:@"query"] ) {
		NSString *targetName = nil;
		MVChatString *msg = nil;

		[argumentsScanner scanUpToCharactersFromSet:whitespaceCharacters intoString:&targetName];
		[argumentsScanner scanCharactersFromSet:whitespaceCharacters maxLength:1 intoString:NULL];

		if( !targetName.length ) return;

		if( ![argumentsScanner isAtEnd] ) {
#if USE(ATTRIBUTED_CHAT_STRING)
			msg = [arguments attributedSubstringFromRange:NSMakeRange( [argumentsScanner scanLocation], arguments.length - [argumentsScanner scanLocation] )];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
			msg = [arguments substringFromIndex:[argumentsScanner scanLocation]];
#endif
		}

		if( !msg.length ) return;

		NSString *roomTargetName = targetName;
		NSString *targetPrefix = nil;

		NSScanner *scanner = [NSScanner scannerWithString:targetName];
		[scanner setCharactersToBeSkipped:nil];
		[scanner scanCharactersFromSet:[self _nicknamePrefixes] intoString:&targetPrefix];

		if( targetPrefix.length )
			roomTargetName = [targetName substringFromIndex:targetPrefix.length];

		MVChatRoom *room = nil;
		if( [command isCaseInsensitiveEqualToString:@"msg"] && roomTargetName.length >= 1 && [[self chatRoomNamePrefixes] characterIsMember:[roomTargetName characterAtIndex:0]] )
			room = [self chatRoomWithUniqueIdentifier:roomTargetName];

		BOOL echo = (isUser || isRoom || [command isCaseInsensitiveEqualToString:@"query"]);
		if( room ) {
			[self _sendMessage:msg withEncoding:encoding toTarget:room withTargetPrefix:targetPrefix withAttributes:[NSDictionary dictionary] localEcho:echo];
			return;
		}

		MVChatUser *user = [[self chatUsersWithNickname:targetName] anyObject];
		if( user ) {
			[self _sendMessage:msg withEncoding:encoding toTarget:user withTargetPrefix:nil withAttributes:[NSDictionary dictionary] localEcho:echo];
			return;
		}

		return;
	} else if( [command isCaseInsensitiveEqualToString:@"j"] || [command isCaseInsensitiveEqualToString:@"join"] ) {
		NSString *roomsString = MVChatStringAsString(arguments);
		NSArray *roomStrings = [roomsString componentsSeparatedByString:@","];
		NSMutableArray *roomsToJoin = [[NSMutableArray allocWithZone:nil] initWithCapacity:roomStrings.count];

		for( NSString *room in roomStrings ) {
			room = [room stringByTrimmingCharactersInSet:whitespaceCharacters];
			if( room.length )
				[roomsToJoin addObject:room];
		}

		if( roomsToJoin.count)
			[self joinChatRoomsNamed:roomsToJoin];
		else if( isRoom )
			[target join];

		[roomsToJoin release];

		return;
	} else if( [command isCaseInsensitiveEqualToString:@"part"] || [command isCaseInsensitiveEqualToString:@"leave"] ) {
		NSString *roomsString = nil;
		[argumentsScanner scanUpToCharactersFromSet:whitespaceCharacters intoString:&roomsString];

		MVChatString *reason = nil;
		if( roomsString.length ) {
			if( arguments.length >= [argumentsScanner scanLocation] + 1 )
#if USE(ATTRIBUTED_CHAT_STRING)
				reason = [arguments attributedSubstringFromRange:NSMakeRange( [argumentsScanner scanLocation] + 1, ( arguments.length - [argumentsScanner scanLocation] - 1 ) )];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
				reason = [arguments	substringFromIndex:( [argumentsScanner scanLocation] + 1 )];
#endif
		}

		NSArray *rooms = [roomsString componentsSeparatedByString:@","];
		if( !rooms.count || [roomsString isEqualToString:@"-"] ) {
			if( isRoom ) [target partWithReason:reason];
			return;
		}

		for( NSString *roomName in rooms )
			[[self joinedChatRoomWithName:roomName] partWithReason:reason];

		return;
	} else if ([command isCaseInsensitiveEqualToString:@"raw"] || [command isCaseInsensitiveEqualToString:@"quote"]) {
		[self sendRawMessage:MVChatStringAsString(arguments) immediately:YES];
		return;
	} else if ([command isCaseInsensitiveEqualToString:@"quit"] || [command isCaseInsensitiveEqualToString:@"disconnect"]) {
		[self disconnectWithReason:arguments];
		return;
	} else if ([command isCaseInsensitiveEqualToString:@"connect"] || [command isCaseInsensitiveEqualToString:@"reconnect"]) {
		[self connect];
		return;
	} else if ([command isCaseInsensitiveEqualToString:@"away"]) {
		[self setAwayStatusMessage:arguments];
		return;
	} else if ([command isCaseInsensitiveEqualToString:@"umode"]) {
		[self sendRawMessage:[NSString stringWithFormat:@"MODE %@ %@", [self nickname], MVChatStringAsString(arguments)]];
		return;
	} else if ([command isCaseInsensitiveEqualToString:@"globops"]) {
		NSData *argumentsData = [[self class] _flattenedIRCDataForMessage:arguments withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
		[self sendRawMessageWithComponents:command, @" :", argumentsData, nil];
		return;
	}

	if( [command hasPrefix:@"/"] )
		command = [command substringFromIndex:1];

	if( arguments && arguments.length > 0 ) {
		NSData *argumentsData = [[self class] _flattenedIRCDataForMessage:arguments withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
		[self sendRawMessageWithComponents:command, @" ", argumentsData, nil];
	} else [self sendRawMessage:command];
}

/*

#pragma mark -

- (void) _processErrorCode:(NSUInteger) errorCode withContext:(char *) context {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	NSError *error = nil;

	[userInfo setObject:self forKey:@"connection"];

	switch( errorCode ) {
		case ERR_NOSUCHNICK: {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:context]];
			[user _setStatus:MVChatUserOfflineStatus];
			[userInfo setObject:user forKey:@"user"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The user \"%@\" is no longer connected (or never was connected) to the \"%@\" server.", "user not on the server" ), [user nickname], [self server]] forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionNoSuchUserError userInfo:userInfo];
			break;
		}
		case ERR_UNKNOWNCOMMAND: {
			NSString *command = [self stringWithEncodedBytes:context];
			[userInfo setObject:command forKey:@"command"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The command \"%@\" is not a valid command on the \"%@\" server.", "user not on the server" ), command, [self server]] forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionUnknownCommandError userInfo:userInfo];
			break;
		}
	}

	if( error ) [self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
}
*/

#pragma mark -

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) newNickname {
	@synchronized( _knownUsers ) {
		[user retain];
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:[newNickname lowercaseString]];
		[user _setNickname:newNickname];
		[_knownUsers setObject:user forKey:[user uniqueIdentifier]];
		[user release];
	}
}

- (void) _setCurrentNickname:(NSString *) currentNickname {
	MVSafeCopyAssign( _currentNickname, currentNickname );
	[_localUser _setUniqueIdentifier:[currentNickname lowercaseString]];
}

#pragma mark -

- (void) _handleConnect {
	MVAssertCorrectThreadRequired( _connectionThread );
	MVSafeRetainAssign( _queueWait, [NSDate dateWithTimeIntervalSinceNow:0.5] );
	[self _resetSendQueueInterval];
	[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:NO];
}

- (void) _identifyWithServicesUsingNickname:(NSString *) nickname {
	if( !_pendingIdentificationAttempt && ![[self localUser] isIdentified] && [[self nicknamePassword] length] ) {
		_pendingIdentificationAttempt = YES;
		if( [[self server] hasCaseInsensitiveSubstring:@"quakenet"] ) {
			[self sendRawMessageImmediatelyWithFormat:@"AUTH %@ %@", [self preferredNickname], [self nicknamePassword]];
		} else if( [[self server] hasCaseInsensitiveSubstring:@"undernet"] ) {
			[self sendRawMessageImmediatelyWithFormat:@"PRIVMSG X@channels.undernet.org :LOGIN %@ %@", [self preferredNickname], [self nicknamePassword]];
		} else if( [[self server] hasCaseInsensitiveSubstring:@"gamesurge"] ) {
			[self sendRawMessageImmediatelyWithFormat:@"AS AUTH %@ %@", [self preferredNickname], [self nicknamePassword]];
		} else if( [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) {
			[self sendRawMessageImmediatelyWithFormat:@"PASS %@", [self nicknamePassword]];
		} else if( ![nickname isEqualToString:[self nickname]] ) {
			if( [[self server] hasCaseInsensitiveSubstring:@"oftc"] ) {
				[self sendRawMessageImmediatelyWithFormat:@"NICKSERV IDENTIFY %@ %@", [self nicknamePassword], nickname]; // workaround for irc.oftc.net: their nickserv expects password and nickname in reverse order for some reason
			} else {
				[self sendRawMessageImmediatelyWithFormat:@"NICKSERV IDENTIFY %@ %@", nickname, [self nicknamePassword]];
			}
		} else {
			// TODO v remove, have mac colloquy set the nickname password on "nickname accepted" instead (if there is one for the new nick)
			// if ( ![nickname isEqualToString:[self preferredNickname]] && keychain has seperate pass for current nickname) {
			//	[self sendRawMessageImmediatelyWithFormat:@"NICKSERV IDENTIFY %@", <KEYCHAIN PASSWORD>];
			// } else {
			[self sendRawMessageImmediatelyWithFormat:@"NICKSERV IDENTIFY %@", [self nicknamePassword]];
			// }
		}
	}
}

#pragma mark -

- (void) _markUserAsOffline:(MVChatUser *) user {
	@synchronized( _alternateNicks ) {
	if( [[user nickname] isCaseInsensitiveEqualToString:[self preferredNickname]] && ( ( [[self nickname] hasCaseInsensitivePrefix:[self preferredNickname]] && [[self nickname] hasSuffix:@"_"] ) || [_alternateNicks containsObject:[self nickname]] ) )
		[self setNickname:[self preferredNickname]]; // someone was blocking our preferred nickname (probably us from a previous connection), let's use it now
	}
	[super _markUserAsOffline:user];
}

#pragma mark -

- (void) _periodicEvents {
	MVAssertCorrectThreadRequired( _connectionThread );

	[_pendingJoinRoomNames removeAllObjects];

	[self _pruneKnownUsers];

#if !ENABLE(BOUNCER_MODE)
	@synchronized( _joinedRooms ) {
		for( MVChatRoom *room in _joinedRooms )
			if( [[room memberUsers] count] <= JVMaximumMembersForWhoRequest )
				[self sendRawMessageWithFormat:@"WHO %@", [room name]];
	}
#endif

	[self performSelector:@selector( _periodicEvents ) withObject:nil afterDelay:JVPeriodicEventsInterval];
}

- (void) _pingServer {
	MVAssertCorrectThreadRequired( _connectionThread );
	[self sendRawMessageImmediatelyWithFormat:@"PING %@", [self server]];
	[self performSelector:@selector( _pingServer ) withObject:nil afterDelay:JVPingServerInterval];
}

- (void) _startSendQueue {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( _sendQueueProcessing ) return;
	_sendQueueProcessing = YES;

	if( _queueWait && [_queueWait timeIntervalSinceNow] > 0. )
		[self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:[_queueWait timeIntervalSinceNow]];
	else [self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:[self minimumSendQueueDelay]];
}

- (void) _stopSendQueue {
	MVAssertCorrectThreadRequired( _connectionThread );
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _sendQueue ) object:nil];
	_sendQueueProcessing = NO;
}

- (void) _resetSendQueueInterval {
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _stopSendQueue];

	@synchronized( _sendQueue ) {
		if( _sendQueue.count )
			[self _startSendQueue];
	}
}

- (void) _sendQueue {
	MVAssertCorrectThreadRequired( _connectionThread );

	@synchronized( _sendQueue ) {
		if( ! _sendQueue.count ) {
			_sendQueueProcessing = NO;
			return;
		}
	}

	if( _queueWait && [_queueWait timeIntervalSinceNow] > 0. ) {
		[self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:[_queueWait timeIntervalSinceNow]];
		return;
	}

	NSData *data = nil;
	@synchronized( _sendQueue ) {
		data = [[_sendQueue objectAtIndex:0] retain];
		[_sendQueue removeObjectAtIndex:0];

		if( _sendQueue.count )
			[self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:MIN( [self minimumSendQueueDelay] + ( _sendQueue.count * [self sendQueueDelayIncrement] ), [self maximumSendQueueDelay] )];
		else _sendQueueProcessing = NO;
	}

	[self _writeDataToServer:data];
	[data release];

	MVSafeAdoptAssign( _lastCommand, [[NSDate allocWithZone:nil] init] );
}

#pragma mark -

- (void) _addDirectClientConnection:(id) connection {
	if( ! _directClientConnections )
		_directClientConnections = [[NSMutableSet allocWithZone:nil] initWithCapacity:5];
	@synchronized( _directClientConnections ) {
		if( connection ) [_directClientConnections addObject:connection];
	}
}

- (void) _removeDirectClientConnection:(id) connection {
	@synchronized( _directClientConnections ) {
		if( connection ) [_directClientConnections removeObject:connection];
	}
}

- (void) _resetSupportedFeatures {
	@synchronized( _supportedFeatures ) {
		[_supportedFeatures removeAllObjects];

		// all server should support these features per RFC 1459
		[_supportedFeatures addObject:MVChatRoomMemberVoicedFeature];
		[_supportedFeatures addObject:MVChatRoomMemberOperatorFeature];
	}
}

#pragma mark -

- (void) _scheduleWhoisForUser:(MVChatUser *) user {
	MVAssertCorrectThreadRequired( _connectionThread );

	// Don't WHOIS server operators, since they can often see the WHOIS request and get annoyed.
	if( [user isServerOperator] )
		return;

	if( ! _pendingWhoisUsers )
		_pendingWhoisUsers = [[NSMutableSet allocWithZone:nil] initWithCapacity:50];

	[_pendingWhoisUsers addObject:user];

	if( _pendingWhoisUsers.count == 1 )
		[self _whoisNextScheduledUser];
}

- (void) _whoisNextScheduledUser {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( _pendingWhoisUsers.count ) {
		MVChatUser *user = [_pendingWhoisUsers anyObject];
		[user refreshInformation];
	}
}

- (void) _whoisWatchedUsers {
	MVAssertCorrectThreadRequired( _connectionThread );

	[self performSelector:@selector( _whoisWatchedUsers ) withObject:nil afterDelay:JVWatchedUserWHOISDelay];

	NSMutableSet *matchedUsers = [NSMutableSet set];
	@synchronized( _chatUserWatchRules ) {
		if( ! _chatUserWatchRules.count ) return; // nothing to do, return and wait until the next scheduled fire

		for( MVChatUserWatchRule *rule in _chatUserWatchRules )
			[matchedUsers unionSet:[rule matchedChatUsers]];
	}

	for( MVChatUser *user in matchedUsers )
		[self _scheduleWhoisForUser:user];
}

- (void) _checkWatchedUsers {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( _watchCommandSupported ) return; // we don't need to call this anymore, return before we reschedule

	[self performSelector:@selector( _checkWatchedUsers ) withObject:nil afterDelay:JVWatchedUserISONDelay];

	if( _lastSentIsonNicknames.count ) return; // there is already pending ISON requests, skip this round to catch up

	NSMutableSet *matchedUsers = [NSMutableSet set];
	@synchronized( _chatUserWatchRules ) {
		if( ! _chatUserWatchRules.count ) return; // nothing to do, return and wait until the next scheduled fire

		for( MVChatUserWatchRule *rule in _chatUserWatchRules )
			[matchedUsers unionSet:[rule matchedChatUsers]];
	}

	NSMutableString *request = [[NSMutableString allocWithZone:nil] initWithCapacity:JVMaximumISONCommandLength];
	[request setString:@"ISON "];

	_isonSentCount = 0;

	[_lastSentIsonNicknames release];
	_lastSentIsonNicknames = [[NSMutableSet allocWithZone:nil] initWithCapacity:( _chatUserWatchRules.count * 5 )];

	for( MVChatUser *user in matchedUsers ) {
		if( ! [[user connection] isEqual:self] )
			continue;

		NSString *nick = [user nickname];
		NSString *nickLower = [nick lowercaseString];

		if( nick.length && ! [_lastSentIsonNicknames containsObject:nickLower] ) {
			if( ( nick.length + request.length ) > JVMaximumISONCommandLength ) {
				[self sendRawMessage:request];
				[request release];
				_isonSentCount++;

				request = [[NSMutableString allocWithZone:nil] initWithCapacity:JVMaximumISONCommandLength];
				[request setString:@"ISON "];
			}

			[request appendString:nick];
			[request appendString:@" "];

			[_lastSentIsonNicknames addObject:nickLower];
		}
	}

	@synchronized( _chatUserWatchRules ) {
		for( MVChatUserWatchRule *rule in _chatUserWatchRules ) {
			NSString *nick = [rule nickname];
			NSString *nickLower = [nick lowercaseString];

			if( nick.length && ! [rule nicknameIsRegularExpression] && ! [_lastSentIsonNicknames containsObject:nickLower] ) {
				if( ( nick.length + request.length ) > JVMaximumISONCommandLength ) {
					[self sendRawMessage:request];
					[request release];
					_isonSentCount++;

					request = [[NSMutableString allocWithZone:nil] initWithCapacity:JVMaximumISONCommandLength];
					[request setString:@"ISON "];
				}

				[request appendString:nick];
				[request appendString:@" "];

				[_lastSentIsonNicknames addObject:nickLower];
			}
		}
	}

	if( ! [request isEqualToString:@"ISON "] ) {
		[self sendRawMessage:request];
		_isonSentCount++;
	}

	[request release];
}

#pragma mark -

- (NSString *) _newStringWithBytes:(const char *) bytes length:(NSUInteger) length {
	if( bytes && length ) {
		NSStringEncoding encoding = [self encoding];
		if( encoding != NSUTF8StringEncoding && isValidUTF8( bytes, length ) )
			encoding = NSUTF8StringEncoding;
		NSString *ret = [[NSString allocWithZone:nil] initWithBytes:bytes length:length encoding:encoding];
		if( ! ret && encoding != JVFallbackEncoding ) ret = [[NSString allocWithZone:nil] initWithBytes:bytes length:length encoding:JVFallbackEncoding];
		return ret;
	}

	if( bytes && ! length )
		return @"";
	return nil;
}

- (NSString *) _stringFromPossibleData:(id) input {
	if( [input isKindOfClass:[NSData class]] )
		return [[self _newStringWithBytes:[input bytes] length:[input length]] autorelease];
	return input;
}

#pragma mark -

- (NSCharacterSet *) _nicknamePrefixes {
	NSCharacterSet *prefixes = [_serverInformation objectForKey:@"roomMemberPrefixes"];
	if( prefixes ) return prefixes;

	static NSCharacterSet *defaultPrefixes = nil;
	if( !defaultPrefixes )
		defaultPrefixes = [[NSCharacterSet characterSetWithCharactersInString:@"@+"] retain];
	return defaultPrefixes;
}

- (MVChatRoomMemberMode) _modeForNicknamePrefixCharacter:(unichar) character {
	switch( character ) {
		case '+': return MVChatRoomMemberVoicedMode;

		case '%': return MVChatRoomMemberHalfOperatorMode;

		case '-': // This is suppose to be "super op". But just treat it like op. http://colloquy.info/project/ticket/642
		case '@': return MVChatRoomMemberOperatorMode;

		case '&':
		case '!': return MVChatRoomMemberAdministratorMode;

		case '*':
		case '~':
		case '.': return MVChatRoomMemberFounderMode;
	}

	return MVChatRoomMemberNoModes;
}

- (MVChatRoomMemberMode) _stripModePrefixesFromNickname:(NSString **) nicknamePtr {
	NSString *nickname = *nicknamePtr;
	MVChatRoomMemberMode modes = MVChatRoomMemberNoModes;
	NSMutableDictionary *prefixes = [_serverInformation objectForKey:@"roomMemberPrefixTable"];

	NSUInteger i = 0;
	NSUInteger length = nickname.length;
	for( i = 0; i < length; ++i ) {
		if( prefixes.count ) {
			NSNumber *prefix = [prefixes objectForKey:[NSString stringWithFormat:@"%c", [nickname characterAtIndex:i]]];
			if( prefix ) modes |= [prefix unsignedLongValue];
			else break;
		} else {
			MVChatRoomMemberMode mode = [self _modeForNicknamePrefixCharacter:[nickname characterAtIndex:i]];
			if( mode != MVChatRoomMemberNoModes ) modes |= mode;
			else break;
		}
	}

	if( i ) *nicknamePtr = [nickname substringFromIndex:i];
	return modes;
}

#pragma mark -

- (void) _cancelScheduledSendEndCapabilityCommand {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_sendEndCapabilityCommand) object:nil];
}

- (void) _sendEndCapabilityCommandAfterTimeout {
	[self _cancelScheduledSendEndCapabilityCommand];
	[self performSelector:@selector(_sendEndCapabilityCommand) withObject:nil afterDelay:JVEndCapabilityTimeoutDelay];
}

- (void) _sendEndCapabilityCommand {
	[self _cancelScheduledSendEndCapabilityCommand];

	if( _sentEndCapabilityCommand )
		return;

	_sentEndCapabilityCommand = YES;

	[self sendRawMessageImmediatelyWithFormat:@"CAP END"];
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionProtocolHandlers)

#pragma mark Connecting Replies

- (void) _handleCapWithParameters:(NSArray *) parameters fromSender:(id) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	BOOL furtherNegotiation = NO;

	if( parameters.count >= 3 ) {
		NSString *subCommand = [parameters objectAtIndex:1];

		NSString *capabilitiesString = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		NSArray *capabilities = [capabilitiesString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		for( NSString *capability in capabilities ) {
			if( [capability	isCaseInsensitiveEqualToString:@"sasl"] ) {
				if( [subCommand isCaseInsensitiveEqualToString:@"NAK"] )
					continue;

				@synchronized( _supportedFeatures ) {
					[_supportedFeatures addObject:MVChatConnectionSASLFeature];
				}

				if( self.nicknamePassword.length ) {
					if( [subCommand isCaseInsensitiveEqualToString:@"LS"] ) {
						[self sendRawMessageImmediatelyWithFormat:@"CAP REQ :sasl"];
						furtherNegotiation = YES;
					} else if( [subCommand isCaseInsensitiveEqualToString:@"ACK"] ) {
						[self sendRawMessageImmediatelyWithFormat:@"AUTHENTICATE PLAIN"];
						furtherNegotiation = YES;
					}
				} else {
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
				}
			}
		}
	}

	if( !furtherNegotiation )
		[self _sendEndCapabilityCommand];
}

- (void) _handleAuthenticateWithParameters:(NSArray *) parameters fromSender:(id) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 1 && [[self _stringFromPossibleData:[parameters objectAtIndex:0]] isEqualToString:@"+"] ) {
		NSData *usernameData = [self.preferredNickname dataUsingEncoding:self.encoding allowLossyConversion:YES];

		NSMutableData *authenticateData = [usernameData mutableCopy];
		[authenticateData appendBytes:"\0" length:1];
		[authenticateData appendData:usernameData];
		[authenticateData appendBytes:"\0" length:1];
		[authenticateData appendData:[self.nicknamePassword dataUsingEncoding:self.encoding allowLossyConversion:YES]];

		NSString *authString = [authenticateData base64EncodingWithLineLength:400];

		NSArray *authStrings = [authString componentsSeparatedByString:@"\n"];
		for( NSString *string in authStrings )
			[self sendRawMessageImmediatelyWithComponents:@"AUTHENTICATE ", string, nil];

		if( !authStrings.count || [[authStrings lastObject] length] == 400 ) {
			// If empty or the last string was exactly 400 bytes we need to send an empty AUTHENTICATE to indicate we're done.
			[self sendRawMessageImmediatelyWithFormat:@"AUTHENTICATE +"];
		}
	} else [self _sendEndCapabilityCommand];
}

- (void) _handle900WithParameters:(NSArray *) parameters fromSender:(id) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 4 ) {
		NSString *message = [self _stringFromPossibleData:[parameters objectAtIndex:3]];
		if( [message hasCaseInsensitiveSubstring:@"You are now logged in as "] ) {
			if( !self.localUser.identified )
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", [parameters objectAtIndex:2], @"target", nil]];
			[[self localUser] _setIdentified:YES];
		}
	}
}

- (void) _handle903WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_SASLSUCCESS
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _sendEndCapabilityCommand];
}

- (void) _handle904WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLFAIL
	MVAssertCorrectThreadRequired( _connectionThread );

	[self.localUser _setIdentified:NO];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];

	[self _sendEndCapabilityCommand];
}

- (void) _handle905WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLTOOLONG
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _sendEndCapabilityCommand];
}

- (void) _handle906WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLABORTED
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _sendEndCapabilityCommand];
}

- (void) _handle907WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLALREADY
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _sendEndCapabilityCommand];
}

- (void) _handle001WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WELCOME
	MVAssertCorrectThreadRequired( _connectionThread );

	[self _cancelScheduledSendEndCapabilityCommand];

	[self performSelector:@selector( _handleConnect ) withObject:nil inThread:_connectionThread waitUntilDone:NO];

	// set the _realServer because it's different from the server we connected to
	MVSafeCopyAssign( _realServer, sender );

	// set the current nick name if it is not the same as what re requested (some servers/bouncers will give us a new nickname)
	if( parameters.count >= 1 ) {
		NSString *nick = [self _stringFromPossibleData:[parameters objectAtIndex:0]];
		if( ! [nick isEqualToString:[self nickname]] ) {
			[self _setCurrentNickname:nick];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:nil];
		}
	}

	if( _pendingIdentificationAttempt && [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) {
		// workaround for ustream which uses PASS rather than NickServ for nickname identification, so 001 counts as successful identification
		_pendingIdentificationAttempt = NO;
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Ustream", @"user", [self nickname], @"target", nil]];
		[[self localUser] _setIdentified:YES];
	} else if( !self.localUser.identified ) {
		// Identify with services
		[self _identifyWithServicesUsingNickname:[self preferredNickname]]; // identifying proactively -> preferred nickname
	}

	[self performSelector:@selector( _checkWatchedUsers ) withObject:nil afterDelay:2.];
}

- (void) _handle005WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ISUPPORT
	MVAssertCorrectThreadRequired( _connectionThread );

	if( ! _serverInformation )
		_serverInformation = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];

	for( NSString *feature in parameters ) {
		if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"WATCH"] ) {
			_watchCommandSupported = YES;

			NSMutableString *request = [[NSMutableString allocWithZone:nil] initWithCapacity:JVMaximumWatchCommandLength];
			[request setString:@"WATCH "];

			@synchronized( _chatUserWatchRules ) {
				for( MVChatUserWatchRule *rule in _chatUserWatchRules ) {
					NSString *nick = [rule nickname];
					if( nick && ! [rule nicknameIsRegularExpression] ) {
						if( ( nick.length + request.length + 1 ) > JVMaximumWatchCommandLength ) {
							[self sendRawMessage:request];
							[request release];

							request = [[NSMutableString allocWithZone:nil] initWithCapacity:JVMaximumWatchCommandLength];
							[request setString:@"WATCH "];
						}

						[request appendFormat:@"+%@ ", nick];
					}
				}
			}

			if( ! [request isEqualToString:@"WATCH "] )
				[self sendRawMessage:request];

			[request release];

//			[self performSelector:@selector( _whoisWatchedUsers ) withObject:nil afterDelay:JVWatchedUserWHOISDelay];
		} else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"CHANTYPES="] ) {
			NSString *types = [feature substringFromIndex:10]; // length of "CHANTYPES="
			if( types.length )
				MVSafeRetainAssign( _roomPrefixes, [NSCharacterSet characterSetWithCharactersInString:types] );
		} else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"PREFIX="] ) {
			NSScanner *scanner = [NSScanner scannerWithString:feature];
			[scanner setScanLocation:7]; // length of "PREFIX="
			if( [scanner scanString:@"(" intoString:NULL] ) {
				NSString *modes = nil;
				if( [scanner scanUpToString:@")" intoString:&modes] ) {
					[scanner scanString:@")" intoString:NULL];

					@synchronized( _supportedFeatures ) {
						// remove these in case the server does not support them when we parse the modes
						[_supportedFeatures removeObject:MVChatRoomMemberVoicedFeature];
						[_supportedFeatures removeObject:MVChatRoomMemberOperatorFeature];
					}

					NSMutableDictionary *modesTable = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:modes.length];
					NSUInteger length = modes.length;
					NSUInteger i = 0;
					for( i = 0; i < length; i++ ) {
						MVChatRoomMemberMode mode = MVChatRoomMemberNoModes;
						NSString *modeFeature = nil;
						switch( [modes characterAtIndex:i] ) {
							case 'v': mode = MVChatRoomMemberVoicedMode; modeFeature = MVChatRoomMemberVoicedFeature; break;
							case 'h': mode = MVChatRoomMemberHalfOperatorMode; modeFeature = MVChatRoomMemberHalfOperatorFeature; break;
							case 'o': mode = MVChatRoomMemberOperatorMode; modeFeature = MVChatRoomMemberOperatorFeature; break;
							case 'a':
							case 'u': mode = MVChatRoomMemberAdministratorMode; modeFeature = MVChatRoomMemberAdministratorFeature; break;
							case 'q': mode = MVChatRoomMemberFounderMode; modeFeature = MVChatRoomMemberFounderFeature; break;
							default: break;
						}

						if( mode != MVChatRoomMemberNoModes ) {
							NSString *key = [[NSString allocWithZone:nil] initWithFormat:@"%c", [modes characterAtIndex:i]];
							[modesTable setObject:[NSNumber numberWithUnsignedLong:mode] forKey:key];
							[key release];

							if( modeFeature ) {
								@synchronized( _supportedFeatures ) {
									 [_supportedFeatures addObject:modeFeature];
								}
							}
						}
					}

					if( modesTable.count ) [_serverInformation setObject:modesTable forKey:@"roomMemberModeTable"];
					[_serverInformation setObject:[NSCharacterSet characterSetWithCharactersInString:modes] forKey:@"roomMemberModes"];
					[modesTable release];
				}

				NSString *prefixes = [feature substringFromIndex:[scanner scanLocation]];
				if( prefixes.length ) {
					NSMutableDictionary *prefixTable = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:modes.length];
					NSUInteger length = prefixes.length;
					NSUInteger i = 0;
					for( i = 0; i < length; i++ ) {
						MVChatRoomMemberMode mode = [self _modeForNicknamePrefixCharacter:[prefixes characterAtIndex:i]];
						if( mode != MVChatRoomMemberNoModes ) {
							NSString *key = [[NSString allocWithZone:nil] initWithFormat:@"%c", [prefixes characterAtIndex:i]];
							[prefixTable setObject:[NSNumber numberWithUnsignedLong:mode] forKey:key];
							[key release];
						}
					}

					if( prefixTable.count ) [_serverInformation setObject:prefixTable forKey:@"roomMemberPrefixTable"];
					[_serverInformation setObject:[NSCharacterSet characterSetWithCharactersInString:prefixes] forKey:@"roomMemberPrefixes"];
					[prefixTable release];
				}
			}
		}
	}
}

- (void) _handle433WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NICKNAMEINUSE
	MVAssertCorrectThreadRequired( _connectionThread );

	if( ! [self isConnected] ) {
		NSString *nick = [self nextAlternateNickname];
		if( ! nick.length && parameters.count >= 2 ) {
			NSString *lastNickTried = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

			if( ( _failedNickname && [_failedNickname isCaseInsensitiveEqualToString:lastNickTried] ) || _nicknameShortened) {
				nick = [NSString stringWithFormat:@"%@-%d", [lastNickTried substringToIndex:(lastNickTried.length - 2)], _failedNicknameCount];

				_nicknameShortened = YES;

				if ( _failedNicknameCount < 9 ) _failedNicknameCount++;
				else _failedNicknameCount = 1;
			} else nick = [lastNickTried stringByAppendingString:@"_"];
		}

		if ( ! _failedNickname ) _failedNickname = [[self _stringFromPossibleData:[parameters objectAtIndex:1]] copy];

		if( nick.length ) [self setNickname:nick];
	} else {
		// "<current nickname> <new nickname> :Cannot change nick"
		// - Sent to a user who is changing their nickname to a nickname someone else is actively using.

		if( parameters.count >= 2 ) {
			NSString *usedNickname = [self _stringFromPossibleData:[parameters objectAtIndex:0]];
			NSString *newNickname = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			[userInfo setObject:self forKey:@"connection"];
			[userInfo setObject:usedNickname forKey:@"oldnickname"];
			[userInfo setObject:newNickname forKey:@"newnickname"];

			if ( ! [newNickname isCaseInsensitiveEqualToString:usedNickname] ) {
				[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Can't change nick from \"%@\" to \"%@\" because it is already taken on \"%@\".", "cannot change used nickname error" ), usedNickname, newNickname, [self server]] forKey:NSLocalizedDescriptionKey];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeUsedNickError userInfo:userInfo]];
			} else {
				[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Your nickname is being changed by services on \"%@\" because it is registered and you did not supply the correct password to identify.", "nickname changed by services error" ), [self server]] forKey:NSLocalizedDescriptionKey];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionNickChangedByServicesError userInfo:userInfo]];
			}
		}
	}
}

#pragma mark -
#pragma mark Incoming Message Replies

- (void) _handlePrivmsg:(NSMutableDictionary *) privmsgInfo {
#if ENABLE(PLUGINS)
	MVAssertMainThreadRequired();
#else
	MVAssertCorrectThreadRequired( _connectionThread );
#endif

	MVChatRoom *room = [privmsgInfo objectForKey:@"room"];
	MVChatUser *sender = [privmsgInfo objectForKey:@"user"];
	NSMutableData *message = [privmsgInfo objectForKey:@"message"];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatUser * ), @encode( id ), @encode( NSMutableDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processIncomingMessageAsData:from:to:attributes: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&sender atIndex:3];
	[invocation setArgument:&room atIndex:4];
	[invocation setArgument:&privmsgInfo atIndex:5];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	if( ! message.length ) return;

	if( room ) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:privmsgInfo];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:privmsgInfo];
	}
}

- (void) _handlePrivmsgWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *)sender];
	else if( !sender )
		sender = [self chatUserWithUniqueIdentifier:[self server]];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( ! targetName.length ) return;

		NSScanner *scanner = [NSScanner scannerWithString:targetName];
		[scanner setCharactersToBeSkipped:nil];
		[scanner scanCharactersFromSet:[self _nicknamePrefixes] intoString:NULL];

		NSString *roomTargetName = targetName;
		if( [scanner scanLocation] )
			roomTargetName = [targetName substringFromIndex:[scanner scanLocation]];

		NSMutableData *msgData = [parameters objectAtIndex:1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && msgData.length > 2 );

		[sender _setIdleTime:0.];
		[self _markUserAsOnline:sender];

		MVChatRoom *room = nil;
		if( roomTargetName.length >= 1 && [[self chatRoomNamePrefixes] characterIsMember:[roomTargetName characterAtIndex:0]] )
			room = [self chatRoomWithUniqueIdentifier:roomTargetName];

		MVChatUser *targetUser = nil;
		if( !room ) targetUser = [self chatUserWithUniqueIdentifier:targetName];

		id target = room;
		if( !target ) target = targetUser;

		if( ctcp ) {
			[self _handleCTCP:msgData asRequest:YES fromSender:sender toTarget:target forRoom:room];
		} else {
			NSMutableDictionary *privmsgInfo = [[NSMutableDictionary allocWithZone:nil] initWithObjectsAndKeys:msgData, @"message", sender, @"user", [NSString locallyUniqueString], @"identifier", target, @"target", room, @"room", nil];
#if ENABLE(PLUGINS)
			[self performSelectorOnMainThread:@selector( _handlePrivmsg: ) withObject:privmsgInfo waitUntilDone:NO];
#else
			[self _handlePrivmsg:privmsgInfo];
#endif
			[privmsgInfo release];
		}
	}
}

- (void) _handleNotice:(NSMutableDictionary *) noticeInfo {
#if ENABLE(PLUGINS)
	MVAssertMainThreadRequired();
#else
	MVAssertCorrectThreadRequired( _connectionThread );
#endif

	id target = [noticeInfo objectForKey:@"target"];
	MVChatRoom *room = [noticeInfo objectForKey:@"room"];
	MVChatUser *sender = [noticeInfo objectForKey:@"user"];
	NSMutableData *message = [noticeInfo objectForKey:@"message"];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatUser * ), @encode( id ), @encode( NSMutableDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processIncomingMessageAsData:from:to:attributes: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&sender atIndex:3];
	[invocation setArgument:&room atIndex:4];
	[invocation setArgument:&noticeInfo atIndex:5];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	if( ! message.length ) return;

	if( room ) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:noticeInfo];
	} else {
		if( [[sender nickname] isCaseInsensitiveEqualToString:[self server]] || ( _realServer && [[sender nickname] isCaseInsensitiveEqualToString:_realServer] ) || [[sender nickname] isCaseInsensitiveEqualToString:@"irc.umich.edu"] ) {
			NSString *msg = [self _newStringWithBytes:[message bytes] length:message.length];

			// Auto reply to servers asking us to send a PASS because they could not detect an identd
			if (![self isConnected]) {
				NSString *matchedPassword = [msg stringByMatching:@"/QUOTE PASS (\\w+)" options:RKLCaseless inRange:NSMakeRange(0, msg.length) capture:1 error:NULL];
				if( matchedPassword ) [self sendRawMessageImmediatelyWithFormat:@"PASS %@", matchedPassword];
				if( [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) {
					if( [msg isEqualToString:@"This is a registered nick, either choose another nick or enter the password by doing: /PASS <password>"] ) {
						if( ! [[self nicknamePassword] length] )
							[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
						else [self _identifyWithServicesUsingNickname:[self nickname]];
					} else if( [msg isEqualToString:@"Incorrect password for this account"] ) {
						[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
					}
				}
			}

			// Catch connect notices by the server and mark them as handled
			BOOL handled = NO;
			if( [msg hasCaseInsensitiveSubstring:@"Highest connection count"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** Your host is"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** You are exempt from DNS blacklists"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** Notice -- motd was last changed at"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** Notice -- Please read the motd if you haven't read it"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** Notice -- This server runs an open proxy monitor to prevent abuse"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** Notice -- For more information please visit"] )
				handled = YES;
			if( !handled && [msg isEqualToString:@"To complete your connection to this server, type \"/QUOTE PONG :cookie\", where cookie is the following ascii."] )
				handled = YES;
			if( !handled && [msg isMatchedByRegex:@"\\*\\*\\* Notice -- If you see.*? connections.*? from" options:RKLCaseless inRange:NSMakeRange(0, msg.length) error:NULL] )
				handled = YES;
			if( !handled && [msg isMatchedByRegex:@"\\*\\*\\* Notice -- please disregard them, as they are the .+? in action" options:RKLCaseless inRange:NSMakeRange(0, msg.length) error:NULL] )
				handled = YES;
			if( !handled && [msg isMatchedByRegex:@"on .+? ca .+?\\(.+?\\) ft .+?\\(.+?\\)" options:RKLCaseless inRange:NSMakeRange(0, msg.length) error:NULL] )
				handled = YES;

			if( handled ) [noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			[msg release];

		} else if( ![self isConnected] && [[sender nickname] isCaseInsensitiveEqualToString:@"Welcome"] ) {
			// Workaround for psybnc bouncers which are configured to combine multiple networks in one bouncer connection. These bouncers don't send a 001 command on connect...
			// Catch ":Welcome!psyBNC@lam3rz.de NOTICE * :psyBNC2.3.2-7" on these connections instead:
			NSString *msg = [self _newStringWithBytes:[message bytes] length:message.length];
			if( [msg hasCaseInsensitiveSubstring:@"psyBNC"] )
				[self performSelector:@selector( _handleConnect ) withObject:nil inThread:_connectionThread waitUntilDone:NO];
			[msg release];

		} else if( [[sender nickname] isEqualToString:@"NickServ"] || [[sender nickname] isEqualToString:@"ChanServ"] ||
		   ( [[sender nickname] isEqualToString:@"Q"] && [[self server] hasCaseInsensitiveSubstring:@"quakenet"] ) ||
		   ( [[sender nickname] isEqualToString:@"X"] && [[self server] hasCaseInsensitiveSubstring:@"undernet"] ) ||
		   ( [[sender nickname] isEqualToString:@"AuthServ"] && [[self server] hasCaseInsensitiveSubstring:@"gamesurge"] ) ) {
			NSString *msg = [self _newStringWithBytes:[message bytes] length:message.length];

			if( [msg hasCaseInsensitiveSubstring:@"password accepted"] ||				// Nickserv/*
			   [msg hasCaseInsensitiveSubstring:@"you are now identified"] ||			// NickServ/freenode
			   [msg hasCaseInsensitiveSubstring:@"you are already logged in"] ||		// NickServ/freenode
			   [msg hasCaseInsensitiveSubstring:@"successfully identified"] ||			// NickServ/oftc
			   [msg hasCaseInsensitiveSubstring:@"already identified"] ||				// NickServ
			   [msg hasCaseInsensitiveSubstring:@"you are now logged in"] ||			// Q/quakenet
			   [msg hasCaseInsensitiveSubstring:@"authentication successful"] ||		// X/undernet
			   [msg hasCaseInsensitiveSubstring:@"i recognize you"] ) {					// AuthServ/gamesurge

				_pendingIdentificationAttempt = NO;

				if( ![[self localUser] isIdentified] )
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:noticeInfo];
				[[self localUser] _setIdentified:YES];

				[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			} else if( ( [msg hasCaseInsensitiveSubstring:@"NickServ"] && [msg hasCaseInsensitiveSubstring:@" ID"] ) ||
					  [msg hasCaseInsensitiveSubstring:@"identify yourself"] ||
					  [msg hasCaseInsensitiveSubstring:@"authenticate yourself"] ||
					  [msg hasCaseInsensitiveSubstring:@"authentication required"] ||
					  [msg hasCaseInsensitiveSubstring:@"nickname is registered"] ||
					  [msg hasCaseInsensitiveSubstring:@"nickname is owned"] ||
					  [msg hasCaseInsensitiveSubstring:@"nick belongs to another user"] ||
					  ( [[self server] hasCaseInsensitiveSubstring:@"oftc"] && ( [msg isCaseInsensitiveEqualToString:@"getting this message because you are not on the access list for the"] || [msg isCaseInsensitiveEqualToString:[NSString stringWithFormat:@"\002%@\002 nickname.", [self nickname]]] ) ) ) {

				[[self localUser] _setIdentified:NO];

				if( ! [[self nicknamePassword] length] )
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
				else [self _identifyWithServicesUsingNickname:[self nickname]]; // responding to nickserv -> current nickname

				[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			} else if( ( [msg hasCaseInsensitiveSubstring:@"invalid"] ||		// NickServ/freenode, X/undernet
						 [msg hasCaseInsensitiveSubstring:@"incorrect"] ) &&	// NickServ/dalnet+foonetic+sorcery+azzurra+webchat+rizon, Q/quakenet, AuthServ/gamesurge
					   ( [msg hasCaseInsensitiveSubstring:@"password"] || [msg hasCaseInsensitiveSubstring:@"identify"] || [msg hasCaseInsensitiveSubstring:@"identification"] ) ) {

				_pendingIdentificationAttempt = NO;

				[[self localUser] _setIdentified:NO];

				[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];

				[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			} else if( [msg isCaseInsensitiveEqualToString:@"Syntax: \002IDENTIFY \037password\037\002"] ) {

				_pendingIdentificationAttempt = NO;

				[[self localUser] _setIdentified:NO];

				[self _identifyWithServicesUsingNickname:[self nickname]]; // responding nickserv error about the "nickserv identify <nick> <pass>" syntax -> current nickname

				[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			} else if( [msg isCaseInsensitiveEqualToString:@"Remember: Nobody from CService will ever ask you for your password, do NOT give out your password to anyone claiming to be CService."] ||													// Undernet
					  [msg isCaseInsensitiveEqualToString:@"REMINDER: Do not share your password with anyone. DALnet staff will not ask for your password unless"] || [msg hasCaseInsensitiveSubstring:@"you are seeking their assistance. See"] ||		// DALnet
					  [msg hasCaseInsensitiveSubstring:@"You have been invited to"] ) {	// ChanServ invite, hide since it's auto accepted

				[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			} else if ([[sender nickname] isEqualToString:@"ChanServ"] && [msg hasCaseInsensitiveSubstring:@"You're already on"])
				[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];

			// Catch "[#room] - Welcome to #room!" notices and show them in the room instead
			NSString *possibleRoomPrefix = [msg stringByMatching:@"^[\\[\\(](.+?)[\\]\\)]" capture:1];
			if( possibleRoomPrefix && [[self chatRoomNamePrefixes] characterIsMember:[possibleRoomPrefix characterAtIndex:0]] ) {
				MVChatRoom *roomInWelcomeToRoomNotice = [self chatRoomWithUniqueIdentifier:possibleRoomPrefix];
				if( roomInWelcomeToRoomNotice ) {
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:roomInWelcomeToRoomNotice userInfo:noticeInfo];
					[noticeInfo setObject:[NSNumber numberWithBool:YES] forKey:@"handled"];
				}
			}

			[msg release];
		}

		if( target == room || ( [target isKindOfClass:[MVChatUser class]] && [target isLocalUser] ) )
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:noticeInfo];
	}
}

- (void) _handleNoticeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *)sender];
	else if( !sender )
		sender = [self chatUserWithUniqueIdentifier:[self server]];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( ! targetName.length ) return;

		NSScanner *scanner = [NSScanner scannerWithString:targetName];
		[scanner setCharactersToBeSkipped:nil];
		[scanner scanCharactersFromSet:[self _nicknamePrefixes] intoString:NULL];

		NSString *roomTargetName = targetName;
		if( [scanner scanLocation] )
			roomTargetName = [targetName substringFromIndex:[scanner scanLocation]];

		NSMutableData *msgData = [parameters objectAtIndex:1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && msgData.length > 2 );

		MVChatRoom *room = nil;
		if( roomTargetName.length >= 1 && [[self chatRoomNamePrefixes] characterIsMember:[roomTargetName characterAtIndex:0]] )
			room = [self chatRoomWithUniqueIdentifier:roomTargetName];

		MVChatUser *targetUser = nil;
		if( !room ) targetUser = [self chatUserWithUniqueIdentifier:targetName];

		id target = room;
		if( !target ) target = targetUser;

		if( ctcp ) {
			[self _handleCTCP:msgData asRequest:NO fromSender:sender toTarget:target forRoom:room];
		} else {
			NSMutableDictionary *noticeInfo = [[NSMutableDictionary allocWithZone:nil] initWithObjectsAndKeys:msgData, @"message", sender, @"user", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"notice", target, @"target", room, @"room", nil];
#if ENABLE(PLUGINS)
			[self performSelectorOnMainThread:@selector( _handleNotice: ) withObject:noticeInfo waitUntilDone:NO];
#else
			[self _handleNotice:noticeInfo];
#endif
			[noticeInfo release];
		}
	}
}

- (void) _handleCTCP:(NSDictionary *) ctcpInfo {
#if ENABLE(PLUGINS)
	MVAssertMainThreadRequired();
#else
	MVAssertCorrectThreadRequired( _connectionThread );
#endif

	BOOL request = [[ctcpInfo objectForKey:@"request"] boolValue];
	NSData *data = [ctcpInfo objectForKey:@"data"];
	MVChatUser *sender = [ctcpInfo objectForKey:@"sender"];
	MVChatRoom *room = [ctcpInfo objectForKey:@"room"];
	id target = [ctcpInfo objectForKey:@"target"];

	const char *line = (const char *)[data bytes] + 1; // skip the \001 char
	const char *end = line + data.length - 2; // minus the first and last \001 char
	const char *current = line;

	while( line != end && *line != ' ' ) line++;

	NSString *command = [self _newStringWithBytes:current length:(line - current)];
	NSMutableData *arguments = nil;
	if( line != end ) {
		line++;
		arguments = [[NSMutableData allocWithZone:nil] initWithBytes:line length:(end - line)];
	}

	if( [command isCaseInsensitiveEqualToString:@"ACTION"] && arguments ) {
		// special case ACTION and send it out like a message with the action flag
		NSMutableDictionary *msgInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:arguments, @"message", sender, @"user", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"action", target, @"target", room, @"room", nil];

		[self _handlePrivmsg:msgInfo]; // No need to explicitly call this on a different thread, as we are already in it.

		[command release];
		[arguments release];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:( request ? MVChatConnectionSubcodeRequestNotification : MVChatConnectionSubcodeReplyNotification ) object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:command, @"command", arguments, @"arguments", nil]];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatUser * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	if( request ) [invocation setSelector:@selector( processSubcodeRequest:withArguments:fromUser: )];
	else [invocation setSelector:@selector( processSubcodeReply:withArguments:fromUser: )];
	[invocation setArgument:&command atIndex:2];
	[invocation setArgument:&arguments atIndex:3];
	[invocation setArgument:&sender atIndex:4];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) {
		[command release];
		[arguments release];
		return;
	}
#endif

	if( request ) {
		if( [command isCaseInsensitiveEqualToString:@"VERSION"] ) {
			NSDictionary *systemVersion = [[NSDictionary allocWithZone:nil] initWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
			if( !systemVersion ) systemVersion = [[NSDictionary allocWithZone:nil] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
			NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];

#if __ppc__
			NSString *processor = @"PowerPC";
#elif __i386__ || __x86_64__
			NSString *processor = @"Intel";
#elif __arm__
			NSString *processor = @"ARM";
#else
			NSString *processor = @"Unknown Architecture";
#endif

			NSString *reply = [[NSString allocWithZone:nil] initWithFormat:@"%@ %@ (%@) - %@ %@ (%@) - %@", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [clientVersion objectForKey:@"CFBundleVersion"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductVersion"], processor, [clientVersion objectForKey:@"MVChatCoreCTCPVersionReplyInfo"]];
			[sender sendSubcodeReply:command withArguments:reply];

			[reply release];
			[systemVersion release];
		} else if( [command isCaseInsensitiveEqualToString:@"TIME"] ) {
			[sender sendSubcodeReply:command withArguments:[[NSDate date] description]];
		} else if( [command isCaseInsensitiveEqualToString:@"PING"] ) {
			// only reply with packets less than 100 bytes, anything over that is bad karma
			if( arguments.length < 100 ) [sender sendSubcodeReply:command withArguments:arguments];
		} else if( [command isCaseInsensitiveEqualToString:@"DCC"] ) {
			NSString *msg = [self _newStringWithBytes:[arguments bytes] length:arguments.length];
			NSString *subCommand = nil;
			NSString *fileName = nil;
			BOOL quotedFileName = NO;

			NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
			NSScanner *scanner = [NSScanner scannerWithString:msg];

			[scanner scanUpToCharactersFromSet:whitespace intoString:&subCommand];

			if( [scanner scanString:@"\"" intoString:NULL] && [scanner scanUpToString:@"\"" intoString:&fileName] && [scanner scanString:@"\"" intoString:NULL] ) {
				quotedFileName = YES;
			} else {
				[scanner scanUpToCharactersFromSet:whitespace intoString:&fileName];
			}

			if( [subCommand isCaseInsensitiveEqualToString:@"SEND"] ) {
				BOOL passive = NO;
				NSString *address = nil;
				int port = 0;
				long long size = 0;
				long long passiveId = 0;

				[scanner scanUpToCharactersFromSet:whitespace intoString:&address];
				[scanner scanInt:&port];
				[scanner scanLongLong:&size];

				if( [scanner scanLongLong:&passiveId] )
					passive = YES;

				if( [address rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@".:"]].location == NSNotFound ) {
					unsigned ip4 = 0;
					sscanf( [address UTF8String], "%u", &ip4 );
					address = [NSString stringWithFormat:@"%lu.%lu.%lu.%lu", (ip4 & 0xff000000) >> 24, (ip4 & 0x00ff0000) >> 16, (ip4 & 0x0000ff00) >> 8, (ip4 & 0x000000ff)];
				}

				port %= 65536; // some clients use ports greater than 65535, mod with 65536 to get the real port

				if( passive && port > 0 ) {
					// this is a passive reply, look up the original transfer
					MVIRCUploadFileTransfer *transfer = nil;

					@synchronized( _directClientConnections ) {
						for( transfer in _directClientConnections ) {
							if( ! [transfer isUpload] )
								continue;
							if( ! [transfer isPassive] )
								continue;
							if( ! [[transfer user] isEqualToChatUser:sender] )
								continue;
							if( [transfer _passiveIdentifier] == passiveId )
								break;
						}
					}

					if( transfer ) {
						[transfer _setHost:address];
						[transfer _setPort:port];
						[transfer _setupAndStart];
					}
				} else {
					MVIRCDownloadFileTransfer *transfer = [(MVIRCDownloadFileTransfer *)[MVIRCDownloadFileTransfer allocWithZone:nil] initWithUser:sender];

					if( port == 0 && passive ) {
						[transfer _setPassiveIdentifier:passiveId];
						[transfer _setPassive:YES];
					} else {
						[transfer _setHost:address];
						[transfer _setPort:port];
					}

					[transfer _setTurbo:[scanner scanString:@"T" intoString:NULL]];
					[transfer _setOriginalFileName:fileName];
					[transfer _setFileNameQuoted:quotedFileName];
					[transfer _setFinalSize:(unsigned long long)size];

					[self _addDirectClientConnection:transfer];

					[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDownloadFileTransferOfferNotification object:transfer];

					[transfer release];
				}
			} else if( [subCommand isCaseInsensitiveEqualToString:@"ACCEPT"] ) {
				BOOL passive = NO;
				int port = 0;
				long long size = 0;
				long long passiveId = 0;

				[scanner scanInt:&port];
				[scanner scanLongLong:&size];

				if( [scanner scanLongLong:&passiveId] )
					passive = YES;

				port %= 65536; // some clients use ports greater than 65535, mod with 65536 to get the real port

				@synchronized( _directClientConnections ) {
					for( MVIRCDownloadFileTransfer *transfer in _directClientConnections ) {
						if( ! [transfer isDownload] )
							continue;
						if( [transfer isPassive] != passive )
							continue;
						if( ! [[transfer user] isEqualToChatUser:sender] )
							continue;

						BOOL portMatches = ( ! passive && [transfer port] == port );
						BOOL passiveIdMatches = ( passive && [transfer _passiveIdentifier] == passiveId );

						if( portMatches || passiveIdMatches ) {
							[transfer _setTransferred:(unsigned long long)size];
							[transfer _setStartOffset:(unsigned long long)size];
							[transfer _setupAndStart];
							break;
						}
					}
				}
			} else if( [subCommand isCaseInsensitiveEqualToString:@"RESUME"] ) {
				BOOL passive = NO;
				int port = 0;
				long long size = 0;
				long long passiveId = 0;

				[scanner scanInt:&port];
				[scanner scanLongLong:&size];

				if( [scanner scanLongLong:&passiveId] )
					passive = YES;

				port %= 65536; // some clients use ports greater than 65535, mod with 65536 to get the real port

				@synchronized( _directClientConnections ) {
					for( MVIRCUploadFileTransfer *transfer in _directClientConnections ) {
						if( ! [transfer isUpload] )
							continue;
						if( [transfer isPassive] != passive )
							continue;
						if( ! [[transfer user] isEqualToChatUser:sender] )
							continue;

						BOOL portMatches = ( ! passive && [transfer port] == port );
						BOOL passiveIdMatches = ( passive && [transfer _passiveIdentifier] == passiveId );

						if( portMatches || passiveIdMatches ) {
							[transfer _setTransferred:(unsigned long long)size];
							[transfer _setStartOffset:(unsigned long long)size];
							[sender sendSubcodeRequest:@"DCC ACCEPT" withArguments:[msg substringFromIndex:7]];
							break;
						}
					}
				}
			} else if( [subCommand isCaseInsensitiveEqualToString:@"CHAT"] ) {
				BOOL passive = NO;
				NSString *address = nil;
				int port = 0;
				long long passiveId = 0;

				[scanner scanUpToCharactersFromSet:whitespace intoString:&address];
				[scanner scanInt:&port];

				if( [scanner scanLongLong:&passiveId] )
					passive = YES;

				if( [address rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@".:"]].location == NSNotFound ) {
					unsigned ip4 = 0;
					sscanf( [address UTF8String], "%u", &ip4 );
					address = [NSString stringWithFormat:@"%lu.%lu.%lu.%lu", (ip4 & 0xff000000) >> 24, (ip4 & 0x00ff0000) >> 16, (ip4 & 0x0000ff00) >> 8, (ip4 & 0x000000ff)];
				}

				port %= 65536; // some clients use ports greater than 65535, mod with 65536 to get the real port

				if( [fileName isCaseInsensitiveEqualToString:@"CHAT"] || [fileName isCaseInsensitiveEqualToString:@"C H A T"] ) {
					if( passive && port > 0 ) {
						// this is a passive reply, look up the original chat request
						MVDirectChatConnection *directChat = nil;

						@synchronized( _directClientConnections ) {
							for( directChat in _directClientConnections ) {
								if( ! [directChat isPassive] )
									continue;
								if( ! [[directChat user] isEqualToChatUser:sender] )
									continue;
								if( [directChat _passiveIdentifier] == passiveId )
									break;
							}
						}

						if( directChat ) {
							[directChat _setHost:address];
							[directChat _setPort:port];
							[directChat initiate];
						}
					} else {
						MVDirectChatConnection *directChatConnection = [(MVDirectChatConnection *)[MVDirectChatConnection allocWithZone:nil] initWithUser:sender];

						if( port == 0 && passive ) {
							[directChatConnection _setPassiveIdentifier:passiveId];
							[directChatConnection _setPassive:YES];
						} else {
							[directChatConnection _setHost:address];
							[directChatConnection _setPort:port];
						}

						[self _addDirectClientConnection:directChatConnection];

						[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionOfferNotification object:directChatConnection userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];

						[directChatConnection release];
					}
				}
			}

			[msg release];
		} else if( [command isCaseInsensitiveEqualToString:@"CLIENTINFO"] ) {
			// make this extensible later with a plugin registration method
			[sender sendSubcodeReply:command withArguments:@"VERSION TIME PING DCC CLIENTINFO"];
		}
	} else {
		if( [command isCaseInsensitiveEqualToString:@"DCC"] ) {
			NSString *msg = [self _newStringWithBytes:[arguments bytes] length:arguments.length];
			NSString *subCommand = nil;

			NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
			NSScanner *scanner = [NSScanner scannerWithString:msg];

			[scanner scanUpToCharactersFromSet:whitespace intoString:&subCommand];

			if( [subCommand isCaseInsensitiveEqualToString:@"REJECT"] ) {
				[scanner scanUpToCharactersFromSet:whitespace intoString:&subCommand];

				if( [subCommand isCaseInsensitiveEqualToString:@"SEND"] ) {
					NSString *fileName = nil;
					BOOL portKnown = NO;
					BOOL passive = NO;
					int port = 0;
					long long passiveId = 0;

					// scan the filename
					if( [scanner scanString:@"\"" intoString:NULL] && [scanner scanUpToString:@"\"" intoString:&fileName] && [scanner scanString:@"\"" intoString:NULL] ) {
						// nothing to do
					} else {
						[scanner scanUpToCharactersFromSet:whitespace intoString:&fileName];
					}

					// skip the address and scan for the port
					if( [scanner scanUpToCharactersFromSet:whitespace intoString:NULL] && [scanner scanInt:&port] )
						portKnown = YES;

					// skip the file size and scan for the passive id
					if( [scanner scanLongLong:NULL] && [scanner scanLongLong:&passiveId] )
						passive = YES;

					port %= 65536; // some clients use ports greater than 65535, mod with 65536 to get the real port

					@synchronized( _directClientConnections ) {
						for( MVIRCUploadFileTransfer *transfer in [[_directClientConnections copy] autorelease] ) {
							if( ! [transfer isUpload] )
								continue;
							if( [transfer isPassive] != passive )
								continue;
							if( ! [[transfer user] isEqualToChatUser:sender] )
								continue;

							BOOL fileMatches = ( [[[(MVUploadFileTransfer *)transfer source] lastPathComponent] isCaseInsensitiveEqualToString:fileName] );
							if( ! fileMatches && ! portKnown && ! passive )
								continue;

							BOOL portMatches = ( portKnown && ! passive && [transfer port] == port );
							BOOL passiveIdMatches = ( passive && [transfer _passiveIdentifier] == passiveId );

							if( fileMatches || portMatches || passiveIdMatches )
								[transfer cancel];
						}
					}
				}
			}

			[msg release];
		}
	}

	[command release];
	[arguments release];
}

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender toTarget:(id) target forRoom:(MVChatRoom *) room {
	MVAssertCorrectThreadRequired( _connectionThread );

	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:4];

	if( data ) [info setObject:data forKey:@"data"];
	if( sender ) [info setObject:sender forKey:@"sender"];
	if( target ) [info setObject:target forKey:@"target"];
	if( room ) [info setObject:room forKey:@"room"];
	[info setObject:[NSNumber numberWithBool:request] forKey:@"request"];

#if ENABLE(PLUGINS)
	[self performSelectorOnMainThread:@selector( _handleCTCP: ) withObject:info waitUntilDone:NO];
#else
	[self _handleCTCP:info];
#endif

	[info release];
}

#pragma mark -
#pragma mark Room Replies

- (void) _handleJoinWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *name = [self _stringFromPossibleData:[parameters objectAtIndex:0]];
		MVChatRoom *room = [self chatRoomWithName:name];

		if( [sender isLocalUser] ) {
			[_pendingJoinRoomNames removeObject:name];

			[room _setDateJoined:[NSDate date]];
			[room _setDateParted:nil];
			[room _clearMemberUsers];
			[room _clearBannedUsers];
		} else {
			[sender _setIdleTime:0.];
			[self _markUserAsOnline:sender];
			[room _addMemberUser:sender];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
		}
	}
}

- (void) _handlePartWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *roomName = [self _stringFromPossibleData:[parameters objectAtIndex:0]];
		MVChatRoom *room = [self joinedChatRoomWithUniqueIdentifier:roomName];
		if( ! room ) return;

		[room _removeMemberUser:sender];

		NSData *reason = ( parameters.count >= 2 ? [parameters objectAtIndex:1] : nil );
		if( ! [reason isKindOfClass:[NSData class]] ) reason = nil;

		if( [sender isLocalUser] ) {
			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:reason, @"reason", nil]];
		} else {
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", reason, @"reason", nil]];
		}
	}
}

- (void) _handleQuitWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		if( [sender isLocalUser] ) {
			_userDisconnected = YES;
			[[self _chatConnection] disconnect];
			return;
		}

		[self _markUserAsOffline:sender];
		[_pendingWhoisUsers removeObject:sender];

		NSData *reason = [parameters objectAtIndex:0];
		if( ! [reason isKindOfClass:[NSData class]] ) reason = nil;
		NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:sender, @"user", reason, @"reason", nil];

		for( MVChatRoom *room in [self joinedChatRooms] ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _removeMemberUser:sender];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:info];
		}

		[info release];
	}
}

- (void) _handleKickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count >= 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:0]];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		if( ! room || ! user ) return;

		NSData *reason = ( parameters.count == 3 ? [parameters objectAtIndex:2] : nil );
		if( ! [reason isKindOfClass:[NSData class]] ) reason = nil;
		if( [user isLocalUser] ) {
			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"byUser", reason, @"reason", nil]];
		} else {
			[room _removeMemberUser:user];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", sender, @"byUser", reason, @"reason", nil]];
		}
	}
}

- (void) _handleTopic:(NSDictionary *)topicInfo {
#if ENABLE(PLUGINS)
	MVAssertMainThreadRequired();
#else
	MVAssertCorrectThreadRequired(_connectionThread);
#endif

	MVChatRoom *room = [topicInfo objectForKey:@"room"];
	MVChatUser *author = [topicInfo objectForKey:@"author"];
	NSMutableData *topic = [[topicInfo objectForKey:@"topic"] mutableCopyWithZone:nil];

#if ENABLE(PLUGINS)
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatRoom * ), @encode( MVChatUser * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processTopicAsData:inRoom:author: )];
	[invocation setArgument:&topic atIndex:2];
	[invocation setArgument:&room atIndex:3];
	[invocation setArgument:&author atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	[room _setTopic:topic];
	[room _setTopicAuthor:author];
	[room _setTopicDate:[NSDate date]];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification object:room userInfo:nil];

	[topic release];
}

- (void) _handleTopicWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:0]];
		NSData *topic = [parameters objectAtIndex:1];
		if( ! [topic isKindOfClass:[NSData class]] ) topic = nil;

		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:room, @"room", sender, @"author", topic, @"topic", nil];
#if ENABLE(PLUGINS)
		[self performSelectorOnMainThread:@selector( _handleTopic: ) withObject:info waitUntilDone:NO];
#else
		[self _handleTopic:info];
#endif
	}
}

- (void) _parseRoomModes:(NSArray *) parameters forRoom:(MVChatRoom *) room fromSender:(MVChatUser *) sender {
#define enabledHighBit ( 1 << 31 )
#define banMode ( 1 << 30 )
#define banExcludeMode ( 1 << 29 )
#define inviteExcludeMode ( 1 << 28 )

	NSUInteger oldModes = [room modes];
	NSUInteger argModes = 0;
	NSUInteger value = 0;
	NSMutableArray *argsNeeded = [[NSMutableArray allocWithZone:nil] initWithCapacity:10];
	NSUInteger i = 0, count = parameters.count;
	while( i < count ) {
		NSString *param = [self _stringFromPossibleData:[parameters objectAtIndex:i++]];
		if( param.length ) {
			char chr = [param characterAtIndex:0];
			if( chr == '+' || chr == '-' ) {
				unsigned enabled = YES;
				NSUInteger j = 0, length = param.length;
				while( j < length ) {
					chr = [param characterAtIndex:j++];
					switch( chr ) {
						case '+': enabled = YES; break;
						case '-': enabled = NO; break;
						case 'i':
							if( enabled ) [room _setMode:MVChatRoomInviteOnlyMode withAttribute:nil];
							else [room _removeMode:MVChatRoomInviteOnlyMode];
							break;
						case 'p':
							if( enabled ) [room _setMode:MVChatRoomPrivateMode withAttribute:nil];
							else [room _removeMode:MVChatRoomPrivateMode];
							break;
						case 's':
							if( enabled ) [room _setMode:MVChatRoomSecretMode withAttribute:nil];
							else [room _removeMode:MVChatRoomSecretMode];
							break;
						case 'm':
							if( enabled ) [room _setMode:MVChatRoomNormalUsersSilencedMode withAttribute:nil];
							else [room _removeMode:MVChatRoomNormalUsersSilencedMode];
							break;
						case 'n':
							if( enabled ) [room _setMode:MVChatRoomNoOutsideMessagesMode withAttribute:nil];
							else [room _removeMode:MVChatRoomNoOutsideMessagesMode];
							break;
						case 't':
							if( enabled ) [room _setMode:MVChatRoomOperatorsOnlySetTopicMode withAttribute:nil];
							else [room _removeMode:MVChatRoomOperatorsOnlySetTopicMode];
							break;
						case 'l':
							if( ! enabled ) {
								[room _removeMode:MVChatRoomLimitNumberOfMembersMode];
								break;
							}
							value = MVChatRoomLimitNumberOfMembersMode;
							goto queue;
						case 'k':
							if( ! enabled ) {
								[room _removeMode:MVChatRoomPassphraseToJoinMode];
								break;
							}
							value = MVChatRoomPassphraseToJoinMode;
							goto queue;
						case 'b':
							value = banMode;
							goto queue;
						case 'e':
							value = banExcludeMode;
							goto queue;
						case 'I':
							value = inviteExcludeMode;
							goto queue;
						case 'o':
							value = MVChatRoomMemberOperatorMode;
							goto queue;
						case 'v':
							value = MVChatRoomMemberVoicedMode;
							goto queue;
						queue:
							if( enabled ) value |= enabledHighBit;
							[argsNeeded addObject:[NSNumber numberWithUnsignedLong:value]];
							break;
						default: {
							NSMutableDictionary *supportedModes = [_serverInformation objectForKey:@"roomMemberModeTable"];
							if( supportedModes.count ) {
								value = [[supportedModes objectForKey:[NSString stringWithFormat:@"%c", chr]] unsignedLongValue];
								if( value ) goto queue;
							}
						}
					}
				}
			} else {
				if( argsNeeded.count ) {
					NSUInteger value = [[argsNeeded objectAtIndex:0] unsignedLongValue];
					BOOL enabled = ( ( value & enabledHighBit ) ? YES : NO );
					NSUInteger mode = ( value & ~enabledHighBit );

					if( mode == MVChatRoomMemberFounderMode || mode == MVChatRoomMemberAdministratorMode || mode == MVChatRoomMemberOperatorMode || mode == MVChatRoomMemberHalfOperatorMode || mode == MVChatRoomMemberVoicedMode ) {
						MVChatUser *member = [self chatUserWithUniqueIdentifier:param];
						if( enabled ) [room _setMode:mode forMemberUser:member];
						else [room _removeMode:mode forMemberUser:member];
						[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:mode], @"mode", sender, @"by", nil]];
					} else if( mode == banMode ) {
						MVChatUser *user = [MVChatUser wildcardUserFromString:param];
						if( enabled ) {
							[room _addBanForUser:user];
							[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserBannedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", sender, @"byUser", nil]];
						} else {
							[room _removeBanForUser:user];
							[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserBanRemovedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", sender, @"byUser", nil]];
						}
					} else if( mode == MVChatRoomLimitNumberOfMembersMode && enabled ) {
						argModes |= MVChatRoomLimitNumberOfMembersMode;
						[room _setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:[NSNumber numberWithInt:[param intValue]]];
					} else if( mode == MVChatRoomPassphraseToJoinMode && enabled ) {
						argModes |= MVChatRoomPassphraseToJoinMode;
						[room _setMode:MVChatRoomPassphraseToJoinMode withAttribute:param];
					}

					[argsNeeded removeObjectAtIndex:0];
				}
			}
		}
	}

#undef enabledHighBit
#undef banMode
#undef banExcludeMode
#undef inviteExcludeMode

	[argsNeeded release];

	NSUInteger changedModes = ( oldModes ^ [room modes] ) | argModes;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomModesChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:changedModes], @"changedModes", sender, @"by", nil]];
}

- (void) _handleModeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count >= 2 ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( targetName.length >= 1 && [[self chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]] ) {
			MVChatRoom *room = [self chatRoomWithUniqueIdentifier:targetName];
			[self _parseRoomModes:[parameters subarrayWithRange:NSMakeRange( 1, parameters.count - 1)] forRoom:room fromSender:sender];
		} else {
			// user modes not handled yet
		}
	}
}

- (void) _handle324WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_CHANNELMODEIS
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 3 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[self _parseRoomModes:[parameters subarrayWithRange:NSMakeRange( 2, parameters.count - 2)] forRoom:room fromSender:nil];
	}
}

#pragma mark -
#pragma mark Misc. Replies

- (void) _handlePingWithParameters:(NSArray *) parameters fromSender:(id) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 1 ) {
		if( parameters.count == 1 )
			[self sendRawMessageImmediatelyWithComponents:@"PONG :", [parameters objectAtIndex:0], nil];
		else [self sendRawMessageImmediatelyWithComponents:@"PONG ", [parameters objectAtIndex:1], @" :", [parameters objectAtIndex:0], nil];

		if( [sender isKindOfClass:[MVChatUser class]] )
			[self _markUserAsOnline:sender];
	}
}

- (void) _handleInviteWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *roomName = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

		[self _markUserAsOnline:sender];

		if( [[sender nickname] isEqualToString:@"ChanServ"] ) {
			// Auto-accept invites from ChanServ since the user initiated the invite.
			[self joinChatRoomNamed:roomName];
		} else {
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomInvitedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", roomName, @"room", nil]];
		}
	}
}

- (void) _handleNickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *nick = [self _stringFromPossibleData:[parameters objectAtIndex:0]];
		NSString *oldNickname = [[sender nickname] retain];
		NSString *oldIdentifier = [[sender uniqueIdentifier] retain];

		[sender _setIdleTime:0.];
		[self _markUserAsOnline:sender];

		NSNotification *note = nil;
		if( [sender isLocalUser] ) {
			[self _setCurrentNickname:nick];
			_pendingIdentificationAttempt = NO; // TODO see below
			[sender _setIdentified:NO]; // TODO this needs to be changed for quakenet, gamesurge, undernet and other account-based (= not nickname-based) identification services
			note = [NSNotification notificationWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:nil];
		} else {
			[self _updateKnownUser:sender withNewNickname:nick];
			note = [NSNotification notificationWithName:MVChatUserNicknameChangedNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldNickname, @"oldNickname", nil]];
		}

		for( MVChatRoom *room in [self joinedChatRooms] ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _updateMemberUser:sender fromOldUniqueIdentifier:oldIdentifier];
		}

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		[oldNickname release];
		[oldIdentifier release];
	}
}

- (void) _handle303WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ISON
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 2 && _isonSentCount > 0 ) {
		_isonSentCount--;

		NSString *names = [self _stringFromPossibleData:[parameters objectAtIndex:1]];
		NSArray *users = [names componentsSeparatedByString:@" "];

		for( NSString *nick in users ) {
			if( ! nick.length ) continue;

			NSString *nickLower = [nick lowercaseString];
			if( [_lastSentIsonNicknames containsObject:nickLower] ) {
				MVChatUser *user = [self chatUserWithUniqueIdentifier:nick];
				if( ! [[user nickname] isEqualToString:nick] && [[user nickname] isCaseInsensitiveEqualToString:nick] )
					[user _setNickname:nick]; // nick differed only in case, change to the proper case
//				if( [[user dateUpdated] timeIntervalSinceNow] < -JVWatchedUserWHOISDelay || ! [user dateUpdated] )
//					[self _scheduleWhoisForUser:user];
				[self _markUserAsOnline:user];
				[_lastSentIsonNicknames removeObject:nickLower];
			}
		}

		if( ! _isonSentCount ) {
			for( NSString *nick in _lastSentIsonNicknames ) {
				MVChatUser *user = [self chatUserWithUniqueIdentifier:nick];
				[self _markUserAsOffline:user];
			}

			[_lastSentIsonNicknames release];
			_lastSentIsonNicknames = nil;
		}
	} else if( parameters.count == 2 ) {
		NSString *names = [self _stringFromPossibleData:[parameters objectAtIndex:1]];
		NSArray *users = [names componentsSeparatedByString:@" "];

		for( NSString *nick in users ) {
			if( ! nick.length ) continue;

			MVChatUser *user = [self chatUserWithUniqueIdentifier:nick];
			if( ! [[user nickname] isEqualToString:nick] && [[user nickname] isCaseInsensitiveEqualToString:nick] )
				[user _setNickname:nick]; // nick differed only in case, change to the proper case
			[self _markUserAsOnline:user];
		}
	}
}

#pragma mark -
#pragma mark Away Replies

- (void) _handle301WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_AWAY
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		NSData *awayMsg = [parameters objectAtIndex:2];
		if( ! [awayMsg isKindOfClass:[NSData class]] ) awayMsg = nil;

		if( ! [[user awayStatusMessage] isEqual:awayMsg] ) {
			[user _setAwayStatusMessage:awayMsg];
			[user _setStatus:MVChatUserAwayStatus];

			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserAwayStatusMessageChangedNotification object:user userInfo:nil];
		}
	}
}

- (void) _handle305WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_UNAWAY
	MVAssertCorrectThreadRequired( _connectionThread );

	[[self localUser] _setAwayStatusMessage:nil];
	[[self localUser] _setStatus:MVChatUserAvailableStatus];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
}

- (void) _handle306WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NOWAWAY
	MVAssertCorrectThreadRequired( _connectionThread );

	[[self localUser] _setStatus:MVChatUserAwayStatus];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
}

#pragma mark -
#pragma mark NAMES Replies

- (void) _handle353WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NAMREPLY
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 4 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:2]];
		if( room && ! [room _namesSynced] ) {
			NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
			NSString *names = [self _stringFromPossibleData:[parameters objectAtIndex:3]];
			NSArray *members = [names componentsSeparatedByString:@" "];

			for( NSString *memberName in members ) {
				if( ! memberName.length ) break;

				MVChatRoomMemberMode modes = [self _stripModePrefixesFromNickname:&memberName];
				MVChatUser *member = [self chatUserWithUniqueIdentifier:memberName];
				[room _addMemberUser:member];
				[room _setModes:modes forMemberUser:member];

				[self _markUserAsOnline:member];
			}

			[pool drain];
		}
	}
}

- (void) _handle366WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFNAMES
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		if( room && ! [room _namesSynced] ) {
			[room _setNamesSynced:YES];

			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification object:room];

#if !ENABLE(BOUNCER_MODE)
			if( [[room memberUsers] count] <= JVMaximumMembersForWhoRequest )
				[self sendRawMessage:[NSString stringWithFormat:@"WHO %@", [room name]]];
			[self sendRawMessage:[NSString stringWithFormat:@"MODE %@ b", [room name]]];
#endif
		}
	}
}

#pragma mark -
#pragma mark WHO Replies

- (void) _handle352WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOREPLY
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 7 ) {
		MVChatUser *member = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:5]];
		[member _setUsername:[parameters objectAtIndex:2]];
		[member _setAddress:[parameters objectAtIndex:3]];

		NSString *statusString = [self _stringFromPossibleData:[parameters objectAtIndex:6]];
		unichar userStatus = ( statusString.length ? [statusString characterAtIndex:0] : 0 );
		if( userStatus == 'H' ) {
			[member _setAwayStatusMessage:nil];
			[member _setStatus:MVChatUserAvailableStatus];
		} else if( userStatus == 'G' ) {
			[member _setStatus:MVChatUserAwayStatus];
		}

		[member _setServerOperator:( statusString.length >= 2 && [statusString characterAtIndex:1] == '*' )];

		if( parameters.count >= 8 ) {
			NSString *lastParam = [self _stringFromPossibleData:[parameters objectAtIndex:7]];
			NSRange range = [lastParam rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
			if( range.location != NSNotFound ) {
				NSString *name = [lastParam substringFromIndex:range.location + range.length];
				if( name.length ) [member _setRealName:name];
				else [member _setRealName:nil];
			} else [member _setRealName:nil];
		}

		[self _markUserAsOnline:member];
	}
}

- (void) _handle315WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFWHO
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		if( room ) [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomMemberUsersSyncedNotification object:room];
	}
}

#pragma mark -
#pragma mark Channel List Reply

- (void) _handle322WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_LIST
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 4 ) {
		NSString *room = [parameters objectAtIndex:1];
		NSUInteger users = [[parameters objectAtIndex:2] intValue];
		NSData *topic = [parameters objectAtIndex:3];
		if( ! [topic isKindOfClass:[NSData class]] ) topic = nil;

		NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:users], @"users", [NSDate date], @"cached", room, @"room", topic, @"topic", nil];
		[self performSelectorOnMainThread:@selector( _addRoomToCache: ) withObject:info waitUntilDone:NO];
		[info release];
	}
}

#pragma mark -
#pragma mark Ban List Replies

- (void) _handle367WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_BANLIST
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 3 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:1]];
		MVChatUser *user = [MVChatUser wildcardUserFromString:[self _stringFromPossibleData:[parameters objectAtIndex:2]]];
		if( parameters.count >= 5 ) {
			[user setAttribute:[parameters objectAtIndex:3] forKey:MVChatUserBanServerAttribute];

			NSString *dateString = [self _stringFromPossibleData:[parameters objectAtIndex:4]];
			NSTimeInterval time = [dateString doubleValue];
			if( time > JVFirstViableTimestamp )
				[user setAttribute:[NSDate dateWithTimeIntervalSince1970:time] forKey:MVChatUserBanDateAttribute];
		}

		if( [room _bansSynced] )
			[room _clearBannedUsers];

		[room _addBanForUser:user];
	}
}

- (void) _handle368WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFBANLIST
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		[room _setBansSynced:YES];
		if( room ) [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomBannedUsersSyncedNotification object:room];
	}
}

#pragma mark -
#pragma mark Topic Replies

- (void) _handle332WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_TOPIC
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 3 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:1]];
		NSData *topic = [parameters objectAtIndex:2];
		if( ! [topic isKindOfClass:[NSData class]] ) topic = nil;
		[room _setTopic:topic];
	}
}

- (void) _handle333WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_TOPICWHOTIME_IRCU
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 4 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[parameters objectAtIndex:1]];
		MVChatUser *author = [MVChatUser wildcardUserFromString:[parameters objectAtIndex:2]];
		[room _setTopicAuthor:author];

		NSString *setTime = [self _stringFromPossibleData:[parameters objectAtIndex:3]];
		NSTimeInterval time = [setTime doubleValue];
		if( time > JVFirstViableTimestamp )
			[room _setTopicDate:[NSDate dateWithTimeIntervalSince1970:time]];

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification object:room userInfo:nil];
	}
}

#pragma mark -
#pragma mark WHOIS Replies

- (void) _handle311WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISUSER
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 6 ) {
		NSString *nick = [parameters objectAtIndex:1];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:nick];
		if( ! [[user nickname] isEqualToString:nick] && [[user nickname] isCaseInsensitiveEqualToString:nick] )
			[user _setNickname:nick]; // nick differed only in case, change to the proper case
		[user _setUsername:[parameters objectAtIndex:2]];
		[user _setAddress:[parameters objectAtIndex:3]];
		[user _setRealName:[self _stringFromPossibleData:[parameters objectAtIndex:5]]];
		[user _setStatus:MVChatUserAvailableStatus]; // set this to available, we will change it if we get a RPL_AWAY
		[user _setAwayStatusMessage:nil]; // set this to nil, we will get it if we get a RPL_AWAY
		[user _setServerOperator:NO]; // set this to NO now so we get the true values later in the RPL_WHOISOPERATOR

		[self _markUserAsOnline:user];
	}
}

- (void) _handle312WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISSERVER
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setServerAddress:[self _stringFromPossibleData:[parameters objectAtIndex:2]]];
	}
}

- (void) _handle313WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISOPERATOR
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		[user _setServerOperator:YES];
	}
}

- (void) _handle317WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISIDLE
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		NSString *idleTime = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		[user _setIdleTime:[idleTime doubleValue]];
		[user _setDateConnected:nil];

		// parameter 4 is connection time on some servers
		if( parameters.count >= 4 ) {
			NSString *connectedTime = [self _stringFromPossibleData:[parameters objectAtIndex:3]];
			NSTimeInterval time = [connectedTime doubleValue];
			if( time > JVFirstViableTimestamp )
				[user _setDateConnected:[NSDate dateWithTimeIntervalSince1970:time]];
		}
	}
}

- (void) _handle318WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFWHOIS
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		[user _setDateUpdated:[NSDate date]];

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserInformationUpdatedNotification object:user userInfo:nil];

		if( [_pendingWhoisUsers containsObject:user] ) {
			[_pendingWhoisUsers removeObject:user];
			[self _whoisNextScheduledUser];
		}
	}
}

- (void) _handle319WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISCHANNELS
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 3 ) {
		NSString *rooms = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		NSArray *chanArray = [[rooms stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSMutableArray *results = [[NSMutableArray allocWithZone:nil] initWithCapacity:chanArray.count];

		NSCharacterSet *nicknamePrefixes = [self _nicknamePrefixes];
		for( NSString *room in chanArray ) {
			NSRange prefixRange = [room rangeOfCharacterFromSet:nicknamePrefixes options:NSAnchoredSearch];
			if( prefixRange.location != NSNotFound )
				room = [room substringFromIndex:( prefixRange.location + prefixRange.length )];
			room = [room stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if( room.length ) [results addObject:room];
		}

		if( results.count ) {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
			[user setAttribute:results forKey:MVChatUserKnownRoomsAttribute];
		}

		[results release];
	}
}

- (void) _handle320WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISIDENTIFIED
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count == 3 ) {
		NSString *comment = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		if( [comment hasCaseInsensitiveSubstring:@"identified"] ) {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
			[user _setIdentified:YES];
		}
	}
}

#pragma mark -
#pragma mark Error Replies

- (void) _handle401WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NOSUCHNICK
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		[self _markUserAsOffline:user];

		//workaround for a freenode (hyperion) bug where the ircd doesnt reply with 318 (RPL_ENDOFWHOIS) in case of 401 (ERR_NOSUCHNICK): end the whois when receiving 401
		[user _setDateUpdated:[NSDate date]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserInformationUpdatedNotification object:user userInfo:nil];

		if( [_pendingWhoisUsers containsObject:user] ) {
			[_pendingWhoisUsers removeObject:user];
			[self _whoisNextScheduledUser];
		}

		//workaround for quakenet and undernet which don't send 440 (ERR_SERVICESDOWN) if they are
		if ( ( [[self server] hasCaseInsensitiveSubstring:@"quakenet"] && [[user nickname] isCaseInsensitiveEqualToString:@"Q@CServe.quakenet.org"] ) || ( [[self server] hasCaseInsensitiveSubstring:@"undernet"] && [[user nickname] isCaseInsensitiveEqualToString:@"X@channels.undernet.org"] ) ) {
			_pendingIdentificationAttempt = NO;

			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			[userInfo setObject:self forKey:@"connection"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Services down on \"%@\".", "services down error" ), [self server]] forKey:NSLocalizedDescriptionKey];

			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionServicesDownError userInfo:userInfo]];
		}

		/* TODO
		NSString *errorLiteralReason = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:self, @"connection", user, @"user", @"401", @"errorCode", errorLiteralReason, @"errorLiteralReason", nil];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"There is no user called \"%@\" on \"%@\".", "no such user error" ), user, [self server]] forKey:NSLocalizedDescriptionKey];
		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionNoSuchUserError userInfo:userInfo]];
		*/
	}
}

- (void) _handle402WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NOSUCHSERVER
	MVAssertCorrectThreadRequired( _connectionThread );

	// some servers send back 402 (No such server) when we send our double nickname WHOIS requests, treat as a user
	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:[parameters objectAtIndex:1]]];
		[self _markUserAsOffline:user];
		if( [_pendingWhoisUsers containsObject:user] ) {
			[_pendingWhoisUsers removeObject:user];
			[self _whoisNextScheduledUser];
		}
	}
	// TODO MVChatConnectionNoSuchServerError
}

/* TODO      _handle403    ERR_NOSUCHCHANNEL
 "<channel name> :No such channel"

 - Used to indicate the given channel name is invalid.

 MVChatConnectionNoSuchRoomError
*/

- (void) _handle404WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_CANNOTSENDTOCHAN
	MVAssertCorrectThreadRequired( _connectionThread );

	// "<channel name> :Cannot send to channel"
	// - Sent to a user who is either (a) not on a channel which is mode +n or (b) not a chanop (or mode +v) on a channel which has mode +m set or where the user is banned and is trying to send a PRIVMSG message to that channel.

	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:self forKey:@"connection"];
		[userInfo setObject:room forKey:@"room"];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Can't send to room \"%@\" on \"%@\".", "cant send to room error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantSendToRoomError userInfo:userInfo]];

	}
}

/* TODO      _handle405    ERR_TOOMANYCHANNELS
 "<channel name> :You have joined too many channels"

 - Sent to a user when they have joined the maximum
 number of allowed channels and they try to join
 another channel.

 */

- (void) _handle410WithParameters:(NSArray *) parameters fromSender:(id) sender { // "services down" (freenode/hyperion) or "Invalid CAP subcommand" (freenode/ircd-seven, not supported here)
	MVAssertCorrectThreadRequired( _connectionThread );

	// "No services can currently be detected" (same as 440, which is the "standard" numeric for this error)
	// - Send to us after trying to identify with /nickserv, ui should ask the user wether to go ahead with the autojoin without identification (= no host/ip cloaks)

	_pendingIdentificationAttempt = NO;

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:self forKey:@"connection"];
	[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Services down on \"%@\".", "services down error" ), [self server]] forKey:NSLocalizedDescriptionKey];

	[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionServicesDownError userInfo:userInfo]];
}

- (void) _handle421WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_UNKNOWNCOMMAND
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		NSString *command = [self _stringFromPossibleData:[parameters objectAtIndex:1]];
		if( [command isCaseInsensitiveEqualToString:@"NickServ"] ) {
			// the NickServ command isn't supported, this is an older server
			// lets send a private message to NickServ to identify
			if( [[self nicknamePassword] length] )
				[self sendRawMessageWithFormat:@"PRIVMSG NickServ :IDENTIFY %@", [self nicknamePassword]];
		}
	}
	// TODO MVChatConnectionUnknownCommandError
}

/* TODO      _handle431    ERR_NONICKNAMEGIVEN
 ":No nickname given"

 - Returned when a nickname parameter expected for a
 command and isn't found.*/

/* TODO      _handle432    ERR_ERRONEUSNICKNAME
 "<nick> :Erroneous nickname"

 - Returned after receiving a NICK message which contains
 characters which do not fall in the defined set.  See
 section 2.3.1 for details on valid nicknames.

 MVChatConnectionErroneusNicknameError
 */

- (void) _handle435WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BANONCHAN Bahamut (also ERR_SERVICECONFUSED on Unreal, not implemented here)
	MVAssertCorrectThreadRequired( _connectionThread );

	// "<current nickname> <new nickname> <channel name> :Cannot change nickname while banned on channel"
	// - Sent to a user who is changing their nick in a room where it is prohibited.

	if( parameters.count >= 3 ) {
		NSString *possibleRoom = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		if( [self joinedChatRoomWithUniqueIdentifier:possibleRoom] ) {
			NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
			[userInfo setObject:self forKey:@"connection"];
			[userInfo setObject:possibleRoom forKey:@"room"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname while in \"%@\" on \"%@\". Please leave the room and try again.", "cant change nick because of chatroom error" ), possibleRoom, [self server]] forKey:NSLocalizedDescriptionKey];

			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];

			[userInfo release];
		}
	}
}

- (void) _handle437WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BANNICKCHANGE Unreal (also ERR_UNAVAILRESOURCE in RFC2812, not implemented here)
	MVAssertCorrectThreadRequired( _connectionThread );

	// "<current nickname> <channel name> :Cannot change nickname while banned on channel or channel is moderated"
	// - Sent to a user who is changing their nick in a room where it is prohibited.

	if( parameters.count >= 2 ) {
		NSString *possibleRoom = [self _stringFromPossibleData:[parameters objectAtIndex:1]];
		if( [self joinedChatRoomWithUniqueIdentifier:possibleRoom] ) {
			NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
			[userInfo setObject:self forKey:@"connection"];
			[userInfo setObject:possibleRoom forKey:@"room"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname while in \"%@\" on \"%@\". Please leave the room and try again.", "cant change nick because of chatroom error" ), possibleRoom, [self server]] forKey:NSLocalizedDescriptionKey];

			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];

			[userInfo release];
		}
	}
}

- (void) _handle438WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NICKTOOFAST_IRCU
	MVAssertCorrectThreadRequired( _connectionThread );

	// "<current nickname> <new nickname|channel name> :Cannot change nick"
	// - Sent to a user who is either (a) changing their nickname to fast or (b) changing their nick in a room where it is prohibited.

	if( parameters.count >= 3 ) {
		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
		[userInfo setObject:self forKey:@"connection"];

		// workaround for freenode/hyperion where 438 means "banned in room, cant change nick"
		NSString *possibleRoom = [self _stringFromPossibleData:[parameters objectAtIndex:2]];
		if( [self joinedChatRoomWithUniqueIdentifier:possibleRoom] ) {
			[userInfo setObject:possibleRoom forKey:@"room"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname while in \"%@\" on \"%@\". Please leave the room and try again.", "cant change nick because of chatroom error" ), possibleRoom, [self server]] forKey:NSLocalizedDescriptionKey];
		} else [userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"You changed your nickname too fast on \"%@\", please wait and try again.", "cant change nick too fast error" ), [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];

		[userInfo release];
	}
}

- (void) _handle440WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SERVICESDOWN_BAHAMUT_UNREAL (also freenode/ircd-seven)
	MVAssertCorrectThreadRequired( _connectionThread );

	// "NickServ Services are currently down. Please try again later."
	// - Send to us after trying to identify with /nickserv, ui should ask the user wether to go ahead with the autojoin without identification (= no host/ip cloaks)

	_pendingIdentificationAttempt = NO;

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:self forKey:@"connection"];
	[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Services down on \"%@\".", "services down error" ), [self server]] forKey:NSLocalizedDescriptionKey];

	[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionServicesDownError userInfo:userInfo]];
}

- (void) _handle462WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_ALREADYREGISTERED (RFC1459)

	if ( [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) { // workaround for people that have their ustream pw in the server pass AND the nick pass field: use 462 as sign that identification took place
		_pendingIdentificationAttempt = NO;

		if( ![[self localUser] isIdentified] )
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Ustream", @"user", [self nickname], @"target", nil]];
		[[self localUser] _setIdentified:YES];
	}
}

- (void) _handle471WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_CHANNELISFULL
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:self forKey:@"connection"];
		[userInfo setObject:room forKey:@"room"];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" is full.", "room is full error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionRoomIsFullError userInfo:userInfo]];
	}
}

- (void) _handle473WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_INVITEONLYCHAN
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

		MVChatRoom *chatRoom = [self chatRoomWithUniqueIdentifier:room];
		[chatRoom _setMode:MVChatRoomInviteOnlyMode withAttribute:nil];

		[_pendingJoinRoomNames removeObject:room];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:self forKey:@"connection"];
		[userInfo setObject:room forKey:@"room"];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" is invite only.", "invite only room error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionInviteOnlyRoomError userInfo:userInfo]];
	}
}

- (void) _handle474WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BANNEDFROMCHAN
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

		[_pendingJoinRoomNames removeObject:room];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:self forKey:@"connection"];
		[userInfo setObject:room forKey:@"room"];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"You are banned from the room \"%@\" on \"%@\".", "banned from room error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionBannedFromRoomError userInfo:userInfo]];
	}
}

- (void) _handle475WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BADCHANNELKEY
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];

		MVChatRoom *chatRoom = [self chatRoomWithUniqueIdentifier:room];
		[chatRoom _setMode:MVChatRoomPassphraseToJoinMode withAttribute:nil];

		[_pendingJoinRoomNames removeObject:room];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:self forKey:@"connection"];
		[userInfo setObject:room forKey:@"room"];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" is password protected.", "room password protected error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionRoomPasswordIncorrectError userInfo:userInfo]];
	}
}

- (void) _handle477WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NOCHANMODES_RFC2812 or ERR_NEEDREGGEDNICK_BAHAMUT_IRCU_UNREAL
	MVAssertCorrectThreadRequired( _connectionThread );

	// I:	rfc 2812: "<channel> :Channel doesn't support modes"
	// II:	more common non standard room mode +R:
	// - Unreal3.2.7: "<channel> :You need a registered nick to join that channel."
	// - bahamut-1.8(04)/DALnet: <channel> :You need to identify to a registered nick to join that channel. For help with registering your nickname, type "/msg NickServ@services.dal.net help register" or see http://docs.dal.net/docs/nsemail.html

	if( parameters.count >= 3 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];
		NSString *errorLiteralReason = [self _stringFromPossibleData:[parameters objectAtIndex:2]];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:self, @"connection", room, @"room", @"477", @"errorCode", errorLiteralReason, @"errorLiteralReason", nil];
		if( [_pendingJoinRoomNames containsObject:room] ) { // (probably II)
			[_pendingJoinRoomNames removeObject:room];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"You need to identify with network services to join the room \"%@\" on \"%@\".", "identify to join room error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];
			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionIdentifyToJoinRoomError userInfo:userInfo]];
		} else if( ![[self server] hasCaseInsensitiveSubstring:@"freenode"] ) { // ignore on freenode until they stop randomly sending 477s when joining a room
			if( [errorLiteralReason hasCaseInsensitiveSubstring:@"modes"] ) { // (probably I)
				[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" does not support modes.", "room does not support modes error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionRoomDoesNotSupportModesError userInfo:userInfo]];
			} else { // (could be either)
				[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" encountered an unknown error, see server details for more information.", "room encountered unknown error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionUnknownError userInfo:userInfo]];
			}
		}
	}
}

/* for ticket #1303
- (void) _handleErrorWithParameters:(NSArray *) parameters fromSender:(id) sender { // ERROR message: http://tools.ietf.org/html/rfc2812#section-3.7.4
	MVAssertCorrectThreadRequired( _connectionThread );

	NSLog(@"ERROR parameter count: %d.", parameters.count);

	if( parameters.count == 1 ) {
		NSLog(@"0: %@", [self _stringFromPossibleData:[parameters objectAtIndex:0]]);
	}
}
*/

- (void) _handle506WithParameters:(NSArray *) parameters fromSender:(id) sender { // freenode/hyperion: identify with services to talk in this room
	MVAssertCorrectThreadRequired( _connectionThread );

	// "<channel> Please register with services and use the IDENTIFY command (/msg nickserv help) to speak in this channel"
	//  freenode/hyperion sends 506 if the user is not identified and tries to talk on a room with mode +R

	if( parameters.count == 3 ) {
		NSString *room = [self _stringFromPossibleData:[parameters objectAtIndex:1]];
		NSString *errorLiteralReason = [self _stringFromPossibleData:[parameters objectAtIndex:2]];

		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:5];
		[userInfo setObject:self forKey:@"connection"];
		[userInfo setObject:room forKey:@"room"];
		[userInfo setObject:@"506" forKey:@"errorCode"];
		[userInfo setObject:errorLiteralReason forKey:@"errorLiteralReason"];
		[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"Can't send to room \"%@\" on \"%@\".", "cant send to room error" ), room, [self server]] forKey:NSLocalizedDescriptionKey];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantSendToRoomError userInfo:userInfo]];

		[userInfo release];
	}
}

#pragma mark -
#pragma mark Watch Replies

- (void) _handle604WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NOWON_BAHAMUT_UNREAL
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 4 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setUsername:[parameters objectAtIndex:2]];
		[user _setAddress:[parameters objectAtIndex:3]];

		[self _markUserAsOnline:user];

//		if( [[user dateUpdated] timeIntervalSinceNow] < -JVWatchedUserWHOISDelay || ! [user dateUpdated] )
//			[self _scheduleWhoisForUser:user];
	}
}

- (void) _handle600WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_LOGON_BAHAMUT_UNREAL
	MVAssertCorrectThreadRequired( _connectionThread );

	if( parameters.count >= 4 )
		[self _handle604WithParameters:parameters fromSender:sender]; // do everything we do above
}

#pragma mark -
#pragma mark Watch Replies

- (void) _handle998WithParameters:(NSArray *) parameters fromSender:(id) sender { // undefined code, irc.umich.edu (efnet) uses this to show a captcha to users without identd (= us) which we have to reply to
	MVAssertCorrectThreadRequired( _connectionThread );

	if( ![self isConnected] && parameters.count == 2 ) {
		if( !_umichNoIdentdCaptcha ) _umichNoIdentdCaptcha = [[NSMutableArray alloc] init];

		NSMutableString *parameterString = [[self _stringFromPossibleData:[parameters objectAtIndex:1]] mutableCopy];
		[_umichNoIdentdCaptcha addObject:parameterString];
		[parameterString release];

		if( _umichNoIdentdCaptcha.count == 7 ) {
			NSDictionary *captchaAlphabet = [NSDictionary dictionaryWithObjectsAndKeys:
										  @"A", @"     /     /_    / /   / _   / /_   \\ \\_    \\ _     \\ \\     \\_      \\ ",
										  @"B", @" ||||| _    _ _ | |_ ______ _ ) )_  \\ < /   | |  ",
										  @"C", @"  |||   /   \\ _ |||_ __  __ __  __ __  __ __  __  |   | ",
										  @"D", @" ||||| _    _ _ |||_ __  __ __  __ _ |||_  \\   /   |||  ",
										  @"E", @" ||||| _    _ _ | |_ ______ ______ __ |__ __  __  |   | ",
										  @"F", @" ||||| _    _ _ | || ____   ____   __ |   __      |     ",
										  @"G", @"  |||   /   \\ _ |||_ __  __ __ |__ ____|_ ___  _  | ||| ",
										  @"H", @" ||||| _    _  || ||   __     __    || || _    _  ||||| ",
										  @"I", @" |   | __  __ _ |||_ _    _ _ |||_ __  __  |   | ",
										  @"J", @"    |     _ \\     |_     __     __  ||||_ _    /  ||||  ",
										  @"K", @" ||||| _    _  |' .|  / < \\ _ / \\_ _/   \\ ",
										  @"L", @" ||||| _    _  ||||_     __     __     __     __      | ",
										  @"M", @" ||||| _    _ _ \\|||  \\ \\    / /   _ /||| _    _  ||||| ",
										  @"N", @" ||||| _    _  \\ .||   \\ \\   ||` \\ _    _  ||||| ",
										  @"O", @"  |||   /   \\ _ |||_ __  __ __  __ _ |||_  \\   /   |||  ",
										  @"P", @" ||||| _    _ _ | || ____   ____   _ )_    \\ /     |    ",
										  @"Q", @"  |||   /   \\ _ |||_ __  __ __  __ _ |||\\  \\   _   |||\\ ",
										  @"R", @" ||||| _    _ _ | || ____   ___ \\  _ )  \\  \\ /\\_   |  \\ ",
										  @"S", @"  |  |  / \\__ _ (___ ______ ______ ___ )_ __ \\ /  |  |  ",
										  @"T", @" |     __     __     _ |||| _    _ _ |||| __     __      |     ",
										  @"U", @" ||||  _    \\  ||||_     __     __  ||||_ _    /  ||||  ",
										  @"V", @"_\\     _ \\     \\ \\     \\ \\     \\ \\    / /   / /   / /   _ /    _/     ",
										  @"W", @"_\\     _ \\     \\ \\     \\ \\     \\ \\    / /   / /    \\ \\     \\ \\    / /   / /   / /   _ /    _/     ",
										  @"X", @"_\\   / _ \\ /_  \\ > /   V .   / < \\ _ / \\_ _/   \\ ",
										  @"Y", @"_\\     _ \\     \\ \\     \\ ||   _  _   / ||  / /   _ /    _/     ",
										  @"Z", @" |   / __  /_ __ / _ __/ /_ _  /__ _ / __ _/   | ",
			nil];

			NSMutableString *testString = [NSMutableString string];
			NSMutableString *captchaReply = [NSMutableString string];
			BOOL empty = NO;
			while( !empty ) {
				for( NSMutableString *row in _umichNoIdentdCaptcha ) {
					[testString appendString:[row substringToIndex:1]];
					[row deleteCharactersInRange:NSMakeRange(0, 1)];
					if( !row.length ) empty = YES;
				}
				if( [captchaAlphabet objectForKey:testString] ) {
					[captchaReply appendString:[captchaAlphabet objectForKey:testString]];
					testString = [NSMutableString string];
				}
			}
			[self sendRawMessageImmediatelyWithFormat:@"PONG :%@", captchaReply];

			[_umichNoIdentdCaptcha release];
			_umichNoIdentdCaptcha = nil;
		}
	}
}
@end
