#import "MVSILCChatRoom.h"
#import "MVSILCChatUser.h"
#import "MVSILCChatConnection.h"

@implementation MVSILCChatRoom
- (id) initWithChannelEntry:(SilcChannelEntry) channelEntry andConnection:(MVSILCChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = connection; // prevent circular retain

		[[connection _silcClientLock] lock];

		_name = [[NSString allocWithZone:[self zone]] initWithUTF8String:channelEntry -> channel_name];

		unsigned char *identifier = silc_id_id2str( channelEntry -> id, SILC_ID_CHANNEL );
		unsigned len = silc_id_get_len( channelEntry -> id, SILC_ID_CHANNEL );
		_uniqueIdentifier = [[NSData allocWithZone:[self zone]] initWithBytes:identifier length:len];

		[[connection _silcClientLock] unlock];
	}

	return self;
}

#pragma mark -

- (unsigned long) supportedModes {
	return ( MVChatRoomPrivateMode | MVChatRoomSecretMode | MVChatRoomInviteOnlyMode | MVChatRoomNormalUsersSilencedMode | MVChatRoomOperatorsOnlySetTopicMode | MVChatRoomPassphraseToJoinMode | MVChatRoomLimitNumberOfMembersMode );
}

- (unsigned long) supportedMemberUserModes {
	return ( MVChatRoomMemberFounderMode | MVChatRoomMemberOperatorMode | MVChatRoomMemberQuietedMode );
}

- (NSString *) displayName {
	return [self name];
}

#pragma mark -

- (void) partWithReason:(NSAttributedString *) reason {
	if( ! [self isJoined] ) return;
	if( [reason length] ) [[self connection] sendRawMessageWithFormat:@"LEAVE %@ %@", [self name], reason];
	else [[self connection] sendRawMessageWithFormat:@"LEAVE %@", [self name]];
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic {
	NSParameterAssert( topic != nil );
	const char *msg = [[[self connection] class] _flattenedSILCStringForMessage:topic];
	[[self connection] sendRawMessageWithFormat:@"TOPIC %@ %s", [self name], msg];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	NSParameterAssert( message != nil );

	const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:message];
	SilcMessageFlags flags = SILC_MESSAGE_FLAG_UTF8;

	if( action ) flags |= SILC_MESSAGE_FLAG_ACTION;

	[[[self connection] _silcClientLock] lock];

	SilcChannelEntry channel = silc_client_get_channel( [[self connection] _silcClient], [[self connection] _silcConn], (char *) [[self name] UTF8String] );

	if( ! channel) {
		[[[self connection] _silcClientLock] unlock];
		return;
	}

	silc_client_send_channel_message( [[self connection] _silcClient], [[self connection] _silcConn], channel, NULL, flags, (char *) msg, strlen( msg ), false );

	[[[self connection] _silcClientLock] unlock];
}

#pragma mark -

- (void) setMode:(MVChatRoomMode) mode withAttribute:(id) attribute {
	[super setMode:mode withAttribute:attribute];

	switch( mode ) {
	case MVChatRoomPrivateMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +p", [self name]];
		break;
	case MVChatRoomSecretMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +s", [self name]];
		break;
	case MVChatRoomInviteOnlyMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +i", [self name]];
		break;
	case MVChatRoomNormalUsersSilencedMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +m", [self name]];
		break;
	case MVChatRoomOperatorsOnlySetTopicMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +t", [self name]];
		break;
	case MVChatRoomPassphraseToJoinMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +k %@", [self name], attribute];
		break;
	case MVChatRoomLimitNumberOfMembersMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ +l %@", [self name], attribute];
	default:
		break;
	}
}

- (void) removeMode:(MVChatRoomMode) mode {
	[super removeMode:mode];
	
	switch( mode ) {
	case MVChatRoomPrivateMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -p", [self name]];
		break;
	case MVChatRoomSecretMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -s", [self name]];
		break;
	case MVChatRoomInviteOnlyMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -i", [self name]];
		break;
	case MVChatRoomNormalUsersSilencedMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -m", [self name]];
		break;
	case MVChatRoomOperatorsOnlySetTopicMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -t", [self name]];
		break;
	case MVChatRoomPassphraseToJoinMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -k *", [self name]];
		break;
	case MVChatRoomLimitNumberOfMembersMode:
		[[self connection] sendRawMessageWithFormat:@"CMODE %@ -l *", [self name]];
	default:
		break;
	}
}

#pragma mark -

- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	[super setMode:mode forMemberUser:user];
	
	switch( mode ) {
	case MVChatRoomMemberOperatorMode:
		[[self connection] sendRawMessageWithFormat:@"CUMODE %@ +o %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberQuietedMode:
		[[self connection] sendRawMessageWithFormat:@"CUMODE %@ +q %@", [self name], [user nickname]];
	default:
		break;
	}
}

- (void) removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	[super removeMode:mode forMemberUser:user];
	
	switch( mode ) {
	case MVChatRoomMemberOperatorMode:
		[[self connection] sendRawMessageWithFormat:@"CUMODE %@ -o %@", [self name], [user nickname]];
		break;
	case MVChatRoomMemberQuietedMode:
		[[self connection] sendRawMessageWithFormat:@"CUMODE %@ -q %@", [self name], [user nickname]];
	default:
		break;
	}
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(NSAttributedString *) reason {
	[super kickOutMemberUser:user forReason:reason];

	if( reason ) {
		const char *msg = [[[self connection] class] _flattenedSILCStringForMessage:reason];
		[[self connection] sendRawMessageWithFormat:@"KICK %@ %@ %s", [self name], [user nickname], msg];
	} else [[self connection] sendRawMessageWithFormat:@"KICK %@ %@", [self name], [user nickname]];
}

/*
- (void) addBanForUser:(MVChatUser *) user {
	[super addBanForUser:user];
	[[self connection] sendRawMessageWithFormat:@"MODE %@ +b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
}

- (void) removeBanForUser:(MVChatUser *) user {
	[super removeBanForUser:user];
	[[self connection] sendRawMessageWithFormat:@"MODE %@ -b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
}
*/
@end