#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"

#define MODULE_NAME "MVIRCChatUser"

#import "core.h"
#import "irc.h"
#import "servers.h"

@interface MVChatConnection (MVChatConnectionPrivate)
+ (const char *) _flattenedIRCStringForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc;
- (SERVER_REC *) _irssiConnection;
@end

#pragma mark -

@implementation MVIRCChatUser
- (id) initLocalUserWithConnection:(MVIRCChatConnection *) connection {
	if( ( self = [self initWithNickname:nil andConnection:connection] ) ) {
		_type = MVChatLocalUserType;
	}

	return self;
}

- (id) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection {
	if( ( self = [super init] ) ) {
		_connection = connection; // prevent circular retain
		_nickname = [nickname copyWithZone:[self zone]];
		_type = MVChatRemoteUserType;
	}

	return self;
}

#pragma mark -

- (id) uniqueIdentifier {
	return [[self nickname] lowercaseString];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	NSParameterAssert( message != nil );

	const char *msg = [[[self connection] class] _flattenedIRCStringForMessage:message withEncoding:encoding];

	[MVIRCChatConnectionThreadLock lock];

	if( ! action ) [[self connection] _irssiConnection] -> send_message( [[self connection] _irssiConnection], [[self connection] encodedBytesWithString:[self nickname]], msg, 0 );
	else irc_send_cmdv( (IRC_SERVER_REC *) [[self connection] _irssiConnection], "PRIVMSG %s :\001ACTION %s\001", [[self connection] encodedBytesWithString:[self nickname]], msg );

	[MVIRCChatConnectionThreadLock unlock];
}

- (void) sendSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSString *request = ( [arguments length] ? [NSString stringWithFormat:@"%@ %@", command, arguments] : command );
	[[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", [self nickname], request];
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSString *request = ( [arguments length] ? [NSString stringWithFormat:@"%@ %@", command, arguments] : command );
	[[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", [self nickname], request];
}
@end