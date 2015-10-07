#import "XMPPFramework.h"

#import "MVXMPPChatUser.h"
#import "MVXMPPChatConnection.h"
#import "MVUtilities.h"
#import "MVChatString.h"
#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVXMPPChatUser
- (id) initWithJabberID:(XMPPJID *) identifier andConnection:(MVXMPPChatConnection *) userConnection {
	if( ( self = [self init] ) ) {
		_type = MVChatRemoteUserType;
		_connection = userConnection; // prevent circular retain
		MVSafeRetainAssign( _uniqueIdentifier, identifier );
		[_connection _addKnownUser:self];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
}

#pragma mark -

- (NSString *) displayName {
	return [self username];
}

- (NSString *) nickname {
	return [self username];
}

- (NSString *) realName {
	return nil;
}

- (NSString *) username {
	if( _roomMember )
		return [_uniqueIdentifier resource];
	return [_uniqueIdentifier username];
}

- (NSString *) address {
	return [_uniqueIdentifier domain];
}

- (NSString *) serverAddress {
	return [_uniqueIdentifier domain];
}

#pragma mark -

- (NSUInteger) supportedModes {
	return MVChatUserNoModes;
}

- (NSSet *) supportedAttributes {
	return [NSSet set];
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );

	XMPPMessage *xmppMessage = [XMPPMessage messageWithType:@"chat" to:_uniqueIdentifier];
	[xmppMessage addBody:[message string]];

	[[(MVXMPPChatConnection *)_connection _chatSession] sendElement:xmppMessage];
}
@end

#pragma mark -

@implementation MVXMPPChatUser (MVXMPPChatUserPrivate)
- (void) _setRoomMember:(BOOL) member {
	_roomMember = member;
}

- (BOOL) _isRoomMember {
	return _roomMember;
}
@end

NS_ASSUME_NONNULL_END
