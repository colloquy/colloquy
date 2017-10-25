@import XMPPFramework;

#import "MVXMPPChatConnection.h"
#import "MVXMPPChatUser.h"
#import "MVXMPPChatRoom.h"
#import "MVUtilities.h"
#import "MVChatPluginManager.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "MVChatString.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVXMPPChatConnection
+ (NSArray *) defaultServerPorts {
	return @[ @((unsigned short)5222), @((unsigned short)5223) ];
}

+ (NSUInteger) maxMessageLength {
	// the actual stanza length varies per server: http://www.xmpp.org/extensions/inbox/stanzalimits.html#request
	// todo: request stanza limit when we support OTR over XMPP
	return 65536;
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_serverPort = 5222;
		_server = @"jabber.org";
		_username = NSUserName();
		_nickname = _username;
		_session = [[XMPPStream alloc] init];
 		[_session addDelegate:self delegateQueue:dispatch_get_main_queue()];

//		[_session addObserver:self selector:@selector( outgoingPacket: ) name:JSESSION_RAWDATA_OUT];
//		[_session addObserver:self selector:@selector( incomingPacket: ) name:JSESSION_RAWDATA_IN];
	}

	return self;
}

- (void) dealloc {
	[self disconnect];
}

#pragma mark -

- (NSString *) urlScheme {
	return @"xmpp";
}

- (MVChatConnectionType) type {
	return MVChatConnectionXMPPType;
}

- (const NSStringEncoding *) supportedStringEncodings {
	static const NSStringEncoding supportedEncodings[] = { NSUTF8StringEncoding, 0 };
	return supportedEncodings;
}

#pragma mark -

- (void) connect {
	if( _status != MVChatConnectionDisconnectedStatus && _status != MVChatConnectionServerDisconnectedStatus && _status != MVChatConnectionSuspendedStatus ) return;

	[self _willConnect];

	XMPPJID *localId = nil;
	NSRange atRange = [_username rangeOfString:@"@" options:NSLiteralSearch];
	if( atRange.location == NSNotFound )
		localId = [XMPPJID jidWithUser:_username domain:_server resource:@"colloquy"];
	else localId = [XMPPJID jidWithString:_username resource:@"colloquy"];

	MVChatUser *localUser = [[MVXMPPChatUser alloc] initWithJabberID:localId andConnection:self];
	[localUser _setType:MVChatLocalUserType];

	MVSafeAdoptAssign( _localID, localId );
	MVSafeAdoptAssign( _localUser, localUser );

	[_session setStartTLSPolicy:_secure ? XMPPStreamStartTLSPolicyRequired : XMPPStreamStartTLSPolicyPreferred];
	[_session setHostName:_server];
	[_session setHostPort:_serverPort];
	[_session setMyJID:_localID];

	NSError *error;
	if (![_session connectWithTimeout:30.0 error:&error]) {
		MVSafeAdoptAssign( _lastError, error );
	}
	
}

- (void) disconnectWithReason:(MVChatString * __nullable) reason {
	[self _willDisconnect];
	[_session disconnect];
}

#pragma mark -

- (void) setRealName:(NSString *__nullable) name {
	// not supported
}

- (NSString *__nullable) realName {
	return nil;
}

#pragma mark -

- (void) setNickname:(NSString *__nullable) newNickname {
	NSParameterAssert( newNickname != nil );
	NSParameterAssert( newNickname.length > 0 );
	MVSafeCopyAssign( _nickname, newNickname );
}

- (NSString *__nullable) nickname {
	return _nickname;
}

- (NSString *) preferredNickname {
	return [self nickname];
}

#pragma mark -

- (void) setNicknamePassword:(NSString * __nullable) newPassword {
	// not supported
}

- (NSString *__nullable) nicknamePassword {
	return nil;
}

#pragma mark -

- (void) setPassword:(NSString *__nullable) newPassword {
	MVSafeCopyAssign( _password, newPassword );
}

- (NSString *__nullable) password {
	return _password;
}

#pragma mark -

- (void) setUsername:(NSString *__nullable) newUsername {
	NSParameterAssert( newUsername != nil );
	NSParameterAssert( newUsername.length > 0 );
	MVSafeCopyAssign( _username, newUsername );
}

- (NSString *__nullable) username {
	return _username;
}

#pragma mark -

