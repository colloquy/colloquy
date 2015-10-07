#import "MVIRCChatRoom.h"

#import "MVIRCChatConnection.h"
#import "MVIRCChatUser.h"
#import "NSStringAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVIRCChatRoom
- (instancetype) initWithName:(NSString *) roomName andConnection:(MVIRCChatConnection *) roomConnection {
	if( ( self = [self init] ) ) {
		_connection = roomConnection; // prevent circular retain
		_name = [roomName copy];
		_uniqueIdentifier = [roomName lowercaseString];
		[roomConnection _addKnownRoom:self];

		NSString *recentActivityDateKey = [NSString stringWithFormat:@"%@-%@", self.connection.uniqueIdentifier, self.uniqueIdentifier];
		_mostRecentUserActivity = [[NSUserDefaults standardUserDefaults] objectForKey:recentActivityDateKey];
	}

	return self;
}

#pragma mark -

- (NSUInteger) supportedModes {
	return ( MVChatRoomPrivateMode | MVChatRoomSecretMode | MVChatRoomInviteOnlyMode | MVChatRoomNormalUsersSilencedMode | MVChatRoomOperatorsOnlySetTopicMode | MVChatRoomNoOutsideMessagesMode | MVChatRoomPassphraseToJoinMode | MVChatRoomLimitNumberOfMembersMode );
}

- (NSUInteger) supportedMemberUserModes {
	NSUInteger supported = ( MVChatRoomMemberVoicedMode | MVChatRoomMemberOperatorMode );
	supported |= MVChatRoomMemberHalfOperatorMode; // optional later
	supported |= MVChatRoomMemberAdministratorMode; // optional later
	supported |= MVChatRoomMemberFounderMode; // optional later
	return supported;
}

- (NSUInteger) supportedMemberDisciplineModes {
	return MVChatRoomMemberDisciplineQuietedMode;
}

#pragma mark -

