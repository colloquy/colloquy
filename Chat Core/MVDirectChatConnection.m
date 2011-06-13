#import "MVDirectChatConnection.h"
#import "MVDirectChatConnectionPrivate.h"

#import "InterThreadMessaging.h"
#import "MVDirectClientConnection.h"
#import "MVIRCChatConnection.h"
#import "MVFileTransfer.h"
#import "MVChatUser.h"
#import "MVChatString.h"
#import "MVUtilities.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"

#if USE(ATTRIBUTED_CHAT_STRING)
#import "NSAttributedStringAdditions.h"
#endif

NSString *MVDirectChatConnectionOfferNotification = @"MVDirectChatConnectionOfferNotification";

NSString *MVDirectChatConnectionDidConnectNotification = @"MVDirectChatConnectionDidConnectNotification";
NSString *MVDirectChatConnectionDidDisconnectNotification = @"MVDirectChatConnectionDidDisconnectNotification";
NSString *MVDirectChatConnectionErrorOccurredNotification = @"MVDirectChatConnectionErrorOccurredNotification";

NSString *MVDirectChatConnectionGotMessageNotification = @"";

NSString *MVDirectChatConnectionErrorDomain = @"MVDirectChatConnectionErrorDomain";

@implementation MVDirectChatConnection
+ (id) directChatConnectionWithUser:(MVChatUser *) user passively:(BOOL) passive {
	static NSUInteger passiveId = 0;

	MVDirectChatConnection *ret = [(MVDirectChatConnection *)[MVDirectChatConnection alloc] initWithUser:user];
	[ret _setLocalRequest:YES];
	[ret _setPassive:passive];

	if( passive ) {
		if( ++passiveId > 999 ) passiveId = 1;
		[ret _setPassiveIdentifier:passiveId];

		// register with the main connection so the passive reply can find the original
		[(MVIRCChatConnection *)[user connection] _addDirectClientConnection:ret];

		[user sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"CHAT chat 16843009 0 %lu", passiveId]];
	} else {
		[ret initiate];
	}

	return [ret autorelease];
}

- (oneway void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		_releasing = YES;
		[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
	}

	[super release];
}

- (void) dealloc {
	[_directClientConnection disconnect];
	[_directClientConnection setDelegate:nil];
	[_directClientConnection release];

	[_host release];
	[_connectedHost release];
	[_user release];
	[_lastError release];

	[super dealloc];
}

- (void) finalize {
	[_directClientConnection disconnect];

	[super finalize];
}

#pragma mark -

- (BOOL) isPassive {
	return _passive;
}

- (MVDirectChatConnectionStatus) status {
	return _status;
}

- (MVChatUser *) user {
	return _user;
}

- (NSString *) host {
	return _host;
}

- (NSString *) connectedHost {
	return _connectedHost;
}

- (unsigned short) port {
	return _port;
}

- (NSString *) description {
	return [[self user] description];
}

#pragma mark -

- (void) initiate {
	if( [_directClientConnection connectionThread] ) return;

	MVSafeAdoptAssign( _directClientConnection, [[MVDirectClientConnection alloc] init] );
	[_directClientConnection setDelegate:self];

	if( _localRequest ) {
		if( ! [self isPassive] ) [_directClientConnection acceptConnectionOnFirstPortInRange:[MVFileTransfer fileTransferPortRange]];
		else [_directClientConnection connectToHost:[self host] onPort:[self port]];
	} else {
		if( [self isPassive] ) [_directClientConnection acceptConnectionOnFirstPortInRange:[MVFileTransfer fileTransferPortRange]];
		else [_directClientConnection connectToHost:[self host] onPort:[self port]];
	}
}

- (void) disconnect {
	[_directClientConnection disconnect];
	if( [self status] != MVDirectChatConnectionErrorStatus )
		[self _setStatus:MVDirectChatConnectionDisconnectedStatus];
}

#pragma mark -

- (void) setEncoding:(NSStringEncoding) newEncoding {
	_encoding = newEncoding;
}

- (NSStringEncoding) encoding {
	return _encoding;
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

- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action {
	[self sendMessage:message withEncoding:[self encoding] asAction:action];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	[self sendMessage:message withEncoding:encoding withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:action] forKey:@"action"]];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *)attributes {
	NSParameterAssert( message != nil );

	if( [self status] != MVDirectChatConnectionConnectedStatus )
		return;

#if USE(ATTRIBUTED_CHAT_STRING)
	NSString *cformat = nil;

	switch( [self outgoingChatFormat] ) {
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

	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:encoding], @"StringEncoding", cformat, @"FormatType", nil];
	NSData *msg = [message chatFormatWithOptions:options];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	NSData *msg = [message dataUsingEncoding:encoding allowLossyConversion:YES];
#endif

	if( [[attributes objectForKey:@"action"] boolValue] ) {
		NSMutableData *newMsg = [[NSMutableData alloc] initWithCapacity:msg.length + 11];
		[newMsg appendBytes:"\001ACTION " length:8];
		[newMsg appendData:msg];
		[newMsg appendBytes:"\001\x0D\x0A" length:3];

		[self performSelector:@selector( _writeMessage: ) withObject:newMsg inThread:[_directClientConnection connectionThread]];

		[newMsg release];
	} else {
		NSMutableData *newMsg = [msg mutableCopy];
		[newMsg appendBytes:"\x0D\x0A" length:2];

		[self performSelector:@selector( _writeMessage: ) withObject:newMsg inThread:[_directClientConnection connectionThread]];

		[newMsg release];
	}
}

