#import <Acid/acid.h>

#import "MVXMPPChatConnection.h"
#import "MVXMPPChatUser.h"
#import "MVXMPPChatRoom.h"
#import "MVUtilities.h"
#import "MVChatPluginManager.h"
#import "NSMethodSignatureAdditions.h"
#import "NSStringAdditions.h"
#import "MVChatString.h"

@implementation MVXMPPChatConnection
+ (NSArray *) defaultServerPorts {
	return [NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:5222], [NSNumber numberWithUnsignedShort:5223], nil];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_serverPort = 5222;
		_server = @"jabber.org";
		_username = [NSUserName() retain];
		_nickname = [_username retain];
		_session = [[JabberSession alloc] init];

		[_session addObserver:self selector:@selector( sessionStarted: ) name:JSESSION_STARTED];
		[_session addObserver:self selector:@selector( sessionEnded: ) name:JSESSION_ENDED];
		[_session addObserver:self selector:@selector( connectFailed: ) name:JSESSION_ERROR_CONNECT_FAILED];
		[_session addObserver:self selector:@selector( badUser: ) name:JSESSION_ERROR_BADUSER];
		[_session addObserver:self selector:@selector( authorizationReady: ) name:JSESSION_AUTHREADY];
		[_session addObserver:self selector:@selector( authorizationFailed: ) name:JSESSION_ERROR_AUTHFAILED];
		[_session addObserver:self selector:@selector( outgoingPacket: ) name:JSESSION_RAWDATA_OUT];
		[_session addObserver:self selector:@selector( incomingPacket: ) name:JSESSION_RAWDATA_IN];
		[_session addObserver:self selector:@selector( incomingMessage: ) xpath:@"/message"];
		[_session addObserver:self selector:@selector( incomingPresence: ) xpath:@"/presence"];
	}

	return self;
}

- (void) finalize {
	[self disconnect];
	[super finalize];
}

- (void) dealloc {
	[self disconnect];

	[_session release];
	[_localID release];
	[_server release];
	[_username release];
	[_nickname release];
	[_password release];

	_session = nil;
	_localID = nil;
	_server = nil;
	_username = nil;
	_nickname = nil;
	_password = nil;

	[super dealloc];
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

	JabberID *localId = nil;
	NSRange atRange = [_username rangeOfString:@"@" options:NSLiteralSearch];
	if( atRange.location == NSNotFound )
		localId = [[JabberID alloc] initWithFormat:@"%@@%@/colloquy", _username, _server];
	else localId = [[JabberID alloc] initWithFormat:@"%@/colloquy", _username];

	MVChatUser *localUser = [[MVXMPPChatUser allocWithZone:nil] initWithJabberID:localId andConnection:self];
	[localUser _setType:MVChatLocalUserType];

	MVSafeAdoptAssign( &_localID, localId );
	MVSafeAdoptAssign( &_localUser, localUser );

	[_session setUseSSL:_secure];
	[_session startSession:_localID onPort:_serverPort withServer:_server];
}

- (void) disconnectWithReason:(MVChatString *) reason {
	[self _willDisconnect];
	[_session stopSession];
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	// not supported
}

- (NSString *) realName {
	return nil;
}

#pragma mark -

- (void) setNickname:(NSString *) newNickname {
	NSParameterAssert( newNickname != nil );
	NSParameterAssert( [newNickname length] > 0 );
	MVSafeCopyAssign( &_nickname, newNickname );
}

- (NSString *) nickname {
	return _nickname;
}

- (NSString *) preferredNickname {
	return [self nickname];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) newPassword {
	// not supported
}

- (NSString *) nicknamePassword {
	return nil;
}

#pragma mark -

- (void) setPassword:(NSString *) newPassword {
	MVSafeCopyAssign( &_password, newPassword );
}

- (NSString *) password {
	return _password;
}

#pragma mark -

- (void) setUsername:(NSString *) newUsername {
	NSParameterAssert( newUsername != nil );
	NSParameterAssert( [newUsername length] > 0 );
	MVSafeCopyAssign( &_username, newUsername );
}

- (NSString *) username {
	return _username;
}

#pragma mark -

