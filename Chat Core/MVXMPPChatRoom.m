#import "XMPPFramework.h"

#import "MVXMPPChatRoom.h"
#import "MVXMPPChatUser.h"
#import "MVXMPPChatConnection.h"
#import "MVUtilities.h"
#import "NSStringAdditions.h"
#import "MVChatString.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVXMPPChatRoom
- (id) initWithJabberID:(XMPPJID *) identifier andConnection:(MVXMPPChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = connection; // prevent circular retain
		MVSafeRetainAssign( _uniqueIdentifier, identifier );
		[_connection _addKnownRoom:self];
	}

	return self;
}

#pragma mark -

- (NSUInteger) supportedModes {
	return ( MVChatRoomPrivateMode | MVChatRoomSecretMode | MVChatRoomInviteOnlyMode | MVChatRoomNormalUsersSilencedMode | MVChatRoomOperatorsOnlySetTopicMode | MVChatRoomNoOutsideMessagesMode | MVChatRoomPassphraseToJoinMode | MVChatRoomLimitNumberOfMembersMode );
}

- (NSUInteger) supportedMemberUserModes {
	return ( MVChatRoomMemberVoicedMode | MVChatRoomMemberOperatorMode );
}

#pragma mark -

- (NSURL *) url {
	NSString *urlString = [[NSString alloc] initWithFormat:@"%@:%@?join", [[self connection] urlScheme], [[_uniqueIdentifier domain] stringByEncodingIllegalURLCharacters]];
	if( urlString ) return [NSURL URLWithString:urlString];
	return nil;
}

- (NSString *) name {
	return [_uniqueIdentifier username];
}

#pragma mark -

- (void) partWithReason:(MVChatString * __nullable) reason {
	if( ! [self isJoined] ) return;
	[self _setDateParted:[NSDate date]];
}

#pragma mark -

- (void) changeTopic:(MVChatString *) newTopic {
	NSParameterAssert( newTopic != nil );

}

#pragma mark -

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) msgEncoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );

	XMPPMessage *xmppMessage = [XMPPMessage messageWithType:@"groupchat" to:_uniqueIdentifier];
	[xmppMessage addBody:[message string]];

	[[(MVXMPPChatConnection *)_connection _chatSession] sendElement:xmppMessage];
}

#pragma mark -

- (MVChatUser *) localMemberUser {
	return _localMemberUser;
}

- (NSSet *) memberUsersWithNickname:(NSString *) nickname {
	MVChatUser *user = [self memberUserWithUniqueIdentifier:nickname];
	if( user ) return [NSSet setWithObject:user];
	return nil;
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(MVChatString * __nullable) reason {
	[super kickOutMemberUser:user forReason:reason];
}

- (void) addBanForUser:(MVChatUser *) user {
	[super addBanForUser:user];
}

- (void) removeBanForUser:(MVChatUser *) user {
	[super removeBanForUser:user];

}
@end

@implementation MVXMPPChatRoom (MVXMPPChatRoomPrivate)
- (void) _setLocalMemberUser:(MVChatUser *) user {
	MVSafeRetainAssign( _localMemberUser, user );
}
@end

NS_ASSUME_NONNULL_END
