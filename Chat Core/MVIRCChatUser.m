#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"

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
		_nickname = [nickname copyWithZone:nil];
		_uniqueIdentifier = [[nickname lowercaseString] retain];
		_type = MVChatRemoteUserType;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( ctcpReplyNotification: ) name:MVChatConnectionSubcodeReplyNotification object:self];
	}

	return self;
}

- (void) finalize {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super finalize];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

#pragma mark -

- (unsigned long) supportedModes {
	return MVChatUserInvisibleMode;
}

- (NSSet *) supportedAttributes {
	return [NSSet setWithObjects:MVChatUserKnownRoomsAttribute, MVChatUserLocalTimeDifferenceAttribute, MVChatUserClientInfoAttribute, nil];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	NSParameterAssert( message != nil );
	NSData *msg = [MVIRCChatConnection _flattenedIRCDataForMessage:message withEncoding:encoding andChatFormat:[[self connection] outgoingChatFormat]];
	[[self connection] _sendMessage:message withEncoding:encoding toTarget:[self nickname] asAction:action];
}

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments {
	NSParameterAssert( command != nil );
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@ :\001%@ ", [self nickname], command];
		[[self connection] sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
		[prefix release];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@ %@\001", [self nickname], command, arguments];
	} else [[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", [self nickname], command];
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments {
	NSParameterAssert( command != nil );
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"NOTICE %@ :\001%@ ", [self nickname], command];
		[[self connection] sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
		[prefix release];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@ %@\001", [self nickname], command, arguments];
	} else [[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", [self nickname], command];
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
	} else if( [key isEqualToString:MVChatUserKnownRoomsAttribute] ) {
		[self refreshInformation];
	}
}

#pragma mark -

- (void) ctcpReplyNotification:(NSNotification *) notification {
	NSString *command = [[notification userInfo] objectForKey:@"command"];
	NSData *arguments = [[notification userInfo] objectForKey:@"arguments"];
	if( [command caseInsensitiveCompare:@"VERSION"] == NSOrderedSame ) {
		NSString *info = [[NSString allocWithZone:nil] initWithData:arguments encoding:[[self connection] encoding]];
		[self setAttribute:info forKey:MVChatUserClientInfoAttribute];
		[info release];
	} else if( [command caseInsensitiveCompare:@"TIME"] == NSOrderedSame ) {
		NSString *date = [[NSString allocWithZone:nil] initWithData:arguments encoding:[[self connection] encoding]];
		NSDate *localThere = [NSDate dateWithNaturalLanguageString:date];
		if( localThere ) {
			NSTimeInterval diff = [localThere timeIntervalSinceDate:[NSDate date]];
			[self setAttribute:[NSNumber numberWithDouble:diff] forKey:MVChatUserLocalTimeDifferenceAttribute];
		} else [self setAttribute:nil forKey:MVChatUserLocalTimeDifferenceAttribute];
		[date release];
	}
}
@end