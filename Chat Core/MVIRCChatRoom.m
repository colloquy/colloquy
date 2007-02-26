#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"

@implementation MVIRCChatRoom
- (id) initWithName:(NSString *) roomName andConnection:(MVIRCChatConnection *) roomConnection {
	if( ( self = [self init] ) ) {
		_connection = roomConnection; // prevent circular retain
		_name = [roomName copyWithZone:nil];
		_uniqueIdentifier = [[roomName lowercaseString] retain];
	}

	return self;
}

#pragma mark -

- (unsigned long) supportedModes {
	return ( MVChatRoomPrivateMode | MVChatRoomSecretMode | MVChatRoomInviteOnlyMode | MVChatRoomNormalUsersSilencedMode | MVChatRoomOperatorsOnlySetTopicMode | MVChatRoomNoOutsideMessagesMode | MVChatRoomPassphraseToJoinMode | MVChatRoomLimitNumberOfMembersMode );
}

- (unsigned long) supportedMemberUserModes {
	unsigned long supported = ( MVChatRoomMemberVoicedMode | MVChatRoomMemberOperatorMode );
	supported |= MVChatRoomMemberQuietedMode; // optional later
	supported |= MVChatRoomMemberHalfOperatorMode; // optional later
	supported |= MVChatRoomMemberAdministratorMode; // optional later
	supported |= MVChatRoomMemberFounderMode; // optional later
	return supported;
}

- (NSString *) displayName {
	return [[self name] substringFromIndex:1];
}

#pragma mark -

- (void) partWithReason:(NSAttributedString *) reason {
	if( ! [self isJoined] ) return;
	if( ! [reason length] ) [[self connection] sendRawMessageImmediatelyWithFormat:@"PART %@", [self name]];
	else [[self connection] sendRawMessageImmediatelyWithFormat:@"PART %@ :%@", [self name], [reason string]];
	[self _setDateParted:[NSDate date]];
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) newTopic {
	NSParameterAssert( newTopic != nil );
	NSData *msg = [MVIRCChatConnection _flattenedIRCDataForMessage:newTopic withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];
	NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"TOPIC %@ :", [self name]];
	[[self connection] sendRawMessageWithComponents:prefix, msg, nil];
	[prefix release];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) msgEncoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );
	[[self connection] _sendMessage:message withEncoding:msgEncoding toTarget:self withAttributes:attributes];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments {
	NSParameterAssert( command != nil );
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@ :\001%@ ", [self name], command];
		[[self connection] sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
		[prefix release];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@ %@\001", [self name], command, arguments];
	} else [[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", [self name], command];
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments {
	NSParameterAssert( command != nil );
	if( arguments && [arguments isKindOfClass:[NSData class]] && [arguments length] ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"NOTICE %@ :\001%@ ", [self name], command];
		[[self connection] sendRawMessageWithComponents:prefix, arguments, @"\001", nil];
		[prefix release];
	} else if( arguments && [arguments isKindOfClass:[NSString class]] && [arguments length] ) {
		[[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@ %@\001", [self name], command, arguments];
	} else [[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", [self name], command];
}

#pragma mark -

- (void) setMode:(MVChatRoomMode) mode withAttribute:(id) attribute {
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
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -k *", [self name]];
		break;
	case MVChatRoomLimitNumberOfMembersMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -l *", [self name]];
	default:
		break;
	}
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
	case MVChatRoomMemberQuietedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ +q %@", [self name], [user nickname]];
	default:
		break;
	}
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
	case MVChatRoomMemberQuietedMode:
		[[self connection] sendRawMessageWithFormat:@"MODE %@ -q %@", [self name], [user nickname]];
	default:
		break;
	}
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
		MVChatUser *user = nil;
		NSEnumerator *enumerator = [_memberUsers objectEnumerator];
		while( ( user = [enumerator nextObject] ) )
			if( [[user uniqueIdentifier] isEqualToString:uniqueIdentfier] )
				return user;
	}

	return nil;
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(NSAttributedString *) reason {
	[super kickOutMemberUser:user forReason:reason];

	if( reason ) {
		NSData *msg = [MVIRCChatConnection _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"KICK %@ %@ :", [self name], [user nickname]];
		[[self connection] sendRawMessageImmediatelyWithComponents:prefix, msg, nil];
		[prefix release];
	} else [[self connection] sendRawMessageImmediatelyWithFormat:@"KICK %@ %@", [self name], [user nickname]];
}

- (void) addBanForUser:(MVChatUser *) user {
	[super addBanForUser:user];
	[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ +b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
}

- (void) removeBanForUser:(MVChatUser *) user {
	[super removeBanForUser:user];
	[[self connection] sendRawMessageImmediatelyWithFormat:@"MODE %@ -b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
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
