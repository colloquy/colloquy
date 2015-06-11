#import "MVIRCChatConnection.h"
#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCFileTransfer.h"
#import "MVIRCNumerics.h"
#import "MVDirectChatConnectionPrivate.h"
#import "MVChatString.h"

#import "GCDAsyncSocket.h"
#import "InterThreadMessaging.h"
#import "MVChatuserWatchRule.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "NSDataAdditions.h"
#import "NSDateAdditions.h"
#import "MVUtilities.h"

#if USE(ATTRIBUTED_CHAT_STRING)
#import "NSAttributedStringAdditions.h"
#endif

#if ENABLE(PLUGINS)
#import "NSMethodSignatureAdditions.h"
#import "MVChatPluginManager.h"
#endif

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#define JVQueueWaitBeforeConnected 120.
#define JVPingServerInterval 120.
#define JVPeriodicEventsInterval 600.
//#define JVWatchedUserWHOISDelay 300.
#define JVWatchedUserISONDelay 60.
#define JVEndCapabilityTimeoutDelay 45.
#define JVMaximumCommandLength 510
#define JVMaximumISONCommandLength JVMaximumCommandLength
#define JVMaximumWatchCommandLength JVMaximumCommandLength
#define JVMaximumMembersForWhoRequest 40
#define JVFirstViableTimestamp 631138520
#define JVFallbackEncoding NSISOLatin1StringEncoding

#ifndef LIKELY
#define LIKELY(x) __builtin_expect((x) ? 1 : 0, 1)
#endif

#ifndef UNLIKELY
#define UNLIKELY(x) __builtin_expect((x) ? 1 : 0, 0)
#endif

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

NSString *const MVIRCChatConnectionZNCPluginPlaybackFeature = @"MVIRCChatConnectionZNCPluginPlaybackFeature";

@interface MVIRCChatConnection (MVIRCChatConnectionProtocolHandlers)

#pragma mark Connecting Replies

- (void) _handleCapWithParameters:(NSArray *) parameters fromSender:(id) sender;
- (void) _handleAuthenticateWithParameters:(NSArray *) parameters fromSender:(id) sender;

- (void) _handle900WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_SASLSUCCESS */
- (void) _handle903WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_SASLFAIL */
- (void) _handle904WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_SASLTOOLONG */
- (void) _handle905WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_SASLABORTED */
- (void) _handle906WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_SASLALREADY */
- (void) _handle907WithParameters:(NSArray *) parameters fromSender:(id) sender;

/** RPL_WELCOME */
- (void) _handle001WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_ISUPPORT */
- (void) _handle005WithParameters:(NSArray *) parameters fromSender:(id) sender;

/** ERR_NICKNAMEINUSE */
- (void) _handle433WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Incoming Message Replies

- (MVChatRoom*) _chatRoomFromMessageTarget:(NSString*)messageTarget;

- (void) _handlePrivmsg:(NSMutableDictionary *) privmsgInfo;
- (void) _handlePrivmsgWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;

- (void) _handleNotice:(NSMutableDictionary *) noticeInfo;
- (void) _handleNoticeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;

- (void) _handleCTCP:(NSDictionary *) ctcpInfo;
- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender toTarget:(id) target forRoom:(MVChatRoom *) room withTags:(NSDictionary *) tags;

#pragma mark Room Replies

- (void) _handleJoinWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;
- (void) _handlePartWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;
- (void) _handleQuitWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;
- (void) _handleKickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;

- (void) _handleTopic:(NSDictionary *)topicInfo;
- (void) _handleTopicWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;

- (void) _parseRoomModes:(NSArray *) parameters forRoom:(MVChatRoom *) room fromSender:(MVChatUser *__nullable) sender;
- (void) _handleModeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;
/** RPL_CHANNELMODEIS */
- (void) _handle324WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Misc. Replies

- (void) _handlePingWithParameters:(NSArray *) parameters fromSender:(id) sender;
- (void) _handleInviteWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;
- (void) _handleNickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender;

/** RPL_ISON */
- (void) _handle303WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Away Replies

/** RPL_AWAY */
- (void) _handle301WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_UNAWAY */
- (void) _handle305WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_NOWAWAY */
- (void) _handle306WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark NAMES Replies

/** RPL_NAMREPLY */
- (void) _handle353WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_ENDOFNAMES */
- (void) _handle366WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark WHO Replies

/** RPL_WHOREPLY */
- (void) _handle352WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_ENDOFWHO */
- (void) _handle315WithParameters:(NSArray *) parameters fromSender:(id) sender;


#pragma mark Channel List Reply

/** RPL_LIST */
- (void) _handle322WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Ban List Replies

/** RPL_BANLIST */
- (void) _handle367WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_ENDOFBANLIST */
- (void) _handle368WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Topic Replies

/** RPL_TOPIC */
- (void) _handle332WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_TOPICWHOTIME_IRCU */
- (void) _handle333WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark WHOIS Replies

/** RPL_WHOISUSER */
- (void) _handle311WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_WHOISSERVER */
- (void) _handle312WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_WHOISOPERATOR */
- (void) _handle313WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_WHOISIDLE */
- (void) _handle317WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_ENDOFWHOIS */
- (void) _handle318WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_WHOISCHANNELS */
- (void) _handle319WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_WHOISIDENTIFIED */
- (void) _handle320WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Error Replies

/** ERR_NOSUCHNICK */
- (void) _handle401WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_NOSUCHSERVER */
- (void) _handle402WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_CANNOTSENDTOCHAN */
- (void) _handle404WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** "services down" (freenode/hyperion) or "Invalid CAP subcommand" (freenode/ircd-seven, not supported here) */
- (void) _handle410WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_UNKNOWNCOMMAND */
- (void) _handle421WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_ERRONEUSNICKNAME, "<nick> :Erroneous nickname" */
- (void) _handle432WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_BANONCHAN Bahamut (also ERR_SERVICECONFUSED on Unreal, not implemented here) */
- (void) _handle435WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_BANNICKCHANGE Unreal (also ERR_UNAVAILRESOURCE in RFC2812, not implemented here) */
- (void) _handle437WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_NICKTOOFAST_IRCU */
- (void) _handle438WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_SERVICESDOWN_BAHAMUT_UNREAL (also freenode/ircd-seven) */
- (void) _handle440WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_ALREADYREGISTERED (RFC1459) */
- (void) _handle462WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_CHANNELISFULL */
- (void) _handle471WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_INVITEONLYCHAN */
- (void) _handle473WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_BANNEDFROMCHAN */
- (void) _handle474WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_BADCHANNELKEY */
- (void) _handle475WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERR_NOCHANMODES_RFC2812 or ERR_NEEDREGGEDNICK_BAHAMUT_IRCU_UNREAL */
- (void) _handle477WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** ERROR message: <http://tools.ietf.org/html/rfc2812#section-3.7.4> */
- (void) _handleErrorWithParameters:(NSArray *) parameters fromSender:(id) sender;
/** freenode/hyperion: identify with services to talk in this room */
- (void) _handle506WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark Watch Replies

/** RPL_NOWON_BAHAMUT_UNREAL */
- (void) _handle604WithParameters:(NSArray *) parameters fromSender:(id) sender;
/** RPL_LOGON_BAHAMUT_UNREAL */
- (void) _handle600WithParameters:(NSArray *) parameters fromSender:(id) sender;

#pragma mark EFnet / umich captcha

/** irc.umich.edu (efnet) uses this code to show a captcha to users without identd which we have to reply to automatically. */
- (void) _handle998WithParameters:(NSArray *) parameters fromSender:(id) sender;

@end


@implementation MVIRCChatConnection {
	dispatch_queue_t _connectionQueue;

	NSTimeInterval _nextPingTimeInterval;
}

+ (NSArray *) defaultServerPorts {
	return @[@(6667), @(6660), @(6669), @(6697), @(7000), @(7001), @(994)];
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		NSString *queueName = [bundleIdentifier stringByAppendingString:@".connection-queue"];
		_connectionQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);

		_localUser = [[MVIRCChatUser alloc] initLocalUserWithConnection:self];

		[self _resetSupportedFeatures];
	}

	return self;
}

- (void) dealloc {
	[_chatConnection setDelegate:nil];
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

	MVSafeAdoptAssign( _lastConnectAttempt, [[NSDate alloc] init] );
	MVSafeRetainAssign( _queueWait, [NSDate dateWithTimeIntervalSinceNow:JVQueueWaitBeforeConnected] );

	[self _willConnect]; // call early so other code has a chance to change our info

	[self _connect];
}

- (void) disconnectWithReason:(MVChatString * __nullable) reason {
	[self performSelectorOnMainThread:@selector( cancelPendingReconnectAttempts ) withObject:nil waitUntilDone:YES];

	if( _status == MVChatConnectionConnectedStatus ) {
		_userDisconnected = YES;
		if( reason.length ) {
			NSData *msg = [[self class] _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
			[self sendRawMessageImmediatelyWithComponents:@"QUIT :", msg, nil];
		} else [self sendRawMessage:@"QUIT" immediately:YES];
	} else if( _status == MVChatConnectionConnectingStatus ) {
		_userDisconnected = YES;
		[self._chatConnection disconnect];
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

- (void) setNicknamePassword:(NSString * __nullable) newPassword {
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

- (void) sendCommand:(NSString *) command withArguments:(MVChatString * __nullable) arguments {
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
	return self.recentlyConnected ? 1.5 : 3.;
}

- (double) sendQueueDelayIncrement {
	return self.recentlyConnected ? .25 : .15;
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

	if( now ) {
		__weak __typeof__((self)) weakSelf = self;
		dispatch_async(_connectionQueue, ^{
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			MVSafeAdoptAssign( strongSelf->_lastCommand, [[NSDate alloc] init] );
			[self _writeDataToServer:raw];
		});
	} else {
		if( ! _sendQueue )
			_sendQueue = [[NSMutableArray alloc] init];

		@synchronized( _sendQueue ) {
			[_sendQueue addObject:raw];
		}

		if( ! _sendQueueProcessing ) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self _startSendQueue];
			});
		}
	}
}

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! rooms.count ) return;

	if( !_pendingJoinRoomNames )
		_pendingJoinRoomNames = [[NSMutableSet alloc] initWithCapacity:10];

	NSMutableArray *roomList = [[NSMutableArray alloc] initWithCapacity:rooms.count];

	for( __strong NSString *room in rooms ) {
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
			NSArray *components = [room componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (components.count) {
				password = [[components subarrayWithRange:NSMakeRange(1, (components.count - 1))] componentsJoinedByString:@""];
				components = [components subarrayWithRange:NSMakeRange(0, 1)];
			}

			if( !components.count)
				continue;

			room = [self properNameForChatRoomNamed:components[0]];

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
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString * __nullable) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( room.length > 0 );

	if( !_pendingJoinRoomNames )
		_pendingJoinRoomNames = [[NSMutableSet alloc] initWithCapacity:10];

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
	if( ! room ) room = [[MVIRCChatRoom alloc] initWithName:identifier andConnection:self];
	return room;
}

- (MVChatRoom *) chatRoomWithName:(NSString *) name {
	return [self chatRoomWithUniqueIdentifier:[self properNameForChatRoomNamed:name]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	static NSCharacterSet *defaultPrefixes = nil;
	if( ! _roomPrefixes && ! defaultPrefixes )
		defaultPrefixes = [NSCharacterSet characterSetWithCharactersInString:@"#&+!~"];
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
	if( ! user ) user = [[MVIRCChatUser alloc] initWithNickname:identifier andConnection:self];
	return user;
}

#pragma mark -

- (void) addChatUserWatchRule:(MVChatUserWatchRule *) rule {
	if( !rule.nicknameIsRegularExpression && rule.nickname.length && [[MVIRCChatUser servicesNicknames] containsObject:rule.nickname.lowercaseString] ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[rule nickname]];
		[self _markUserAsOnline:user];
		return;
	}

	@synchronized( _chatUserWatchRules ) {
		if( [_chatUserWatchRules containsObject:rule] ) return;
	}

	[super addChatUserWatchRule:rule];

	if( [rule nickname] && ! [rule nicknameIsRegularExpression] ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[rule nickname]];
		[rule matchChatUser:user];
		if( [self isConnected] ) {
			if( [self.supportedFeatures containsObject:MVChatConnectionMonitor] && !_monitorListFull ) {
				if( !_fetchingMonitorList ) [self sendRawMessageWithFormat:@"MONITOR + %@", [rule nickname]];
				else [_pendingMonitorList addObject:[rule nickname]];
			}
			else if( [self.supportedFeatures containsObject:MVChatConnectionWatchFeature] ) [self sendRawMessageWithFormat:@"WATCH +%@", [rule nickname]];
			else [self sendRawMessageWithFormat:@"ISON %@", [rule nickname]];
		}
	} else {
		@synchronized( _knownUsers ) {
			[_knownUsers enumerateKeysAndObjectsUsingBlock:^(id key, MVChatUser *user, BOOL *stop) {
				[rule matchChatUser:user];
			}];
		}
	}
}

- (void) removeChatUserWatchRule:(MVChatUserWatchRule *) rule {
	[super removeChatUserWatchRule:rule];

	if( [self isConnected] && [rule nickname] && ! [rule nicknameIsRegularExpression] ) {
		if( [self.supportedFeatures containsObject:MVChatConnectionMonitor] )
			[self sendRawMessageWithFormat:@"MONITOR - %@", [rule nickname]];
		if( [self.supportedFeatures containsObject:MVChatConnectionWatchFeature] )
			[self sendRawMessageWithFormat:@"WATCH -%@", [rule nickname]];
	}

	if( _monitorListFull ) {
		NSString *nicknameToMonitor = _pendingMonitorList.firstObject;
		[_pendingMonitorList removeObjectAtIndex:0];

		MVChatUserWatchRule *watchRule = [[MVChatUserWatchRule alloc] init];
		watchRule.nickname = nicknameToMonitor;

		// remove the watch user from our local cache, and re-add it with a remote MONITOR instead of ISON
		[super removeChatUserWatchRule:watchRule];
		[self addChatUserWatchRule:watchRule];

		if( _pendingMonitorList.count == 0 ) {
			_monitorListFull = NO;
			_pendingMonitorList = nil;
		}
	}
}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 300. ) {
		[self sendRawMessage:@"LIST"];
		MVSafeAdoptAssign( _cachedDate, [[NSDate alloc] init] );
	}
}

- (void) stopFetchingChatRoomList {
	if( _cachedDate && ABS( [_cachedDate timeIntervalSinceNow] ) < 600. )
		[self sendRawMessage:@"LIST STOP" immediately:YES];
}

#pragma mark -

- (void) setAwayStatusMessage:(MVChatString * __nullable) message {
	if( message.length ) {
		MVSafeCopyAssign( _awayMessage, message );

		NSData *msg = [[self class] _flattenedIRCDataForMessage:message withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
		[self sendRawMessageImmediatelyWithComponents:@"AWAY :", [message string], nil];

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
- (GCDAsyncSocket *) _chatConnection {
	return _chatConnection;
}

- (void) _connect {
	id old = _chatConnection;
	_chatConnection = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_connectionQueue socketQueue:_connectionQueue];
	_chatConnection.IPv6Enabled = YES;
	_chatConnection.IPv4PreferredOverIPv6 = YES;
	[old setDelegate:nil];
	[old disconnect];

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

	_failedNickname = nil;
	_failedNicknameCount = 1;
	_nicknameShortened = NO;

	[super _didDisconnect];
}

#pragma mark -

- (void) socket:(GCDAsyncSocket *) socket didReceiveTrust:(SecTrustRef) trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
	if (!trust || !completionHandler)
		return;

	SecTrustEvaluateAsync(trust, dispatch_get_main_queue(), ^(SecTrustRef trustRef, SecTrustResultType result) {
		if (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified) {
			completionHandler(YES);
			return;
		}

		[[NSNotificationCenter chatCenter] postNotificationName:MVChatConnectionNeedTLSPeerTrustFeedbackNotification object:self userInfo:@{
			@"completionHandler": completionHandler,
			@"trust": (__bridge id)trust,
			@"result": [NSString stringWithFormat:@"%d", result]
		}];
	});
}

- (void) socketDidDisconnect:(GCDAsyncSocket *) sock withError:(NSError *) error {
	if( sock != _chatConnection ) return;

	__strong id me = self;

	MVSafeRetainAssign( _lastError, error );

	GCDAsyncSocket *oldChatConnection = _chatConnection;
	_chatConnection = nil;
	[oldChatConnection setDelegate:nil];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self _stopSendQueue];
	});

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

	dispatch_async(dispatch_get_main_queue(), ^{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _periodicEvents ) object:nil];
