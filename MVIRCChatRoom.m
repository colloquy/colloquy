#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCChatConnection.h"

#define MODULE_NAME "MVIRCChatRoom"

#import "core.h"
#import "irc.h"
#import "servers.h"

@interface MVChatConnection (MVChatConnectionPrivate)
+ (const char *) _flattenedIRCStringForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc;
- (SERVER_REC *) _irssiConnection;
@end

#pragma mark -

@implementation MVIRCChatRoom
- (id) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection {
	if( ( self = [super init] ) ) {
		_connection = connection; // prevent circular retain
		_name = [name copyWithZone:[self zone]];
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
	[[self connection] sendRawMessageWithFormat:@"PART %@", [self name]];
}

- (void) sendMessage:(NSAttributedString *) message asAction:(BOOL) action {
	NSParameterAssert( message != nil );

	const char *msg = [[[self connection] class] _flattenedIRCStringForMessage:message withEncoding:[self encoding]];

	[MVIRCChatConnectionThreadLock lock];

	if( ! action ) [[self connection] _irssiConnection] -> send_message( [[self connection] _irssiConnection], [[self connection] encodedBytesWithString:[self name]], msg, 0 );
	else irc_send_cmdv( (IRC_SERVER_REC *) [[self connection] _irssiConnection], "PRIVMSG %s :\001ACTION %s\001", [[self connection] encodedBytesWithString:[self name]], msg );

	[MVIRCChatConnectionThreadLock unlock];
}

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
@end

#pragma mark -

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