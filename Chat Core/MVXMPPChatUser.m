#import <Acid/acid.h>

#import "MVXMPPChatUser.h"
#import "MVXMPPChatConnection.h"
#import "MVUtilities.h"

@implementation MVXMPPChatUser
- (id) initLocalUserWithConnection:(MVXMPPChatConnection *) userConnection {
	if( ( self = [self initWithJabberID:[userConnection _localUserID] andConnection:userConnection] ) )
		_type = MVChatLocalUserType;
	return self;
}

- (id) initWithJabberID:(JabberID *) identifier andConnection:(MVXMPPChatConnection *) userConnection {
	if( ( self = [self init] ) ) {
		_type = MVChatRemoteUserType;
		_connection = userConnection; // prevent circular retain
		MVSafeRetainAssign( &_identifier, identifier );
		MVSafeCopyAssign( &_uniqueIdentifier, [identifier completeID] );
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

#pragma mark -

- (NSString *) displayName {
	if( _type == MVChatWildcardUserType )
		return [NSString stringWithFormat:@"%@@%@", ( [self username] ? [self username] : @"*" ), ( [self address] ? [self address] : @"*" )];
	return [self nickname];
}

- (NSString *) nickname {
	if( _type == MVChatLocalUserType )
		return [[self connection] username];
	return [_identifier username];
}

- (NSString *) realName {
	return nil;
}

- (NSString *) username {
	if( _type == MVChatLocalUserType )
		return [[self connection] username];
	return [_identifier username];
}

- (NSString *) address {
	return [_identifier hostname];
}

- (NSString *) serverAddress {
	return [_identifier hostname];
}

#pragma mark -

- (unsigned long) supportedModes {
	return MVChatUserNoModes;
}

- (NSSet *) supportedAttributes {
	return [NSSet set];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );

	JabberMessage *jabberMsg = [[JabberMessage alloc] initWithRecipient:_identifier andBody:[message string]];
	[jabberMsg setType:@"chat"];
	[jabberMsg addComposingRequest];
	[[(MVXMPPChatConnection *)_connection _chatSession] sendElement:jabberMsg];
	[jabberMsg release];
}
@end
