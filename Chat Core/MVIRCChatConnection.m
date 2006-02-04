#import <sched.h>

#import "MVIRCChatConnection.h"
#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCFileTransfer.h"
#import "MVIRCNumerics.h"

#import "AsyncSocket.h"
#import "InterThreadMessaging.h"
#import "MVChatPluginManager.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "NSDataAdditions.h"

static const NSStringEncoding supportedEncodings[] = {
	/* Universal */
	NSUTF8StringEncoding,
	NSNonLossyASCIIStringEncoding,
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
	/* Japanese */
	(NSStringEncoding) 0x80000A01,		// ShiftJIS
	NSISO2022JPStringEncoding,			// ISO-2022-JP
	NSJapaneseEUCStringEncoding,		// EUC
	(NSStringEncoding) 0x80000001,		// Mac
	NSShiftJISStringEncoding,			// Windows
	/* Simplified Chinese */
	(NSStringEncoding) 0x80000632,		// GB 18030
	(NSStringEncoding) 0x80000631,		// GBK
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
	/* Hebrew */
	(NSStringEncoding) 0x80000208,		// ISO-8859-8
	(NSStringEncoding) 0x80000005,		// Mac
	(NSStringEncoding) 0x80000505,		// Windows
	0
};

/*
static void MVChatGotUserMode( CHANNEL_REC *channel, NICK_REC *nick, char *by, char *mode, char *type ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick -> nick]];
	MVChatUser *byMember = ( by ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:by]] : nil );

	unsigned int m = MVChatRoomMemberNoModes;
	if( *mode == '@' ) m = MVChatRoomMemberOperatorMode;
	else if( *mode == '%' ) m = MVChatRoomMemberHalfOperatorMode;
	else if( *mode == '+' ) m = MVChatRoomMemberVoicedMode;

	if( m == MVChatRoomMemberNoModes ) return;

	if( *type == '+' ) [room _setMode:m forMemberUser:member];
	else [room _removeMode:m forMemberUser:member];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:( *type == '+' ? YES : NO )], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", byMember, @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatGotRoomMode( CHANNEL_REC *channel, const char *setby ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *byMember = ( setby ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:setby]] : nil );

	unsigned int oldModes = [room modes];

	[room _clearModes];

	if( strchr( channel -> mode, 'p' ) )
		[room _setMode:MVChatRoomPrivateMode withAttribute:nil];

	if( strchr( channel -> mode, 's' ) )
		[room _setMode:MVChatRoomSecretMode withAttribute:nil];

	if( strchr( channel -> mode, 'i' ) )
		[room _setMode:MVChatRoomInviteOnlyMode withAttribute:nil];

	if( strchr( channel -> mode, 'm' ) )
		[room _setMode:MVChatRoomNormalUsersSilencedMode withAttribute:nil];

	if( strchr( channel -> mode, 'n' ) )
		[room _setMode:MVChatRoomNoOutsideMessagesMode withAttribute:nil];

	if( strchr( channel -> mode, 't' ) )
		[room _setMode:MVChatRoomOperatorsOnlySetTopicMode withAttribute:nil];

	if( strchr( channel -> mode, 'k' ) )
		[room _setMode:MVChatRoomPassphraseToJoinMode withAttribute:[self stringWithEncodedBytes:channel -> key]];

	if( strchr( channel -> mode, 'l' ) )
		[room _setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:[NSNumber numberWithInt:channel -> limit]];

	unsigned int changedModes = ( oldModes ^ [room modes] );

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomModesChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:changedModes], @"changedModes", byMember, @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatBanNew( CHANNEL_REC *channel, BAN_REC *ban ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self || ! ban || ! ban -> ban ) return;

	NSString *banString = [self stringWithEncodedBytes:ban -> ban];
	NSArray *parts = [banString componentsSeparatedByString:@"!"];
	NSString *nickname = ( [parts count] >= 1 ? [parts objectAtIndex:0] : nil );
	NSString *host = ( [parts count] >= 2 ? [parts objectAtIndex:1] : nil );
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:nickname andHostMask:host];

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *byMember = ( ban -> setby ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:ban -> setby]] : nil );

	[room _addBanForUser:user];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserBannedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", byMember, @"byUser", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBanRemove( CHANNEL_REC *channel, BAN_REC *ban, const char *who ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self || ! ban || ! ban -> ban ) return;

	NSString *banString = [self stringWithEncodedBytes:ban -> ban];
	NSArray *parts = [banString componentsSeparatedByString:@"!"];
	NSString *nickname = ( [parts count] >= 1 ? [parts objectAtIndex:0] : nil );
	NSString *host = ( [parts count] >= 2 ? [parts objectAtIndex:1] : nil );
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:nickname andHostMask:host];

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *byMember = ( who ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:who]] : nil );

	[room _removeBanForUser:user];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserBanRemovedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", byMember, @"byUser", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBanListFinished( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel]];
	g_free( params );

	if( ! room ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomBannedUsersSyncedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatBuddyOnline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setRealName:[self stringWithEncodedBytes:realname]];
	[user _setUsername:[self stringWithEncodedBytes:username]];
	[user _setAddress:[self stringWithEncodedBytes:host]];
	if( [user status] != MVChatUserAwayStatus ) [user _setStatus:MVChatUserAvailableStatus];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionWatchedUserOnlineNotification object:user userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyOffline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setStatus:MVChatUserOfflineStatus];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionWatchedUserOfflineNotification object:user userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyAway( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

//	NSNotification *note = nil;
//	if( awaymsg ) note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:awaymsg], @"msg", nil]];
//	else note = [NSNotification notificationWithName:MVChatConnectionBuddyIsUnawayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyUnidle( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

//	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [NSNumber numberWithLong:0], @"idle", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatListRoom( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL, *count = NULL, *topic = NULL;
	char *params = event_get_params( data, 4 | PARAM_FLAG_GETREST, NULL, &channel, &count, &topic );

	NSString *r = [self stringWithEncodedBytes:channel];
	NSData *t = [[NSData allocWithZone:nil] initWithBytes:topic length:strlen( topic )];
	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:strtoul( count, NULL, 10 )], @"users", t, @"topic", [NSDate date], @"cached", r, @"room", nil];

	[self performSelectorOnMainThread:@selector( _addRoomToCache: ) withObject:info waitUntilDone:NO];

	[info release];
	[t release];
	g_free( params );
}

#pragma mark -

static void MVChatErrorNoSuchUser( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	g_return_if_fail( data != NULL );

	char *nick = NULL;
	char *params = event_get_params( data, 2, NULL, &nick );

	[self _processErrorCode:ERR_NOSUCHNICK withContext:nick];

	g_free( params );
}

static void MVChatErrorUnknownCommand( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	g_return_if_fail( data != NULL );

	char *command = NULL;
	char *params = event_get_params( data, 2, NULL, &command );

	[self _processErrorCode:ERR_UNKNOWNCOMMAND withContext:command];

	g_free( params );
}

#pragma mark - */

