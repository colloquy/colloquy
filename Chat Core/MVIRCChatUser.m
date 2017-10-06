#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "NSStringAdditions.h"
#import "MVUtilities.h"
#import "MVChatString.h"
#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVIRCChatUser {
	BOOL _hasPendingRefreshInformationRequest;
}

+ (NSArray <NSString *> *) servicesNicknames {
	return @[
		@"nickserv", @"chanserv", @"memoserv", @"operserv", @"botserv", // common services
		@"q", @"quakenet", @"x", @"undernet", @"authserv", @"gamesurge", // network-specific services
		@"*status", @"*playback", @"*colloquy" // bouncer-specific services
	];
}

- (instancetype) initLocalUserWithConnection:(MVIRCChatConnection *) userConnection {
	if( ( self = [self initWithNickname:@"" andConnection:userConnection] ) ) {
		_type = MVChatLocalUserType;
		MVSafeCopyAssign( _uniqueIdentifier, [[self nickname] lowercaseString] );
	}

	return self;
}

- (instancetype) initWithNickname:(NSString *) userNickname andConnection:(MVIRCChatConnection *) userConnection {
	if( ( self = [self init] ) ) {
		_type = MVChatRemoteUserType;
		_connection = userConnection; // prevent retain cycles

		MVSafeCopyAssign( _nickname, userNickname );
		MVSafeCopyAssign( _uniqueIdentifier, [userNickname lowercaseString] );

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( ctcpReplyNotification: ) name:MVChatConnectionSubcodeReplyNotification object:self];

		[userConnection _addKnownUser:self];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
}

#pragma mark -

- (NSString *__nullable) maskRepresentation {
	return [NSString stringWithFormat:@"%@!%@@%@", (self.nickname ?: @""), (self.username ?: @""), (self.address ?: @"")];
}

#pragma mark -

- (NSUInteger) supportedModes {
	return MVChatUserInvisibleMode;
}

