#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"

#define MODULE_NAME "MVIRCChatUser"

#import "core.h"
#import "irc.h"
#import "servers.h"

@implementation MVIRCChatUser
- (id) initLocalUserWithConnection:(MVIRCChatConnection *) connection {
	if( ( self = [self initWithNickname:nil andConnection:connection] ) ) {
		_type = MVChatLocalUserType;
		_uniqueIdentifier = [[[self nickname] lowercaseString] retain];
	}

	return self;
}

- (id) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = connection; // prevent circular retain
		_nickname = [nickname copyWithZone:[self zone]];
		_uniqueIdentifier = [[nickname lowercaseString] retain];
		_type = MVChatRemoteUserType;
	}

	return self;
}

#pragma mark -

- (unsigned) hash {
	// this hash assumes the MVIRCChatConnection will return the same instance for equal users
	return ( [self type] ^ [[self connection] hash] ^ (unsigned int) self );
}

- (unsigned long) supportedModes {
	return MVChatUserInvisibleMode;
}

- (NSSet *) supportedAttributes {
	return [NSSet setWithObjects:MVChatUserKnownRoomsAttribute, MVChatUserLocalTimeAttribute, MVChatUserClientInfoAttribute, nil];
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

#pragma mark -

- (void) refreshAttributes {
	[[self connection] sendRawMessageWithFormat:@"WHOIS %@ %@", [self nickname], [self nickname]];
}

- (void) refreshAttributeForKey:(NSString *) key {
	[super refreshAttributeForKey:key];
	if( [key isEqualToString:MVChatUserLocalTimeAttribute] ) {
		[self sendSubcodeRequest:@"TIME" withArguments:nil];
	} else if( [key isEqualToString:MVChatUserClientInfoAttribute] ) {
		[self sendSubcodeRequest:@"VERSION" withArguments:nil];
	} else [self refreshAttributes];
}
@end