@implementation MVIRCChatConnection
+ (NSArray *) defaultServerPorts {
	return [NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:6667],[NSNumber numberWithUnsignedShort:6660],[NSNumber numberWithUnsignedShort:6669],[NSNumber numberWithUnsignedShort:7000],[NSNumber numberWithUnsignedShort:994], nil];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_chatConnection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

		_serverPort = 6667;
		_server = @"irc.freenode.net";
		_username = [NSUserName() retain];
		_nickname = [_username retain];
		_currentNickname = [_nickname retain];
		_realName = [NSFullUserName() retain];

		_knownUsers = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:200];
		_fileTransfers = [[NSMutableSet allocWithZone:nil] initWithCapacity:5];
	}

	return self;
}

- (void) dealloc {
	[self disconnect];

	[_chatConnection setDelegate:nil];

	[_chatConnection release];
	[_knownUsers release];
	[_fileTransfers release];
	[_server release];
	[_currentNickname release];
	[_nickname release];
	[_username release];
	[_password release];
	[_realName release];
	[_proxyServer release];
	[_proxyUsername release];
	[_proxyPassword release];

	_chatConnection = nil;
	_connectionThread = nil;
	_knownUsers = nil;
	_fileTransfers = nil;
	_server = nil;
	_currentNickname = nil;
	_nickname = nil;
	_username = nil;
	_password = nil;
	_realName = nil;
	_proxyServer = nil;
	_proxyUsername = nil;
	_proxyPassword = nil;

	[super dealloc];
}

#pragma mark -

- (NSString *) urlScheme {
	return @"irc";
}

- (MVChatConnectionType) type {
	return MVChatConnectionIRCType;
}

- (NSSet *) supportedFeatures {
	return nil;
}

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

#pragma mark -