//		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _whoisWatchedUsers ) object:nil];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _checkWatchedUsers ) object:nil];
	});

	if( _status == MVChatConnectionConnectingStatus ) {
		if( !_lastError )
			[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:NO];
	} else {
		if( _lastError && !_userDisconnected )
			_status = MVChatConnectionServerDisconnectedStatus;
		[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:NO];
	}

	@synchronized( _knownUsers ) {
		[_knownUsers enumerateKeysAndObjectsUsingBlock:^(id key, MVChatUser *user, BOOL *stop) {
			[user _setStatus:MVChatUserUnknownStatus];
		}];
	}

	@synchronized( _chatUserWatchRules ) {
		for( MVChatUserWatchRule *rule in _chatUserWatchRules )
			[rule removeMatchedUsersForConnection:self];
	}

	me = nil;
}

- (void) socket:(GCDAsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	MVSafeRetainAssign( _lastError, nil );

	//	if( [[self proxyServer] length] && [self proxyServerPort] ) {
	//		if( _proxy == MVChatConnectionHTTPSProxy || _proxy == MVChatConnectionHTTPProxy ) {
	//			NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
	//			if( _proxy == MVChatConnectionHTTPSProxy ) {
	//				[settings setObject:[self proxyServer] forKey:(NSString *)kCFStreamPropertyHTTPSProxyHost];
	//				[settings setObject:[NSNumber numberWithUnsignedShort:[self proxyServerPort]] forKey:(NSString *)kCFStreamPropertyHTTPSProxyPort];
	//			} else {
	//				[settings setObject:[self proxyServer] forKey:(NSString *)kCFStreamPropertyHTTPProxyHost];
	//				[settings setObject:[NSNumber numberWithUnsignedShort:[self proxyServerPort]] forKey:(NSString *)kCFStreamPropertyHTTPProxyPort];
	//			}
	//
	//			CFReadStreamSetProperty( [sock readStream], kCFStreamPropertyHTTPProxy, (CFDictionaryRef) settings );
	//			CFWriteStreamSetProperty( [sock writeStream], kCFStreamPropertyHTTPProxy, (CFDictionaryRef) settings );
	//			[settings release];
	//		} else if( _proxy == MVChatConnectionSOCKS4Proxy || _proxy == MVChatConnectionSOCKS5Proxy ) {
	//			NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
	//
	//			[settings setObject:[self proxyServer] forKey:(NSString *)kCFStreamPropertySOCKSProxyHost];
	//			[settings setObject:[NSNumber numberWithUnsignedShort:[self proxyServerPort]] forKey:(NSString *)kCFStreamPropertySOCKSProxyPort];
	//
	//			if( [[self proxyUsername] length] )
	//				[settings setObject:[self proxyUsername] forKey:(NSString *)kCFStreamPropertySOCKSUser];
	//			if( [[self proxyPassword] length] )
	//				[settings setObject:[self proxyPassword] forKey:(NSString *)kCFStreamPropertySOCKSPassword];
	//
	//			if( _proxy == MVChatConnectionSOCKS4Proxy )
	//				[settings setObject:(NSString *)kCFStreamSocketSOCKSVersion4 forKey:(NSString *)kCFStreamPropertySOCKSVersion];
	//
	//			CFReadStreamSetProperty( [sock readStream], kCFStreamPropertySOCKSProxy, (CFDictionaryRef) settings );
	//			CFWriteStreamSetProperty( [sock writeStream], kCFStreamPropertySOCKSProxy, (CFDictionaryRef) settings );
	//			[settings release];
	//		}
	//	}

	BOOL secure = _secure;
	if( _bouncer == MVChatConnectionColloquyBouncer )
		secure = NO; // This should always be YES in the future when the bouncer supports secure connections.

	if( secure ) {
//		[self sendRawMessageImmediatelyWithFormat:@"STARTTLS"];

		self.connectedSecurely = YES;

		[self _startTLS];
	} else self.connectedSecurely = NO;

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

	{ // schedule an end to the capability negotiation in case it stalls the connection
		[self _sendEndCapabilityCommandAfterTimeout];

		NSArray *IRCv31Required = nil;
		if ( _requestsSASL && self.nicknamePassword.length )
			IRCv31Required = @[ @"sasl", @"multi-prefix", @" " ];
		else IRCv31Required = @[ @"multi-prefix", @" " ];

		NSArray *IRCv31Optional = @[ @"tls", @"away-notify", @"extended-join", @"account-notify", @" " ];
		NSArray *IRCv32Required = @[ @"account-tag", @"intent", @" " ];
		NSArray *IRCv32Optional = @[ @"self-message", @"cap-notify", @"chghost", @"invite-notify", @"server-time", @"userhost-in-names", @"batch", @" " ];

		// In theory, IRCv3.2 isn't finalized yet and may change, so ZNC prefixes their capabilities. In practice,
		// the official spec is pretty stable, and their behavior matches the official spec at this time.
		NSArray *ZNCPrefixedIRCv32Optional = @[ @"znc.in/server-time-iso", @"znc.in/self-message", @"znc.in/batch", @"znc.in/playback", @" " ];

		[self sendRawMessageImmediatelyWithFormat:@"CAP LS 302"];

		NSMutableString *rawMessage = [@"CAP REQ : " mutableCopy];
		[rawMessage appendString:[IRCv31Required componentsJoinedByString:@" "]];
		[rawMessage appendString:[IRCv31Optional componentsJoinedByString:@" "]];
		[rawMessage appendString:[IRCv32Required componentsJoinedByString:@" "]];
		[rawMessage appendString:[IRCv32Optional componentsJoinedByString:@" "]];
		[rawMessage appendString:[ZNCPrefixedIRCv32Optional componentsJoinedByString:@" "]];

		[self sendRawMessageImmediatelyWithFormat:[rawMessage copy]];
	}

	if( password.length ) [self sendRawMessageImmediatelyWithFormat:@"PASS %@", password];
	[self sendRawMessageImmediatelyWithFormat:@"NICK %@", [self preferredNickname]];
	[self sendRawMessageImmediatelyWithFormat:@"USER %@ 0 * :%@", username, ( _realName.length ? _realName : @"Anonymous User" )];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self performSelector:@selector(_periodicEvents) withObject:nil afterDelay:JVPeriodicEventsInterval];
	});

	[self _pingServerAfterInterval];

	[self _readNextMessageFromServer];
}

- (void) socket:(GCDAsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	@autoreleasepool {
		[self _processIncomingMessage:data fromServer:YES];

		[self _readNextMessageFromServer];
	}
}

#pragma mark -

- (void) processIncomingMessage:(id) raw fromServer:(BOOL) fromServer {
	NSParameterAssert([raw isKindOfClass:[NSData class]]);

	dispatch_async(_connectionQueue, ^{
		[self _processIncomingMessage:raw fromServer:fromServer];
	});
}

- (void) _processIncomingMessage:(NSData *) data fromServer:(BOOL) fromServer {
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
	const char *intentOrTags = NULL;
	NSUInteger intentOrTagsLength = 0;

	NSMutableArray *parameters = [[NSMutableArray alloc] initWithCapacity:15];

	// Parsing as defined in 2.3.1 at http://www.irchelp.org/irchelp/rfc/rfc2812.txt
	// With support for IRCv3.2 extensions

	if( len <= 2 )
		goto end; // bad message

#define checkAndMarkIfDone() if( line == end ) done = YES
#define consumeWhitespace() while( *line == ' ' && line != end && ! done ) line++
#define notEndOfLine() line != end && ! done

	BOOL done = NO;
	if( notEndOfLine() ) {
		if( *line == '@' ) {
			intentOrTags = ++line;
			// IRCv3.2
			// @intent=ACTION;aaa=bbb;ccc;example.com/ddd=eee
			while( notEndOfLine() && *line != ' ' ) line++;
			intentOrTagsLength = (line - intentOrTags);
			checkAndMarkIfDone();
			consumeWhitespace();
		}

		if( notEndOfLine() && *line == ':' ) {
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
				param = [[NSMutableData alloc] initWithBytes:currentParameter length:(end - currentParameter)];
				done = YES;
			} else {
				currentParameter = line;
				while( notEndOfLine() && *line != ' ' ) line++;
				param = [self _newStringWithBytes:currentParameter length:(line - currentParameter)];
				checkAndMarkIfDone();
				if( ! done ) line++;
			}

			if( param ) [parameters addObject:param];

			consumeWhitespace();
		}
	}

#undef checkAndMarkIfDone
#undef consumeWhitespace
#undef notEndOfLine

end:
	{
		NSString *senderString = [self _newStringWithBytes:sender length:senderLength];
		NSString *commandString = ((command && commandLength) ? [[NSString alloc] initWithBytes:command length:commandLength encoding:NSASCIIStringEncoding] : nil);

		NSString *intentOrTagsString = [self _newStringWithBytes:intentOrTags length:intentOrTagsLength];
		NSMutableDictionary *intentOrTagsDictionary = [NSMutableDictionary dictionary];
		for( NSString *anIntentOrTag in [intentOrTagsString componentsSeparatedByString:@";"] ) {
			NSArray *intentOrTagPair = [anIntentOrTag componentsSeparatedByString:@"="];
			if (intentOrTagPair.count != 2) continue;
			intentOrTagsDictionary[intentOrTagPair[0]] = intentOrTagPair[1];
		}

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:@{ @"message": rawString, @"messageData": data, @"sender": (senderString ?: @""), @"command": (commandString ?: @""), @"parameters": parameters, @"outbound": @(NO), @"fromServer": @(fromServer), @"message-tags": intentOrTagsDictionary }];

		BOOL hasTagsToSend = !!intentOrTagsDictionary.allKeys.count;
		NSString *selectorString = nil;
		SEL selector = NULL;
		if( hasTagsToSend ) {
			selectorString = [[NSString alloc] initWithFormat:@"_handle%@WithParameters:tags:fromSender:", (commandString ? [commandString capitalizedString] : @"Unknown")];
			selector = NSSelectorFromString(selectorString);

			NSString *timestampString = intentOrTagsDictionary[@"time"];
			if (timestampString.length) {
				// threadsafe as of iOS 7
				NSDateFormatter *dateFormatter = [NSThread currentThread].threadDictionary[@"IRCv32ServerTimeDateFormatter"];
				if (!dateFormatter) {
					dateFormatter = [[NSDateFormatter alloc] init];
					dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
					dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";

					[NSThread currentThread].threadDictionary[@"IRCv32ServerTimeDateFormatter"] = dateFormatter;
				}

				NSDate *timestamp = [dateFormatter dateFromString:timestampString];
				if (timestamp)
					intentOrTagsDictionary[@"time"] = timestamp;
				else [intentOrTagsDictionary removeObjectForKey:@"time"]; // failed to convert string to date, drop any invalid data
			}
		}

		if( selector == NULL || ![self respondsToSelector:selector] ) {
			selectorString = [[NSString alloc] initWithFormat:@"_handle%@WithParameters:fromSender:", (commandString ? [commandString capitalizedString] : @"Unknown")];
			selector = NSSelectorFromString(selectorString);
			hasTagsToSend = NO; // if we don't support sending tags to the command or numeric, pretend we don't have tags to send
		}

		if( [self respondsToSelector:selector] ) {
			MVChatUser *chatUser = nil;
			// if user is not null that shows it was a user not a server sender.
			// the sender was also a user if senderString equals the current local nickname (some bouncers will do this).
			if( ( senderString.length && user && userLength ) || [senderString isEqualToString:_currentNickname] ) {
				chatUser = [self chatUserWithUniqueIdentifier:senderString];
				if( ! [chatUser address] && host && hostLength ) {
					NSString *hostString = [self _newStringWithBytes:host length:hostLength];
					[chatUser _setAddress:hostString];
				}

				if( ! [chatUser username] ) {
					NSString *userString = [self _newStringWithBytes:user length:userLength];
					[chatUser _setUsername:userString];
				}
			}

			id chatSender = ( chatUser ? (id) chatUser : (id) senderString );

			@try {
				if( hasTagsToSend ) {
					NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
					invocation.target = self;
					invocation.selector = selector;
					[invocation setArgument:&parameters atIndex:2];
					[invocation setArgument:&intentOrTagsDictionary atIndex:3];
					[invocation setArgument:&chatSender atIndex:4];
					[invocation invoke];
				} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
					[self performSelector:selector withObject:parameters withObject:chatSender];
#pragma clang diagnostic pop
				}
			} @catch (NSException *e) {
				NSLog(@"Exception handling command %@: %@", NSStringFromSelector(selector), e);
			}
		}

		[self _pingServerAfterInterval];
	}
}

#pragma mark -

- (void) _writeDataToServer:(id) raw {
	NSMutableData *data = nil;
	NSString *string = [self _stringFromPossibleData:raw];

	if( [raw isKindOfClass:[NSMutableData class]] ) {
		data = raw;
	} else if( [raw isKindOfClass:[NSData class]] ) {
		data = [raw mutableCopy];
	} else if( [raw isKindOfClass:[NSString class]] ) {
		data = [[raw dataUsingEncoding:[self encoding] allowLossyConversion:YES] mutableCopy];
	} else if( [raw isKindOfClass:[NSAttributedString class]] ) {
		data = [[[raw string] dataUsingEncoding:[self encoding] allowLossyConversion:YES] mutableCopy];
	} else {
		NSAssert(NO, @"%@ is of the wrong class (type %@)", raw, NSStringFromClass([raw class]));
		return;
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

	NSString *stringWithPasswordsHidden = [[[string copy] stringByReplacingOccurrencesOfRegex:@"(^PASS |^AUTHENTICATE (?!\\+$|PLAIN$)|IDENTIFY (?:[^ ]+ )?|(?:LOGIN|AUTH|JOIN) [^ ]+ )[^ ]+$" withString:@"$1********" options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, string.length) error:NULL] copy];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:@{ @"message": stringWithPasswordsHidden, @"messageData": data, @"outbound": @(YES) }];
}

- (void) _readNextMessageFromServer {
	// IRC messages end in \x0D\x0A, but some non-compliant servers only use \x0A during the connecting phase
	[_chatConnection readDataToData:[GCDAsyncSocket LFData] withTimeout:-1. tag:0];
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
		cformat = @"";
	}

	NSDictionary *options = @{ @"StringEncoding": @(enc), @"FormatType": cformat };
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

	static NSCharacterSet *backspaceCharacterSet = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		backspaceCharacterSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(8, 1)] copy]; // 08 in ASCII is backspace, that OS X sometimes inserts if you shift + arrow and then delete text
	});
	[message cq_stringByRemovingCharactersInSet:backspaceCharacterSet];
	NSMutableData *msg = [[[self class] _flattenedIRCDataForMessage:message withEncoding:msgEncoding andChatFormat:[self outgoingChatFormat]] mutableCopy];