- (void) setServer:(NSString *) newServer {
	if( [newServer length] >= 7 && [newServer hasPrefix:@"xmpp://"] )
		newServer = [newServer substringFromIndex:7];
	NSParameterAssert( newServer != nil );
	NSParameterAssert( [newServer length] > 0 );
	MVSafeCopyAssign( &_server, newServer );

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
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] || [identifier isKindOfClass:[JabberID class]] );

	if( [identifier isKindOfClass:[NSString class]] )
		identifier = [[[JabberID allocWithZone:nil] initWithString:identifier] autorelease];
	if( [identifier isEqual:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:[identifier completeID]];
		if( user ) return [[user retain] autorelease];

		user = [[MVXMPPChatUser allocWithZone:nil] initWithJabberID:identifier andConnection:self];
	}

	return [user autorelease];
}

#pragma mark -

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );

	/* Example:
	<presence from='hag66@shakespeare.lit/pda' to='darkcave@macbeth.shakespeare.lit/thirdwitch'>
	  <x xmlns='http://jabber.org/protocol/muc' />
	</presence>
	*/

	JabberID *roomId = [[JabberID allocWithZone:nil] initWithString:room];
	MVXMPPChatRoom *joiningRoom = (MVXMPPChatRoom *)[[self joinedChatRoomWithUniqueIdentifier:roomId] retain];
	if( joiningRoom && [joiningRoom isJoined] ) {
		// already joined
		[joiningRoom release];
		[roomId release];
		return;
	}

	NSString *localUserStringId = [[NSString allocWithZone:nil] initWithFormat:@"%@/%@", room, [self nickname]];
	JabberPresence *presence = [[JabberPresence allocWithZone:nil] initWithQName:JABBER_PRESENCE_QN];
	[presence putAttribute:@"to" withValue:localUserStringId];

	[presence addElement:[self _capabilitiesElement]];
	XMLElement *x = [presence addElement:[self _multiUserChatExtensionElement]];

	if ([passphrase length])
		[[x addElementWithName:@"password"] addCData:passphrase];

	[_session sendElement:presence];
	[presence release];

	JabberID *localUserJabberId = [[JabberID allocWithZone:nil] initWithString:localUserStringId];
	MVXMPPChatUser *localUser = (MVXMPPChatUser *)[self chatUserWithUniqueIdentifier:localUserJabberId];
	[localUser _setRoomMember:YES];
	[localUser _setType:MVChatLocalUserType];

	if( ! joiningRoom )
		joiningRoom = [[MVXMPPChatRoom allocWithZone:nil] initWithJabberID:roomId andConnection:self];
	[joiningRoom _setLocalMemberUser:localUser];
	[joiningRoom _setDateJoined:nil];
	[joiningRoom _setDateParted:nil];
	[joiningRoom _clearMemberUsers];
	[joiningRoom _clearBannedUsers];

	// joiningRoom will be released in incomingPresence

	[localUserStringId release];
	[localUserJabberId release];
	[roomId release];
}

#pragma mark -

- (void) connectFailed:(NSNotification *) notification {
	[self _didNotConnect];
}

- (void) badUser:(NSNotification *) notification {
	NSLog(@"badUser");
}

- (void) authorizationReady:(NSNotification *) notification {
	if( _password )
		[[notification object] authenticateWithPassword:_password];
}

- (void) authorizationFailed:(NSNotification *) notification {
	NSLog(@"authorizationFailed");
}

- (void) sessionStarted:(NSNotification *) notification {
	[self _didConnect];
}

- (void) sessionEnded:(NSNotification *) notification {
	[self _didDisconnect];
}

- (void) outgoingPacket:(NSNotification *) notification {
	NSString *string = [[NSString alloc] initWithData:[notification object] encoding:NSUTF8StringEncoding];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:string, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
	[string release];
}

- (void) incomingPacket:(NSNotification *) notification {
	NSString *string = [[NSString alloc] initWithData:[notification object] encoding:NSUTF8StringEncoding];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:string, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
	[string release];
}