- (void) setServer:(NSString *) newServer {
	if( newServer.length >= 7 && [newServer hasPrefix:@"xmpp://"] )
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
	_serverPort = ( port ? port : 5222 );
}

- (unsigned short) serverPort {
	return _serverPort;
}

#pragma mark -

- (NSSet *) chatUsersWithNickname:(NSString *) name {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:name]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] || [identifier isKindOfClass:[XMPPJID class]] );

	if( [identifier isKindOfClass:[NSString class]] )
		identifier = [XMPPJID jidWithString:identifier];
	if( [identifier isEqual:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:[identifier full]];
		if( user ) return user;

		user = [[MVXMPPChatUser alloc] initWithJabberID:identifier andConnection:self];
	}

	return user;
}

#pragma mark -

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString * __nullable) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( room.length > 0 );

	/* Example:
	<presence from='hag66@shakespeare.lit/pda' to='darkcave@macbeth.shakespeare.lit/thirdwitch'>
	  <x xmlns='http://jabber.org/protocol/muc' />
	</presence>
	*/

	XMPPJID *roomId = [XMPPJID jidWithString:room];
	MVXMPPChatRoom *joiningRoom = (MVXMPPChatRoom *)[self joinedChatRoomWithUniqueIdentifier:roomId];
	if( joiningRoom && [joiningRoom isJoined] ) {
		// already joined
		return;
	}

	NSString *localUserStringId = [[NSString alloc] initWithFormat:@"%@/%@", room, [self nickname]];
//	[XMLQName construct:@"presence" withURI:@"jabber:client"];
	XMPPPresence *presence = [XMPPPresence presence];
	[presence addAttributeWithName:@"to" objectValue:localUserStringId];
	[presence addChild:[self _capabilitiesElement]];
	XMPPElement *x = [self _multiUserChatExtensionElement];
	[presence addChild:x];

	if (passphrase.length)
		[x addChild:[XMPPElement elementWithName:@"cdata" objectValue:passphrase]];

	[_session sendElement:presence];

	XMPPJID *localUserJabberId = [XMPPJID jidWithString:localUserStringId];
	MVXMPPChatUser *localUser = (MVXMPPChatUser *)[self chatUserWithUniqueIdentifier:localUserJabberId];
	[localUser _setRoomMember:YES];
	[localUser _setType:MVChatLocalUserType];

	if( ! joiningRoom )
		joiningRoom = [[MVXMPPChatRoom alloc] initWithJabberID:roomId andConnection:self];
	[joiningRoom _setLocalMemberUser:localUser];
	[joiningRoom _setDateJoined:nil];
	[joiningRoom _setDateParted:nil];
	[joiningRoom _clearMemberUsers];
	[joiningRoom _clearBannedUsers];

	// joiningRoom will be released in incomingPresence
}

#pragma mark -

