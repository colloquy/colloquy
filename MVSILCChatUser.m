#import "MVSILCChatUser.h"
#import "MVSILCChatConnection.h"

void silc_privmessage_resolve_callback( SilcClient client, SilcClientConnection conn, SilcClientEntry *clients, SilcUInt32 clients_count, void *context ) {
	NSMutableDictionary *dict = context;
	MVSILCChatUser *user = [dict objectForKey:@"user"];
	MVChatConnection *self = [user connection];

	if( ! clients_count ) {
		goto out;
	} else {
		char *nickname = NULL;
		SilcClientEntry target;

		if( clients_count > 1 ) {
			silc_parse_userfqdn( [[user nickname] UTF8String], &nickname, NULL );

			/* Find the correct one. The rec -> nick might be a formatted nick
			so this will find the correct one. */

			clients = silc_client_get_clients_local( client, conn, nickname, [[user nickname] UTF8String], &clients_count);
			silc_free( nickname );
			nickname = NULL;
			if( ! clients ) goto finish;
		}

		target = clients[0];

		/* Still check for exact math for nickname, this compares the
		   real (formatted) nickname and the nick (maybe formatted) that
		   use gave. This is to assure that `nick' does not match `nick@host'. */

		if( ! [[user nickname] isEqualToString:[NSString stringWithUTF8String:target -> nickname]] )
			goto finish;

		[[self _silcClientLock] lock];
		silc_client_send_private_message( [self _silcClient], [self _silcConn], target, [[dict objectForKey:@"flags"] intValue], (char *) [[[dict objectForKey:@"message"] string] UTF8String], strlen( [[[dict objectForKey:@"message"] string] UTF8String] ), false );
		[[self _silcClientLock] unlock];
	}

finish:
	[dict release];
}

#pragma mark -

@implementation MVSILCChatUser
- (id) initLocalUserWithConnection:(MVSILCChatConnection *) connection {
	if( ( self = [self initWithNickname:nil andConnection:connection andUniqueIdentifier:nil] ) ) {
		_type = MVChatLocalUserType;
		_uniqueIdentifier = [[[self nickname] lowercaseString] retain];
	}

	return self;
}

- (id) initWithNickname:(NSString *) nickname andConnection:(MVSILCChatConnection *) connection andUniqueIdentifier:(NSString *) identifier {
	if( ( self = [super init] ) ) {
		_connection = connection; // prevent circular retain
		_nickname = [nickname copyWithZone:[self zone]];
		_uniqueIdentifier = [identifier copyWithZone:[self zone]];
		_type = MVChatRemoteUserType;
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

	SilcUInt32 clientsCount;
	[[[self connection] _silcClientLock] lock];
	SilcClientEntry *clients = silc_client_get_clients_local( [[self connection] _silcClient], [[self connection] _silcConn], [[self nickname] UTF8String], [[self connection] _silcClientParams] -> nickname_format, &clientsCount );
	[[[self connection] _silcClientLock] unlock];

	if( ! clients || ! clientsCount ) {
		NSMutableDictionary *dict = [[NSMutableDictionary dictionary] retain];
		[dict setObject:message forKey:@"message"];
		[dict setObject:self forKey:@"user"];
		[dict setObject:[NSNumber numberWithInt:flags] forKey:@"flags"];

		[[[self connection] _silcClientLock] lock];
		silc_client_get_clients_whois( [[self connection] _silcClient], [[self connection] _silcConn], [[self nickname] UTF8String], NULL, NULL, silc_privmessage_resolve_callback, dict );
		[[[self connection] _silcClientLock] unlock];
		return;
	}

	[[[self connection] _silcClientLock] lock];
	silc_client_send_private_message( [[self connection] _silcClient], [[self connection] _silcConn], clients[0], flags, (char *) msg, strlen( msg ), false );	
	[[[self connection] _silcClientLock] unlock];
}
@end