#if ENABLE(PLUGINS)
	__unsafe_unretained NSMutableData *unsafeMsg = msg;
	__unsafe_unretained id unsafeTarget = target;
	__unsafe_unretained NSDictionary *unsafeAttributes = attributes;

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( id ), @encode( NSDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processOutgoingMessageAsData:to:attributes: )];
	[invocation setArgument:&unsafeMsg atIndex:2];
	[invocation setArgument:&unsafeTarget atIndex:3];
	[invocation setArgument:&unsafeAttributes atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	if( ! msg.length ) {
		return;
	}

	if( echo ) {
		MVChatRoom *room = ([target isKindOfClass:[MVChatRoom class]] ? target : nil);
		NSNumber *action = ([attributes[@"action"] boolValue] ? attributes[@"action"] : @(NO));
		NSMutableDictionary *privmsgInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:msg, @"message", [self localUser], @"user", [NSString locallyUniqueString], @"identifier", action, @"action", target, @"target", room, @"room", nil];
		dispatch_async(_connectionQueue, ^{ @autoreleasepool {
			[self performSelector:@selector(_handlePrivmsg:) withObject:privmsgInfo];
		}});
	}

	NSString *targetName = [target isKindOfClass:[MVChatRoom class]] ? [target name] : [target nickname];

	BOOL usingIntentTags = ( [self.supportedFeatures containsObject:MVChatConnectionMessageIntents] );
	NSString *accountName = self.localUser.account;
	[self _stripModePrefixesFromNickname:&accountName];
	if( [attributes[@"action"] boolValue] ) {
		NSString *prefix = nil;
		NSUInteger messageTagLength = 0;

		if( usingIntentTags ) {
			NSString *messageTags = @"@intent=ACTION";
			if ([self.supportedFeatures containsObject:MVChatConnectionAccountTag] && self.localUser.account)
				messageTags = [messageTags stringByAppendingString:[NSString stringWithFormat:@";account=%@", accountName]];
			messageTagLength = messageTags.length + 1; // space is not in the prefix formatter (due to \001 being sent if not using @intent)
			prefix = [[NSString alloc] initWithFormat:@"%@ PRIVMSG %@%@ :", messageTags, targetPrefix, targetName];
		} else {
			prefix = [[NSString alloc] initWithFormat:@"PRIVMSG %@%@ :\001ACTION ", targetPrefix, targetName];
		}
		NSUInteger bytesLeft = [self bytesRemainingForMessage:[[self localUser] nickname] withUsername:[[self localUser] username] withAddress:[[self localUser] address] withPrefix:prefix withEncoding:msgEncoding];
		bytesLeft += messageTagLength; // IRCv3.2 specifically excludes message-tag from the message length limit

		if ( msg.length > bytesLeft ) [self sendBrokenDownMessage:msg withPrefix:prefix withEncoding:msgEncoding withMaximumBytes:bytesLeft];
		else [self sendRawMessageWithComponents:prefix, msg, (usingIntentTags ? nil : @"\001"), nil]; // exclude trailing \001 byte if we are using intent tags
	} else {
		NSString *messageTags = @"";
		NSUInteger messageTagLength = 0;
		NSString *prefix = nil;
		if (usingIntentTags && [self.supportedFeatures containsObject:MVChatConnectionAccountTag] && self.localUser.account) {
			messageTags = [NSString stringWithFormat:@"@account=%@ ", accountName];
			messageTagLength = messageTags.length; // space is in the tag substring since we don't have to worry about \001 for regular PRIVMSGs
			prefix = [[NSString alloc] initWithFormat:@"%@PRIVMSG %@%@ :", messageTags, targetPrefix, targetName];
		} else {
			prefix = [[NSString alloc] initWithFormat:@"PRIVMSG %@%@ :", targetPrefix, targetName];
		}

		NSUInteger bytesLeft = [self bytesRemainingForMessage:[[self localUser] nickname] withUsername:[[self localUser] username] withAddress:[[self localUser] address] withPrefix:prefix withEncoding:msgEncoding];
		bytesLeft += messageTagLength;

		if ( msg.length > bytesLeft )	[self sendBrokenDownMessage:msg withPrefix:prefix withEncoding:msgEncoding withMaximumBytes:bytesLeft];
		else [self sendRawMessageWithComponents:prefix, msg, nil];
	}
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
				msgCutDown = [[msg subdataWithRange:NSMakeRange( 0, bytesRemainingForMessage )] mutableCopy];
			}
			else if ( msg.length < bytesLeft ) break;
			else [msgCutDown setLength:msgCutDown.length - 1];
		}

		if ( [prefix hasCaseInsensitiveSubstring:@"\001ACTION"]	) [self sendRawMessageWithComponents:prefix, msgCutDown, @"\001", nil];
		else [self sendRawMessageWithComponents:prefix, msgCutDown, nil];
		[msg replaceBytesInRange:NSMakeRange(0, bytesRemainingForMessage) withBytes:NULL length:0];

		if ( msg.length >= bytesRemainingForMessage ) bytesRemainingForMessage = bytesLeft;
		else bytesRemainingForMessage = msg.length;
	}
}

- (NSUInteger) bytesRemainingForMessage:(NSString *) nickname withUsername:(NSString *) username withAddress:(NSString *) address withPrefix:(NSString *) prefix withEncoding:(NSStringEncoding) msgEncoding {
	return ( sizeof(char) * JVMaximumCommandLength ) - [nickname lengthOfBytesUsingEncoding:msgEncoding] - [username lengthOfBytesUsingEncoding:msgEncoding] - [address lengthOfBytesUsingEncoding:msgEncoding] - [prefix lengthOfBytesUsingEncoding:msgEncoding];
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

- (void) _sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding toTarget:(id __nullable) target {
	MVAssertMainThreadRequired();

	BOOL isRoom = [target isKindOfClass:[MVChatRoom class]];
	BOOL isUser = ([target isKindOfClass:[MVChatUser class]] || [target isKindOfClass:[MVDirectChatConnection class]]);

	NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSScanner *argumentsScanner = [NSScanner scannerWithString:MVChatStringAsString(arguments)];
	[argumentsScanner setCharactersToBeSkipped:nil];

	if( isUser || isRoom ) {
		if( [command isCaseInsensitiveEqualToString:@"me"] || [command isCaseInsensitiveEqualToString:@"action"] ) {
			[self _sendMessage:arguments withEncoding:encoding toTarget:target withTargetPrefix:@"" withAttributes:@{ @"action": @(YES) } localEcho:YES];
			return;
		} else if( [command isCaseInsensitiveEqualToString:@"say"] ) {
			[self _sendMessage:arguments withEncoding:encoding toTarget:target withTargetPrefix:@"" withAttributes:@{ } localEcho:YES];
			return;
		}
	}

	if( isRoom ) {
		MVChatRoom *room = (MVChatRoom *)target;
		if( [command isCaseInsensitiveEqualToString:@"cycle"] || [command isCaseInsensitiveEqualToString:@"hop"] ) {
			__strong MVChatRoom *strongRoom = room;
			[room part];

			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomPartedNotification object:room];

			[room performSelector:@selector(join) withObject:nil afterDelay:.5];

			strongRoom = nil;
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
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];
			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"deop"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"halfop"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"dehalfop"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberHalfOperatorMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"voice"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"devoice"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeMode:MVChatRoomMemberVoicedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"quiet"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room setDisciplineMode:MVChatRoomMemberDisciplineQuietedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"dequiet"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( NSString *userString in users ) {
				if( userString.length ) {
					MVChatUser *user = [[room memberUsersWithNickname:userString] anyObject];
					if( user ) [room removeDisciplineMode:MVChatRoomMemberDisciplineQuietedMode forMemberUser:user];
				}
			}

			if( users.count )
				return;
		} else if( [command isCaseInsensitiveEqualToString:@"ban"] ) {
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( __strong NSString *userString in users ) {
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
			NSArray *users = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:whitespaceCharacters];

			for( __strong NSString *userString in users ) {
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
		if( [whitespaceCharacters characterIsMember:[argumentsScanner.string characterAtIndex:argumentsScanner.scanLocation]] )
			argumentsScanner.scanLocation++;

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
			[self _sendMessage:msg withEncoding:encoding toTarget:room withTargetPrefix:targetPrefix withAttributes:@{ } localEcho:echo];
			return;
		}

		MVChatUser *user = [[self chatUsersWithNickname:targetName] anyObject];
		if( user ) {
			[self _sendMessage:msg withEncoding:encoding toTarget:user withTargetPrefix:@"" withAttributes:@{ } localEcho:echo];
			return;
		}

		return;
	} else if( [command isCaseInsensitiveEqualToString:@"j"] || [command isCaseInsensitiveEqualToString:@"join"] ) {
		NSString *roomsString = MVChatStringAsString(arguments);
		NSArray *roomStrings = [roomsString componentsSeparatedByString:@","];
		NSMutableArray *roomsToJoin = [[NSMutableArray alloc] initWithCapacity:roomStrings.count];

		for( __strong NSString *room in roomStrings ) {
			room = [room stringByTrimmingCharactersInSet:whitespaceCharacters];
			if( room.length )
				[roomsToJoin addObject:room];
		}

		if( roomsToJoin.count)
			[self joinChatRoomsNamed:roomsToJoin];
		else if( isRoom )
			[target join];

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
		__strong MVChatUser *strongUser = user;
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:[newNickname lowercaseString]];
		[user _setNickname:newNickname];
		_knownUsers[[user uniqueIdentifier]] = user;
		strongUser = nil;
	}
}

- (void) _setCurrentNickname:(NSString *) currentNickname {
	MVSafeCopyAssign( _currentNickname, currentNickname );
	[_localUser _setUniqueIdentifier:[currentNickname lowercaseString]];
}

- (NSString *) _nextPossibleNicknameFromNickname:(NSString *) nickname {
	if( ( _failedNickname && [_failedNickname isCaseInsensitiveEqualToString:nickname] ) || _nicknameShortened) {
		NSString *nick = [NSString stringWithFormat:@"%@-%d", [nickname substringToIndex:(nickname.length - 2)], _failedNicknameCount];

		_nicknameShortened = YES;

		if ( _failedNicknameCount < 9 ) _failedNicknameCount++;
		else _failedNicknameCount = 1;

		return nick;
	}

	return [nickname stringByAppendingString:@"_"];
}

#pragma mark -

- (void) _startTLS {
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	settings[GCDAsyncSocketSSLSessionOptionSendOneByteRecord] = @(0);
	settings[GCDAsyncSocketSSLSessionOptionFalseStart] = @(0);
	settings[GCDAsyncSocketManuallyEvaluateTrust] = @(1);

	[_chatConnection startTLS:settings];
}

- (void) _handleConnect {
	MVSafeRetainAssign( _queueWait, [NSDate dateWithTimeIntervalSinceNow:0.5] );
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _resetSendQueueInterval];
		[self _didConnect];
	});
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

- (void) _requestServerNotificationsOfUserConnectedState {
	NSString *userObservationPrefix = nil;
	NSString *appendFormat = nil;
	if( [_supportedFeatures containsObject:MVChatConnectionMonitor] ) {
		userObservationPrefix = @"MONITOR + ";
		appendFormat = @"%@,";
	} else if( [_supportedFeatures containsObject:MVChatConnectionWatchFeature] ) {
		userObservationPrefix = @"WATCH ";
		appendFormat = @"+%@ ";
	} else return;

	NSMutableString *request = [[NSMutableString alloc] initWithCapacity:JVMaximumWatchCommandLength];
	[request setString:userObservationPrefix];

	@synchronized( _chatUserWatchRules ) {
		for( MVChatUserWatchRule *rule in _chatUserWatchRules ) {
			NSString *nick = [rule nickname];
			if( nick && ! [rule nicknameIsRegularExpression] ) {
				if( ( nick.length + request.length + 1 ) > JVMaximumWatchCommandLength ) {
					[self sendRawMessage:request];

					request = [[NSMutableString alloc] initWithCapacity:JVMaximumWatchCommandLength];
					[request setString:userObservationPrefix];
				}

				[request appendFormat:appendFormat, nick];
			}
		}
	}

	if( ! [request isEqualToString:userObservationPrefix] )
		[self sendRawMessage:request];
}

#pragma mark -

- (void) _periodicEvents {
	MVAssertMainThreadRequired();
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
	[self sendRawMessage:[@"PING " stringByAppendingString:_realServer?:self.server] immediately:YES];
}

- (void) _pingServerAfterInterval {
	if ( _status != MVChatConnectionConnectingStatus && _status != MVChatConnectionConnectedStatus)
		return;

	_nextPingTimeInterval = [NSDate timeIntervalSinceReferenceDate] + JVPingServerInterval ;
	double delayInSeconds = JVPingServerInterval + 1.;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	__weak __typeof__((self)) weakSelf = self;
	dispatch_after(popTime, _connectionQueue, ^(void){
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		NSTimeInterval nowTimeInterval = [NSDate timeIntervalSinceReferenceDate];
		if (strongSelf->_nextPingTimeInterval < nowTimeInterval) {
			strongSelf->_nextPingTimeInterval = nowTimeInterval + JVPingServerInterval;
			[strongSelf _pingServer];
		}
	});
}

- (void) _startSendQueue {
	MVAssertMainThreadRequired();
	if( _sendQueueProcessing ) return;
	_sendQueueProcessing = YES;

	if( _queueWait && [_queueWait timeIntervalSinceNow] > 0. )
		[self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:[_queueWait timeIntervalSinceNow]];
	else [self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:[self minimumSendQueueDelay]];
}

- (void) _stopSendQueue {
	MVAssertMainThreadRequired();
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _sendQueue ) object:nil];
	_sendQueueProcessing = NO;
}

- (void) _resetSendQueueInterval {
	MVAssertMainThreadRequired();
	[self _stopSendQueue];

	@synchronized( _sendQueue ) {
		if( _sendQueue.count )
			[self _startSendQueue];
	}
}

- (void) _sendQueue {
	MVAssertMainThreadRequired();
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
		data = _sendQueue[0];
		[_sendQueue removeObjectAtIndex:0];

		if( _sendQueue.count )
			[self performSelector:@selector( _sendQueue ) withObject:nil afterDelay:MIN( [self minimumSendQueueDelay] + ( _sendQueue.count * [self sendQueueDelayIncrement] ), [self maximumSendQueueDelay] )];
		else _sendQueueProcessing = NO;
	}

	__weak __typeof__((self)) weakSelf = self;
	dispatch_async(_connectionQueue, ^{
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		MVSafeAdoptAssign( strongSelf->_lastCommand, [[NSDate alloc] init] );
		[strongSelf _writeDataToServer:data];
	});
}

#pragma mark -

- (void) _addDirectClientConnection:(id) connection {
	if( ! _directClientConnections )
		_directClientConnections = [[NSMutableSet alloc] initWithCapacity:5];
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
	// Don't WHOIS server operators, since they can often see the WHOIS request and get annoyed.
	if( [user isServerOperator] )
		return;

	if( ! _pendingWhoisUsers )
		_pendingWhoisUsers = [[NSMutableSet alloc] initWithCapacity:50];

	[_pendingWhoisUsers addObject:user];

	if( _pendingWhoisUsers.count == 1 )
		[self _whoisNextScheduledUser];
}

- (void) _whoisNextScheduledUser {
	if( _pendingWhoisUsers.count ) {
		MVChatUser *user = [_pendingWhoisUsers anyObject];
		[user refreshInformation];
	}
}

//- (void) _whoisWatchedUsers {
//	MVAssertMainThreadRequired();
//	[self performSelector:@selector( _whoisWatchedUsers ) withObject:nil afterDelay:JVWatchedUserWHOISDelay];
//
//	NSMutableSet *matchedUsers = [NSMutableSet set];
//	@synchronized( _chatUserWatchRules ) {
//		if( ! _chatUserWatchRules.count ) return; // nothing to do, return and wait until the next scheduled fire
//
//		for( MVChatUserWatchRule *rule in _chatUserWatchRules )
//			[matchedUsers unionSet:[rule matchedChatUsers]];
//	}
//
//	for( MVChatUser *user in matchedUsers )
//		[self _scheduleWhoisForUser:user];
//}

