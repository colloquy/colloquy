#import <Acid/acid.h>

#import "MVXMPPChatConnection.h"
#import "MVXMPPChatUser.h"
#import "MVUtilities.h"
#import "MVChatPluginManager.h"
#import "NSMethodSignatureAdditions.h"

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
		_session = [[JabberSession alloc] init];

		[_session addObserver:self selector:@selector( sessionStarted: ) name:JSESSION_STARTED];
		[_session addObserver:self selector:@selector( sessionEnded: ) name:JSESSION_ENDED];
		[_session addObserver:self selector:@selector( connectFailed: ) name:JSESSION_ERROR_CONNECT_FAILED];
		[_session addObserver:self selector:@selector( badUser: ) name:JSESSION_ERROR_BADUSER];
		[_session addObserver:self selector:@selector( authorizationReady: ) name:JSESSION_AUTHREADY];
		[_session addObserver:self selector:@selector( authorizationFailed: ) name:JSESSION_ERROR_AUTHFAILED];
		[_session addObserver:self selector:@selector( outgoingPacket: ) name:JSESSION_RAWDATA_OUT];
		[_session addObserver:self selector:@selector( incomingPacket: ) name:JSESSION_RAWDATA_IN];
		[_session addObserver:self selector:@selector( incomingPrivateMessage: ) xpath:@"/message[@type='chat']"];
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
	[_password release];
	[_knownUsers release];

	_session = nil;
	_localID = nil;
	_server = nil;
	_username = nil;
	_password = nil;
	_knownUsers = nil;

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

	MVSafeAdoptAssign( &_localID, [[JabberID alloc] initWithFormat:@"%@@%@/colloquy", _username, _server] );
	MVSafeAdoptAssign( &_localUser, [[MVXMPPChatUser allocWithZone:nil] initLocalUserWithConnection:self] );

    [_session startSession:_localID onPort:_serverPort];
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
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
	[self setUsername:newNickname];
}

- (NSString *) nickname {
	return [self username];
}

- (NSString *) preferredNickname {
	return [self username];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) newPassword {
	[self setPassword:newPassword];
}

- (NSString *) nicknamePassword {
	return [self password];
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
	NSParameterAssert( newServer != nil );
	NSParameterAssert( [newServer length] > 0 );
	MVSafeCopyAssign( &_server, newServer );
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

- (NSSet *) knownChatUsers {
	@synchronized( _knownUsers ) {
		return [NSSet setWithArray:[_knownUsers allValues]];
	} return nil;
}

- (NSSet *) chatUsersWithNickname:(NSString *) name {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:name]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] || [identifier isKindOfClass:[JabberID class]] );

	if( [identifier isKindOfClass:[JabberID class]] )
		identifier = [identifier completeID];
	if( [identifier isEqualToString:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	if( ! _knownUsers )
		_knownUsers = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:50];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:identifier];
		if( user ) return user;

		JabberID *jabberID = [[JabberID alloc] initWithString:identifier];
		user = [[MVXMPPChatUser allocWithZone:nil] initWithJabberID:jabberID andConnection:self];
		if( user ) [_knownUsers setObject:user forKey:identifier];
		[jabberID release];
	}

	return [user autorelease];
}

#pragma mark -

- (void) connectFailed:(NSNotification *) notification {
	[self _didNotConnect];
}

- (void) badUser:(NSNotification *) notification {
	NSLog(@"badUser");
}

- (void) authorizationReady:(NSNotification *) notification {
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
	NSString *string = [@"send: " stringByAppendingString:[[NSString alloc] initWithData:[notification object] encoding:NSUTF8StringEncoding]];
	NSLog(@"%@", string);
}

- (void) incomingPacket:(NSNotification *) notification {
    NSString *string = [@"recv: " stringByAppendingString:[[NSString alloc] initWithData:[notification object] encoding:NSUTF8StringEncoding]];
	NSLog(@"%@", string);
}

- (void) incomingPrivateMessage:(NSNotification *) notification {
    JabberMessage *message = [notification object];

    switch( [message eventType] ) {
    case JMEVENT_COMPOSING_REQUEST:
		// fall through
    case JMEVENT_NONE: {
		MVChatRoom *room = nil;
		MVChatUser *sender = [self chatUserWithUniqueIdentifier:[message from]];
		NSMutableData *msgData = [[[message body] dataUsingEncoding:NSUTF8StringEncoding] mutableCopyWithZone:nil];

		NSMutableDictionary *msgAttributes = [[NSMutableDictionary allocWithZone:nil] init];
		[msgAttributes setObject:sender forKey:@"sender"];
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

		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:msgAttributes];

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
@end


#pragma mark -

@implementation MVXMPPChatConnection (MVXMPPChatConnectionPrivate)
- (JabberSession *) _chatSession {
	return _session;
}

- (JabberID *) _localUserID {
	return _localID;
}
@end
