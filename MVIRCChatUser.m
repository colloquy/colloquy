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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( ctcpReplyNotification: ) name:MVChatConnectionSubcodeReplyNotification object:self];
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
	return [NSSet setWithObjects:MVChatUserKnownRoomsAttribute, MVChatUserLocalTimeDifferenceAttribute, MVChatUserClientInfoAttribute, nil];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	NSParameterAssert( message != nil );

	const char *msg = [MVIRCChatConnection _flattenedIRCStringForMessage:message withEncoding:encoding andChatFormat:[[self connection] outgoingChatFormat]];

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

- (void) refreshInformation {
	[[self connection] sendRawMessageWithFormat:@"WHOIS %@ %@", [self nickname], [self nickname]];
}

- (void) refreshAttributeForKey:(NSString *) key {
	[super refreshAttributeForKey:key];
	if( [key isEqualToString:MVChatUserLocalTimeDifferenceAttribute] ) {
		[self sendSubcodeRequest:@"TIME" withArguments:nil];
	} else if( [key isEqualToString:MVChatUserClientInfoAttribute] ) {
		[self sendSubcodeRequest:@"VERSION" withArguments:nil];
	} else [self refreshAttributes];
}

#pragma mark -

- (void) ctcpReplyNotification:(NSNotification *) notification {
	NSString *command = [[notification userInfo] objectForKey:@"command"];
	NSString *arguments = [[notification userInfo] objectForKey:@"arguments"];
	if( ! [command caseInsensitiveCompare:@"version"] ) {
		[self _setAttribute:arguments forKey:MVChatUserClientInfoAttribute];
	} else if( ! [command caseInsensitiveCompare:@"time"] ) {
		NSDate *localThere = [NSDate dateWithNaturalLanguageString:arguments];
		if( localThere ) {
			NSTimeInterval diff = [localThere timeIntervalSinceDate:[NSDate date]];
			[self _setAttribute:[NSNumber numberWithDouble:diff] forKey:MVChatUserLocalTimeDifferenceAttribute];
		} else [self _setAttribute:nil forKey:MVChatUserLocalTimeDifferenceAttribute]; 
	}
}
@end