- (void) connect {
	if( [self status] != MVChatConnectionDisconnectedStatus && [self status] != MVChatConnectionServerDisconnectedStatus && [self status] != MVChatConnectionSuspendedStatus ) return;

	if( _lastConnectAttempt && ABS( [_lastConnectAttempt timeIntervalSinceNow] ) < 5. ) {
		// prevents connecting too quick
		// cancel any reconnect attempts, this lets a user cancel the attempts with a "double connect"
		[self cancelPendingReconnectAttempts];
		return;
	}

	[_lastConnectAttempt release];
	_lastConnectAttempt = [[NSDate allocWithZone:nil] init];

	[self _willConnect]; // call early so other code has a chance to change our info

	if( ! _connectionThread ) {
		[NSThread prepareForInterThreadMessages];
		[NSThread detachNewThreadSelector:@selector( _ircRunloop ) toTarget:self withObject:nil];
		while( ! _connectionThread ) sched_yield();
	}

	[self performSelector:@selector( _connect ) inThread:_connectionThread];

/*
// Setup the proxy header with the most current connection address and port.
	if( _proxy == MVChatConnectionHTTPSProxy || _proxy == MVChatConnectionHTTPProxy ) {
		NSString *userCombo = [NSString stringWithFormat:@"%@:%@", _proxyUsername, _proxyPassword];
		NSData *combo = [userCombo dataUsingEncoding:NSASCIIStringEncoding];

		g_free_not_null( _chatConnectionSettings -> proxy_string );
		if( [combo length] > 1 ) {
			NSString *userCombo = [combo base64EncodingWithLineLength:0];
			_chatConnectionSettings -> proxy_string = g_strdup_printf( "CONNECT %s:%d HTTP/1.0\r\nProxy-Authorization: Basic %s\r\n\r\n", _chatConnectionSettings -> address, _chatConnectionSettings -> port, [userCombo UTF8String] );
		} else _chatConnectionSettings -> proxy_string = g_strdup_printf( "CONNECT %s:%d HTTP/1.0\r\n\r\n", _chatConnectionSettings -> address, _chatConnectionSettings -> port );

		g_free_not_null( _chatConnectionSettings -> proxy_string_after );
		_chatConnectionSettings -> proxy_string_after = NULL;
	}
*/
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
	[self cancelPendingReconnectAttempts];

	if( [self status] == MVChatConnectionConnectedStatus ) {
		if( [[reason string] length] ) {
			NSData *msg = [[self class] _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
			[self sendRawMessageWithComponents:@"QUIT :", msg, nil];
		} else [self sendRawMessage:@"QUIT"];
	}

	_status = MVChatConnectionDisconnectedStatus;
	[_chatConnection performSelector:@selector( disconnectAfterWriting ) inThread:_connectionThread];
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	NSParameterAssert( name != nil );

	id old = _realName;
	_realName = [name copyWithZone:nil];
	[old release];
}

- (NSString *) realName {
	return [[_realName retain] autorelease];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	NSParameterAssert( nickname != nil );
	NSParameterAssert( [nickname length] > 0 );

	if( [nickname isEqualToString:[self nickname]] )
		return;

	id old = _nickname;
	_nickname = [nickname copyWithZone:nil];
	[old release];

	if( ! _currentNickname || ! [self isConnected] ) {
		id old = _currentNickname;
		_currentNickname = [_nickname retain];
		[old release];
	}

	if( [self isConnected] )
		[self sendRawMessageWithFormat:@"NICK %@", nickname];
}

- (NSString *) nickname {
	return [[_currentNickname retain] autorelease];
}

- (NSString *) preferredNickname {
	return [[_nickname retain] autorelease];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
	if( ! [[self localUser] isIdentified] && password && [self isConnected] )
		[self sendRawMessageWithFormat:@"NickServ IDENTIFY %@", password];
	[super setNicknamePassword:password];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	id old = _password;
	_password = [password copyWithZone:nil];
	[old release];
}

- (NSString *) password {
	return [[_password retain] autorelease];
}

#pragma mark -

- (void) setUsername:(NSString *) username {
	NSParameterAssert( username != nil );
	NSParameterAssert( [username length] > 0 );

	id old = _username;
	_username = [username copyWithZone:nil];
	[old release];
}

- (NSString *) username {
	return [[_username retain] autorelease];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	NSParameterAssert( server != nil );
	NSParameterAssert( [server length] > 0 );

	id old = _server;
	_server = [server copyWithZone:nil];
	[old release];
}

- (NSString *) server {
	return [[_server retain] autorelease];
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	_serverPort = ( port ? port : 6667 );
}

- (unsigned short) serverPort {
	return _serverPort;
}

#pragma mark -

- (void) setSecure:(BOOL) ssl {
	_secure = ssl;
}

- (BOOL) isSecure {
	return _secure;
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

- (void) setProxyUsername:(NSString *) username {
	id old = _proxyUsername;
	_proxyUsername = [username copyWithZone:nil];
	[old release];
}

- (NSString *) proxyUsername {
	return [[_proxyUsername retain] autorelease];
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
	id old = _proxyPassword;
	_proxyPassword = [password copyWithZone:nil];
	[old release];
}

- (NSString *) proxyPassword {
	return [[_proxyPassword retain] autorelease];
}

#pragma mark -

- (void) sendRawMessage:(id) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );
	NSParameterAssert( [raw isKindOfClass:[NSData class]] || [raw isKindOfClass:[NSString class]] );

	NSMutableData *data = nil;
	NSString *string = nil;

	if( [raw isKindOfClass:[NSMutableData class]] ) {
		data = [raw retain];
		string = [[NSString allocWithZone:nil] initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSData class]] ) {
		data = [raw mutableCopyWithZone:nil];
		string = [[NSString allocWithZone:nil] initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSString class]] ) {
		data = [[raw dataUsingEncoding:[self encoding] allowLossyConversion:YES] mutableCopyWithZone:nil];
		string = [raw retain];
	}

	// IRC messages are always lines of characters terminated with a CR-LF
	// (Carriage Return - Line Feed) pair, and these messages SHALL NOT
	// exceed 512 characters in length, counting all characters including
	// the trailing CR-LF. Thus, there are 510 characters maximum allowed
	// for the command and its parameters.

	if( [data length] > 510 ) [data setLength:510];
	[data appendBytes:"\x0D\x0A" length:2];

	[self performSelector:@selector( _writeDataToServer: ) withObject:data inThread:_connectionThread];

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:string, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];

	[string release];
	[data release];
}

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! [rooms count] ) return;

	NSMutableArray *roomList = [[NSMutableArray allocWithZone:nil] initWithCapacity:[rooms count]];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) ) {
		if( [room length] && [room rangeOfString:@" "].location == NSNotFound ) { // join non-password room in bulk
			[roomList addObject:[self properNameForChatRoomNamed:room]];
		} else if( [room length] && [room rangeOfString:@" "].location != NSNotFound ) { // has a password, join separately
			// join all requested rooms before this one so we do things in order
			if( [roomList count] ) [self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
			[self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
			[roomList removeAllObjects]; // clear list since we joined them
		}
	}

	if( [roomList count] ) [self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
	[roomList release];
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	if( [passphrase length] ) [self sendRawMessageWithFormat:@"JOIN %@ %@", [self properNameForChatRoomNamed:room], passphrase];
	else [self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	static NSCharacterSet *prefixes = nil;
	if( ! prefixes ) prefixes = [[NSCharacterSet characterSetWithCharactersInString:@"#&+!"] retain];
	return prefixes;
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	if( ! [room length] ) return room;
	return ( [[self chatRoomNamePrefixes] characterIsMember:[room characterAtIndex:0]] ? room : [@"#" stringByAppendingString:room] );
}

#pragma mark -

- (NSSet *) knownChatUsers {
	@synchronized( _knownUsers ) {
		return [NSSet setWithArray:[_knownUsers allValues]];
	}
}

- (NSSet *) chatUsersWithNickname:(NSString *) nickname {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:nickname]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );

	NSString *uniqueIdentfier = [identifier lowercaseString];
	if( [uniqueIdentfier isEqualToString:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:uniqueIdentfier];
		if( user ) return [[user retain] autorelease];

		user = [[MVIRCChatUser allocWithZone:nil] initWithNickname:identifier andConnection:self];
		if( user ) [_knownUsers setObject:user forKey:uniqueIdentfier];
	}

	return [user autorelease];
}

#pragma mark -

- (void) startWatchingUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [[user nickname] length] > 0 );

}

- (void) stopWatchingUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [[user nickname] length] > 0 );

}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 300. ) {
		[self sendRawMessage:@"LIST"];
		[_cachedDate release];
		_cachedDate = [[NSDate allocWithZone:nil] init];
	}
}

- (void) stopFetchingChatRoomList {
	if( _cachedDate && ABS( [_cachedDate timeIntervalSinceNow] ) < 600. )
		[self sendRawMessage:@"LIST STOP"];
}