- (void) _checkWatchedUsers {
	MVAssertMainThreadRequired();
	if( [self.supportedFeatures containsObject:MVChatConnectionWatchFeature] ) return; // we don't need to call this anymore, return before we reschedule
	if( [self.supportedFeatures containsObject:MVChatConnectionMonitor] ) return; // we don't need to call this anymore, return before we reschedule

	[self performSelector:@selector( _checkWatchedUsers ) withObject:nil afterDelay:JVWatchedUserISONDelay];

	if( _lastSentIsonNicknames.count ) return; // there is already pending ISON requests, skip this round to catch up

	NSMutableSet *matchedUsers = [NSMutableSet set];
	@synchronized( _chatUserWatchRules ) {
		if( ! _chatUserWatchRules.count ) return; // nothing to do, return and wait until the next scheduled fire

		for( MVChatUserWatchRule *rule in _chatUserWatchRules )
			[matchedUsers unionSet:[rule matchedChatUsers]];
	}

	NSMutableString *request = [[NSMutableString alloc] initWithCapacity:JVMaximumISONCommandLength];
	[request setString:@"ISON "];

	_isonSentCount = 0;

	_lastSentIsonNicknames = [[NSMutableSet alloc] initWithCapacity:( _chatUserWatchRules.count * 5 )];

	for( MVChatUser *user in matchedUsers ) {
		if( ! [[user connection] isEqual:self] )
			continue;

		NSString *nick = [user nickname];
		NSString *nickLower = [nick lowercaseString];

		if( nick.length && ! [_lastSentIsonNicknames containsObject:nickLower] ) {
			if( ( nick.length + request.length ) > JVMaximumISONCommandLength ) {
				[self sendRawMessage:request];
				_isonSentCount++;

				request = [[NSMutableString alloc] initWithCapacity:JVMaximumISONCommandLength];
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
					_isonSentCount++;

					request = [[NSMutableString alloc] initWithCapacity:JVMaximumISONCommandLength];
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
}

#pragma mark -

- (NSString *) _newStringWithBytes:(const char *) bytes length:(NSUInteger) length NS_RETURNS_RETAINED {
	if( bytes && length ) {
		NSStringEncoding encoding = [self encoding];
		if( encoding != NSUTF8StringEncoding && isValidUTF8( bytes, length ) )
			encoding = NSUTF8StringEncoding;
		NSString *ret = [[NSString alloc] initWithBytes:bytes length:length encoding:encoding];
		if( ! ret && encoding != JVFallbackEncoding ) ret = [[NSString alloc] initWithBytes:bytes length:length encoding:JVFallbackEncoding];
		return ret;
	}

	if( bytes && ! length )
		return @"";
	return nil;
}

- (NSString *) _stringFromPossibleData:(id) input {
	if( [input isKindOfClass:[NSData class]] )
		return [self _newStringWithBytes:[input bytes] length:[input length]];
	return input;
}

#pragma mark -

- (NSCharacterSet *) _nicknamePrefixes {
	NSCharacterSet *prefixes = _serverInformation[@"roomMemberPrefixes"];
	if( prefixes ) return prefixes;

	static NSCharacterSet *defaultPrefixes = nil;
	if( !defaultPrefixes )
		defaultPrefixes = [NSCharacterSet characterSetWithCharactersInString:@"@+"];
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

- (MVChatRoomMemberMode) _stripModePrefixesFromNickname:(NSString *__nonnull *__nonnull) nicknamePtr {
	NSString *nickname = *nicknamePtr;
	MVChatRoomMemberMode modes = MVChatRoomMemberNoModes;
	NSMutableDictionary *prefixes = _serverInformation[@"roomMemberPrefixTable"];

	NSUInteger i = 0;
	NSUInteger length = nickname.length;
	for( i = 0; i < length; ++i ) {
		if( prefixes.count ) {
			NSNumber *prefix = prefixes[[NSString stringWithFormat:@"%c", [nickname characterAtIndex:i]]];
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
	_sendEndCapabilityCommandAtTime = 0.;
}

- (void) _sendEndCapabilityCommandAfterTimeout {
	[self _cancelScheduledSendEndCapabilityCommand];

	_sendEndCapabilityCommandAtTime = [NSDate timeIntervalSinceReferenceDate] + JVEndCapabilityTimeoutDelay;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(JVEndCapabilityTimeoutDelay * NSEC_PER_SEC)), _connectionQueue, ^{
		[self _sendEndCapabilityCommandForcefully:NO];
	});
}

- (void) _sendEndCapabilityCommandSoon {
	[self _cancelScheduledSendEndCapabilityCommand];

	_sendEndCapabilityCommandAtTime = [NSDate timeIntervalSinceReferenceDate] + 1.;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1. * NSEC_PER_SEC)), _connectionQueue, ^{
		[self _sendEndCapabilityCommandForcefully:NO];
	});
}

- (void) _sendEndCapabilityCommandForcefully:(BOOL) forcefully {
	if( _sentEndCapabilityCommand )
		return;

	if( !forcefully && (!_sendEndCapabilityCommandAtTime || [NSDate timeIntervalSinceReferenceDate] < _sendEndCapabilityCommandAtTime))
		return;

	[self _cancelScheduledSendEndCapabilityCommand];

	_sentEndCapabilityCommand = YES;

	[self sendRawMessageImmediatelyWithFormat:@"CAP END"];
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionProtocolHandlers)

#pragma mark Connecting Replies

- (void) _handleCapWithParameters:(NSArray *) parameters fromSender:(id) sender {
	BOOL furtherNegotiation = NO;

	if( parameters.count >= 3 ) {
		NSString *subCommand = parameters[1];
		if( [subCommand isCaseInsensitiveEqualToString:@"LS"] || [subCommand isCaseInsensitiveEqualToString:@"ACK"] || [subCommand isCaseInsensitiveEqualToString:@"NEW"] || [subCommand isCaseInsensitiveEqualToString:@"LIST"] ) {
			NSString *capabilitiesString = [self _stringFromPossibleData:parameters[2]];

			// IRCv3.2 says that multiline CAP replies will prefix capabilities with a * for all but the last line
			if( [capabilitiesString isCaseInsensitiveEqualToString:@"*"] && parameters.count >= 4 )
				capabilitiesString = [self _stringFromPossibleData:parameters[3]];

			NSArray *capabilities = [capabilitiesString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			for( __strong NSString *capability in capabilities ) {
				BOOL sendCapReqForFeature = YES;

				// IRCv3.1 Required
				if( [capability isCaseInsensitiveEqualToString:@"sasl"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionSASLFeature];
					}

					if( self.nicknamePassword.length ) {
						if( [subCommand isCaseInsensitiveEqualToString:@"ACK"] ) {
							[self sendRawMessageImmediatelyWithFormat:@"AUTHENTICATE PLAIN"];
							furtherNegotiation = YES;
							sendCapReqForFeature = NO;
						}
					} else {
						[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self];
						sendCapReqForFeature = NO;
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"multi-prefix"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionMultipleNicknamePrefixFeature];
					}
				}

				// IRCv3.1 Optional
				else if( [capability isCaseInsensitiveEqualToString:@"tls"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionTLS];
					}

					self.secure = YES;
					self.serverPort = 6697; // Charybdis defaults to 6697 for SSL connections. Theoretically, STARTTLS support makes this a non-issue, but, this seems safer.
				} else if( [capability isCaseInsensitiveEqualToString:@"away-notify"]) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionAwayNotify];
					}

				} else if( [capability isCaseInsensitiveEqualToString:@"extended-join"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionExtendedJoin];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"account-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionAccountNotify];
					}
				}

				// IRCv3.2 Required
				else if( [capability isCaseInsensitiveEqualToString:@"account-tag"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionAccountTag];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"intents"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionMessageIntents];
					}
				}

				// IRCv3.2 Optional
				else if( [capability isCaseInsensitiveEqualToString:@"chghost"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionChghost];
					}
				}  else if( [capability isCaseInsensitiveEqualToString:@"server-time"] || [capability isCaseInsensitiveEqualToString:@"znc.in/server-time-iso"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionServerTime];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"userhost-in-names"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionUserhostInNames];
					}
				}

				// IRCv3.2 Proposed
				else if( [capability isCaseInsensitiveEqualToString:@"cap-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionCapNotify];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"self-message"] || [capability isCaseInsensitiveEqualToString:@"znc.in/self-message"] || [capability isCaseInsensitiveEqualToString:@"echo-message"] || [capability isCaseInsensitiveEqualToString:@"znc.in/echo-message"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionEchoMessage];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"invite-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVChatConnectionInvite];
					}
				}

				// ZNC plugins
				else if( [capability isCaseInsensitiveEqualToString:@"znc.in/playback"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures addObject:MVIRCChatConnectionZNCPluginPlaybackFeature];
					}

					if (!_hasRequestedPlaybackList) {
						_hasRequestedPlaybackList = YES;
						[self sendRawMessage:@"PRIVMSG *playback LIST" immediately:NO];
					}
				}

				// Unknown / future capabilities
				else {
					sendCapReqForFeature = NO;
				}

				if (sendCapReqForFeature) {
					if( [subCommand isCaseInsensitiveEqualToString:@"LS"] || [subCommand isCaseInsensitiveEqualToString:@"NEW"] ) {
						[self sendRawMessageImmediatelyWithFormat:@"CAP REQ :%@", capability.lowercaseString];
						furtherNegotiation = YES;
					}
				}
			}
		} else if( [subCommand isCaseInsensitiveEqualToString:@"DEL"] ) {
			NSString *capabilitiesString = [self _stringFromPossibleData:parameters[2]];
			NSArray *capabilities = [capabilitiesString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			for( NSString *capability in capabilities ) {
				if( [capability isCaseInsensitiveEqualToString:@"sasl"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionSASLFeature];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"multi-prefix"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionMultipleNicknamePrefixFeature];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"tls"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionTLS];
					}
					self.secure = NO;
					self.serverPort = 6667; // reset back to default
				} else if( [capability isCaseInsensitiveEqualToString:@"away-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionAwayNotify];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"extended-join"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionExtendedJoin];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"account-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionAccountNotify];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"cap-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionAccountNotify];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"self-message"] || [capability isCaseInsensitiveEqualToString:@"znc.in/self-message"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionEchoMessage];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"chghost"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionChghost];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"invite-notify"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionInvite];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"account-tag"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionAccountTag];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"intents"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionMessageIntents];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"server-time"] || [capability isCaseInsensitiveEqualToString:@"znc.in/server-time-iso"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionServerTime];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"userhost-in-names"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVChatConnectionUserhostInNames];
					}
				} else if( [capability isCaseInsensitiveEqualToString:@"znc.in/playback"] ) {
					@synchronized( _supportedFeatures ) {
						[_supportedFeatures removeObject:MVIRCChatConnectionZNCPluginPlaybackFeature];
					}
				}

			}
		}
	}

	if( furtherNegotiation )
		[self _sendEndCapabilityCommandAfterTimeout];
	else
		[self _sendEndCapabilityCommandSoon];
}

- (void) _handleAuthenticateWithParameters:(NSArray *) parameters fromSender:(id) sender {
	if( parameters.count >= 1 && [[self _stringFromPossibleData:parameters[0]] isEqualToString:@"+"] ) {
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
	} else [self _sendEndCapabilityCommandForcefully:YES];
}

- (void) _handle900WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_LOGGEDIN
	if( parameters.count >= 4 ) {
		NSString *message = [self _stringFromPossibleData:parameters[3]];
		if( [message hasCaseInsensitiveSubstring:@"You are now logged in as "] ) {
			if( !self.localUser.identified )
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:@{ @"user": sender, @"target": parameters[2] }];
			[[self localUser] _setIdentified:YES];
		}
	}
}

- (void) _handle903WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_SASLSUCCESS
	[self _sendEndCapabilityCommandForcefully:YES];
}

- (void) _handle904WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLFAIL
	[self.localUser _setIdentified:NO];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self];

	[self _sendEndCapabilityCommandForcefully:YES];
}

- (void) _handle905WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLTOOLONG
	[self _sendEndCapabilityCommandForcefully:YES];
}

- (void) _handle906WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLABORTED
	[self _sendEndCapabilityCommandForcefully:YES];
}

- (void) _handle907WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SASLALREADY
	[self _sendEndCapabilityCommandForcefully:YES];
}

- (void) _handle001WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WELCOME
	[self _cancelScheduledSendEndCapabilityCommand];

	[self _handleConnect];

	// set the _realServer because it's different from the server we connected to
	MVSafeCopyAssign( _realServer, sender );

	// set the current nick name if it is not the same as what re requested (some servers/bouncers will give us a new nickname)
	if( parameters.count >= 1 ) {
		NSString *nick = [self _stringFromPossibleData:parameters[0]];
		if( ! [nick isEqualToString:[self nickname]] ) {
			[self _setCurrentNickname:nick];
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNicknameAcceptedNotification object:self];
		}
	}

	if( _pendingIdentificationAttempt && [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) {
		// workaround for ustream which uses PASS rather than NickServ for nickname identification, so 001 counts as successful identification
		_pendingIdentificationAttempt = NO;
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:@{ @"user": @"Ustream", @"target": [self nickname] }];
		[[self localUser] _setIdentified:YES];
	} else if( !self.localUser.identified ) {
		// Identify with services
		[self _identifyWithServicesUsingNickname:[self preferredNickname]]; // identifying proactively -> preferred nickname
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self performSelector:@selector(_checkWatchedUsers) withObject:nil afterDelay:2.];
	});
}

- (void) _handle005WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ISUPPORT
	if( ! _serverInformation )
		_serverInformation = [[NSMutableDictionary alloc] initWithCapacity:5];

	BOOL foundNAMESXCommand = NO;
	for( NSString *feature in parameters ) {
		// IRCv3.x
		if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"STARTTLS"] ) {
			[_supportedFeatures addObject:MVChatConnectionTLS];
		} else if ( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"METADATA"] ) {
			[_supportedFeatures addObject:MVChatConnectionMetadata];
		} else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"WATCH"] ) {
			@synchronized(_supportedFeatures) {
				[_supportedFeatures addObject:MVChatConnectionWatchFeature];
			}
		} else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"MONITOR"] ) {
			@synchronized(_supportedFeatures) {
				[_supportedFeatures addObject:MVChatConnectionMonitor];
			}
		} else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"UHNAMES"] ) {
			@synchronized(_supportedFeatures) {
				[_supportedFeatures addObject:MVChatConnectionUserhostInNames];
			}
		}

		// InspIRCd
		else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"NAMESX"] ) {
			@synchronized(_supportedFeatures) {
				[_supportedFeatures addObject:MVChatConnectionNamesx];
			}

			foundNAMESXCommand = YES;
		}

		// Standard 005's
		else if( [feature isKindOfClass:[NSString class]] && [feature hasPrefix:@"CHANTYPES="] ) {
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

					NSMutableDictionary *modesTable = [[NSMutableDictionary alloc] initWithCapacity:modes.length];
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
							NSString *key = [[NSString alloc] initWithFormat:@"%c", [modes characterAtIndex:i]];
							modesTable[key] = @(mode);

							if( modeFeature ) {
								@synchronized( _supportedFeatures ) {
									 [_supportedFeatures addObject:modeFeature];
								}
							}
						}
					}

					if( modesTable.count ) _serverInformation[@"roomMemberModeTable"] = modesTable;
					_serverInformation[@"roomMemberModes"] = [NSCharacterSet characterSetWithCharactersInString:modes];
				}

				NSString *prefixes = [feature substringFromIndex:[scanner scanLocation]];
				if( prefixes.length ) {
					NSMutableDictionary *prefixTable = [[NSMutableDictionary alloc] initWithCapacity:modes.length];
					NSUInteger length = prefixes.length;
					NSUInteger i = 0;
					for( i = 0; i < length; i++ ) {
						MVChatRoomMemberMode mode = [self _modeForNicknamePrefixCharacter:[prefixes characterAtIndex:i]];
						if( mode != MVChatRoomMemberNoModes ) {
							NSString *key = [[NSString alloc] initWithFormat:@"%c", [prefixes characterAtIndex:i]];
							prefixTable[key] = [NSNumber numberWithUnsignedLong:mode];
						}
					}

					if( prefixTable.count ) _serverInformation[@"roomMemberPrefixTable"] = prefixTable;
					_serverInformation[@"roomMemberPrefixes"] = [NSCharacterSet characterSetWithCharactersInString:prefixes];
				}
			}
		}
	}

	if( !_fetchingMonitorList && [_supportedFeatures containsObject:MVChatConnectionMonitor] ) {
		[self sendRawMessageImmediatelyWithFormat:@"MONITOR L"];
		_fetchingMonitorList = YES;
		_pendingMonitorList = [NSMutableArray array];
		return;
	}
	if( [_supportedFeatures containsObject:MVChatConnectionWatchFeature] )
		[self _requestServerNotificationsOfUserConnectedState];

	if( [_supportedFeatures containsObject:MVChatConnectionMetadata] ) {
		NSBundle *bundle = [NSBundle mainBundle];
		[self sendRawMessageImmediatelyWithFormat:@"METADATA SET client.name :%@", bundle.infoDictionary[(__bridge id)kCFBundleIdentifierKey]];
		[self sendRawMessageImmediatelyWithFormat:@"METADATA SET client.version :%@ (%@)", bundle.infoDictionary[@"CFBundleShortVersionString"], bundle.infoDictionary[@"CFBundleVersion"]];
	}

	if( foundNAMESXCommand && [_supportedFeatures containsObject:MVChatConnectionNamesx] ) {
		[self sendRawMessageImmediatelyWithFormat:@"PROTOCTL NAMESX"];
	}
}

- (void) _handle433WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NICKNAMEINUSE
	if( ! [self isConnected] ) {
		NSString *nick = [self nextAlternateNickname];
		if( ! nick.length && parameters.count >= 2 ) {
			NSString *lastNickTried = [self _stringFromPossibleData:parameters[1]];

			nick = [self _nextPossibleNicknameFromNickname:lastNickTried];
		}

		if ( ! _failedNickname ) _failedNickname = [[self _stringFromPossibleData:parameters[1]] copy];

		if( nick.length ) [self setNickname:nick];
	} else {
		// "<current nickname> <new nickname> :Cannot change nick"
		// - Sent to a user who is changing their nickname to a nickname someone else is actively using.

		if( parameters.count >= 2 ) {
			NSString *usedNickname = [self _stringFromPossibleData:parameters[0]];
			NSString *newNickname = [self _stringFromPossibleData:parameters[1]];

			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			userInfo[@"connection"] = self;
			userInfo[@"oldnickname"] = usedNickname;
			userInfo[@"newnickname"] = newNickname;

			if ( ! [newNickname isCaseInsensitiveEqualToString:usedNickname] ) {
				userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Can't change nick from \"%@\" to \"%@\" because it is already taken on \"%@\".", "cannot change used nickname error" ), usedNickname, newNickname, [self server]];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeUsedNickError userInfo:userInfo]];
			} else {
				userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Your nickname is being changed by services on \"%@\" because it is registered and you did not supply the correct password to identify.", "nickname changed by services error" ), [self server]];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionNickChangedByServicesError userInfo:userInfo]];
			}
		}
	}
}

- (void) _handle691WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_STARTTLS
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [parameters componentsJoinedByString:@" "] };
	[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionTLSError userInfo:userInfo]];
}

#pragma mark -
#pragma mark Incoming Message Replies