- (void) incomingMessage:(NSNotification *) notification {
	JabberMessage *message = [notification object];

	if( [[message type] isEqualToString:@"error"] ) {
		// handle error
		return;
	}

	switch( [message eventType] ) {
	case JMEVENT_COMPOSING_REQUEST:
		// fall through
	case JMEVENT_NONE: {
		MVChatRoom *room = nil;
		MVChatUser *sender = nil;

		if( [[message type] isEqualToString:@"groupchat"] ) {
			room = [self joinedChatRoomWithUniqueIdentifier:[[message from] userhostJID]];
			if( ! room ) return;
			sender = [self chatUserWithUniqueIdentifier:[message from]];
			if( [sender isLocalUser] ) return;
		} else {
			sender = [self chatUserWithUniqueIdentifier:[message from]];
		}

		NSMutableData *msgData = [[[message body] dataUsingEncoding:NSUTF8StringEncoding] mutableCopyWithZone:nil];

		NSMutableDictionary *msgAttributes = [[NSMutableDictionary allocWithZone:nil] init];
		[msgAttributes setObject:sender forKey:@"user"];
		[msgAttributes setObject:msgData forKey:@"message"];

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableData * ), @encode( MVChatUser * ), @encode( id ), @encode( NSMutableDictionary * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setSelector:@selector( processIncomingMessageAsData:from:to:attributes: )];
		[invocation setArgument:&msgData atIndex:2];
		[invocation setArgument:&sender atIndex:3];
		[invocation setArgument:&room atIndex:4];
		[invocation setArgument:&msgAttributes atIndex:5];

		[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
		if( ! [msgData length] ) return;

		if( room ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomGotMessageNotification object:room userInfo:msgAttributes];
		} else {
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:msgAttributes];
		}

		[msgData release];
		[msgAttributes release];
		break;
	}

	case JMEVENT_COMPOSING:
		break;
	case JMEVENT_COMPOSING_CANCEL:
		break;
	}
}

- (void) incomingPresence:(NSNotification *) notification {
	JabberPresence *presence = [notification object];
	JabberID *roomID = [[presence from] userhostJID];
	MVChatRoom *room = [self joinedChatRoomWithUniqueIdentifier:roomID];

	if( ! room ) return;

	if ([[presence getAttribute:@"type"] isCaseInsensitiveEqualToString:@"error"]) {
		[room release]; // balance the alloc or retain in joinChatRoomNamed:
		// handle error...
		return;
	}

	MVXMPPChatUser *user = nil;
	if( [[[room localMemberUser] uniqueIdentifier] isEqual:[presence from]] )
		user = (MVXMPPChatUser *)[room localMemberUser];
	else user = (MVXMPPChatUser *)[self chatUserWithUniqueIdentifier:[presence from]];

	if ([[presence getAttribute:@"type"] isCaseInsensitiveEqualToString:@"unavailable"]) {
		[room _removeMemberUser:user];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
		return;
	}

	[room retain]; // retain incase the following release is the last reference

	if( ! [room isJoined] ) {
		[room _setDateJoined:[NSDate date]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomJoinedNotification object:room];
		[room release]; // balance the alloc or retain in joinChatRoomNamed:
	}

	if( ! [room hasUser:user] ) {
		[user _setRoomMember:YES];
		[room _addMemberUser:user];
		[self _markUserAsOnline:user];

		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:user] forKey:@"added"];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomMemberUsersSyncedNotification object:room userInfo:userInfo];
	}

	[room release];
}
@end

#pragma mark -

@implementation MVXMPPChatConnection (MVXMPPChatConnectionPrivate)
- (JabberSession *) _chatSession {
	return _session;
}

- (JabberID *) _localUserID {
	return _localID;
}

- (XMLElement *) _capabilitiesElement {
	XMLElement *caps = [[XMLElement allocWithZone:nil] initWithQName:JABBER_CLIENTCAP_QN];
	[caps putAttribute:@"node" withValue:@"http://colloquy.info/caps"];
	[caps putAttribute:@"ver" withValue:@"2.1"];
	return [caps autorelease];
}

- (XMLElement *) _multiUserChatExtensionElement {
	XMLQName *xQName = [XMLQName construct:@"x" withURI:@"http://jabber.org/protocol/muc"];
	return [[[XMLElement allocWithZone:nil] initWithQName:xQName] autorelease];
}
@end