- (void) partWithReason:(MVChatString * __nullable) reason {
	if( ! [self isJoined] ) return;

	if( reason.length ) {
		NSData *reasonData = [MVIRCChatConnection _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];
		NSString *prefix = [[NSString alloc] initWithFormat:@"PART %@ :", [self name]];
		[[self connection] sendRawMessageWithComponents:prefix, reasonData, nil];
	} else [[self connection] sendRawMessageImmediatelyWithFormat:@"PART %@", [self name]];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (void) changeTopic:(MVChatString *) newTopic {
	NSParameterAssert( newTopic != nil );
	NSData *msg = [MVIRCChatConnection _flattenedIRCDataForMessage:newTopic withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];
	NSString *prefix = [[NSString alloc] initWithFormat:@"TOPIC %@ :", [self name]];
	[[self connection] sendRawMessageWithComponents:prefix, msg, nil];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) msgEncoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );
	[[self connection] _sendMessage:message withEncoding:msgEncoding toTarget:self withTargetPrefix:@"" withAttributes:attributes localEcho:NO];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding {
	NSParameterAssert( command != nil );
	[[self connection] _sendCommand:command withArguments:arguments withEncoding:encoding toTarget:self];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments {
	NSParameterAssert( command != nil );
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString alloc] initWithFormat:@"PRIVMSG %@ :\001%@ ", [self name], command];
		[[self connection] sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@ %@\001", [self name], command, arguments];
	} else [[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", [self name], command];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments {
	NSParameterAssert( command != nil );
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString alloc] initWithFormat:@"NOTICE %@ :\001%@ ", [self name], command];
		[[self connection] sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@ %@\001", [self name], command, arguments];
	} else [[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", [self name], command];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (void) setMode:(MVChatRoomMode) mode withAttribute:(id __nullable) attribute {
	[super setMode:mode withAttribute:attribute];

	switch( mode ) {
	case MVChatRoomPrivateMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +p", [self name]];
		break;
	case MVChatRoomSecretMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +s", [self name]];
		break;
	case MVChatRoomInviteOnlyMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +i", [self name]];
		break;
	case MVChatRoomNormalUsersSilencedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +m", [self name]];
		break;
	case MVChatRoomOperatorsOnlySetTopicMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +t", [self name]];
		break;
	case MVChatRoomNoOutsideMessagesMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +n", [self name]];
		break;
	case MVChatRoomPassphraseToJoinMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +k %@", [self name], attribute];
		break;
	case MVChatRoomLimitNumberOfMembersMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +l %@", [self name], attribute];
	default:
		break;
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) removeMode:(MVChatRoomMode) mode {
	[super removeMode:mode];

	switch( mode ) {
	case MVChatRoomPrivateMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -p", [self name]];
		break;
	case MVChatRoomSecretMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -s", [self name]];
		break;
	case MVChatRoomInviteOnlyMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -i", [self name]];
		break;
	case MVChatRoomNormalUsersSilencedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -m", [self name]];
		break;
	case MVChatRoomOperatorsOnlySetTopicMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -t", [self name]];
		break;
	case MVChatRoomNoOutsideMessagesMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -n", [self name]];
		break;
	case MVChatRoomPassphraseToJoinMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -k %@", [self name], ( [self attributeForMode:MVChatRoomPassphraseToJoinMode] != nil ? [self attributeForMode:MVChatRoomPassphraseToJoinMode] : @"*" )];
		break;
	case MVChatRoomLimitNumberOfMembersMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -l", [self name]];
	default:
		break;
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	[super setMode:mode forMemberUser:user];

	switch( mode ) {
	case MVChatRoomMemberFounderMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +q %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberAdministratorMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +a %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberOperatorMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +o %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberHalfOperatorMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +h %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberVoicedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +v %@", [self name], [user nickname]];
		break;
	default:
		break;
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	[super removeMode:mode forMemberUser:user];

	switch( mode ) {
	case MVChatRoomMemberFounderMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -q %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberAdministratorMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -a %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberOperatorMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -o %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberHalfOperatorMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -h %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberVoicedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -v %@", [self name], [user nickname]];
		break;
	default:
		break;
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) setDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user {
	[super setDisciplineMode:mode forMemberUser:user];

	switch (mode) {
	case MVChatRoomMemberDisciplineQuietedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +q %@", [self name], [user nickname]];
		break;
	default:
		break;
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) removeDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user {
	[super removeDisciplineMode:mode forMemberUser:user];

	switch (mode) {
	case MVChatRoomMemberDisciplineQuietedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -q %@", [self name], [user nickname]];
		break;
	default:
		break;
	}

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

#pragma mark -

- (NSSet *) memberUsersWithNickname:(NSString *) nickname {
	MVChatUser *user = [self memberUserWithUniqueIdentifier:nickname];
	if( user ) return [NSSet setWithObject:user];
	return nil;
}

- (MVChatUser *) memberUserWithUniqueIdentifier:(id) identifier {
	if( ! [identifier isKindOfClass:[NSString class]] ) return nil;

	NSString *uniqueIdentfier = [identifier lowercaseString];

	@synchronized( _memberUsers ) {
		for( MVChatUser *user in _memberUsers )
			if( [[user uniqueIdentifier] isEqualToString:uniqueIdentfier] )
				return user;
	}

	return nil;
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(MVChatString * __nullable) reason {
	[super kickOutMemberUser:user forReason:reason];

	if( reason ) {
		NSData *msg = [MVIRCChatConnection _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];
		NSString *prefix = [[NSString alloc] initWithFormat:@"KICK %@ %@ :", [self name], [user nickname]];
		[[self connection] sendRawMessageImmediatelyWithComponents:prefix, msg, nil];
	} else [[self connection] sendRawMessageImmediatelyWithFormat:@"KICK %@ %@", [self name], [user nickname]];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) addBanForUser:(MVChatUser *) user {
	if ([[user nickname] hasCaseInsensitiveSubstring:@"$"] || [[user nickname] hasCaseInsensitiveSubstring:@":"] || [[user nickname] hasCaseInsensitiveSubstring:@"~"]) { // extended bans on ircd-seven, inspircd and unrealircd
		if ([[user nickname] hasCaseInsensitiveSubstring:@"~q"] || [[user nickname] hasCaseInsensitiveSubstring:@"~n"]) // These two extended bans on unreal-style ircds take full hostmasks as their arguments
			[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ +b %@", [self name], [user displayName]];
		else
			[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ +b %@", [self name], [user nickname]];
	} else if ( [user isWildcardUser] || ! [user username] || ! [user address] )
		[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ +b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
	else {
		NSString *addressToBan = [self modifyAddressForBan:user];

		[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ +b *!*%@*@%@", [self name], [user username], addressToBan ];
	}
	[super addBanForUser:user];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (void) removeBanForUser:(MVChatUser *) user {
	if ([[user nickname] hasCaseInsensitiveSubstring:@"$"] || [[user nickname] hasCaseInsensitiveSubstring:@":"] || [[user nickname] hasCaseInsensitiveSubstring:@"~"]) { // extended bans on ircd-seven, inspircd and unrealircd
		if ([[user nickname] hasCaseInsensitiveSubstring:@"~q"] || [[user nickname] hasCaseInsensitiveSubstring:@"~n"]) // These two extended bans on unreal-style ircds take full hostmasks as their arguments
			[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ -b %@", [self name], [user displayName]];
		else
			[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ -b %@", [self name], [user nickname]];
	} else if ( [user isWildcardUser] || ! [user username] || ! [user address] )
		[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ -b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
	else {
		NSString *addressToBan = [self modifyAddressForBan:user];

		[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ -b *!*%@*@%@", [self name], [user username], addressToBan ];
	}
	[super removeBanForUser:user];

	_mostRecentUserActivity = [NSDate date];
	[self persistLastActivityDate];
}

- (NSString *) modifyAddressForBan:(MVChatUser *) user {
	NSCharacterSet *newSectionOfHostmaskCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@".:/"];
	NSString *addressMaskToRemove = nil;
	NSString *addressMaskToBan = @"*";
	NSString *addressMask = [user address];
	NSScanner *scanner = nil;

	NSString *regexForIPv4Addresses = @"\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b";
	NSString *regexForIPv6Addresses = @"/^\\s*((([0-9A-Fa-f]{1,4}:){7}(([0-9A-Fa-f]{1,4})|:))|(([0-9A-Fa-f]{1,4}:){6}(:|((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})|(:[0-9A-Fa-f]{1,4})))|(([0-9A-Fa-f]{1,4}:){5}((:((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){4}(:[0-9A-Fa-f]{1,4}){0,1}((:((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){3}(:[0-9A-Fa-f]{1,4}){0,2}((:((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:){2}(:[0-9A-Fa-f]{1,4}){0,3}((:((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(([0-9A-Fa-f]{1,4}:)(:[0-9A-Fa-f]{1,4}){0,4}((:((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(:(:[0-9A-Fa-f]{1,4}){0,5}((:((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})?)|((:[0-9A-Fa-f]{1,4}){1,2})))|(((25[0-5]|2[0-4]\\d|[01]?\\d{1,2})(\\.(25[0-5]|2[0-4]\\d|[01]?\\d{1,2})){3})))(%.+)?\\s*$/";

	if ( [addressMask hasCaseInsensitiveSuffix:@"IP"] ) {
		addressMaskToBan = [[addressMask substringToIndex:addressMask.length - 2] stringByAppendingString:@"*"];
	} else if ( [addressMask isMatchedByRegex:regexForIPv4Addresses] || [addressMask isMatchedByRegex:regexForIPv6Addresses] ) {
		NSString *reversedIP = [NSString stringByReversingString:addressMask];
		scanner = [NSScanner scannerWithString:reversedIP];

		[scanner setCharactersToBeSkipped:nil];
		[scanner scanUpToCharactersFromSet:newSectionOfHostmaskCharacterSet intoString:&addressMaskToRemove];

		addressMaskToBan = [[addressMask substringToIndex:(addressMask.length - addressMaskToRemove.length)] stringByAppendingString:@"*"];
	} else {
		scanner = [NSScanner scannerWithString:addressMask];

		[scanner setCharactersToBeSkipped:nil];
		[scanner scanUpToCharactersFromSet:newSectionOfHostmaskCharacterSet intoString:&addressMaskToRemove];

		addressMaskToBan = [addressMaskToBan stringByAppendingString:[addressMask substringFromIndex:addressMaskToRemove.length]];
	}

	if ( ! [scanner isAtEnd] )
		return addressMaskToBan;
	return addressMask;
}

#pragma mark -

- (void) requestRecentActivity {
	if( [[[self connection] supportedFeatures] containsObject:MVIRCChatConnectionZNCPluginPlaybackFeature] )
		[[self connection] sendRawMessageImmediatelyWithFormat:@"PRIVMSG *playback PLAY %@ %.3f", self.name, [self.mostRecentUserActivity timeIntervalSince1970]];
}

- (void) persistLastActivityDate {
	if ( _mostRecentUserActivity && [[[self connection] supportedFeatures] containsObject:MVIRCChatConnectionZNCPluginPlaybackFeature] ) {
		NSString *recentActivityDateKey = [NSString stringWithFormat:@"%@-%@", self.connection.uniqueIdentifier, self.uniqueIdentifier];
		[[NSUserDefaults standardUserDefaults] setObject:_mostRecentUserActivity forKey:recentActivityDateKey];
	}
}
@end

#pragma mark -

@implementation MVIRCChatRoom (MVIRCChatRoomPrivate)
- (BOOL) _namesSynced {
	return _namesSynced;
}

- (void) _setNamesSynced:(BOOL) synced {
	_namesSynced = synced;
}

- (BOOL) _bansSynced {
	return _bansSynced;
}

- (void) _setBansSynced:(BOOL) synced {
	_bansSynced = synced;
}

- (void) _clearMemberUsers {
	[super _clearMemberUsers];
	[self _setNamesSynced:NO];
}

- (void) _clearBannedUsers {
	[super _clearBannedUsers];
	[self _setBansSynced:NO];
}
@end

NS_ASSUME_NONNULL_END