- (MVChatRoom*) _chatRoomFromMessageTarget:(NSString*)messageTarget
{
	// a room identifier consists of a chatroom prefix (for example #&+!) and the room name: #room
	// additionally it can be pre-prefixed in PRIVMSG or NOTICE with a nickname prefix (for example @+), indicating a room message, that is only visible to room members with that user status: @#room
	// some characters can occur in both groups (for example +), this was confusing the old code: +room

	/*
	 incomplete list of examples:
	 regular rooms
	 #room			#room
	 @#room		@	#room
	 +#room		+	#room <- could also be a double prefix, but unlikely
	 @+#room	@+	#room
	 rooms prefixed with + (no user modes). filtered messages are very unlikely here
	 +room			+room
	 @+room		@	+room
	 ++room		+	+room <- could also be a double prefix, but unlikely
	 @++room	@+	+room
	 double room prefix (freenode)
	 ##room			##room
	 @##room	@	##room
	 +##room	+	##room
	 @+##room	@+	##room
	 */

	MVChatRoom *room = nil;

	NSMutableCharacterSet* allPrefixesCharacterSet = [[self chatRoomNamePrefixes] mutableCopy];					// @+#
	[allPrefixesCharacterSet formUnionWithCharacterSet:[self _nicknamePrefixes]];
	NSMutableCharacterSet* ambiguousPrefixesCharacterSet = [[self chatRoomNamePrefixes] mutableCopy];			// +
	[ambiguousPrefixesCharacterSet formIntersectionWithCharacterSet:[self _nicknamePrefixes]];
	NSMutableCharacterSet* roomPrefixesCharacterSet = [[self chatRoomNamePrefixes] mutableCopy];				// #
	[roomPrefixesCharacterSet formIntersectionWithCharacterSet:[ambiguousPrefixesCharacterSet invertedSet]];
	NSMutableCharacterSet* nickPrefixesCharacterSet = [[self _nicknamePrefixes] mutableCopy];					// @
	[nickPrefixesCharacterSet formIntersectionWithCharacterSet:[ambiguousPrefixesCharacterSet invertedSet]];

	while ( !room && [messageTarget length] >= 1 ) {
		// if the first char of the messageTarget is a nick prefix OR if the first char is ambiguous and the second char is also a prefix: remove the first char and repeat
		if ( [nickPrefixesCharacterSet characterIsMember:[messageTarget characterAtIndex:0]] ||
			( [ambiguousPrefixesCharacterSet characterIsMember:[messageTarget characterAtIndex:0]] && [messageTarget length] >= 2 && [allPrefixesCharacterSet characterIsMember:[messageTarget characterAtIndex:1]] ) )
			messageTarget = [messageTarget substringFromIndex:1];
		// if the first char is a room prefix OR the first char is ambiguous and the target has no further chars or no further prefix chars: use this string as unique identifier, end the loop
		else if ( [roomPrefixesCharacterSet characterIsMember:[messageTarget characterAtIndex:0]] ||
				 ( [ambiguousPrefixesCharacterSet characterIsMember:[messageTarget characterAtIndex:0]] && ( [messageTarget length] < 2 || ( [messageTarget length] >= 2 && ![allPrefixesCharacterSet characterIsMember:[messageTarget characterAtIndex:1]] ) ) ) )
			room = [self chatRoomWithUniqueIdentifier:messageTarget];
		// first char is not nick or room or ambiguous: not a room identifier, end the loop
		else
			break;
	}

	return room;
}

- (void) _handleBatchWithParameters:(NSArray *) parameters tags:(NSDictionary *) tags fromSender:(MVChatUser *) sender {
	if( 2 > parameters.count )
		return;

	NSString *batchIdentifier = parameters[0];
	if (2 > batchIdentifier.length) // "+1" is the minimum we need; +/- and an identifier
		return;

	BOOL isStartingBatch = ( [batchIdentifier characterAtIndex:0] == '+' );
	BOOL isEndingBatch = ( [batchIdentifier characterAtIndex:0] == '-' );

	if ( !isStartingBatch && !isEndingBatch )
		return;

	batchIdentifier = [batchIdentifier substringFromIndex:1];

	NSDictionary *userInfo = @{
		@"identifier": batchIdentifier,
		@"type": parameters[1]
	};
	if( isStartingBatch )
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionBatchUpdatesWillBeginNotification object:self userInfo:userInfo];
	else [[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionBatchUpdatesDidEndNotification object:self userInfo:userInfo];
}

- (void) _handlePrivmsg:(NSMutableDictionary *) privmsgInfo {
#if ENABLE(PLUGINS)
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:privmsgInfo waitUntilDone:NO];
		return;
	}
	MVAssertMainThreadRequired();
#else
#endif

	__unsafe_unretained MVChatRoom *room = privmsgInfo[@"room"];
	__unsafe_unretained MVChatUser *sender = privmsgInfo[@"user"];
	__unsafe_unretained NSMutableData *message = privmsgInfo[@"message"];
#if ENABLE(PLUGINS)
	__unsafe_unretained NSMutableDictionary *unsafePrivmsgInfo = privmsgInfo;

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatUser * ), @encode( id ), @encode( NSMutableDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processIncomingMessageAsData:from:to:attributes: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&sender atIndex:3];
	[invocation setArgument:&room atIndex:4];
	[invocation setArgument:&unsafePrivmsgInfo atIndex:5];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	if( ! message.length ) return;

	if( room ) {
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:privmsgInfo];
	} else {
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:privmsgInfo];
	}
}

- (void) _handlePrivmsgWithParameters:(NSArray *) parameters tags:(NSDictionary *) tags fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *)sender];
	else if( !sender )
		sender = [self chatUserWithUniqueIdentifier:[self server]];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		// TODO: If/when mobile supports plugins, move this out of Chat Core and into a separate module.
		// TODO: Option make this infinitely-scrollable and request x amount of data when near/at the beginning of chat.
		//		 How does this interact with chat scrollback limits?
		if( UNLIKELY(_hasRequestedPlaybackList) && UNLIKELY([_supportedFeatures containsObject:MVIRCChatConnectionZNCPluginPlaybackFeature]) && UNLIKELY([sender.nickname isCaseInsensitiveEqualToString:@"*playback"]) ) {
			// << PRIVMSG *playback LIST
			// >> *playback PRIVMSG #example 1420604714.26 1420623254.90 // *sender cmd room earliest_msg latest_msg
			// parameters[0] = sender. parameters[1] = message data.
			// components[0] = buffer chat room/person name. components[1] = earliest timestamp. components[2] = latest timestamp

			if (parameters.count == 2) {
				NSArray *components = [[self _stringFromPossibleData:parameters[1]] componentsSeparatedByString:@" "];
				if (components.count == 3) {
					// 1. Find out if we have a channel or a query item. If we have a channel, we can stop doing any work,
					// because we make a *playback PLAY request for channels in response to JOINs.
					BOOL isChannel = [_roomPrefixes characterIsMember:[components[0] characterAtIndex:0]];
					if( isChannel )
						return;

					// 2. Look up the most recent activity we have saved locally for the query buffer.
					NSString *recentActivityDateKey = [NSString stringWithFormat:@"%@-%@", self.uniqueIdentifier, [components[0] lowercaseString]];
					NSDate *mostRecentActivity = [[NSUserDefaults standardUserDefaults] objectForKey:recentActivityDateKey];

					// 3. If we have any recent activity saved, request anything from the last timestamp we have saved. Otherwise,
					// we have to assume everything is new and request everything.
					if (mostRecentActivity)
						[self sendRawMessageImmediatelyWithFormat:@"PRIVMSG *playback PLAY %@ %.3f %@", components[0], [mostRecentActivity timeIntervalSince1970], components[2]];
					else [self sendRawMessageImmediatelyWithFormat:@"PRIVMSG *playback PLAY %@ 0", [components[0] copy]];
				}
			}

			return;
		}

		NSString *targetName = parameters[0];
		if( ! targetName.length ) return;

		[sender _setIdleTime:0.];
		[self _markUserAsOnline:sender];

		MVChatRoom *room = [self _chatRoomFromMessageTarget:targetName];

		MVChatUser *targetUser = nil;
		if( !room ) targetUser = [self chatUserWithUniqueIdentifier:targetName];

		id target = room;
		if( !target ) target = targetUser;

		id msgData = parameters[1];
		if (![msgData respondsToSelector:@selector(bytes)])
		{
			if ( ![msgData respondsToSelector:@selector(dataUsingEncoding:)] ) {
				NSLog(@"Dropping message because we do not know how to handle PRIVMSG parameters: %@", parameters);
				return;
			}
			msgData = [msgData dataUsingEncoding:self.encoding];
		}
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && [msgData length] > 2 );

		if( ctcp ) {
			[self _handleCTCP:msgData asRequest:YES fromSender:sender toTarget:target forRoom:room withTags:tags];
		} else {
			NSMutableDictionary *privmsgInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:msgData, @"message", sender, @"user", [NSString locallyUniqueString], @"identifier", target, @"target", room, @"room", nil];
			[privmsgInfo addEntriesFromDictionary:tags];
			if( [privmsgInfo[@"intent"] isCaseInsensitiveEqualToString:@"ACTION"] )
				privmsgInfo[@"action"] = @(YES);

			@autoreleasepool {
				[self _handlePrivmsg:privmsgInfo];
			}
		}
	}
}

- (void) _handlePrivmsgWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	[self _handlePrivmsgWithParameters:parameters tags:@{} fromSender:sender];
}

- (void) _handleNotice:(NSMutableDictionary *) noticeInfo {
#if ENABLE(PLUGINS)
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:noticeInfo waitUntilDone:NO];
		return;
	}
	MVAssertMainThreadRequired();
#else
#endif

	id target = noticeInfo[@"target"];
	__unsafe_unretained MVChatRoom *room = noticeInfo[@"room"];
	__unsafe_unretained MVChatUser *sender = noticeInfo[@"user"];
	__unsafe_unretained NSMutableData *message = noticeInfo[@"message"];
#if ENABLE(PLUGINS)
	__unsafe_unretained NSMutableDictionary *unsafeNoticeInfo = noticeInfo;

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatUser * ), @encode( id ), @encode( NSMutableDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processIncomingMessageAsData:from:to:attributes: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&sender atIndex:3];
	[invocation setArgument:&room atIndex:4];
	[invocation setArgument:&unsafeNoticeInfo atIndex:5];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	if( ! message.length ) return;

	if( room ) {
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:noticeInfo];
	} else {
		if( [[sender nickname] isCaseInsensitiveEqualToString:[self server]] || ( _realServer && [[sender nickname] isCaseInsensitiveEqualToString:_realServer] ) || [[sender nickname] isCaseInsensitiveEqualToString:@"irc.umich.edu"] ) {
			NSString *msg = [self _newStringWithBytes:[message bytes] length:message.length];

			// Auto reply to servers asking us to send a PASS because they could not detect an identd
			if (![self isConnected]) {
				NSString *matchedPassword = [msg stringByMatching:@"/QUOTE PASS (\\w+)" options:NSRegularExpressionCaseInsensitive inRange:NSMakeRange(0, msg.length) capture:1 error:NULL];
				if( matchedPassword ) [self sendRawMessageImmediatelyWithFormat:@"PASS %@", matchedPassword];
				if( [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) {
					if( [msg isEqualToString:@"This is a registered nick, either choose another nick or enter the password by doing: /PASS <password>"] ) {
						if( ! [[self nicknamePassword] length] )
							[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self];
						else [self _identifyWithServicesUsingNickname:[self nickname]];
					} else if( [msg isEqualToString:@"Incorrect password for this account"] ) {
						[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self];
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
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** Notice -- For more information please visit"] )
				handled = YES;
			if( !handled && [msg hasCaseInsensitiveSubstring:@"*** You are connected to"] )
				handled = YES;
			if( !handled && [msg isMatchedByRegex:@"\\*\\*\\* Notice -- If you see.*? connections.*? from" options:NSRegularExpressionCaseInsensitive inRange:NSMakeRange(0, msg.length) error:NULL] )
				handled = YES;
			if( !handled && [msg isMatchedByRegex:@"\\*\\*\\* Notice -- please disregard them, as they are the .+? in action" options:NSRegularExpressionCaseInsensitive inRange:NSMakeRange(0, msg.length) error:NULL] )
				handled = YES;
			if( !handled && [msg isMatchedByRegex:@"on .+? ca .+?\\(.+?\\) ft .+?\\(.+?\\)" options:NSRegularExpressionCaseInsensitive inRange:NSMakeRange(0, msg.length) error:NULL] )
				handled = YES;

			if( handled ) noticeInfo[@"handled"] = @(YES);

		} else if( ![self isConnected] && [[sender nickname] isCaseInsensitiveEqualToString:@"Welcome"] ) {
			// Workaround for psybnc bouncers which are configured to combine multiple networks in one bouncer connection. These bouncers don't send a 001 command on connect...
			// Catch ":Welcome!psyBNC@lam3rz.de NOTICE * :psyBNC2.3.2-7" on these connections instead:
			NSString *msg = [self _newStringWithBytes:[message bytes] length:message.length];
			if( [msg hasCaseInsensitiveSubstring:@"psyBNC"] ) {
				[self _handleConnect];
			}
		} else if ( [sender.nickname isEqualToString:@"Global"] && [sender.username isEqualToString:@"Global"] && [sender.address isEqualToString:@"Services.GameSurge.net"] && [[self server] hasCaseInsensitiveSubstring:@"gamesurge"] ) {
			// GameSurge's Global bot sends a 'message of the day' via multiple notices after connecting:
			/*
			 :------------- MESSAGE(S) OF THE DAY --------------
			 :[users] Notice from feigling, posted 05:24 PM, 07/17/2008:
			 :GameSurge provides a new service called SpamServ which moderates your channel. If you are interested in learning more about it read http://www.gamesurge.net/cms/SpamServ
			 :[users] Notice from GameSurge, posted 09:44 AM, 03/24/2008:
			 :Please remember that you should never give out your AuthServ account password to anyone. Network staff will not ask you for your password, and network services will never pm you requesting it. Recently malicious users have been posing as network services using nicknames such as "Info" and requesting passwords from users. These are scams.
			 :[users] Notice from GameSurge, posted 09:27 AM, 01/20/2007:
			 :Please be familiar with the GameSurge Acceptable Use Policy. All users on the network are required to abide by it. http://www.gamesurge.net/aup/
			 :---------- END OF MESSAGE(S) OF THE DAY ----------
			 */

			NSString *msg = [self _newStringWithBytes:[message bytes] length:message.length];

			if ( [msg isEqualToString:@"------------- MESSAGE(S) OF THE DAY --------------"] )
				_gamesurgeGlobalBotMOTD = YES;

			if ( _gamesurgeGlobalBotMOTD ) {
				noticeInfo[@"handled"] = @(YES);

				if ( [msg isEqualToString:@"---------- END OF MESSAGE(S) OF THE DAY ----------"] )
					_gamesurgeGlobalBotMOTD = NO;
			}

		} else if( [[MVIRCChatUser servicesNicknames] containsObject:[[sender nickname] lowercaseString]] ) {
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

				if( [self.supportedFeatures containsObject:MVChatConnectionAccountNotify] && self.localUser.isIdentified )
					[self sendRawMessageImmediatelyWithFormat:@"ACCOUNT %@", self.localUser.account];

				if( ![[self localUser] isIdentified] )
					[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:noticeInfo];
				[[self localUser] _setIdentified:YES];

				noticeInfo[@"handled"] = @(YES);

			} else if( ( [msg hasCaseInsensitiveSubstring:@"NickServ"] && [msg hasCaseInsensitiveSubstring:@" ID"] ) ||
					  [msg hasCaseInsensitiveSubstring:@"identify yourself"] ||
					  [msg hasCaseInsensitiveSubstring:@"authenticate yourself"] ||
					  [msg hasCaseInsensitiveSubstring:@"authentication required"] ||
					  [msg hasCaseInsensitiveSubstring:@"nickname is registered"] ||
					  [msg hasCaseInsensitiveSubstring:@"nickname is owned"] ||
					  [msg hasCaseInsensitiveSubstring:@"nick belongs to another user"] ||
					  [msg hasCaseInsensitiveSubstring:@"if you do not change your nickname"] ||
					  ( [[self server] hasCaseInsensitiveSubstring:@"oftc"] && ( [msg isCaseInsensitiveEqualToString:@"getting this message because you are not on the access list for the"] || [msg isCaseInsensitiveEqualToString:[NSString stringWithFormat:@"\002%@\002 nickname.", [self nickname]]] ) ) ) {

				[[self localUser] _setIdentified:NO];

				if( ! [[self nicknamePassword] length] )
					[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self];
				else [self _identifyWithServicesUsingNickname:[self nickname]]; // responding to nickserv -> current nickname

				noticeInfo[@"handled"] = @(YES);

			} else if( ( [msg hasCaseInsensitiveSubstring:@"invalid"] ||		// NickServ/freenode, X/undernet
						 [msg hasCaseInsensitiveSubstring:@"incorrect"] ) &&	// NickServ/dalnet+foonetic+sorcery+azzurra+webchat+rizon, Q/quakenet, AuthServ/gamesurge
					   ( [msg hasCaseInsensitiveSubstring:@"password"] || [msg hasCaseInsensitiveSubstring:@"identify"] || [msg hasCaseInsensitiveSubstring:@"identification"] ) ) {

				_pendingIdentificationAttempt = NO;

				[[self localUser] _setIdentified:NO];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedNicknamePasswordNotification object:self];

				noticeInfo[@"handled"] = @(YES);

			} else if( [msg isCaseInsensitiveEqualToString:@"Syntax: \002IDENTIFY \037password\037\002"] ) {

				_pendingIdentificationAttempt = NO;

				[[self localUser] _setIdentified:NO];

				[self _identifyWithServicesUsingNickname:[self nickname]]; // responding nickserv error about the "nickserv identify <nick> <pass>" syntax -> current nickname

				noticeInfo[@"handled"] = @(YES);

			} else if( [msg isCaseInsensitiveEqualToString:@"Remember: Nobody from CService will ever ask you for your password, do NOT give out your password to anyone claiming to be CService."] ||													// Undernet
					  [msg isCaseInsensitiveEqualToString:@"REMINDER: Do not share your password with anyone. DALnet staff will not ask for your password unless"] || [msg hasCaseInsensitiveSubstring:@"you are seeking their assistance. See"] ||		// DALnet
					  [msg hasCaseInsensitiveSubstring:@"You have been invited to"] ) {	// ChanServ invite, hide since it's auto accepted

				noticeInfo[@"handled"] = @(YES);

			} else if ([[sender nickname] isEqualToString:@"ChanServ"] && [msg hasCaseInsensitiveSubstring:@"You're already on"])
				noticeInfo[@"handled"] = @(YES);

			// Catch "[#room] - Welcome to #room!" notices and show them in the room instead
			NSString *possibleRoomPrefix = [msg stringByMatching:@"^[\\[\\(](.+?)[\\]\\)]" capture:1];
			if( possibleRoomPrefix && possibleRoomPrefix.length && [[self chatRoomNamePrefixes] characterIsMember:[possibleRoomPrefix characterAtIndex:0]] ) {
				MVChatRoom *roomInWelcomeToRoomNotice = [self chatRoomWithUniqueIdentifier:possibleRoomPrefix];
				if( roomInWelcomeToRoomNotice ) {
					[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:roomInWelcomeToRoomNotice userInfo:noticeInfo];
					noticeInfo[@"handled"] = @(YES);
				}
			}
		}

		if( target == room || ( [target isKindOfClass:[MVChatUser class]] && [target isLocalUser] ) )
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:noticeInfo];
	}
}

