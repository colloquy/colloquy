#import "MVSILCChatUser.h"
#import "MVSILCChatConnection.h"

@implementation MVSILCChatUser
- (id) initLocalUserWithConnection:(MVSILCChatConnection *) connection {
	if( ( self = [self initWithClientEntry:[connection _silcConn] -> local_entry andConnection:connection] ) ) {
		_type = MVChatLocalUserType;

		// this info will be pulled live from the connection
		[_nickname release];
		[_username release];
		[_username release];

		_nickname = nil;
		_realName = nil;
		_username = nil;		
	}

	return self;
}

- (id) initWithClientEntry:(SilcClientEntry) clientEntry andConnection:(MVSILCChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_type = MVChatRemoteUserType;
		_connection = connection; // prevent circular retain

		[[connection _silcClientLock] lock];

		_nickname = [[NSString allocWithZone:[self zone]] initWithUTF8String:clientEntry -> nickname];
		if( clientEntry -> username ) _username = [[NSString allocWithZone:[self zone]] initWithUTF8String:clientEntry -> username];
		if( clientEntry -> hostname ) _address = [[NSString allocWithZone:[self zone]] initWithUTF8String:clientEntry -> hostname];
		if( clientEntry -> server ) _serverAddress = [[NSString allocWithZone:[self zone]] initWithUTF8String:clientEntry -> server];
		if( clientEntry -> realname ) _realName = [[NSString allocWithZone:[self zone]] initWithUTF8String:clientEntry -> realname];
		if( clientEntry -> fingerprint ) _fingerprint = [[NSString allocWithZone:[self zone]] initWithBytes:clientEntry -> fingerprint length:clientEntry -> fingerprint_len encoding:NSASCIIStringEncoding];

		if( clientEntry -> public_key ) {
			unsigned long len = 0;
			unsigned char *key = silc_pkcs_public_key_encode( clientEntry -> public_key, &len );
			_publicKey = [[NSData allocWithZone:[self zone]] initWithBytes:key length:len];
		}

		unsigned char *identifier = silc_id_id2str( clientEntry -> id, SILC_ID_CLIENT );
		unsigned len = silc_id_get_len( clientEntry -> id, SILC_ID_CLIENT );
		_uniqueIdentifier = [[NSData allocWithZone:[self zone]] initWithBytes:identifier length:len];

		[[connection _silcClientLock] unlock];
	}

	return self;
}

#pragma mark -

- (unsigned) hash {
	// this hash assumes the MVSILCChatConnection will return the same instance for equal users
	return ( [self type] ^ [[self connection] hash] ^ (unsigned int) self );
}

- (unsigned long) supportedModes {
	return MVChatUserNoModes;
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	NSParameterAssert( message != nil );

	const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:message];
	SilcMessageFlags flags = SILC_MESSAGE_FLAG_UTF8;

	if( action) flags |= SILC_MESSAGE_FLAG_ACTION;

	// unpack the identifier here for now
	// we might want to keep a duplicate of the SilcClientID struct as a instance variable
	SilcClientID *clientID = silc_id_str2id( [(NSData *)[self uniqueIdentifier] bytes], [(NSData *)[self uniqueIdentifier] length], SILC_ID_CLIENT );
	if( clientID ) {
		[[[self connection] _silcClientLock] lock];
		SilcClientEntry client = silc_client_get_client_by_id( [[self connection] _silcClient], [[self connection] _silcConn], clientID );
		if( client ) silc_client_send_private_message( [[self connection] _silcClient], [[self connection] _silcConn], client, flags, (char *) msg, strlen( msg ), false );	
		[[[self connection] _silcClientLock] unlock];
	}
}
@end