#pragma mark -

- (void) directClientConnection:(MVDirectClientConnection *) connection didConnectToHost:(NSString *) host port:(unsigned short) port {
	[self _setStatus:MVDirectChatConnectionConnectedStatus];

	MVSafeRetainAssign( _connectedHost, host );

	[self _readNextMessage];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection acceptingConnectionsToHost:(NSString *) host port:(unsigned short) port {
	NSString *address = MVDCCFriendlyAddress( host );
	[self _setPort:port];

	if( [self isPassive] ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"CHAT chat %@ %hu %lu", address, [self port], [self _passiveIdentifier]]];
	else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"CHAT chat %@ %hu", address, [self port]]];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection willDisconnectWithError:(NSError *) error {
	NSLog(@"DCC chat willDisconnectWithError: %@", error );
	if( error ) [self _postError:error];
}

- (void) directClientConnectionDidDisconnect:(MVDirectClientConnection *) connection {
	if( [self status] != MVDirectChatConnectionErrorStatus )
		[self _setStatus:MVDirectChatConnectionDisconnectedStatus];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection didReadData:(NSData *) data withTag:(long) tag {
	const char *bytes = (const char *)[data bytes];
	NSUInteger len = data.length;
	const char *end = bytes + len - 2; // minus the line endings
	BOOL ctcp = ( *bytes == '\001' && data.length > 3 ); // three is the one minimum line ending and two \001 chars

	if( *end != '\x0D' )
		end = bytes + len - 1; // this client only uses \x0A for the message line ending, lets work with it

	if( ctcp ) {
		const char *line = bytes + 1; // skip the first \001 char
		const char *current = line;

		if( *( end - 1 ) == '\001' )
			end = end - 1; // minus the last \001 char

		while( line != end && *line != ' ' ) line++;

		NSString *command = [[NSString alloc] initWithBytes:current length:(line - current) encoding:NSASCIIStringEncoding];
		NSData *arguments = nil;
		if( line != end ) {
			line++;
			arguments = [[NSData alloc] initWithBytes:line length:(end - line)];
		}

		if( [command isCaseInsensitiveEqualToString:@"ACTION"] && arguments ) {
			// special case ACTION and send it out like a message with the action flag
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionGotMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:arguments, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"action", nil]];
		}

		[command release];
		[arguments release];
	} else {
		NSData *msg = [[NSData alloc] initWithBytes:bytes length:(end - bytes)];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionGotMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msg, @"message", [NSString locallyUniqueString], @"identifier", nil]];
		[msg release];
	}

	[self _readNextMessage];
}
@end

#pragma mark -

@implementation MVDirectChatConnection (MVDirectChatConnectionPrivate)
- (id) initWithUser:(MVChatUser *) chatUser {
	if( ( self = [super init] ) ) {
		_status = MVDirectChatConnectionWaitingStatus;
		_encoding = NSUTF8StringEncoding;
		_outgoingChatFormat = MVChatConnectionDefaultMessageFormat;
		_user = [chatUser retain];
	}

	return self;
}

- (void) _writeMessage:(NSData *) message {
	MVAssertCorrectThreadRequired( [_directClientConnection connectionThread] );
	[_directClientConnection writeData:message withTimeout:-1 withTag:0];
}

- (void) _readNextMessage {
	MVAssertCorrectThreadRequired( [_directClientConnection connectionThread] );

	static NSData *delimiter = nil;
	// DCC chat messages end in \x0D\x0A, but some non-compliant clients only use \x0A
	if( ! delimiter ) delimiter = [[NSData alloc] initWithBytes:"\x0A" length:1];
	[_directClientConnection readDataToData:delimiter withTimeout:-1. withTag:0];
}

- (void) _setStatus:(MVDirectChatConnectionStatus) newStatus {
	NSUInteger oldStatus = _status;
	_status = newStatus;

	if( oldStatus == newStatus )
		return;

	if( newStatus == MVDirectChatConnectionConnectedStatus )
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionDidConnectNotification object:self];
	else if( newStatus == MVDirectChatConnectionDisconnectedStatus )
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionDidDisconnectNotification object:self];
}

- (void) _setHost:(NSString *) newHost {
	MVSafeRetainAssign( _host, newHost );
}

- (void) _setPort:(unsigned short) newPort {
	_port = newPort;
}

- (void) _setPassive:(BOOL) isPassive {
	_passive = isPassive;
}

- (void) _setLocalRequest:(BOOL) localRequest {
	_localRequest = localRequest;
}

- (void) _setPassiveIdentifier:(long long) identifier {
	_passiveId = identifier;
}

- (long long) _passiveIdentifier {
	return _passiveId;
}

- (void) _postError:(NSError *) error {
	[self _setStatus:MVDirectChatConnectionErrorStatus];

	MVSafeRetainAssign( _lastError, error );

	NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:error, @"error", nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVDirectChatConnectionErrorOccurredNotification object:self userInfo:info];
	[info release];
}
@end