- (void) _handleNoticeWithParameters:(NSArray *) parameters tags:(NSDictionary *) tags fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *)sender];
	else if( !sender )
		sender = [self chatUserWithUniqueIdentifier:[self server]];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *targetName = parameters[0];
		if( ! targetName.length ) return;

		[sender _setIdleTime:0.];
		[self _markUserAsOnline:sender];

		MVChatRoom *room = [self _chatRoomFromMessageTarget:targetName];

		MVChatUser *targetUser = nil;
		if( !room ) targetUser = [self chatUserWithUniqueIdentifier:targetName];

		id target = room;
		if( !target ) target = targetUser;

		NSMutableData *msgData = parameters[1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && msgData.length > 2 );

		if( ctcp ) {
			[self _handleCTCP:msgData asRequest:NO fromSender:sender toTarget:target forRoom:room withTags:tags];
		} else {
			NSMutableDictionary *noticeInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:msgData, @"message", sender, @"user", [NSString locallyUniqueString], @"identifier", @(YES), @"notice", target, @"target", room, @"room", nil];
			[noticeInfo addEntriesFromDictionary:tags];
			[self _handleNotice:noticeInfo];
		}
	}
}

- (void) _handleNoticeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	[self _handleNoticeWithParameters:parameters tags:@{} fromSender:sender];
}

- (void) _handleCTCP:(NSDictionary *) ctcpInfo {
#if ENABLE(PLUGINS)
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:ctcpInfo waitUntilDone:NO];
		return;
	}
	MVAssertMainThreadRequired();
#else
#endif

	BOOL request = [ctcpInfo[@"request"] boolValue];
	NSData *data = ctcpInfo[@"data"];
	MVChatUser *sender = ctcpInfo[@"sender"];
	MVChatRoom *room = ctcpInfo[@"room"];
	id target = ctcpInfo[@"target"];

	const char *line = (const char *)[data bytes] + 1; // skip the \001 char
	const char *end = line + data.length - 2; // minus the first and last \001 char
	const char *current = line;

	while( line != end && *line != ' ' ) line++;

	NSString *command = [self _newStringWithBytes:current length:(line - current)];
	NSMutableData *arguments = nil;
	if( line != end ) {
		line++;
		arguments = [[NSMutableData alloc] initWithBytes:line length:(end - line)];
	}

	if( [command isCaseInsensitiveEqualToString:@"ACTION"] && arguments ) {
		// special case ACTION and send it out like a message with the action flag
		NSMutableDictionary *msgInfo = [NSMutableDictionary dictionary];
		if (ctcpInfo) [msgInfo addEntriesFromDictionary:ctcpInfo];
		if (arguments) msgInfo[@"message"] = arguments;
		if (sender) msgInfo[@"user"] = sender;
		msgInfo[@"identifier"] = [NSString locallyUniqueString];
		msgInfo[@"action"] = @(YES);
		if (target) msgInfo[@"target"] = target;
		if (room) msgInfo[@"room"] = room;

		@autoreleasepool {
			[self _handlePrivmsg:msgInfo]; // No need to explicitly call this on a different thread, as we are already in it.
		}

		return;
	}

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	if (command) userInfo[@"command"] = command;
	if (arguments) userInfo[@"arguments"] = arguments;

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:( request ? MVChatConnectionSubcodeRequestNotification : MVChatConnectionSubcodeReplyNotification ) object:sender userInfo:userInfo];

#if ENABLE(PLUGINS)
	__unsafe_unretained NSString *unsafeCommand = command;
	__unsafe_unretained NSMutableData *unsafeArguments = arguments;
	__unsafe_unretained MVChatUser *unsafeSender = sender;

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatUser * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	if( request ) [invocation setSelector:@selector( processSubcodeRequest:withArguments:fromUser: )];
	else [invocation setSelector:@selector( processSubcodeReply:withArguments:fromUser: )];
	[invocation setArgument:&unsafeCommand atIndex:2];
	[invocation setArgument:&unsafeArguments atIndex:3];
	[invocation setArgument:&unsafeSender atIndex:4];

	command = nil;
	arguments = nil;
	sender = nil;

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) {
		return;
	}
#endif

	if( request ) {
		if( [command isCaseInsensitiveEqualToString:@"VERSION"] ) {
			NSDictionary *systemVersion = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
			if( !systemVersion ) systemVersion = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
			NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];

#if defined(__ppc__) && __ppc__
			NSString *processor = @"PowerPC";
#elif (defined(__i386__) && __i386__) || (defined(__x86_64__) && __x86_64__)
			NSString *processor = @"Intel";
#elif (defined(__arm__) && __arm__) || (defined(__arm64__) && __arm64__)
			NSString *processor = @"ARM";
#else
			NSString *processor = @"Unknown Architecture";
#endif

			NSString *reply = [[NSString alloc] initWithFormat:@"%@ %@ (%@) - %@ %@ (%@) - %@", clientVersion[@"CFBundleName"], clientVersion[@"CFBundleShortVersionString"], clientVersion[@"CFBundleVersion"], systemVersion[@"ProductName"], systemVersion[@"ProductVersion"], processor, clientVersion[@"MVChatCoreCTCPVersionReplyInfo"]];
			[sender sendSubcodeReply:command withArguments:reply];
		} else if( [command isCaseInsensitiveEqualToString:@"TIME"] ) {
			[sender sendSubcodeReply:command withArguments:[[NSDate date] localizedDescription]];
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
					address = [NSString stringWithFormat:@"%d.%d.%d.%d", (ip4 & 0xff000000) >> 24, (ip4 & 0x00ff0000) >> 16, (ip4 & 0x0000ff00) >> 8, (ip4 & 0x000000ff)];
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
					MVIRCDownloadFileTransfer *transfer = [(MVIRCDownloadFileTransfer *)[MVIRCDownloadFileTransfer alloc] initWithUser:sender];

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

					[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVDownloadFileTransferOfferNotification object:transfer];
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
					address = [NSString stringWithFormat:@"%d.%d.%d.%d", (ip4 & 0xff000000) >> 24, (ip4 & 0x00ff0000) >> 16, (ip4 & 0x0000ff00) >> 8, (ip4 & 0x000000ff)];
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
						MVDirectChatConnection *directChatConnection = [(MVDirectChatConnection *)[MVDirectChatConnection alloc] initWithUser:sender];

						if( port == 0 && passive ) {
							[directChatConnection _setPassiveIdentifier:passiveId];
							[directChatConnection _setPassive:YES];
						} else {
							[directChatConnection _setHost:address];
							[directChatConnection _setPort:port];
						}

						[self _addDirectClientConnection:directChatConnection];

						[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionOfferNotification object:directChatConnection userInfo:@{ @"user": sender }];
					}
				}
			}
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
						for( MVIRCUploadFileTransfer *transfer in [_directClientConnections copy] ) {
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
		}
	}

}

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender toTarget:(id) target forRoom:(MVChatRoom *) room withTags:(NSDictionary *) tags {
	NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:4];

	if( tags )[info addEntriesFromDictionary:tags];
	if( data ) info[@"data"] = data;
	if( sender ) info[@"sender"] = sender;
	if( target ) info[@"target"] = target;
	if( room ) info[@"room"] = room;
	info[@"request"] = @(request);
	[self _handleCTCP:info];
}

#pragma mark -
#pragma mark Room Replies

- (void) _handleJoinWithParameters:(NSArray *) parameters tags:(NSDictionary *) tags fromSender:(MVChatUser *) sender {
	if( parameters.count >= 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *name = [self _stringFromPossibleData:parameters[0]];
		MVChatRoom *room = [self chatRoomWithName:name];

		if( [sender isLocalUser] ) {
			[_pendingJoinRoomNames removeObject:name];

			[room _setDateJoined:[NSDate date]];
			[room _setDateParted:nil];
			[room _clearMemberUsers];
			[room _clearBannedUsers];

			[room requestRecentActivity];
		} else {
			[sender _setIdleTime:0.];
			[self _markUserAsOnline:sender];
			[room _addMemberUser:sender];

			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			[userInfo addEntriesFromDictionary:tags];

			userInfo[@"user"] = sender;
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification object:room userInfo:userInfo];
		}

		if( parameters.count >= 3 ) {
			NSString *accountName = parameters[1];
			NSString *realName = [self _stringFromPossibleData:parameters[2]];

			[sender _setRealName:realName];
			if( [accountName isEqualToString:@"*"] )
				[sender _setAccount:nil];
			else [sender _setAccount:accountName];
		}
	}
}

- (void) _handleJoinWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	[self _handleJoinWithParameters:parameters tags:@{} fromSender:sender];
}

- (void) _handlePartWithParameters:(NSArray *) parameters tags:(NSDictionary *) tags fromSender:(MVChatUser *) sender {
	if( parameters.count >= 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *roomName = [self _stringFromPossibleData:parameters[0]];
		MVChatRoom *room = [self joinedChatRoomWithUniqueIdentifier:roomName];
		if( ! room ) return;

		[room _removeMemberUser:sender];

		NSData *reason = ( parameters.count >= 2 ? parameters[1] : nil );
		if( ! [reason isKindOfClass:[NSData class]] ) reason = nil;

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo addEntriesFromDictionary:tags];

		if( [sender isLocalUser] ) {
			[room _setDateParted:[NSDate date]];

			if (reason)
				userInfo[@"reason"] = reason;
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomPartedNotification object:room userInfo:userInfo];
		} else {
			if (reason)
				userInfo[@"reason"] = reason;
			if (sender)
				userInfo[@"user"] = sender;
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:userInfo];
		}
	}
}

- (void) _handlePartWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	[self _handlePartWithParameters:parameters tags:@{} fromSender:sender];
}

- (void) _handleQuitWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( parameters.count >= 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		if( [sender isLocalUser] ) {
			_userDisconnected = YES;
			[[self _chatConnection] disconnect];
			return;
		}

		[self _markUserAsOffline:sender];
		[_pendingWhoisUsers removeObject:sender];

		NSData *reason = parameters[0];
		if( ! [reason isKindOfClass:[NSData class]] ) reason = [NSData data];
		NSDictionary *info = @{ @"user": sender, @"reason": reason };

		for( MVChatRoom *room in [self joinedChatRooms] ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _removeMemberUser:sender];
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:info];
		}
	}
}

- (void) _handleKickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count >= 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[0]];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		if( ! room || ! user ) return;

		NSData *reason = ( parameters.count == 3 ? parameters[2] : nil );
		if( ! [reason isKindOfClass:[NSData class]] ) reason = nil;
		if( [user isLocalUser] ) {
			[room _setDateParted:[NSDate date]];
			NSDictionary *userInfo = reason ? @{ @"byUser": sender, @"reason": reason } : @{ @"byUser": sender };
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomKickedNotification object:room userInfo:userInfo];
		} else {
			[room _removeMemberUser:user];
			NSDictionary *userInfo = reason ? @{ @"user": user, @"byUser": sender, @"reason": reason } : @{ @"user": user, @"byUser": sender };
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserKickedNotification object:room userInfo:userInfo];
		}
	}
}

- (void) _handleTopic:(NSDictionary *)topicInfo {
#if ENABLE(PLUGINS)
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd withObject:topicInfo waitUntilDone:NO];
		return;
	}
	MVAssertMainThreadRequired();
#endif

	__unsafe_unretained MVChatRoom *room = topicInfo[@"room"];
	__unsafe_unretained MVChatUser *author = topicInfo[@"author"];
	NSMutableData *topic = [topicInfo[@"topic"] mutableCopy];

#if ENABLE(PLUGINS)
	__unsafe_unretained NSMutableData *unsafeTopic = topic;

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatRoom * ), @encode( MVChatUser * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processTopicAsData:inRoom:author: )];
	[invocation setArgument:&unsafeTopic atIndex:2];
	[invocation setArgument:&room atIndex:3];
	[invocation setArgument:&author atIndex:4];

	topic = nil;

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
#endif

	[room _setTopic:topic];
	[room _setTopicAuthor:author];
	[room _setTopicDate:[NSDate date]];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification object:room];
}

- (void) _handleTopicWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[0]];
		NSData *topic = parameters[1];
		if( ! [topic isKindOfClass:[NSData class]] ) topic = [NSData data];

		NSDictionary *info = @{@"room": room, @"author": sender, @"topic": topic};
		[self _handleTopic:info];
	}
}

