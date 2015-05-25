#import "MVSILCChatUser.h"
#import "MVSILCChatConnection.h"
#import "MVChatString.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVSILCChatUser
- (id) initLocalUserWithConnection:(MVSILCChatConnection *) userConnection {
	if( ( self = [self initWithClientEntry:[userConnection _silcConn] -> local_entry andConnection:userConnection] ) ) {
		_type = MVChatLocalUserType;

		// this info will be pulled live from the connection

		_nickname = nil;
		_realName = nil;
		_username = nil;
	}

	return self;
}

- (id) initWithClientEntry:(SilcClientEntry) clientEntry andConnection:(MVSILCChatConnection *) userConnection {
	if( ( self = [self init] ) ) {
		_type = MVChatRemoteUserType;
		_connection = userConnection; // prevent circular retain
		[self updateWithClientEntry:clientEntry];
		[_connection _addKnownUser:self];
	}

	return self;
}

#pragma mark -

- (void) updateWithClientEntry:(SilcClientEntry) clientEntry {
	SilcLock( [[self connection] _silcClient] );

	__strong id me = self;

	if( _uniqueIdentifier )
		[_connection _removeKnownUser:self];

	if( clientEntry -> nickname )
		[self _setNickname:[NSString stringWithUTF8String:clientEntry -> nickname]];

	if( clientEntry -> username )
		[self _setUsername:[NSString stringWithUTF8String:clientEntry -> username]];

	if( clientEntry -> hostname )
		[self _setAddress:[NSString stringWithUTF8String:clientEntry -> hostname]];

	if( clientEntry -> server )
		[self _setServerAddress:[NSString stringWithUTF8String:clientEntry -> server]];

	if( clientEntry -> realname )
		[self _setRealName:[NSString stringWithUTF8String:clientEntry -> realname]];

	if( clientEntry -> fingerprint ) {
		char *tmp = silc_fingerprint( clientEntry -> fingerprint, clientEntry -> fingerprint_len);
		[self _setFingerprint:[NSString stringWithUTF8String:tmp]];
		silc_free( tmp );
	}

	if( clientEntry -> public_key ) {
		unsigned long len = 0;
		unsigned char *key = silc_pkcs_public_key_encode( clientEntry -> public_key, &len );
		[self _setPublicKey:[NSData dataWithBytes:key length:len]];
	}

	[self _setServerOperator:( clientEntry -> mode & SILC_UMODE_SERVER_OPERATOR || clientEntry -> mode & SILC_UMODE_ROUTER_OPERATOR )];

	unsigned char *identifier = silc_id_id2str( clientEntry -> id, SILC_ID_CLIENT );
	SilcUInt32 len = silc_id_get_len( clientEntry -> id, SILC_ID_CLIENT );
	[self _setUniqueIdentifier:[NSData dataWithBytes:identifier length:len]];

	_clientEntry = clientEntry;

	[_connection _addKnownUser:self];

	me = nil;

	SilcUnlock( [[self connection] _silcClient] );
}

#pragma mark -

- (SilcClientEntry) _getClientEntry {
	return _clientEntry;
}

#pragma mark -

- (NSUInteger) hash {
	// this hash assumes the MVSILCChatConnection will return the same instance for equal users
	return ( _type ^ [[self connection] hash] ^ (intptr_t)self );
}

- (NSUInteger) supportedModes {
	return MVChatUserNoModes;
}

- (NSSet *) supportedAttributes {
	return [NSSet setWithObjects:MVChatUserKnownRoomsAttribute, MVChatUserPictureAttribute, MVChatUserLocalTimeAttribute, MVChatUserClientInfoAttribute, MVChatUserVCardAttribute, MVChatUserServiceAttribute, MVChatUserMoodAttribute, MVChatUserStatusMessageAttribute, MVChatUserPreferredLanguageAttribute, MVChatUserPreferredContactMethodsAttribute, MVChatUserTimezoneAttribute, MVChatUserGeoLocationAttribute, MVChatUserDeviceInfoAttribute, MVChatUserExtensionAttribute, MVChatUserPublicKeyAttribute, MVChatUserServerPublicKeyAttribute, MVChatUserDigitalSignatureAttribute, MVChatUserServerDigitalSignatureAttribute, nil];
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
	NSParameterAssert( message != nil );

	const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:message andChatFormat:[[self connection] outgoingChatFormat]];
	SilcMessageFlags flags = SILC_MESSAGE_FLAG_UTF8;

	if( [[attributes objectForKey:@"action"] boolValue]) flags |= SILC_MESSAGE_FLAG_ACTION;

	// unpack the identifier here for now
	// we might want to keep a duplicate of the SilcClientID struct as a instance variable
	SilcClientID *clientID = silc_id_str2id( [(NSData *)[self uniqueIdentifier] bytes], [(NSData *)[self uniqueIdentifier] length], SILC_ID_CLIENT );
	if( clientID ) {
		SilcLock( [[self connection] _silcClient] );
		SilcClientEntry client = silc_client_get_client_by_id( [[self connection] _silcClient], [[self connection] _silcConn], clientID );
		if( client ) {
			silc_client_send_private_message( [[self connection] _silcClient], [[self connection] _silcConn], client, flags, (unsigned char *) msg, strlen( msg ), false );
			silc_schedule_wakeup( [[self connection] _silcClient] -> schedule );
		}
		SilcUnlock( [[self connection] _silcClient] );
	}
}

#pragma mark -

- (void) refreshInformation {
	SilcBuffer userBuffer;

	userBuffer = silc_id_payload_encode( [self _getClientEntry] -> id, SILC_ID_CLIENT );
	if( ! userBuffer ) return;

	silc_client_command_send( [[self connection] _silcClient], [[self connection] _silcConn], SILC_COMMAND_WHOIS, [[self connection] _silcConn] -> cmd_ident, 1, 4, userBuffer -> data, userBuffer -> len );
	[[self connection] _silcConn] -> cmd_ident++;

	silc_schedule_wakeup( [[self connection] _silcClient] -> schedule );

	silc_buffer_free( userBuffer );
}
@end

NS_ASSUME_NONNULL_END