#pragma mark -

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	[_awayMessage release];
	_awayMessage = nil;

	if( [[message string] length] ) {
		[[self localUser] _setStatus:MVChatUserAwayStatus];

		_awayMessage = [message copyWithZone:nil];

		NSData *msg = [[self class] _flattenedIRCDataForMessage:message withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
		[self sendRawMessageWithComponents:@"AWAY :", msg, nil];
	} else {
		[[self localUser] _setStatus:MVChatUserAvailableStatus];
		[self sendRawMessage:@"AWAY"];
	}
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionPrivate)
- (AsyncSocket *) _chatConnection {
	return _chatConnection;
}

- (void) _connect {
	[_chatConnection disconnect];
	if( ! [_chatConnection connectToHost:[self server] onPort:[self serverPort] error:NULL] )
		[self _didNotConnect];
}

- (oneway void) _ircRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];

	_connectionThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];

	BOOL active = YES;
	while( active && ( _status == MVChatConnectionConnectedStatus || _status == MVChatConnectionConnectingStatus ) )
		active = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

	if( [NSThread currentThread] == _connectionThread )
		_connectionThread = nil;

	[pool release];
}

- (void) _didDisconnect {
	if( ABS( [_lastConnectAttempt timeIntervalSinceNow] ) > 300. )
		[self performSelector:@selector( connect ) withObject:nil afterDelay:5.];
	[self scheduleReconnectAttemptEvery:30.];
	[super _didDisconnect];
}

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"willDisconnectWithError: %@", error );
	_status = MVChatConnectionServerDisconnectedStatus;
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	id old = _localUser;
	_localUser = nil;
	[old release];

	[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:NO];
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	if( [[self password] length] ) [self sendRawMessageWithFormat:@"PASS %@", [self password]];
	[self sendRawMessageWithFormat:@"NICK %@", [self nickname]];
	[self sendRawMessageWithFormat:@"USER %@ %@ %@ :%@", [self username], [[NSHost currentHost] name], [self server], [self realName]];

	id old = _localUser;
	_localUser = [[MVIRCChatUser allocWithZone:nil] initLocalUserWithConnection:self];
	[old release];

	[self _readNextMessageFromServer];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	NSString *rawString = [[NSString allocWithZone:nil] initWithData:data encoding:[self encoding]];
	const char *line = (const char *)[data bytes];
	unsigned int len = [data length];
	const char *end = line + len - 2; // minus the line endings

	const char *sender = NULL;
	unsigned senderLength = 0;
	const char *user = NULL;
	unsigned userLength = 0;
	const char *host = NULL;
	unsigned hostLength = 0;
	const char *command = NULL;
	unsigned commandLength = 0;

	NSMutableArray *parameters = [[NSMutableArray allocWithZone:nil] initWithCapacity:15];

	// Parsing as defined in 2.3.1 at http://www.irchelp.org/irchelp/rfc/rfc2812.txt

	if( len <= 2 || len > 512 )
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
				userLength = (line - host);
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
				param = [[NSString allocWithZone:nil] initWithBytes:currentParameter length:(line - currentParameter) encoding:[self encoding]];
				checkAndMarkIfDone();
				if( ! done ) line++;
			}

			if( param ) [parameters addObject:param];
			[param release];

			consumeWhitespace();
		}
	}

#undef checkAndMarkIfDone()
#undef consumeWhitespace()
#undef notEndOfLine()

end:
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:rawString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];

	if( command && commandLength ) {
		NSString *commandString = [[NSString allocWithZone:nil] initWithBytes:command length:commandLength encoding:[self encoding]];
		NSString *selectorString = [[NSString allocWithZone:nil] initWithFormat:@"_handle%@WithParameters:fromSender:", [commandString capitalizedString]];
		SEL selector = NSSelectorFromString( selectorString );
		[selectorString release];
		[commandString release];

		if( [self respondsToSelector:selector] ) {
			NSString *senderString = nil;
			if( sender ) senderString = [[NSString allocWithZone:nil] initWithBytes:sender length:senderLength encoding:[self encoding]];

			MVChatUser *chatUser = nil;
			if( user && userLength ) {
				chatUser = [self chatUserWithUniqueIdentifier:senderString];
				if( ! [chatUser address] && host && hostLength ) {
					NSString *hostString = [[NSString allocWithZone:nil] initWithBytes:host length:hostLength encoding:[self encoding]];
					[chatUser _setAddress:hostString];
					[hostString release];
				}

				if( ! [chatUser username] ) {
					NSString *userString = [[NSString allocWithZone:nil] initWithBytes:user length:userLength encoding:[self encoding]];
					[chatUser _setUsername:userString];
					[userString release];
				}
			}

			[self performSelector:selector withObject:parameters withObject:( chatUser ? (id) chatUser : (id) senderString )];
			[senderString release];
		}
	}

	[rawString release];
	[parameters release];

	[self _readNextMessageFromServer];
}

- (void) _writeDataToServer:(NSData *) data {
	[_chatConnection writeData:data withTimeout:-1. tag:0];
}

- (void) _readNextMessageFromServer {
	static NSData *delimeter = nil;
	if( ! delimeter ) delimeter = [[NSData allocWithZone:nil] initWithBytes:"\x0D\x0A" length:2];
	[_chatConnection readDataToData:delimeter withTimeout:-1. tag:0];
}