- (void) _parseRoomModes:(NSArray *) parameters forRoom:(MVChatRoom *) room fromSender:(MVChatUser *__nullable) sender {
#define enabledHighBit ( 1 << 31 )
#define banMode ( 1 << 30 )
#define banExcludeMode ( 1 << 29 )
#define inviteExcludeMode ( 1 << 28 )

	NSUInteger oldModes = [room modes];
	NSUInteger argModes = 0;
	NSUInteger value = 0;
	NSMutableArray *argsNeeded = [[NSMutableArray alloc] initWithCapacity:10];
	NSUInteger i = 0, count = parameters.count;
	NSMutableString *unsupportedModes = [NSMutableString string];
	BOOL previousUnknownMode = YES;
	while( i < count ) {
		NSString *param = [self _stringFromPossibleData:parameters[i++]];
		if( param.length ) {
			char chr = [param characterAtIndex:0];
			if( chr == '+' || chr == '-' ) {
				BOOL enabled = YES;
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
							[argsNeeded addObject:@(value)];
							break;
						default: {
							NSMutableDictionary *supportedModes = _serverInformation[@"roomMemberModeTable"];
							if( supportedModes.count ) {
								value = [supportedModes[[NSString stringWithFormat:@"%c", chr]] unsignedLongValue];
								if( value ) goto queue;
								else {
									if (!unsupportedModes.length || previousUnknownMode != enabled) {
										previousUnknownMode = enabled;
										if (previousUnknownMode) [unsupportedModes appendString:@"+"];
										else [unsupportedModes appendString:@"-"];
									}

									[unsupportedModes appendFormat:@"%c", chr];
								}
							}
						}
					}
				}
			} else {
				if( argsNeeded.count ) {
					NSUInteger innerValue = [argsNeeded[0] unsignedLongValue];
					BOOL enabled = ( ( innerValue & enabledHighBit ) ? YES : NO );
					int mode = ( innerValue & ~enabledHighBit );

					if( mode == MVChatRoomMemberFounderMode || mode == MVChatRoomMemberAdministratorMode || mode == MVChatRoomMemberOperatorMode || mode == MVChatRoomMemberHalfOperatorMode || mode == MVChatRoomMemberVoicedMode ) {
						MVChatUser *member = [self chatUserWithUniqueIdentifier:param];
						if( enabled ) [room _setMode:mode forMemberUser:member];
						else [room _removeMode:mode forMemberUser:member];
						NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
						if (member) userInfo[@"who"] = member;
						if (sender) userInfo[@"by"] = sender;
						userInfo[@"enabled"] = @(enabled);
						userInfo[@"mode"] = @(mode);
						[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:userInfo];
					} else if( mode == banMode ) {
						MVChatUser *user = [MVChatUser wildcardUserFromString:param];
						NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
						if (user) userInfo[@"user"] = user;
						if (sender) userInfo[@"byUser"] = sender;
						if( enabled ) {
							[room _addBanForUser:user];
							[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserBannedNotification object:room userInfo:userInfo];
						} else {
							[room _removeBanForUser:user];
							[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserBanRemovedNotification object:room userInfo:userInfo];
						}
					} else if( mode == MVChatRoomLimitNumberOfMembersMode && enabled ) {
						argModes |= MVChatRoomLimitNumberOfMembersMode;
						[room _setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:@([param intValue])];
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


	NSUInteger changedModes = ( oldModes ^ [room modes] ) | argModes;
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomModesChangedNotification object:room userInfo:@{ @"changedModes": @(changedModes), @"by": sender, @"unsupportedModes": [unsupportedModes copy] }];
}

- (void) _handleModeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count >= 2 ) {
		NSString *targetName = parameters[0];
		if( targetName.length >= 1 && [[self chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]] ) {
			MVChatRoom *room = [self chatRoomWithUniqueIdentifier:targetName];
			[self _parseRoomModes:[parameters subarrayWithRange:NSMakeRange( 1, parameters.count - 1)] forRoom:room fromSender:sender];
		} else {
			// user modes not handled yet
		}
	}
}

- (void) _handle324WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_CHANNELMODEIS
	if( parameters.count >= 3 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[1]];
		[self _parseRoomModes:[parameters subarrayWithRange:NSMakeRange( 2, parameters.count - 2)] forRoom:room fromSender:nil];
	}
}

#pragma mark -
#pragma mark Misc. Replies

- (void) _handlePingWithParameters:(NSArray *) parameters fromSender:(id) sender {
	if( parameters.count >= 1 ) {
		if( parameters.count == 1 )
			[self sendRawMessageImmediatelyWithComponents:@"PONG :", parameters[0], nil];
		else [self sendRawMessageImmediatelyWithComponents:@"PONG ", parameters[1], @" :", parameters[0], nil];

		if( [sender isKindOfClass:[MVChatUser class]] )
			[self _markUserAsOnline:sender];
	}
}

- (void) _handleInviteWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	// if the sender is a server lets make a user for the server name
	// this is not ideal but the notifications need user objects
	if( [sender isKindOfClass:[NSString class]] )
		sender = [self chatUserWithUniqueIdentifier:(NSString *) sender];

	if( parameters.count == 2 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *roomName = [self _stringFromPossibleData:parameters[1]];

		[self _markUserAsOnline:sender];

		// get target, and make sure the target is ourselves
		MVChatUser *user = [MVChatUser wildcardUserFromString:parameters[0]];
		if( ![self.localUser isEqualToChatUser:user] ) { // different target being invited, we are seeing the echo of it
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomInvitedNotification object:self userInfo:@{ @"user": sender, @"room": roomName, @"target": user }];
		} else {
			if( [[sender nickname] isEqualToString:@"ChanServ"] ) {
				// Auto-accept invites from ChanServ since the user initiated the invite.
				[self joinChatRoomNamed:roomName];
			} else {
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomInvitedNotification object:self userInfo:@{ @"user": sender, @"room": roomName }];
			}
		}
	}
}

- (void) _handleNickWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( parameters.count == 1 && [sender isKindOfClass:[MVChatUser class]] ) {
		NSString *nick = [self _stringFromPossibleData:parameters[0]];
		NSString *oldNickname = [sender nickname];
		NSString *oldIdentifier = [sender uniqueIdentifier];

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
			note = [NSNotification notificationWithName:MVChatUserNicknameChangedNotification object:sender userInfo:@{@"oldNickname": oldNickname}];
		}

		for( MVChatRoom *room in [self joinedChatRooms] ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _updateMemberUser:sender fromOldUniqueIdentifier:oldIdentifier];
		}

		[[NSNotificationCenter chatCenter] postNotificationOnMainThread:note];
	}
}

- (void) _handleChghostWithParameters:(NSArray *) parameters fromSender:(id) sender {
	if (parameters.count == 2) {
		NSString *newUser = [self _stringFromPossibleData:parameters[0]];
		NSString *newHost = [self _stringFromPossibleData:parameters[1]];

		MVChatUser *user = (MVChatUser *)sender;
		NSString *oldUser = user.username;
		NSString *oldHost = user.address;

		[user _setUsername:newUser];
		[user _setAddress:newHost];

		[[NSNotificationCenter chatCenter] postNotificationName:MVChatUserInformationUpdatedNotification object:sender userInfo:@{ @"oldUsername": oldUser, @"oldAddress": oldHost }];
	}
}

- (void) _handleAccountWithParameters:(NSArray *) parameters fromSender:(id) sender {
	NSString *accountName = [self _stringFromPossibleData:parameters[0]];

	if( [accountName isEqualToString:@"*"] )
		[sender _setAccount:nil];
	else [sender _setAccount:accountName];
}

- (void) _handle303WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ISON
	if( parameters.count == 2 && _isonSentCount > 0 ) {
		_isonSentCount--;

		NSString *names = [self _stringFromPossibleData:parameters[1]];
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

			_lastSentIsonNicknames = nil;
		}
	} else if( parameters.count == 2 ) {
		NSString *names = [self _stringFromPossibleData:parameters[1]];
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
	if( parameters.count == 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:parameters[1]];
		NSData *awayMsg = parameters[2];
		if( ! [awayMsg isKindOfClass:[NSData class]] ) awayMsg = nil;

		if( ! [[user awayStatusMessage] isEqual:awayMsg] ) {
			[user _setAwayStatusMessage:awayMsg];
			[user _setStatus:MVChatUserAwayStatus];

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserAwayStatusMessageChangedNotification object:user];
		}
	}
}

- (void) _handle305WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_UNAWAY
	[[self localUser] _setAwayStatusMessage:nil];
	[[self localUser] _setStatus:MVChatUserAvailableStatus];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self];
}

- (void) _handle306WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NOWAWAY
	[[self localUser] _setStatus:MVChatUserAwayStatus];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self];
}

#pragma mark -
#pragma mark NAMES Replies

- (void) _handle353WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NAMREPLY
	if( parameters.count == 4 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[2]];
		if( room && ! [room _namesSynced] ) {
			@autoreleasepool {
				NSString *names = [self _stringFromPossibleData:parameters[3]];
				NSArray *members = [names componentsSeparatedByString:@" "];

				for( NSString *aMember in members ) {
					if( ! aMember.length ) break;

					// IRCv3.2 provides support for user and host to be provided in NAMES reply
					NSString *memberName = nil;
					NSString *memberUser = nil;
					NSString *memberHost = nil;
					NSArray *nickUserhostComponents = [aMember componentsSeparatedByString:@"!"];
					if (nickUserhostComponents.count == 2) {
						memberName = nickUserhostComponents[0];

						NSArray *userHostComponents = [nickUserhostComponents[1] componentsSeparatedByString:@"@"];
						if (userHostComponents.count == 2) {
							memberUser = userHostComponents[0];
							memberHost = userHostComponents[1];
						}
					} else memberName = aMember;

					MVChatRoomMemberMode modes = [self _stripModePrefixesFromNickname:&memberName];
					MVChatUser *member = [self chatUserWithUniqueIdentifier:memberName];
					[room _addMemberUser:member];
					[room _setModes:modes forMemberUser:member];

					if (memberUser.length)
						[member _setUsername:memberUser];
					if (memberHost.length)
						[member _setAddress:memberHost];
					[self _markUserAsOnline:member];
				}
			}
		}
	}
}

- (void) _handle366WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFNAMES
	if( parameters.count >= 2 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		if( room && ! [room _namesSynced] ) {
			[room _setNamesSynced:YES];

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification object:room];

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
	if( parameters.count >= 7 ) {
		MVChatUser *member = [self chatUserWithUniqueIdentifier:parameters[5]];
		[member _setUsername:parameters[2]];
		[member _setAddress:parameters[3]];

		NSString *statusString = [self _stringFromPossibleData:parameters[6]];
		unichar userStatus = ( statusString.length ? [statusString characterAtIndex:0] : 0 );
		if( userStatus == 'H' ) {
			[member _setAwayStatusMessage:nil];
			[member _setStatus:MVChatUserAvailableStatus];
		} else if( userStatus == 'G' ) {
			[member _setStatus:MVChatUserAwayStatus];
		}

		[member _setServerOperator:( statusString.length >= 2 && [statusString characterAtIndex:1] == '*' )];

		if( parameters.count >= 8 ) {
			NSString *lastParam = [self _stringFromPossibleData:parameters[7]];
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
	if( parameters.count >= 2 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		if( room ) [[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomMemberUsersSyncedNotification object:room];
	}
}

#pragma mark -
#pragma mark Channel List Reply

- (void) _handle322WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_LIST
	if( parameters.count == 4 ) {
		NSString *room = parameters[1];
		NSUInteger users = [parameters[2] intValue];
		NSData *topic = parameters[3];
		if( ! [topic isKindOfClass:[NSData class]] ) topic = nil;

		NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@(users), @"users", [NSDate date], @"cached", room, @"room", topic, @"topic", nil];
		[self performSelectorOnMainThread:@selector( _addRoomToCache: ) withObject:info waitUntilDone:NO];
	}
}

#pragma mark -
#pragma mark Ban List Replies

- (void) _handle367WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_BANLIST
	if( parameters.count >= 3 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[1]];
		MVChatUser *user = [MVChatUser wildcardUserFromString:[self _stringFromPossibleData:parameters[2]]];
		if( parameters.count >= 5 ) {
			[user setAttribute:parameters[3] forKey:MVChatUserBanServerAttribute];

			NSString *dateString = [self _stringFromPossibleData:parameters[4]];
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
	if( parameters.count >= 2 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		[room _setBansSynced:YES];
		if( room ) [[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomBannedUsersSyncedNotification object:room];
	}
}

#pragma mark -
#pragma mark Topic Replies

- (void) _handle332WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_TOPIC
	if( parameters.count == 3 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[1]];
		NSData *topic = parameters[2];
		if( ! [topic isKindOfClass:[NSData class]] ) topic = nil;
		[room _setTopic:topic];
	}
}

- (void) _handle333WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_TOPICWHOTIME_IRCU
	if( parameters.count >= 4 ) {
		MVChatRoom *room = [self chatRoomWithUniqueIdentifier:parameters[1]];
		MVChatUser *author = [MVChatUser wildcardUserFromString:parameters[2]];
		[room _setTopicAuthor:author];

		NSString *setTime = [self _stringFromPossibleData:parameters[3]];
		NSTimeInterval time = [setTime doubleValue];
		if( time > JVFirstViableTimestamp )
			[room _setTopicDate:[NSDate dateWithTimeIntervalSince1970:time]];

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification object:room];
	}
}

#pragma mark -
#pragma mark WHOIS Replies

- (void) _handle311WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISUSER
	if( parameters.count == 6 ) {
		NSString *nick = parameters[1];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:nick];
		if( ! [[user nickname] isEqualToString:nick] && [[user nickname] isCaseInsensitiveEqualToString:nick] )
			[user _setNickname:nick]; // nick differed only in case, change to the proper case
		[user _setUsername:parameters[2]];
		[user _setAddress:parameters[3]];
		[user _setRealName:[self _stringFromPossibleData:parameters[5]]];
		[user _setStatus:MVChatUserAvailableStatus]; // set this to available, we will change it if we get a RPL_AWAY
		[user _setAwayStatusMessage:nil]; // set this to nil, we will get it if we get a RPL_AWAY
		[user _setServerOperator:NO]; // set this to NO now so we get the true values later in the RPL_WHOISOPERATOR

		[self _markUserAsOnline:user];
	}
}

- (void) _handle312WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISSERVER
	if( parameters.count >= 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:parameters[1]];
		[user _setServerAddress:[self _stringFromPossibleData:parameters[2]]];
	}
}

- (void) _handle313WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISOPERATOR
	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		[user _setServerOperator:YES];
	}
}

- (void) _handle317WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISIDLE
	if( parameters.count >= 3 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:parameters[1]];
		NSString *idleTime = [self _stringFromPossibleData:parameters[2]];
		[user _setIdleTime:[idleTime doubleValue]];
		[user _setDateConnected:nil];

		// parameter 4 is connection time on some servers
		if( parameters.count >= 4 ) {
			NSString *connectedTime = [self _stringFromPossibleData:parameters[3]];
			NSTimeInterval time = [connectedTime doubleValue];
			if( time > JVFirstViableTimestamp )
				[user _setDateConnected:[NSDate dateWithTimeIntervalSince1970:time]];
		}
	}
}

- (void) _handle318WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFWHOIS
	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		[user _setDateUpdated:[NSDate date]];

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserInformationUpdatedNotification object:user];

		if( [_pendingWhoisUsers containsObject:user] ) {
			[_pendingWhoisUsers removeObject:user];
			[self _whoisNextScheduledUser];
		}
	}
}

- (void) _handle319WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISCHANNELS
	if( parameters.count == 3 ) {
		NSString *rooms = [self _stringFromPossibleData:parameters[2]];
		NSArray *chanArray = [[rooms stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:chanArray.count];

		NSCharacterSet *nicknamePrefixes = [self _nicknamePrefixes];
		for( __strong NSString *room in chanArray ) {
			NSRange prefixRange = [room rangeOfCharacterFromSet:nicknamePrefixes options:NSAnchoredSearch];
			if( prefixRange.location != NSNotFound )
				room = [room substringFromIndex:( prefixRange.location + prefixRange.length )];
			room = [room stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if( room.length ) [results addObject:room];
		}

		if( results.count ) {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:parameters[1]];
			[user setAttribute:results forKey:MVChatUserKnownRoomsAttribute];
		}
	}
}

- (void) _handle320WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOISIDENTIFIED
	if( parameters.count == 3 ) {
		NSString *comment = [self _stringFromPossibleData:parameters[2]];
		if( [comment hasCaseInsensitiveSubstring:@"identified"] ) {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:parameters[1]];
			[user _setIdentified:YES];
		}
	}
}

#pragma mark -
#pragma mark Metadata Replies

- (void) _handle670WithParameters:(NSArray *) parameters fromSender:(id) sender {
	if( parameters.count == 2) { // STARTTLS start TLS session. nickname :STARTTLS successful, go ahead with TLS handshake
		[self _startTLS];

		self.connectedSecurely = YES;
	} else if (parameters.count == 3) { // IRCv3.2 RPL_WHOISKEYVALUE, <target> <key> :<value
		NSString *nickname = parameters[0];
		if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
		if( !nickname.length ) return;

		MVChatUser *user = [self chatUserWithUniqueIdentifier:nickname];
		[user setAttribute:parameters[2] forKey:parameters[1]];
	}
}

- (void) _handle671WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_KEYVALUE, <target> <key> [:<value>]
	if (2 > parameters.count) return;

	NSString *nickname = parameters[0];
	if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
	if( !nickname.length ) return;

	MVChatUser *user = [self chatUserWithUniqueIdentifier:nickname];
	id attribute = ((parameters.count >= 3) ? parameters[2] : nil);
	[user setAttribute:attribute forKey:parameters[1]];
}

- (void) _handle672WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_METADATAEND, :end of metadata
	// nothing to do
}

- (void) _handle675WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_TARGETINVALID, <target> :invalid metadata target
	// nothing to do
}

- (void) _handle676WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NOMATCHINGKEYS, <string> :no matching keys
	// nothing to do
}

- (void) _handle677WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_KEYINVALID, <key> :invalid metadata key
	if (1 > parameters.count) return;

	[self.localUser setAttribute:nil forKey:parameters[0]];
}

- (void) _handle678WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_KEYNOTSET, <target> <key> :key not set
	if (parameters.count != 2) return;

	NSString *nickname = parameters[0];
	if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
	if( !nickname.length ) return;

	MVChatUser *user = [self chatUserWithUniqueIdentifier:nickname];
	[user setAttribute:nil forKey:parameters[1]];
}

