#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"

#define MODULE_NAME "MVIRCChatRoom"

#import "core.h"
#import "irc.h"
#import "servers.h"

@implementation MVIRCChatRoom
- (id) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = connection; // prevent circular retain
		_name = [name copyWithZone:nil];
		_uniqueIdentifier = [[name lowercaseString] retain];
	}

	return self;
}

#pragma mark -

- (unsigned long) supportedModes {
	return ( MVChatRoomPrivateMode | MVChatRoomSecretMode | MVChatRoomInviteOnlyMode | MVChatRoomNormalUsersSilencedMode | MVChatRoomOperatorsOnlySetTopicMode | MVChatRoomNoOutsideMessagesMode | MVChatRoomPassphraseToJoinMode | MVChatRoomLimitNumberOfMembersMode );
}

- (unsigned long) supportedMemberUserModes {
	unsigned long modes = ( MVChatRoomMemberVoicedMode | MVChatRoomMemberOperatorMode );
	modes |= MVChatRoomMemberQuietedMode; // optional later
	modes |= MVChatRoomMemberHalfOperatorMode; // optional later
	return modes;
}

- (NSString *) displayName {
	return [[self name] substringFromIndex:1];
}

#pragma mark -

- (void) partWithReason:(NSAttributedString *) reason {
	if( ! [self isJoined] ) return;
	if( ! [reason length] ) [[self connection] sendRawMessage:[NSString stringWithFormat:@"PART %@", [self name]] immediately:YES];
	else [[self connection] sendRawMessage:[NSString stringWithFormat:@"PART %@ :%@", [self name], [reason string]] immediately:YES];
	[self _setDateParted:[NSDate date]];
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic {
	NSParameterAssert( topic != nil );

	const char *msg = [MVIRCChatConnection _flattenedIRCStringForMessage:topic withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];

	IrssiLock();
	irc_send_cmdv( (IRC_SERVER_REC *) [[self connection] _irssiConnection], "TOPIC %s :%s", [[self connection] encodedBytesWithString:[self name]], msg );
	IrssiUnlock();
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	NSParameterAssert( message != nil );
	const char *msg = [MVIRCChatConnection _flattenedIRCStringForMessage:message withEncoding:encoding andChatFormat:[[self connection] outgoingChatFormat]];
	[[self connection] _sendMessage:msg toTarget:[self name] asAction:action];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSString *request = ( [arguments length] ? [NSString stringWithFormat:@"%@ %@", command, arguments] : command );
	[[self connection] sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", [self name], request];
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSString *request = ( [arguments length] ? [NSString stringWithFormat:@"%@ %@", command, arguments] : command );
	[[self connection] sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", [self name], request];
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
				return [[user retain] autorelease];
	}

	return nil;
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(NSAttributedString *) reason {
	[super kickOutMemberUser:user forReason:reason];

	IrssiLock();

	if( reason ) {
		const char *msg = [MVIRCChatConnection _flattenedIRCStringForMessage:reason withEncoding:[self encoding] andChatFormat:[[self connection] outgoingChatFormat]];
		irc_send_cmdv( (IRC_SERVER_REC *) [[self connection] _irssiConnection], "KICK %s %s :%s", [[self connection] encodedBytesWithString:[self name]], [[self connection] encodedBytesWithString:[user nickname]], msg );
	} else irc_send_cmdv( (IRC_SERVER_REC *) [[self connection] _irssiConnection], "KICK %s %s", [[self connection] encodedBytesWithString:[self name]], [[self connection] encodedBytesWithString:[user nickname]] );

	IrssiUnlock();
}

- (void) addBanForUser:(MVChatUser *) user {
	[super addBanForUser:user];
	[[self connection] sendRawMessageWithFormat:@"MODE %@ +b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
}

- (void) removeBanForUser:(MVChatUser *) user {
	[super removeBanForUser:user];
	[[self connection] sendRawMessageWithFormat:@"MODE %@ -b %@!%@@%@", [self name], ( [user nickname] ? [user nickname] : @"*" ), ( [user username] ? [user username] : @"*" ), ( [user address] ? [user address] : @"*" )];
}
@end