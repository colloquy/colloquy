#import "MVSILCChatRoom.h"
#import "MVSILCChatUser.h"
#import "MVSILCChatConnection.h"

#define MODULE_NAME "MVSILCChatRoom"

@interface MVChatConnection (MVChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(NSAttributedString *) message;

- (SilcClient) _silcClient;
- (NSRecursiveLock *) _silcClientLock;
- (void) _setSilcConn:(SilcClientConnection)aSilcConn;
- (SilcClientConnection) _silcConn;
@end

#pragma mark -

@implementation MVSILCChatRoom
- (id) initWithName:(NSString *) name andConnection:(MVSILCChatConnection *) connection andUniqueIdentifier:(NSString *) identifier {
	if( ( self = [super init] ) ) {
		_connection = connection; // prevent circular retain
		_name = [name copyWithZone:[self zone]];
		_uniqueIdentifier = [identifier retain];
	}
	
	return self;
}

#pragma mark -

- (unsigned long) supportedModes {
	return ( MVChatRoomPrivateMode | MVChatRoomSecretMode | MVChatRoomInviteOnlyMode | MVChatRoomNormalUsersSilencedMode | MVChatRoomOperatorsOnlySetTopicMode | MVChatRoomPassphraseToJoinMode | MVChatRoomLimitNumberOfMembersMode );
}

- (unsigned long) supportedMemberUserModes {
	unsigned long modes = ( MVChatRoomMemberFounderMode | MVChatRoomMemberOperatorMode );
	modes |= MVChatRoomMemberQuietedMode; // optional later
	return modes;
}

- (NSString *) displayName {
	return [self name];
}

#pragma mark -

- (void) partWithReason:(NSAttributedString *) reason {
	if( ! [self isJoined] ) return;
	if ( [reason length] ) [[self connection] sendRawMessageWithFormat:@"PART %@ %@", [self name], reason];
	else [[self connection] sendRawMessageWithFormat:@"PART %@", [self name]];
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic {
	NSParameterAssert( topic != nil );
	
	const char *msg = [[[self connection] class] _flattenedSILCStringForMessage:topic];
	[[self connection] sendRawMessageWithFormat:@"TOPIC %@ %s", [self name], msg];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message asAction:(BOOL) action {
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
			[[self connection] sendRawMessageWithFormat:@"MODE %@ +m", [self name]];
			break;
		case MVChatRoomOperatorsOnlySetTopicMode:
			[[self connection] sendRawMessageWithFormat:@"MODE %@ +t", [self name]];
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
		case MVChatRoomMemberOperatorMode:
			[[self connection] sendRawMessageWithFormat:@"MODE %@ +o %@", [self name], [user nickname]];
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
		case MVChatRoomMemberOperatorMode:
			[[self connection] sendRawMessageWithFormat:@"MODE %@ -o %@", [self name], [user nickname]];
			break;
		case MVChatRoomMemberQuietedMode:
			[[self connection] sendRawMessageWithFormat:@"MODE %@ -q %@", [self name], [user nickname]];
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

#pragma mark -
/*
@implementation MVIRCChatRoom (MVIRCChatRoomPrivate)
- (void) _updateMemberUser:(MVChatUser *) user fromOldNickname:(NSString *) oldNickname {
	NSNumber *modes = [[[_memberModes objectForKey:[oldNickname lowercaseString]] retain] autorelease];
	if( ! modes ) return;
	@synchronized( _memberModes ) {
		[_memberModes removeObjectForKey:[oldNickname lowercaseString]];
		[_memberModes setObject:modes forKey:[user uniqueIdentifier]];
	}
}
@end
*/