- (void) _handle679WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_KEYNOPERMISSION
	// <Target> <key> :permission denied
}

#pragma mark -
#pragma mark Error Replies

- (void) _handle401WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NOSUCHNICK
	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
		[self _markUserAsOffline:user];

		//workaround for a freenode (hyperion) bug where the ircd doesnt reply with 318 (RPL_ENDOFWHOIS) in case of 401 (ERR_NOSUCHNICK): end the whois when receiving 401
		[user _setDateUpdated:[NSDate date]];
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserInformationUpdatedNotification object:user];

		if( [_pendingWhoisUsers containsObject:user] ) {
			[_pendingWhoisUsers removeObject:user];
			[self _whoisNextScheduledUser];
		}

		//workaround for quakenet and undernet which don't send 440 (ERR_SERVICESDOWN) if they are
		if ( ( [[self server] hasCaseInsensitiveSubstring:@"quakenet"] && [[user nickname] isCaseInsensitiveEqualToString:@"Q@CServe.quakenet.org"] ) || ( [[self server] hasCaseInsensitiveSubstring:@"undernet"] && [[user nickname] isCaseInsensitiveEqualToString:@"X@channels.undernet.org"] ) ) {
			_pendingIdentificationAttempt = NO;

			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			userInfo[@"connection"] = self;
			userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Services down on \"%@\".", "services down error" ), [self server]];

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
	// some servers send back 402 (No such server) when we send our double nickname WHOIS requests, treat as a user
	if( parameters.count >= 2 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self _stringFromPossibleData:parameters[1]]];
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
	// "<channel name> :Cannot send to channel"
	// - Sent to a user who is either (a) not on a channel which is mode +n or (b) not a chanop (or mode +v) on a channel which has mode +m set or where the user is banned and is trying to send a PRIVMSG message to that channel.

	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		userInfo[@"connection"] = self;
		userInfo[@"room"] = room;
		userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Can't send to room \"%@\" on \"%@\".", "cant send to room error" ), room, [self server]];

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
	// "No services can currently be detected" (same as 440, which is the "standard" numeric for this error)
	// - Send to us after trying to identify with /nickserv, ui should ask the user wether to go ahead with the autojoin without identification (= no host/ip cloaks)

	_pendingIdentificationAttempt = NO;

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[@"connection"] = self;
	userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Services down on \"%@\".", "services down error" ), [self server]];

	[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionServicesDownError userInfo:userInfo]];
}

- (void) _handle421WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_UNKNOWNCOMMAND
	if( parameters.count >= 2 ) {
		NSString *command = [self _stringFromPossibleData:parameters[1]];
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

- (void) _handle432WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_ERRONEUSNICKNAME, "<nick> :Erroneous nickname"
	NSString *identifier = [self _stringFromPossibleData:parameters[1]];

	NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
	userInfo[@"connection"] = self;
	userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname to \"%@\" on \"%@\".", "cant change nick because of server error" ), identifier, [self server]];

	[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionErroneusNicknameError userInfo:userInfo]];

}

- (void) _handle435WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BANONCHAN Bahamut (also ERR_SERVICECONFUSED on Unreal, not implemented here)
	// "<current nickname> <new nickname> <channel name> :Cannot change nickname while banned on channel"
	// - Sent to a user who is changing their nick in a room where it is prohibited.

	if( parameters.count >= 3 ) {
		NSString *possibleRoom = [self _stringFromPossibleData:parameters[2]];
		if( [self joinedChatRoomWithUniqueIdentifier:possibleRoom] ) {
			NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
			userInfo[@"connection"] = self;
			userInfo[@"room"] = possibleRoom;
			userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname while in \"%@\" on \"%@\". Please leave the room and try again.", "cant change nick because of chatroom error" ), possibleRoom, [self server]];

			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];

		}
	}
}

- (void) _handle437WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BANNICKCHANGE Unreal (also ERR_UNAVAILRESOURCE in RFC2812, not implemented here)
	// "<current nickname> <channel name> :Cannot change nickname while banned on channel or channel is moderated"
	// - Sent to a user who is changing their nick in a room where it is prohibited.
	// oldnick newnick :Nick/channel is temporarily unavailable, on Freenode


	NSString *identifier = [self _stringFromPossibleData:parameters[1]];

	if( parameters.count >= 2 ) {
		if( [self joinedChatRoomWithUniqueIdentifier:identifier] ) {
			NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
			userInfo[@"connection"] = self;
			userInfo[@"room"] = identifier;
			userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname while in \"%@\" on \"%@\". Please leave the room and try again.", "cant change nick because of chatroom error" ), identifier, [self server]];

			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];

		} else {
			NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
			userInfo[@"connection"] = self;
			userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Unable to change your nickname to \"%@\" on \"%@\".", "cant change nick because of server error" ), identifier, [self server]];

			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];
		}
	}
}

- (void) _handle438WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NICKTOOFAST_IRCU
	// "<current nickname> <new nickname|channel name> :Cannot change nick"
	// - Sent to a user who is either (a) changing their nickname to fast or (b) changing their nick in a room where it is prohibited.

	if( parameters.count >= 3 ) {
		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
		userInfo[@"connection"] = self;

		// workaround for freenode/hyperion where 438 means "banned in room, cant change nick"
		NSString *possibleRoom = [self _stringFromPossibleData:parameters[2]];
		if( [self joinedChatRoomWithUniqueIdentifier:possibleRoom] ) {
			userInfo[@"room"] = possibleRoom;
			userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You can't change your nickname while in \"%@\" on \"%@\". Please leave the room and try again.", "cant change nick because of chatroom error" ), possibleRoom, [self server]];
		} else userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You changed your nickname too fast on \"%@\", please wait and try again.", "cant change nick too fast error" ), [self server]];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantChangeNickError userInfo:userInfo]];
	}
}

- (void) _handle440WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_SERVICESDOWN_BAHAMUT_UNREAL (also freenode/ircd-seven)
	// "NickServ Services are currently down. Please try again later."
	// - Send to us after trying to identify with /nickserv, ui should ask the user wether to go ahead with the autojoin without identification (= no host/ip cloaks)

	_pendingIdentificationAttempt = NO;

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[@"connection"] = self;
	userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Services down on \"%@\".", "services down error" ), [self server]];

	[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionServicesDownError userInfo:userInfo]];
}

- (void) _handle462WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_ALREADYREGISTERED (RFC1459)

	if ( [[self server] hasCaseInsensitiveSubstring:@"ustream"] ) { // workaround for people that have their ustream pw in the server pass AND the nick pass field: use 462 as sign that identification took place
		_pendingIdentificationAttempt = NO;

		if( ![[self localUser] isIdentified] )
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionDidIdentifyWithServicesNotification object:self userInfo:@{@"user": @"Ustream", @"target": [self nickname]}];
		[[self localUser] _setIdentified:YES];
	}
}

- (void) _handle464WithParameters:(NSArray *) parameters fromSender:(id) sender { // ZNC INVALID PASSWORD
	// Possible responses:
	// :irc.znc.in 464 username :Password required // in the event that we do not send a PASS
	// :irc.znc.in 464 username :Invalid Password // in the event that we send the wrong PASS
	if( parameters.count >= 2 ) {
		NSString *message = [self _stringFromPossibleData:parameters[1]];

		if( [message hasCaseInsensitiveSubstring:@"Password Required"] )
			[[NSNotificationCenter chatCenter] postNotificationName:MVChatConnectionNeedServerPasswordNotification object:self];
		else if( [message hasCaseInsensitiveSubstring:@"Invalid Password"] )
			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionServerPasswordIncorrectError userInfo:nil]];
	}
}

- (void) _handle471WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_CHANNELISFULL
	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		userInfo[@"connection"] = self;
		userInfo[@"room"] = room;
		userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" is full.", "room is full error" ), room, [self server]];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionRoomIsFullError userInfo:userInfo]];
	}
}

- (void) _handle473WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_INVITEONLYCHAN
	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];

		MVChatRoom *chatRoom = [self chatRoomWithUniqueIdentifier:room];
		[chatRoom _setMode:MVChatRoomInviteOnlyMode withAttribute:nil];

		[_pendingJoinRoomNames removeObject:room];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		userInfo[@"connection"] = self;
		userInfo[@"room"] = room;
		userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" is invite only.", "invite only room error" ), room, [self server]];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionInviteOnlyRoomError userInfo:userInfo]];
	}
}

- (void) _handle474WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BANNEDFROMCHAN
	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];

		[_pendingJoinRoomNames removeObject:room];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		userInfo[@"connection"] = self;
		userInfo[@"room"] = room;
		userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You are banned from the room \"%@\" on \"%@\".", "banned from room error" ), room, [self server]];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionBannedFromRoomError userInfo:userInfo]];
	}
}

- (void) _handle475WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_BADCHANNELKEY
	if( parameters.count >= 2 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];

		MVChatRoom *chatRoom = [self chatRoomWithUniqueIdentifier:room];
		[chatRoom _setMode:MVChatRoomPassphraseToJoinMode withAttribute:nil];

		[_pendingJoinRoomNames removeObject:room];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		userInfo[@"connection"] = self;
		userInfo[@"room"] = room;
		userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" is password protected.", "room password protected error" ), room, [self server]];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionRoomPasswordIncorrectError userInfo:userInfo]];
	}
}

- (void) _handle477WithParameters:(NSArray *) parameters fromSender:(id) sender { // ERR_NOCHANMODES_RFC2812 or ERR_NEEDREGGEDNICK_BAHAMUT_IRCU_UNREAL
	// I:	rfc 2812: "<channel> :Channel doesn't support modes"
	// II:	more common non standard room mode +R:
	// - Unreal3.2.7: "<channel> :You need a registered nick to join that channel."
	// - bahamut-1.8(04)/DALnet: <channel> :You need to identify to a registered nick to join that channel. For help with registering your nickname, type "/msg NickServ@services.dal.net help register" or see http://docs.dal.net/docs/nsemail.html

	if( parameters.count >= 3 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];
		NSString *errorLiteralReason = [self _stringFromPossibleData:parameters[2]];

		NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:self, @"connection", room, @"room", @"477", @"errorCode", errorLiteralReason, @"errorLiteralReason", nil];
		if( [_pendingJoinRoomNames containsObject:room] ) { // (probably II)
			[_pendingJoinRoomNames removeObject:room];
			userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"You need to identify with network services to join the room \"%@\" on \"%@\".", "identify to join room error" ), room, [self server]];
			[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionIdentifyToJoinRoomError userInfo:userInfo]];
		} else if( ![[self server] hasCaseInsensitiveSubstring:@"freenode"] ) { // ignore on freenode until they stop randomly sending 477s when joining a room
			if( [errorLiteralReason hasCaseInsensitiveSubstring:@"modes"] ) { // (probably I)
				userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" does not support modes.", "room does not support modes error" ), room, [self server]];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionRoomDoesNotSupportModesError userInfo:userInfo]];
			} else { // (could be either)
				userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"The room \"%@\" on \"%@\" encountered an unknown error, see server details for more information.", "room encountered unknown error" ), room, [self server]];
				[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionUnknownError userInfo:userInfo]];
			}
		}
	}
}

- (void) _handleErrorWithParameters:(NSArray *) parameters fromSender:(id) sender { // ERROR message: http://tools.ietf.org/html/rfc2812#section-3.7.4
	if( parameters.count == 1 ) {
		NSString *message = [self _stringFromPossibleData:parameters[0]];

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotErrorNotification object:self userInfo:@{@"message": message}];

		_serverError = [NSError errorWithDomain:MVChatConnectionErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: message}];

		[self disconnect];
	}
}

- (void) _handle506WithParameters:(NSArray *) parameters fromSender:(id) sender { // freenode/hyperion: identify with services to talk in this room
	// "<channel> Please register with services and use the IDENTIFY command (/msg nickserv help) to speak in this channel"
	//  freenode/hyperion sends 506 if the user is not identified and tries to talk on a room with mode +R

	if( parameters.count == 3 ) {
		NSString *room = [self _stringFromPossibleData:parameters[1]];
		NSString *errorLiteralReason = [self _stringFromPossibleData:parameters[2]];

		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:5];
		userInfo[@"connection"] = self;
		userInfo[@"room"] = room;
		userInfo[@"errorCode"] = @"506";
		userInfo[@"errorLiteralReason"] = errorLiteralReason;
		userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:NSLocalizedString( @"Can't send to room \"%@\" on \"%@\".", "cant send to room error" ), room, [self server]];

		[self _postError:[NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionCantSendToRoomError userInfo:userInfo]];
	}
}

#pragma mark -
#pragma mark Watch Replies

- (void) _handle604WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NOWON_BAHAMUT_UNREAL
	if( parameters.count >= 4 ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:parameters[1]];
		[user _setUsername:parameters[2]];
		[user _setAddress:parameters[3]];

		[self _markUserAsOnline:user];

//		if( [[user dateUpdated] timeIntervalSinceNow] < -JVWatchedUserWHOISDelay || ! [user dateUpdated] )
//			[self _scheduleWhoisForUser:user];
	}
}

- (void) _handle600WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_LOGON_BAHAMUT_UNREAL
	if( parameters.count >= 4 )
		[self _handle604WithParameters:parameters fromSender:sender]; // do everything we do above
}

#pragma mark -
#pragma mark Monitor Replies

- (void) _handle730WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_MONONLINE
	// <nick> :target[,target2]*

	for( __strong NSString *nickname in [[self _stringFromPossibleData:parameters[1]] componentsSeparatedByString:@","] ) {
		if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
		if( !nickname.length ) continue;
		MVChatUser *user = [self chatUserWithUniqueIdentifier:nickname];

		[self _markUserAsOnline:user];
	}
}

- (void) _handle731WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_MONOFFLINE
	// <nick> :target[,target2]*

	for( __strong NSString *nickname in [[self _stringFromPossibleData:parameters[1]] componentsSeparatedByString:@","] ) {
		if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
		if( !nickname.length ) continue;
		MVChatUser *user = [self chatUserWithUniqueIdentifier:nickname];

		[self _markUserAsOffline:user];
	}
}

- (void) _handle732WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_MONLIST
	// <nick> :target[,target2]*

	for( __strong NSString *nickname in [[self _stringFromPossibleData:parameters[1]] componentsSeparatedByString:@","] ) {
		if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
		if( !nickname.length ) continue;
		MVChatUserWatchRule *watchRule = [[MVChatUserWatchRule alloc] init];
		watchRule.nickname = nickname;

		[super addChatUserWatchRule:watchRule];
	}
}

- (void) _handle733WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFMONLIST
	// <nick> :End of MONITOR list

	_fetchingMonitorList = NO;

	for( NSString *nickname in _pendingMonitorList ) {
		MVChatUserWatchRule *watchRule = [[MVChatUserWatchRule alloc] init];
		watchRule.nickname = nickname;

		[self addChatUserWatchRule:watchRule];
	}

	_pendingMonitorList = nil;
}

- (void) _handle734WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_MONOFFLINE
	// <nick> <limit> <targets> :Monitor list is full.

	_monitorListFull = YES;

	if (!_pendingMonitorList) _pendingMonitorList = [NSMutableArray array];
	[_pendingMonitorList addObject:parameters.firstObject];

	// move over to WATCH or ISON instead
	for( __strong NSString *nickname in [[self _stringFromPossibleData:parameters[2]] componentsSeparatedByString:@","] ) {
		if( [nickname hasSuffix:@"*"] ) nickname = [nickname substringToIndex:(nickname.length - 1)];
		if( !nickname.length ) continue;
		MVChatUserWatchRule *watchRule = [[MVChatUserWatchRule alloc] init];
		watchRule.nickname = nickname;

		[super removeChatUserWatchRule:watchRule]; // remove watch rule that isn't doing anything server-side
		[self addChatUserWatchRule:watchRule]; // re-add it with _monitorListFull = YES to skip MONITOR
	}
}

#pragma mark -
#pragma mark EFnet / umich captcha

- (void) _handle998WithParameters:(NSArray *) parameters fromSender:(id) sender { // undefined code, irc.umich.edu (efnet) uses this to show a captcha to users without identd (= us) which we have to reply to
	if( ![self isConnected] && parameters.count == 2 ) {
		if( !_umichNoIdentdCaptcha ) _umichNoIdentdCaptcha = [[NSMutableArray alloc] init];

		NSMutableString *parameterString = [[self _stringFromPossibleData:parameters[1]] mutableCopy];
		[_umichNoIdentdCaptcha addObject:parameterString];

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
				if( captchaAlphabet[testString] ) {
					[captchaReply appendString:captchaAlphabet[testString]];
					testString = [NSMutableString string];
				}
			}
			[self sendRawMessageImmediatelyWithFormat:@"PONG :%@", captchaReply];

			_umichNoIdentdCaptcha = nil;
		}
	}
}
@end

NS_ASSUME_NONNULL_END