+ (NSData *) _flattenedIRCDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format {
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
/*

#pragma mark -

- (void) _processErrorCode:(int) errorCode withContext:(char *) context {
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

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname {
	@synchronized( _knownUsers ) {
		[user retain];
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:[nickname lowercaseString]];
		[user _setNickname:nickname];
		[_knownUsers setObject:user forKey:[user uniqueIdentifier]];
		[user release];
	}
}

- (void) _sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action {
	NSData *msg = [[self class] _flattenedIRCDataForMessage:message withEncoding:encoding andChatFormat:[self outgoingChatFormat]];
	if( action ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@ :\001ACTION ", target];
		[self sendRawMessageWithComponents:prefix, msg, @"\001", nil];
		[prefix release];
	} else {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@ :", target];
		[self sendRawMessageWithComponents:prefix, msg, nil];
		[prefix release];
	}
}

- (void) _addFileTransfer:(MVFileTransfer *) transfer {
	@synchronized( _fileTransfers ) {
		if( transfer ) [_fileTransfers addObject:transfer];
	}
}

- (void) _removeFileTransfer:(MVFileTransfer *) transfer {
	@synchronized( _fileTransfers ) {
		if( transfer ) [_fileTransfers removeObject:transfer];
	}
}

- (void) _setCurrentNickname:(NSString *) nickname {
	id old = _currentNickname;
	_currentNickname = [nickname copyWithZone:nil];
	[old release];
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionProtocolHandlers)

#pragma mark Connecting Replies

- (void) _handle001WithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:NO];	
	// Identify if we have a user password
	if( [[self nicknamePassword] length] )
		[self sendRawMessageWithFormat:@"NickServ IDENTIFY %@", [self nicknamePassword]];
	if( [parameters count] >= 1 ) {
		NSString *nickname = [parameters objectAtIndex:0];
		if( ! [nickname isEqualToString:[self nickname]] ) {
			[self _setCurrentNickname:nickname];
			[[self localUser] _setUniqueIdentifier:[nickname lowercaseString]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:nil];
		}
	}
}

- (void) _handle433WithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender { // ERR_NICKNAMEINUSE
	if( ! [self isConnected] ) {
		NSString *nick = [self nextAlternateNickname];
		if( ! [nick length] ) nick = [[self nickname] stringByAppendingString:@"_"];
		if( [nick length] ) [self sendRawMessage:[NSString stringWithFormat:@"NICK %@", nick] immediately:YES];
	}
}

#pragma mark -
#pragma mark Incoming Message Replies

- (void) _handlePrivmsgWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( [parameters count] == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( ! [targetName length] ) return;

		if( [targetName characterAtIndex:0] == '@' ) {
			// This is a special filtered target.
			// @#room	sends only to the operators on the room
			// @%#room	sends to the operators and half-operators on the room
			// @+#room	sends to the operators and half-operators and voices on the room
			BOOL subFilter = [targetName length] >= 2 && ( [targetName characterAtIndex:1] == '%' || [targetName characterAtIndex:1] == '+' ); 
			targetName = [targetName substringFromIndex:( subFilter ? 2 : 1 )];
			if( ! [targetName length] ) return;
		}

		NSMutableData *msgData = [parameters objectAtIndex:1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && [msgData length] > 2 );

		if( [sender status] != MVChatUserAwayStatus ) [sender _setStatus:MVChatUserAvailableStatus];
		[sender _setIdleTime:0.];

		if( [[self chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]] ) {
			MVChatRoom *room = [self joinedChatRoomWithName:targetName];
			if( ctcp ) [self _handleCTCP:msgData asRequest:YES fromSender:sender forRoom:room];
			else [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", msgData, @"message", [NSString locallyUniqueString], @"identifier", nil]];
		} else {
			if( ctcp ) [self _handleCTCP:msgData asRequest:YES fromSender:sender forRoom:nil];
			else [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", [NSString locallyUniqueString], @"identifier", nil]];
		}
	}
}

- (void) _handleNoticeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( [parameters count] == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( ! [targetName length] ) return;

		if( [targetName characterAtIndex:0] == '@' ) {
			// This is a special filtered target.
			// @#room	sends only to the operators on the room
			// @%#room	sends to the operators and half-operators on the room
			// @+#room	sends to the operators and half-operators and voices on the room
			BOOL subFilter = [targetName length] >= 2 && ( [targetName characterAtIndex:1] == '%' || [targetName characterAtIndex:1] == '+' ); 
			targetName = [targetName substringFromIndex:( subFilter ? 2 : 1 )];
			if( ! [targetName length] ) return;
		}

		NSMutableData *msgData = [parameters objectAtIndex:1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && [msgData length] > 2 );

		if( [[self chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]] ) {
			MVChatRoom *room = [self joinedChatRoomWithName:targetName];
			if( ctcp ) [self _handleCTCP:msgData asRequest:NO fromSender:sender forRoom:room];
			else [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", msgData, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"notice", nil]];
		} else {
			if( ctcp ) [self _handleCTCP:msgData asRequest:NO fromSender:sender forRoom:nil];
			else {
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"notice", nil]];
				if( [[sender nickname] isEqualToString:@"NickServ"] ) {
					NSString *msg = [[NSString allocWithZone:nil] initWithData:msgData encoding:[self encoding]];
					if( [msg rangeOfString:@"NickServ"].location != NSNotFound && [msg rangeOfString:@"IDENTIFY"].location != NSNotFound ) {
						if( ! [self nicknamePassword] ) {
							[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
						} else [self sendRawMessageWithFormat:@"NickServ IDENTIFY %@", [self nicknamePassword]];
					} else if( [msg rangeOfString:@"Password accepted"].location != NSNotFound ) {
						[[self localUser] _setIdentified:YES];
					} else if( [msg rangeOfString:@"authentication required"].location != NSNotFound ) {
						[[self localUser] _setIdentified:NO];
					}
					[msg release];
				}
			}
		}
	}
}

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender forRoom:(MVChatRoom *) room {
	const char *line = (const char *)[data bytes] + 1; // skip the \001 char
	const char *end = line + [data length] - 2; // minus the first and last \001 char
	const char *current = line;

	while( line != end && *line != ' ' ) line++;
	NSString *command = [[NSString allocWithZone:nil] initWithBytes:current length:(line - current) encoding:[self encoding]];
	NSMutableData *arguments = nil;
	if( line != end ) arguments = [[NSMutableData allocWithZone:nil] initWithBytes:++line length:(end - line)];

	if( [command caseInsensitiveCompare:@"ACTION"] == NSOrderedSame && arguments ) {
		// special case ACTION and send it out like a message with the action flag
		if( room ) [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", arguments, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"action", nil]];
		else [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:arguments, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"action", nil]];
		[command release];
		[arguments release];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:( request ? MVChatConnectionSubcodeRequestNotification : MVChatConnectionSubcodeReplyNotification ) object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:command, @"command", arguments, @"arguments", nil]];

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

	if( request ) {
		if( [command caseInsensitiveCompare:@"VERSION"] == NSOrderedSame ) {
			NSDictionary *systemVersion = [[NSDictionary allocWithZone:nil] initWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
			if( ! [systemVersion count] ) systemVersion = [[NSDictionary allocWithZone:nil] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
			NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];

#if __ppc__
			NSString *processor = @"PowerPC";
#elif __i386__
			NSString *processor = @"Intel";
#else
			NSString *processor = @"Unknown Architecture";
#endif

			NSString *reply = [[NSString allocWithZone:nil] initWithFormat:@"%@ %@ (%@) - %@ %@ (%@) - %@", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [clientVersion objectForKey:@"CFBundleVersion"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductUserVisibleVersion"], processor, [clientVersion objectForKey:@"MVChatCoreCTCPVersionReplyInfo"]];
			[sender sendSubcodeReply:command withArguments:reply];

			[reply release];
			[systemVersion release];
		} else if( [command caseInsensitiveCompare:@"TIME"] == NSOrderedSame ) {
			[sender sendSubcodeReply:command withArguments:[[NSDate date] description]];
		} else if( [command caseInsensitiveCompare:@"PING"] == NSOrderedSame ) {
			// only reply with packets less than 100 bytes, anything over that is bad karma
			if( [arguments length] < 100 ) [sender sendSubcodeReply:command withArguments:arguments];
		} else if( [command caseInsensitiveCompare:@"DCC"] == NSOrderedSame ) {
			NSString *msg = [[NSString allocWithZone:nil] initWithData:arguments encoding:[self encoding]];
			NSArray *parameters = [msg componentsSeparatedByString:@" "];

			if( [parameters count] >= 5 && [[parameters objectAtIndex:0] caseInsensitiveCompare:@"SEND"] == NSOrderedSame ) {
				long long size = 0;
				unsigned int port = [[parameters objectAtIndex:3] intValue];
				NSScanner *scanner = [NSScanner scannerWithString:[parameters objectAtIndex:4]];
				[scanner scanLongLong:&size];

				NSString *address = [parameters objectAtIndex:2];
				if( [address rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@".:"]].location == NSNotFound ) {
					unsigned int ip4 = [address intValue];
					address = [NSString stringWithFormat:@"%lu.%lu.%lu.%lu", (ip4 & 0xff000000) >> 24, (ip4 & 0x00ff0000) >> 16, (ip4 & 0x0000ff00) >> 8, (ip4 & 0x000000ff)];
				}

				NSHost *host = [NSHost hostWithAddress:address];

				if( port > 0 && [parameters count] >= 6 && [[parameters objectAtIndex:5] rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound ) {
					// this is a passive reply, look up the original transfer
					MVIRCUploadFileTransfer *transfer = nil;
					unsigned long passiveId = [[parameters objectAtIndex:5] intValue];

					@synchronized( _fileTransfers ) {
						NSEnumerator *enumerator = [_fileTransfers objectEnumerator];
						while( ( transfer = [enumerator nextObject] ) )
							if( [transfer isUpload] && [transfer isPassive] && [[transfer user] isEqualToChatUser:sender] && [(id)transfer _passiveIdentifier] == passiveId )
								break;
					}

					if( transfer ) {
						[transfer _setHost:host];
						[transfer _setPort:port];
						[transfer _setupAndStart];
					}
				} else {
					MVIRCDownloadFileTransfer *transfer = [(MVIRCDownloadFileTransfer *)[MVIRCDownloadFileTransfer allocWithZone:nil] initWithUser:sender];
					if( port == 0 && [parameters count] >= 6 ) {
						BOOL turbo = ( [[parameters objectAtIndex:5] rangeOfString:@"T"].location != NSNotFound );
						[transfer _setTurbo:turbo];
						[transfer _setPassiveIdentifier:[[parameters objectAtIndex:5] intValue]];
						[transfer _setPassive:YES];
					} else if( [parameters count] >= 6 ) {
						[transfer _setTurbo:[[parameters objectAtIndex:5] isEqualToString:@"T"]];
					}

					[transfer _setOriginalFileName:[parameters objectAtIndex:1]];
					[transfer _setFinalSize:(unsigned long long)size];
					[transfer _setHost:host];
					[transfer _setPort:port];

					[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDownloadFileTransferOfferNotification object:transfer];

					[self _addFileTransfer:transfer];
					[transfer release];
				}
			} else if( [parameters count] >= 4 && [[parameters objectAtIndex:0] caseInsensitiveCompare:@"ACCEPT"] == NSOrderedSame ) {
				BOOL passive = NO;
				long long size = 0;
				unsigned int port = [[parameters objectAtIndex:2] intValue];
				NSScanner *scanner = [NSScanner scannerWithString:[parameters objectAtIndex:3]];
				[scanner scanLongLong:&size];

				if( [parameters count] >= 5 ) {
					passive = YES;
					port = [[parameters objectAtIndex:4] intValue];
				}

				@synchronized( _fileTransfers ) {
					NSEnumerator *enumerator = [_fileTransfers objectEnumerator];
					MVFileTransfer *transfer = nil;
					while( ( transfer = [enumerator nextObject] ) ) {
						if( [transfer isDownload] && [transfer isPassive] == passive && [[transfer user] isEqualToChatUser:sender] &&
							( ! passive ? [transfer port] == port : [(id)transfer _passiveIdentifier] == port ) ) {
							[transfer _setTransfered:(unsigned long long)size];
							[transfer _setStartOffset:(unsigned long long)size];
							[(MVIRCDownloadFileTransfer *)transfer _setupAndStart];
						}
					}
				}
			} else if( [parameters count] >= 4 && [[parameters objectAtIndex:0] caseInsensitiveCompare:@"RESUME"] == NSOrderedSame ) {
				BOOL passive = NO;
				long long size = 0;
				unsigned int port = [[parameters objectAtIndex:2] intValue];
				NSScanner *scanner = [NSScanner scannerWithString:[parameters objectAtIndex:3]];
				[scanner scanLongLong:&size];

				if( [parameters count] >= 5 ) {
					passive = YES;
					port = [[parameters objectAtIndex:4] intValue];
				}

				@synchronized( _fileTransfers ) {
					NSEnumerator *enumerator = [_fileTransfers objectEnumerator];
					MVFileTransfer *transfer = nil;
					while( ( transfer = [enumerator nextObject] ) ) {
						if( [transfer isUpload] && [transfer isPassive] == passive && [[transfer user] isEqualToChatUser:sender] &&
							( ! passive ? [transfer port] == port : [(id)transfer _passiveIdentifier] == port ) ) {
							[transfer _setTransfered:(unsigned long long)size];
							[transfer _setStartOffset:(unsigned long long)size];
							[sender sendSubcodeRequest:@"DCC ACCEPT" withArguments:[msg substringFromIndex:7]];
						}
					}
				}
			}

			[msg release];
		} else if( [command caseInsensitiveCompare:@"CLIENTINFO"] == NSOrderedSame ) {
			// make this extnesible later with a plugin registration method
			[sender sendSubcodeReply:command withArguments:@"VERSION TIME PING DCC CLIENTINFO"];
		}
	}

	[command release];
	[arguments release];
}

#pragma mark -
#pragma mark Room Replies

- (void) _handleJoinWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] ) {
		id name = [parameters objectAtIndex:0];
		if( [name isKindOfClass:[NSData class]] )
			name = [[[NSString allocWithZone:nil] initWithData:name encoding:[self encoding]] autorelease];

		MVChatRoom *room = [self joinedChatRoomWithName:name];

		if( [sender isLocalUser] ) {
			if( ! room ) {
				room = [[MVIRCChatRoom allocWithZone:nil] initWithName:name andConnection:self];
				[self _addJoinedRoom:room];
				[room release];
			}

			[room _setDateJoined:[NSDate date]];
			[room _setDateParted:nil];
			[room _setNamesSynced:NO];
			[room _clearMemberUsers];
			[room _clearBannedUsers];

			[self sendRawMessageWithFormat:@"WHO %@", name];
		} else {
			if( [sender status] != MVChatUserAwayStatus ) [sender _setStatus:MVChatUserAvailableStatus];
			[sender _setIdleTime:0.];
			[room _addMemberUser:sender];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
		}
	}
}

- (void) _handlePartWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:0]];
		if( ! room ) return;
		if( [sender isLocalUser] ) {
			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomPartedNotification object:room];
		} else {
			[room _removeMemberUser:sender];
			NSData *reason = [parameters objectAtIndex:1];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", reason, @"reason", nil]];
		}
	}
}

- (void) _handleQuitWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [sender isLocalUser] ) return;
	if( [parameters count] ) {
		[sender _setDateDisconnected:[NSDate date]];
		[sender _setStatus:MVChatUserOfflineStatus];

		NSData *reason = [parameters objectAtIndex:0];
		NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:sender, @"user", reason, @"reason", nil];

		MVChatRoom *room = nil;
		NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
		while( ( room = [enumerator nextObject] ) ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _removeMemberUser:sender];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:info];
		}

		[info release];
	}
}

- (void) _handleKickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] >= 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:0]];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		if( ! room || ! user ) return;

		NSData *reason = ( [parameters count] == 3 ? [parameters objectAtIndex:2] : nil );
		if( [user isLocalUser] ) {
			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"byUser", reason, @"reason", nil]];
		} else {
			[room _removeMemberUser:user];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomUserKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", sender, @"byUser", reason, @"reason", nil]];
		}
	}
}

- (void) _handleTopicWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:0]];
		[room _setTopic:[parameters objectAtIndex:1] byAuthor:sender withDate:[NSDate date]];
	}
}

#pragma mark -
#pragma mark Misc. Replies

- (void) _handlePingWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] >= 1 ) {
		if( [parameters count] == 1 ) [self sendRawMessageWithComponents:@"PONG :", [parameters objectAtIndex:0], nil];
		else [self sendRawMessageWithComponents:@"PONG ", [parameters objectAtIndex:1], @" :", [parameters objectAtIndex:0], nil];
	}
}

- (void) _handleInviteWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		id roomName = [parameters objectAtIndex:1];
		if( [roomName isKindOfClass:[NSData class]] )
			roomName = [[[NSString allocWithZone:nil] initWithData:roomName encoding:[self encoding]] autorelease];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomInvitedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", roomName, @"room", nil]];
	}
}

- (void) _handleNickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 1 ) {
		id nickname = [parameters objectAtIndex:0];
		if( [nickname isKindOfClass:[NSData class]] )
			nickname = [[[NSString allocWithZone:nil] initWithData:nickname encoding:[self encoding]] autorelease];

		NSString *oldNickname = [[sender nickname] retain];
		NSString *oldIdentifier = [[sender uniqueIdentifier] retain];

		if( [sender status] != MVChatUserAwayStatus )
			[sender _setStatus:MVChatUserAvailableStatus];
		[sender _setIdleTime:0.];

		NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
		MVChatRoom *room = nil;

		while( ( room = [enumerator nextObject] ) ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _updateMemberUser:sender fromOldUniqueIdentifier:oldIdentifier];
		}

		if( [sender isLocalUser] ) {
			[self _setCurrentNickname:nickname];
			[sender _setIdentified:NO];
			[sender _setUniqueIdentifier:[nickname lowercaseString]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:nil];
		} else {
			[self _updateKnownUser:sender withNewNickname:nickname];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserNicknameChangedNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldNickname, @"oldNickname", nil]];
		}

		[oldNickname release];
		[oldIdentifier release];
	}
}

#pragma mark -
#pragma mark Away Replies

- (void) _handle301WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_AWAY
	if( [parameters count] == 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		if( [[user awayStatusMessage] isEqual:[parameters objectAtIndex:2]] ) {
			[sender _setStatus:MVChatUserAwayStatus];
			[user _setAwayStatusMessage:[parameters objectAtIndex:2]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserAwayStatusMessageChangedNotification object:user userInfo:nil];
		}
	}
}

- (void) _handle305WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_UNAWAY
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
}

- (void) _handle306WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NOWAWAY
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
}

#pragma mark -
#pragma mark NAMES Replies

- (void) _handle353WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NAMREPLY
	if( [parameters count] == 4 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:2]];
		if( room && ! [room _namesSynced] ) {
			NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
			NSString *names = [[NSString allocWithZone:nil] initWithData:[parameters objectAtIndex:3] encoding:[self encoding]];
			NSArray *members = [names componentsSeparatedByString:@" "];
			NSEnumerator *enumerator = [members objectEnumerator];
			NSString *memberName = nil;

			while( ( memberName = [enumerator nextObject] ) ) {
				unsigned int i = 0, len = [memberName length];
				if( ! len ) break;

				unsigned long modes = MVChatRoomMemberNoModes;
				BOOL done = NO;

				while( i < len && ! done ) {
					unichar c = [memberName characterAtIndex:i];
					switch( c ) {
						case '+': modes |= MVChatRoomMemberVoicedMode; break;
						case '%': modes |= MVChatRoomMemberHalfOperatorMode; break;
						case '@': modes |= MVChatRoomMemberOperatorMode; break;
						default: done = YES; break;
					}
					if( ! done ) i++;
				}

				if( i > 0 ) memberName = [memberName substringFromIndex:i];
				MVChatUser *member = [self chatUserWithUniqueIdentifier:memberName];
				[room _addMemberUser:member];
				[room _setModes:modes forMemberUser:member];
			}

			[names release];
			[pool drain];
			[pool release];
		}
	}
}

- (void) _handle366WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFNAMES
	if( [parameters count] >= 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:1]];
		if( room && ! [room _namesSynced] ) {
			[room _setNamesSynced:YES];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification object:room];
		}
	}
}

#pragma mark -
#pragma mark WHO Replies

- (void) _handle352WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOREPLY
	if( [parameters count] >= 7 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:1]];
		MVChatUser *member = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:5]];
		[member _setUsername:[parameters objectAtIndex:2]];
		[member _setAddress:[parameters objectAtIndex:3]];

		unichar status = ( [[parameters objectAtIndex:6] length] ? [[parameters objectAtIndex:6] characterAtIndex:0] : 0 );
		if( status == 'H' ) {
			[member _setStatus:MVChatUserAvailableStatus];
		} else if( status == 'G' ) {
			[member _setStatus:MVChatUserAwayStatus];
		}
	}
}

- (void) _handle315WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFWHO
	if( [parameters count] >= 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:1]];
		if( room ) [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomMemberUsersSyncedNotification object:room];
	}
}

#pragma mark -
#pragma mark WHOIS Replies

- (void) _handle311WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISUSER
	if( [parameters count] == 6 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setServerOperator:NO]; // set these to NO now so we get the true values later in the WHOIS
		[user _setUsername:[parameters objectAtIndex:2]];
		[user _setAddress:[parameters objectAtIndex:3]];
		NSString *realName = [[NSString allocWithZone:nil] initWithData:[parameters objectAtIndex:5] encoding:[self encoding]];
		[user _setRealName:realName];
		[realName release];
	}
}

- (void) _handle312WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISSERVER
	if( [parameters count] >= 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setServerAddress:[parameters objectAtIndex:2]];
	}
}

- (void) _handle313WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISOPERATOR
	if( [parameters count] >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setServerOperator:YES];
	}
}

- (void) _handle317WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISIDLE
	if( [parameters count] >= 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setIdleTime:[[parameters objectAtIndex:2] intValue]];
		[user _setDateConnected:nil];

		// parameter 4 is connection time on some servers
		// prevent showing 34+ years connected time, this makes sure it is a viable date
		if( [parameters count] >= 4 && [[parameters objectAtIndex:3] intValue] > 631138520 )
			[user _setDateConnected:[NSDate dateWithTimeIntervalSince1970:[[parameters objectAtIndex:3] intValue]]];
	}
}

- (void) _handle318WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFWHOIS
	if( [parameters count] >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
		[user _setDateUpdated:[NSDate date]];

		if( [user status] != MVChatUserAwayStatus ) [user _setStatus:MVChatUserAvailableStatus];

		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserInformationUpdatedNotification object:user userInfo:nil];
	}
}

- (void) _handle319WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISCHANNELS
	if( [parameters count] == 3 ) {
		NSString *rooms = [[NSString allocWithZone:nil] initWithData:[parameters objectAtIndex:2] encoding:[self encoding]];
		NSArray *chanArray = [[rooms stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSMutableArray *results = [[NSMutableArray allocWithZone:nil] initWithCapacity:[chanArray count]];
		NSEnumerator *enumerator = [chanArray objectEnumerator];
		NSString *room = nil;

		NSCharacterSet *modeChars = [NSCharacterSet characterSetWithCharactersInString:@"@\%+ "];
		while( ( room = [enumerator nextObject] ) ) {
			room = [room stringByTrimmingCharactersInSet:modeChars];
			if( room ) [results addObject:room];
		}

		if( [results count] ) {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
			[user setAttribute:results forKey:MVChatUserKnownRoomsAttribute];
		}

		[rooms release];
		[results release];
	}
}

- (void) _handle320WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISIDENTIFIED
	if( [parameters count] == 3 ) {
		NSString *comment = [[NSString allocWithZone:nil] initWithData:[parameters objectAtIndex:2] encoding:[self encoding]];
		if( [comment rangeOfString:@"identified" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:1]];
			[user _setIdentified:YES];
		}
		[comment release];
	}
}
@end