- (NSSet *) supportedAttributes {
	return [NSSet setWithObjects:MVChatUserPingAttribute, MVChatUserKnownRoomsAttribute, MVChatUserLocalTimeAttribute, MVChatUserClientInfoAttribute, MVChatUserSSLCertFingerprintAttribute, MVChatUserEmailAttribute, MVChatUserPhoneAttribute, MVChatUserWebsiteAttribute, MVChatUserIMServiceAttribute, MVChatUserCurrentlyPlayingAttribute, MVChatUserStatusAttribute, MVChatUserClientNameAttribute, MVChatUserClientVersionAttribute, nil];
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );
	[[self connection] _sendMessage:message withEncoding:encoding toTarget:self withTargetPrefix:@"" withAttributes:attributes localEcho:NO];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding {
	NSParameterAssert( command != nil );
	[[self connection] _sendCommand:command withArguments:arguments withEncoding:encoding toTarget:self];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id __nullable) arguments {
	NSParameterAssert( command != nil );

	MVChatConnection *connection = [self connection];
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString alloc] initWithFormat:@"PRIVMSG %@ :\001%@ ", [self nickname], command];
		[connection sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[connection sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@ %@\001", [self nickname], command, arguments];
	} else [connection sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", [self nickname], command];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(id __nullable) arguments {
	NSParameterAssert( command != nil );

	MVChatConnection *connection = [self connection];
	if( [connection status] == MVChatConnectionConnectingStatus ) {
		if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
			NSString *prefix = [[NSString alloc] initWithFormat:@"NOTICE %@ :\001%@ ", [self nickname], command];
			[connection sendRawMessageImmediatelyWithComponents:prefix, arguments, @"\001", nil];
		} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
			[connection sendRawMessageImmediatelyWithFormat:@"NOTICE %@ :\001%@ %@\001", [self nickname], command, arguments];
		} else [connection sendRawMessageImmediatelyWithFormat:@"NOTICE %@ :\001%@\001", [self nickname], command];
	} else {
		if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
			NSString *prefix = [[NSString alloc] initWithFormat:@"NOTICE %@ :\001%@ ", [self nickname], command];
			[connection sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
		} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
			[connection sendRawMessageWithFormat:@"NOTICE %@ :\001%@ %@\001", [self nickname], command, arguments];
		} else [connection sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", [self nickname], command];
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (void) refreshInformation {
	if( _hasPendingRefreshInformationRequest ) return;
	_hasPendingRefreshInformationRequest = YES;

	MVChatConnection *connection = [self connection];
	[connection sendRawMessageWithFormat:@"WHOIS %@ %1$@", [self nickname]];
}

- (void) _setDateUpdated:(NSDate *) date {
	_hasPendingRefreshInformationRequest = NO;
	[super _setDateUpdated:date];
}

- (void) refreshAttributeForKey:(NSString *) key {
	[super refreshAttributeForKey:key];
	if( [key isEqualToString:MVChatUserPingAttribute] ) {
		[self setAttribute:[NSDate date] forKey:@"MVChatUserPingSendDateAttribute"];
		[self sendSubcodeRequest:@"PING" withArguments:nil];
	} else if( [key isEqualToString:MVChatUserLocalTimeAttribute] ) {
		[self sendSubcodeRequest:@"TIME" withArguments:nil];
	} else if( [key isEqualToString:MVChatUserClientInfoAttribute] ) {
		[self sendSubcodeRequest:@"VERSION" withArguments:nil];
	} else if( [key isEqualToString:MVChatUserKnownRoomsAttribute] ) {
		[self refreshInformation];
	}
}

#pragma mark -

- (void) ctcpReplyNotification:(NSNotification *) notification {
	MVChatConnection *connection = [self connection];
	NSString *command = [notification userInfo][@"command"];
	NSData *arguments = [notification userInfo][@"arguments"];
	if( [command isCaseInsensitiveEqualToString:@"PING"] ) {
		NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:[self attributeForKey:@"MVChatUserPingSendDateAttribute"]];
		[self setAttribute:@(diff) forKey:MVChatUserPingAttribute];
		[self setAttribute:nil forKey:@"MVChatUserPingSendDateAttribute"];
	} else if( [command isCaseInsensitiveEqualToString:@"VERSION"] ) {
		NSString *info = [[NSString alloc] initWithData:arguments encoding:[connection encoding]];
		[self setAttribute:info forKey:MVChatUserClientInfoAttribute];
	} else if( [command isCaseInsensitiveEqualToString:@"TIME"] ) {
		NSString *date = [[NSString alloc] initWithData:arguments encoding:[connection encoding]];
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
		[self setAttribute:date forKey:MVChatUserLocalTimeAttribute];
#else
		NSCalendarDate *localThere = [NSCalendarDate dateWithNaturalLanguageString:date];
		[self setAttribute:localThere forKey:MVChatUserLocalTimeAttribute];
#endif
	}
}

- (void) requestRecentActivity {
	MVChatConnection *connection = [self connection];
	if( [[connection supportedFeatures] containsObject:MVIRCChatConnectionZNCPluginPlaybackFeature] ) {
		if (self.mostRecentUserActivity)
			[connection sendRawMessageImmediatelyWithFormat:@"PRIVMSG *playback PLAY %@ %.2", self.nickname, [self.mostRecentUserActivity timeIntervalSince1970]];
		else [connection sendRawMessageImmediatelyWithFormat:@"PRIVMSG *playback PLAY %@ 0", self.nickname];
	}
}

- (void) persistLastActivityDate {
	MVChatConnection *connection = [self connection];
	if ( _mostRecentUserActivity && [[connection supportedFeatures] containsObject:MVIRCChatConnectionZNCPluginPlaybackFeature] ) {
		NSString *recentActivityDateKey = [NSString stringWithFormat:@"%@-%@", connection.uniqueIdentifier, self.uniqueIdentifier];
		[[NSUserDefaults standardUserDefaults] setObject:_mostRecentUserActivity forKey:recentActivityDateKey];
	}
}
@end

NS_ASSUME_NONNULL_END