- (void) xmppStreamConnectDidTimeout:(XMPPStream *) sender {
	[self _didNotConnect];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error {
	NSLog(@"authorizationFailed");
}

- (void) xmppStreamDidConnect:(XMPPStream *) sender {
	[self _didConnect];

	if( _password )
		[sender authenticateWithPassword:_password error:NULL];
}

- (void) xmppStreamDidDisconnect:(XMPPStream *) sender withError:(NSError *) error {
	NSLog(@"%@", error);
	[self _didDisconnect];
}

- (void)xmppStream:(XMPPStream *)stream didReceiveError:(NSXMLElement *)error {
	NSLog(@"%@", error);
}

- (void) outgoingPacket:(NSNotification *) notification {
	NSString *string = [[NSString alloc] initWithData:[notification object] encoding:NSUTF8StringEncoding];
	[[NSNotificationCenter chatCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:string, @"message", @YES, @"outbound", nil]];
}

- (void) incomingPacket:(NSNotification *) notification {
	NSString *string = [[NSString alloc] initWithData:[notification object] encoding:NSUTF8StringEncoding];
	[[NSNotificationCenter chatCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:string, @"message", @NO, @"outbound", nil]];
}

- (void) xmppStream:(XMPPStream *) stream didReceiveMessage:(XMPPMessage *) message {
	if( [[message type] isEqualToString:@"error"] ) {
		// handle error
		return;
	}

	__unsafe_unretained MVChatRoom *room = nil;
	__unsafe_unretained MVChatUser *sender = nil;

	if( [[message type] isEqualToString:@"groupchat"] ) {
		room = [self joinedChatRoomWithUniqueIdentifier:[message from]];
		if( ! room ) return;
		sender = [self chatUserWithUniqueIdentifier:[message from]];
		if( [sender isLocalUser] ) return;
	} else {
		sender = [self chatUserWithUniqueIdentifier:[message from]];
	}

	NSMutableData *msgData = [[[message body] dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
	__unsafe_unretained NSMutableData *unsafeMsgData = msgData;

	NSMutableDictionary *msgAttributes = [[NSMutableDictionary alloc] init];
	__unsafe_unretained NSMutableDictionary *unsafeMsgAttributes = msgAttributes;
	[msgAttributes setObject:sender forKey:@"user"];
	[msgAttributes setObject:msgData forKey:@"message"];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatUser * ), @encode( id ), @encode( NSMutableDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processIncomingMessageAsData:from:to:attributes: )];
	[invocation setArgument:&unsafeMsgData atIndex:2];
	[invocation setArgument:&sender atIndex:3];
	[invocation setArgument:&room atIndex:4];
	[invocation setArgument:&unsafeMsgAttributes atIndex:5];

	msgData = nil;
	msgAttributes = nil;

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	if( ! msgData.length ) return;

	if( room ) {
		[[NSNotificationCenter chatCenter] postNotificationName:MVChatRoomGotMessageNotification object:room userInfo:msgAttributes];
	} else {
		[[NSNotificationCenter chatCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:msgAttributes];
	}
}

- (void) xmppStream:(XMPPStream *) stream didReceiveTrust:(SecTrustRef) trust completionHandler:(void (^)(BOOL shouldTrustPeer)) completionHandler {
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

- (void) xmppStream:(XMPPStream *) sender didReceivePresence:(XMPPPresence *) presence {
	XMPPJID *roomID = [presence from];
	MVChatRoom *room = [self joinedChatRoomWithUniqueIdentifier:roomID];

	if( ! room ) return;

	if ([[presence type] isCaseInsensitiveEqualToString:@"error"]) {
		 // balance the alloc or retain in joinChatRoomNamed:
		// handle error...
		return;
	}

	MVXMPPChatUser *user = nil;
	if( [[[room localMemberUser] uniqueIdentifier] isEqual:[presence from]] )
		user = (MVXMPPChatUser *)[room localMemberUser];
	else user = (MVXMPPChatUser *)[self chatUserWithUniqueIdentifier:[presence from]];

	if ([[presence type] isCaseInsensitiveEqualToString:@"unavailable"]) {
		[room _removeMemberUser:user];
		[[NSNotificationCenter chatCenter] postNotificationName:MVChatRoomUserPartedNotification object:room userInfo:@{@"user": user}];
		return;
	}

	__strong id me = room;
	 // retain incase the following release is the last reference

	if( ! [room isJoined] ) {
		[room _setDateJoined:[NSDate date]];
		[[NSNotificationCenter chatCenter] postNotificationName:MVChatRoomJoinedNotification object:room];
		 // balance the alloc or retain in joinChatRoomNamed:
	}

	if( ! [room hasUser:user] ) {
		[user _setRoomMember:YES];
		[room _addMemberUser:user];
		[self _markUserAsOnline:user];

		NSDictionary *userInfo = @{@"added": @[user]};
		[[NSNotificationCenter chatCenter] postNotificationName:MVChatRoomMemberUsersSyncedNotification object:room userInfo:userInfo];
	}

	me = nil;
}
@end

#pragma mark -

@implementation MVXMPPChatConnection (MVXMPPChatConnectionPrivate)
- (XMPPStream *) _chatSession {
	return _session;
}

- (XMPPJID *) _localUserID {
	return _localID;
}

- (XMPPElement *) _capabilitiesElement {
	XMPPElement *caps = [XMPPElement elementWithName:@"c" URI:@"http://jabber.org/protocols/caps"];
	[caps addAttributeWithName:@"node" objectValue:@"http://colloquy.info/caps"];
	[caps addAttributeWithName:@"ver" objectValue:@"2.1"];
	return caps;
}

- (XMPPElement *) _multiUserChatExtensionElement {
	return [XMPPElement elementWithName:@"x" URI:@"http://jabber.org/protocol/muc"];
}
@end

NS_ASSUME_NONNULL_END
