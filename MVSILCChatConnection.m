#import "MVChatConnection.h"
#import "MVSILCChatConnection.h"
#import "MVFileTransfer.h"
#import "MVChatPluginManager.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSDataAdditions.h"

static SilcPKCS silcPkcs;
static SilcPublicKey silcPublicKey;
static SilcPrivateKey silcPrivateKey;

NSString *MVSILCChatConnectionLoadedCertificate = @"MVSILCChatConnectionLoadedCertificate";

@interface MVSILCChatConnection (MVSILCChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(NSAttributedString *) message;

- (SilcClient) _silcClient;
- (NSRecursiveLock *) _silcClientLock;
- (void) _setSilcConn:(SilcClientConnection)aSilcConn;
- (SilcClientConnection) _silcConn;

- (NSMutableArray *) _joinedChannels;
- (void) _addChannel:(NSString *)channel_name;
- (void) _addUser:(NSString *)nick_name toChannel:(NSString *)channel_name withMode:(NSNumber *)mode;
- (void) _delUser:(NSString *)nick_name fromChannel:(NSString *)channel_name;
- (void) _delUser:(NSString *)nick_name;
- (void) _delChannel:(NSString *)channel_name;
- (void) _userChangedNick:(NSString *)old_nick_name to:(NSString *)new_nick_name;
- (void) _userModeChanged:(NSString *)nick_name onChannel:(NSString *)channel_name toMode:(NSNumber *)mode;
- (NSArray *) _getChannelsForUser:(NSString *)nick_name;
- (NSMutableDictionary *) _getChannel:(NSString *)channel_name;
- (NSNumber *) _getModeForUser:(NSString *)nick_name onChannel:(NSString *)channel_name;

- (NSMutableArray *) _queuedCommands;
- (NSLock *) _queuedCommandsLock;

- (BOOL) _loadKeyPair;
- (BOOL) _isKeyPairLoaded;
- (void) _connectKeyPairLoaded:(NSNotification *) notification;

- (void) _addCommand:(NSString *)raw forNumber:(SilcUInt16) cmd_ident;
- (NSString *) _getCommandForNumber:(SilcUInt16) cmd_ident;
- (NSLock *) _sentCommandsLock;
- (NSMutableDictionary *) _sentCommands;

- (void) _sendCommandSucceededNotify:(NSString *) message;
- (void) _sendCommandFailedNotify:(NSString *) message;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
@end

#pragma mark -

void silc_privmessage_resolve_callback( SilcClient client, SilcClientConnection conn, SilcClientEntry *clients, SilcUInt32 clients_count, void *context ) {
	NSMutableDictionary *dict = context;
	MVSILCChatConnection *self = [dict objectForKey:@"connection"];

	if( ! clients_count ) {
		goto out;
	} else {
		char *nickname = NULL;
		SilcClientEntry target;

		if( clients_count > 1 ) {
			silc_parse_userfqdn( [[dict objectForKey:@"user"] UTF8String], &nickname, NULL );

			/* Find the correct one. The rec -> nick might be a formatted nick
			so this will find the correct one. */

			clients = silc_client_get_clients_local( client, conn, nickname, [[dict objectForKey:@"user"] UTF8String], &clients_count);
			silc_free( nickname );
			nickname = NULL;
			if( ! clients ) goto out;
		}

		target = clients[0];

		/* Still check for exact math for nickname, this compares the
			real (formatted) nickname and the nick (maybe formatted) that
			use gave. This is to assure that `nick' does not match `nick@host'. */

		if( ! [[dict objectForKey:@"user"] isEqualToString:[NSString stringWithUTF8String:target -> nickname]] ) {
			goto out;
		}

		[[self _silcClientLock] lock];
		silc_client_send_private_message( [self _silcClient], [self _silcConn], target, [[dict objectForKey:@"flags"] intValue], (char *) [[[dict objectForKey:@"message"] string] UTF8String], strlen( [[[dict objectForKey:@"message"] string] UTF8String] ), false );
		[[self _silcClientLock] unlock];
	}

out:
	[dict release];
}

static void silc_nickname_format_parse( const char *nickname, char **ret_nickname ) {
	silc_parse_userfqdn( nickname, ret_nickname, NULL );
}

void silc_channel_get_clients_per_list_callback( SilcClient client, SilcClientConnection conn, SilcClientEntry *clients, SilcUInt32 clients_count, void *context ) {
	NSDictionary *dict = context;
	MVSILCChatConnection *self = [dict objectForKey:@"connection"];
	NSMutableArray *nickArray = [NSMutableArray arrayWithCapacity:clients_count];

	[[self _silcClientLock] lock];
	SilcChannelEntry channel = silc_client_get_channel( [self _silcClient], [self _silcConn], (char *) [[dict objectForKey:@"channel_name"] UTF8String]);
	[[self _silcClientLock] unlock];

	int i = 0;
	for( i = 0; i < clients_count; i++ ) {
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		
		NSString *nickname = nil;
		if ( clients[i] -> nickname ) nickname = [NSString stringWithUTF8String:clients[i] -> nickname];
		if ( ! nickname ) {
			// we can't add a user without its nickname ... continue
			continue;
		}

		[info setObject:nickname forKey:@"nickname"];

		SilcChannelUser channelUser = silc_client_on_channel( channel, clients[i] );
		BOOL serverOperator = NO;
		BOOL operator = NO;

		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANOP ) {
			operator = YES;
		}

		if( clients[i] -> mode & SILC_UMODE_SERVER_OPERATOR || clients[i] -> mode & SILC_UMODE_ROUTER_OPERATOR ) {
			serverOperator = YES;
		}

		[info setObject:[NSNumber numberWithBool:serverOperator] forKey:@"serverOperator"];
		[info setObject:[NSNumber numberWithBool:operator] forKey:@"operator"];
		[info setObject:[NSNumber numberWithBool:NO] forKey:@"halfOperator"];
		[info setObject:[NSNumber numberWithBool:NO] forKey:@"voice"];
		
		if ( clients[i] -> hostname )
			[info setObject:[NSString stringWithUTF8String:clients[i] -> hostname] forKey:@"address"];
		else
			[info setObject:@"" forKey:@"address"];
		// [info setObject:[NSString stringWithUTF8String:clients[i] -> realname] forKey:@"realName"];

		unsigned int mode = 0;
		if( channelUser ) mode = channelUser -> mode;

		[self _addUser:nickname toChannel:[dict objectForKey:@"channel_name"] withMode:[NSNumber numberWithUnsignedInt:mode]];
		
		[nickArray addObject:info];
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionRoomExistingMemberListNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[dict objectForKey:@"channel_name"], @"room", nickArray, @"members", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_say( SilcClient client, SilcClientConnection conn, SilcClientMessageType type, char *msg, ... ) {
}

static void silc_channel_message( SilcClient client, SilcClientConnection conn, SilcClientEntry sender, SilcChannelEntry channel, SilcMessagePayload payload, SilcChannelPrivateKey key, SilcMessageFlags flags, const unsigned char *message, SilcUInt32 message_len) {
	MVSILCChatConnection *self = conn -> context;
	
	BOOL action = NO;
	if ( flags & SILC_MESSAGE_FLAG_ACTION ) action = YES;

	NSData *msgData = [NSData dataWithBytes:message length:message_len];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", [NSString stringWithUTF8String:sender -> nickname], @"from", msgData, @"message", [NSNumber numberWithBool:action], @"action", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_private_message( SilcClient client, SilcClientConnection conn, SilcClientEntry sender, SilcMessagePayload payload, SilcMessageFlags flags, const unsigned char *message, SilcUInt32 message_len ) {
	MVSILCChatConnection *self = conn -> context;
	
	BOOL action = NO;
	if ( flags & SILC_MESSAGE_FLAG_ACTION ) action = YES;

	NSData *msgData = [NSData dataWithBytes:message length:message_len];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:sender -> nickname], @"from", msgData, @"message", [NSNumber numberWithBool:action], @"action", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_notify( SilcClient client, SilcClientConnection conn, SilcNotifyType type, ... ) {
	va_list list;
	MVSILCChatConnection *self = conn -> context;

	va_start( list, type );

	switch( type ) {
		case SILC_NOTIFY_TYPE_MOTD:
			break;
		case SILC_NOTIFY_TYPE_NONE:
			break;
		case SILC_NOTIFY_TYPE_SIGNOFF: {
			SilcClientEntry signoff_client = va_arg( list, SilcClientEntry );
			char *signoff_message = va_arg( list, char * );

			if( ! signoff_message ) signoff_message = "";
			
			NSString *nickname = nil;
			if ( signoff_client -> nickname ) nickname = [NSString stringWithUTF8String:signoff_client -> nickname];
			if ( ! nickname ) nickname = @"UNKNOWN";
			
			NSString *hostname = nil;
			if ( signoff_client -> hostname ) hostname = [NSString stringWithUTF8String:signoff_client -> hostname];
			if ( ! hostname ) hostname = @"";

			NSData *msgData = [NSData dataWithBytes:signoff_message length:strlen( signoff_message )];
			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserQuitNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:nickname, @"who", hostname, @"address", msgData, @"reason", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

			[self _delUser:nickname];
		}	break;
		case SILC_NOTIFY_TYPE_NICK_CHANGE: {
			SilcClientEntry oldclient = va_arg( list, SilcClientEntry );
			SilcClientEntry newclient = va_arg( list, SilcClientEntry );

			// we can't change the nick if any of these two doesn't exist - we return for now
			if ( ! oldclient -> nickname || ! newclient -> nickname) return;
			
			NSString *oldnick = [NSString stringWithUTF8String:oldclient -> nickname];
			NSString *newnick = [NSString stringWithUTF8String:newclient -> nickname];

			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserNicknameChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldnick, @"oldNickname", newnick, @"newNickname", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

			[self _userChangedNick:oldnick to:newnick];
		}	break;
		case SILC_NOTIFY_TYPE_SERVER_SIGNOFF: {
			va_arg( list, void * );
			SilcClientEntry *clients = va_arg( list, SilcClientEntry * );
			SilcUInt32 clients_count = va_arg( list, int );
			int i;
			
			if ( ! clients ) return;
			
			const char *signoff_message = "Server signoff";
			NSData *signoff_data = [NSData dataWithBytes:signoff_message length:strlen( signoff_message )];
			
			for ( i = 0; i < clients_count; i++ ) {
				SilcClientEntry signoff_client = clients[i];
				
				NSString *nickname = nil;
				if ( signoff_client -> nickname ) nickname = [NSString stringWithUTF8String:signoff_client -> nickname];
				if ( ! nickname ) nickname = @"UNKNOWN";
				
				NSString *hostname = nil;
				if ( signoff_client -> hostname ) hostname = [NSString stringWithUTF8String:signoff_client -> hostname];
				if ( ! hostname ) hostname = @"";
				
				NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserQuitNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:nickname, @"who", hostname, @"address", signoff_data, @"reason", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
				
				[self _delUser:nickname];
			}

		}	break;
		case SILC_NOTIFY_TYPE_WATCH:
			break;
		case SILC_NOTIFY_TYPE_JOIN: {
			SilcClientEntry joining_client = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			
			if ( ! joining_client || ! channel ) return;
			if ( ! joining_client -> nickname || ! channel -> channel_name ) return;
			
			if ( [[self nickname] isEqualToString:[NSString stringWithUTF8String:joining_client -> nickname]] ) {
				// we send a notification that we joined the channel in the COMMAND callback, no need to do it here too.
				return;
			}
			
			NSString *nickname = [NSString stringWithUTF8String:joining_client -> nickname];
			NSString *channelname = [NSString stringWithUTF8String:channel -> channel_name];

			NSMutableDictionary *info = [NSMutableDictionary dictionary];
			[info setObject:nickname forKey:@"nickname"];

			SilcChannelUser channelUser = silc_client_on_channel( channel, joining_client );
			BOOL serverOperator = NO;
			BOOL operator = NO;

			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANOP ) {
				operator = YES;
			}

			if( joining_client -> mode & SILC_UMODE_SERVER_OPERATOR || joining_client -> mode & SILC_UMODE_ROUTER_OPERATOR ) {
				serverOperator = YES;
			}

			[info setObject:[NSNumber numberWithBool:serverOperator] forKey:@"serverOperator"];
			[info setObject:[NSNumber numberWithBool:operator] forKey:@"operator"];
			[info setObject:[NSNumber numberWithBool:NO] forKey:@"halfOperator"];
			[info setObject:[NSNumber numberWithBool:NO] forKey:@"voice"];
			if( joining_client -> hostname ) [info setObject:[NSString stringWithUTF8String:joining_client -> hostname] forKey:@"address"];
			if( joining_client -> realname ) [info setObject:[NSString stringWithUTF8String:joining_client -> realname] forKey:@"realName"];

			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:channelname, @"room", nickname, @"who", info, @"info", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

			unsigned int mode = 0;
			if( channelUser ) mode = channelUser -> mode;

			[self _addUser:nickname toChannel:channelname withMode:[NSNumber numberWithUnsignedInt:mode]];
		}	break;
		case SILC_NOTIFY_TYPE_LEAVE: {
			SilcClientEntry leaving_client = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			
			if ( ! leaving_client || ! channel ) return;
			if ( ! leaving_client -> nickname || ! channel -> channel_name ) return;
			
			NSString *hostname;
			if ( leaving_client -> hostname ) hostname = [NSString stringWithUTF8String:leaving_client -> hostname];
			else hostname = @"";

			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", [NSString stringWithUTF8String:leaving_client -> nickname], @"who", hostname, @"address", [NSNull null], @"reason", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

			[self _delUser:[NSString stringWithUTF8String:leaving_client -> nickname] fromChannel:[NSString stringWithUTF8String:channel -> channel_name]];
		}	break;
		case SILC_NOTIFY_TYPE_TOPIC_SET: {
			SilcIdType setter_id_type = va_arg( list, int );
			void *setter_entry = va_arg( list, void * );
			char *topic = va_arg( list, char * );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			
			if ( ! setter_entry || ! channel ) return;
			if ( ! channel -> channel_name ) return;
			
			SilcClientEntry client_setter;
			SilcChannelEntry channel_setter;
			SilcServerEntry server_setter;

			NSString *author = nil;
			switch( setter_id_type ) {
			case SILC_ID_CLIENT:
				client_setter = setter_entry;
				if ( ! client_setter -> nickname ) author = @"Unknown";
				else author = [NSString stringWithUTF8String:client_setter -> nickname];
				break;
			case SILC_ID_CHANNEL:
				channel_setter = setter_entry;
				if ( ! channel_setter -> channel_name ) author = @"Unknown room";
				else author = [NSString stringWithUTF8String:channel_setter -> channel_name];
				break;
			case SILC_ID_SERVER:
				server_setter = setter_entry;
				if ( ! server_setter -> server_name ) author = @"Unknown server";
				else author = [NSString stringWithUTF8String:server_setter -> server_name];
				break;
			default:
				author = @"Unknown";
			}

			if( ! topic ) topic = "";

			NSData *msgData = [NSData dataWithBytes:topic length:strlen( topic )];
			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", author, @"author", ( msgData ? (id) msgData : (id) [NSNull null] ), @"topic", [NSDate dateWithTimeIntervalSince1970:0], @"time", [NSNumber numberWithBool:NO], @"justJoined", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}	break;
		case SILC_NOTIFY_TYPE_CMODE_CHANGE:
			break;
		case SILC_NOTIFY_TYPE_CUMODE_CHANGE: {
			SilcIdType changer_id_type = va_arg( list, int );
			void *changer_entry = va_arg( list, void * );
			SilcUInt32 mode = va_arg( list, SilcUInt32 );
			SilcClientEntry target_client = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			
			if ( ! changer_entry || ! target_client || ! channel ) return;
			if ( ! target_client -> nickname || ! channel -> channel_name ) return;
			
			NSString *nickname = [NSString stringWithUTF8String:target_client -> nickname];
			NSString *channelname = [NSString stringWithUTF8String:channel -> channel_name];

			SilcClientEntry client_changer;
			SilcChannelEntry channel_changer;
			SilcServerEntry server_changer;			
			
			NSString *changer = nil;
			switch( changer_id_type ) {
			case SILC_ID_CLIENT:
				client_changer = changer_entry;
				if ( ! client_changer -> nickname ) changer = @"Unknown";
				else changer = [NSString stringWithUTF8String:client_changer -> nickname];
				break;
			case SILC_ID_CHANNEL:
				channel_changer = changer_entry;
				if ( ! channel_changer -> channel_name ) changer = @"Unknown room";
				else changer = [NSString stringWithUTF8String:channel_changer -> channel_name];
				break;
			case SILC_ID_SERVER:
				server_changer = changer_entry;
				if ( ! server_changer -> server_name ) changer = @"Unknown server";
				else changer = [NSString stringWithUTF8String:server_changer -> server_name];
				break;
			default:
				changer = @"Unknown";
			}

			unsigned int oldmode = [[self _getModeForUser:nickname onChannel:channelname] unsignedIntValue];

			BOOL enabled = NO;
			unsigned int m = MVChatMemberNoModes;

			/* if( ( oldmode & SILC_CHANNEL_UMODE_CHANFO ) && ! ( mode & SILC_CHANNEL_UMODE_CHANFO ) ) {
				enabled = NO;
				m = MVChatMemberOperatorMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotMemberModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", [NSString stringWithUTF8String:target_client -> nickname], @"who", changer, @"by", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			} else if( ! ( oldmode & SILC_CHANNEL_UMODE_CHANFO ) && ( mode & SILC_CHANNEL_UMODE_CHANFO ) ) {
				enabled = YES;
				m = MVChatMemberOperatorMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotMemberModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", [NSString stringWithUTF8String:target_client -> nickname], @"who", changer, @"by", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			} */

			if( ( oldmode & SILC_CHANNEL_UMODE_CHANOP ) && ! ( mode & SILC_CHANNEL_UMODE_CHANOP ) ) {
				enabled = NO;
				m = MVChatMemberOperatorMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotMemberModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:channelname, @"room", nickname, @"who", changer, @"by", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			} else if( ! ( oldmode & SILC_CHANNEL_UMODE_CHANOP ) && ( mode & SILC_CHANNEL_UMODE_CHANOP ) ) {
				enabled = YES;
				m = MVChatMemberOperatorMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotMemberModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:channelname, @"room", nickname, @"who", changer, @"by", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			}

			[self _userModeChanged:nickname onChannel:channelname toMode:[NSNumber numberWithUnsignedInt:mode]];
		}	break;
		case SILC_NOTIFY_TYPE_CHANNEL_CHANGE:
			break;
		case SILC_NOTIFY_TYPE_KICKED: {
			SilcClientEntry kicked = va_arg( list, SilcClientEntry );
			char *kick_message = va_arg( list, char * );
			SilcClientEntry kicker = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			
			if ( ! kicked || ! kicker || ! channel ) return;
			if ( ! kicked -> nickname || ! kicker -> nickname || ! channel -> channel_name ) return;
			
			NSString *kickedNickname = [NSString stringWithUTF8String:kicked -> nickname];
			NSString *kickerNickname = [NSString stringWithUTF8String:kicker -> nickname];
			NSString *channelName = [NSString stringWithUTF8String:channel -> channel_name];

			if ( ! kick_message ) kick_message = "No Reason";
			NSData *msgData = [NSData dataWithBytes:kick_message length:strlen( kick_message )];
			NSNotification *note = nil;

			if( [[self nickname] isEqualToString:kickedNickname] ) {
				note = [NSNotification notificationWithName:MVChatConnectionKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:channelName, @"room", kickerNickname, @"by", msgData, @"reason", nil]];		
			} else {
				note = [NSNotification notificationWithName:MVChatConnectionUserKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:channelName, @"room", kickedNickname, @"who", kickerNickname, @"by", msgData, @"reason", nil]];
			}

			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

			[self _delUser:kickedNickname fromChannel:channelName];
		}	break;
		case SILC_NOTIFY_TYPE_KILLED: {
			SilcClientEntry killed = va_arg( list, SilcClientEntry );
			char *kill_message = va_arg( list, char * );
			SilcIdType killer_type = va_arg( list, int );
			void *killer = va_arg( list, void * );
			
			if ( ! killed || ! killer ) return;
			if ( ! killed -> nickname ) return;

			NSString *killedNickname = [NSString stringWithUTF8String:killed -> nickname];
			
			SilcClientEntry client_killer;
			SilcChannelEntry channel_killer;
			SilcServerEntry server_killer;		
			
			NSString *killerNickname = nil;
			switch( killer_type ) {
				case SILC_ID_CLIENT:
					client_killer = killer;
					if ( ! client_killer -> nickname ) killerNickname = @"Unknown";
					else killerNickname = [NSString stringWithUTF8String:client_killer -> nickname];
					break;
				case SILC_ID_CHANNEL:
					channel_killer = killer;
					if ( ! channel_killer -> channel_name ) killerNickname = @"Unknown room";
					else killerNickname = [NSString stringWithUTF8String:channel_killer -> channel_name];
					break;
				case SILC_ID_SERVER:
					server_killer = killer;
					if ( ! server_killer -> server_name ) killerNickname = @"Unknown server";
					else killerNickname = [NSString stringWithUTF8String:server_killer -> server_name];
					break;
				default:
					killerNickname = @"Unknown";
			}
			
			if ( ! kill_message ) kill_message = "";
			NSString *killMessage = [NSString stringWithUTF8String:kill_message];
			
			NSString *hostname = nil;
			if ( killed -> hostname ) hostname = [NSString stringWithUTF8String:killed -> hostname];
			else hostname = @"";
			
			NSString *quitReason = [NSString stringWithFormat:@"Killed by %@ (%@)", killerNickname, killMessage];
			const char *quitReasonString = [quitReason UTF8String];
			
			NSData *msgData = [NSData dataWithBytes:quitReasonString length:strlen( quitReasonString )];
			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserQuitNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:killedNickname, @"who", hostname, @"address", msgData, @"reason", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}	break;
		case SILC_NOTIFY_TYPE_UMODE_CHANGE:
			break;
		case SILC_NOTIFY_TYPE_BAN:
			break;
		case SILC_NOTIFY_TYPE_ERROR:
			break;
		case SILC_NOTIFY_TYPE_INVITE: {
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			char *channel_name = va_arg( list, char * );
			SilcClientEntry inviter = va_arg( list, SilcClientEntry );
			
			NSString *channelName = nil;
			if ( channel && channel -> channel_name ) channelName = [NSString stringWithUTF8String:channel -> channel_name];
			if ( ! channelName && channel_name ) channelName = [NSString stringWithUTF8String:channel_name];
			if ( ! channelName ) {
				// we don't get the channel name .. I don't understand this, but silc toolkit documentation
				// tells us that channel_name *can* be NULL ... we just return ...
				return;
			}
			
			NSString *by = nil;
			if ( inviter && inviter -> nickname ) by = [NSString stringWithUTF8String:inviter -> nickname];
			if ( ! by ) {
				return;
			}
			
			NSNotification *note = [NSNotification notificationWithName:MVChatConnectionInvitedToRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:channelName, @"room", by, @"from", nil]];		
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			
		}	break;
	} 

	va_end( list );
}

static void silc_command( SilcClient client, SilcClientConnection conn, SilcClientCommandContext cmd_context, bool success, SilcCommand command, SilcStatus status ) {
}

static void silc_command_reply( SilcClient client, SilcClientConnection conn, SilcCommandPayload cmd_payload, bool success, SilcCommand command, SilcStatus status, ... ) {
	MVSILCChatConnection *self = conn -> context;

	va_list list;
	
	SilcUInt16 cmdid = silc_command_get_ident( cmd_payload );
	
	NSString *rawCommand = [self _getCommandForNumber:cmdid];
	if ( ! rawCommand ) rawCommand = @"Unknown command";
	
	if ( ! success ) {
		char *error_message = (char *)silc_get_status_message( status );
		if ( error_message ) {
			rawCommand = [rawCommand stringByAppendingFormat:@": %s", error_message];
		}
		[self _sendCommandFailedNotify:rawCommand];
		return;
	}
	
	[self _sendCommandSucceededNotify:rawCommand];
	
	va_start( list, status );
	switch( command ) {
	case SILC_COMMAND_WHOIS: {
		SilcClientEntry client_entry = va_arg( list, SilcClientEntry );
		char *nickname = va_arg( list, char * );
		char *username = va_arg( list, char * );
		char *realname = va_arg( list, char * );
		SilcBuffer channels = va_arg( list, SilcBuffer );
		/* SilcUInt32 usermode = */ va_arg( list, int );
		SilcUInt32 idletime = va_arg( list, int );
		/* unsigned char *fingerprint = */ va_arg( list, unsigned char * );
		SilcBuffer user_modes = va_arg( list, SilcBuffer );
		/* SilcDList attrs = */ va_arg( list, SilcDList );
		char *nick = NULL;

		silc_parse_userfqdn( nickname, &nick, NULL );

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserWhoisNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:username], @"username", [NSString stringWithUTF8String:client_entry -> hostname], @"hostname", [NSString stringWithUTF8String:realname], @"realname", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		note = [NSNotification notificationWithName:MVChatConnectionGotUserServerNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:client_entry -> server], @"server", [NSString stringWithString:@""], @"serverinfo", nil]];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		if( channels && user_modes ) {
			NSMutableArray *chanArray = [NSMutableArray array];
			SilcUInt32 *umodes;
			SilcDList list = silc_channel_payload_parse_list( channels -> data, channels -> len);
			if( list && silc_get_mode_list( user_modes, silc_dlist_count( list ), &umodes ) ) {
				SilcChannelPayload entry;
				int i = 0;

				silc_dlist_start( list );
				while( ( entry = silc_dlist_get( list ) ) != SILC_LIST_END ) {
					SilcUInt32 name_len;
					char *m = silc_client_chumode_char( umodes[i++] );
					char *name = silc_channel_get_name( entry, &name_len );

					NSMutableString *buf = [NSMutableString string];
					if( m ) [buf appendString:[NSString stringWithUTF8String:m]];

					[buf appendString:[NSString stringWithUTF8String:name]];
					[chanArray addObject:buf],

					silc_free( m );
				}

				silc_channel_payload_list_free( list );
				silc_free( umodes );
			}

			note = [NSNotification notificationWithName:MVChatConnectionGotUserChannelsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", chanArray, @"channels", nil]];		
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}

		note = [NSNotification notificationWithName:MVChatConnectionGotUserIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSNumber numberWithInt:idletime], @"idle", [NSNumber numberWithInt:0], @"connected", nil]];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		note = [NSNotification notificationWithName:MVChatConnectionGotUserWhoisCompleteNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", nil]];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		silc_free( nick );
	}	break;
	case SILC_COMMAND_WHOWAS:
		break;
	case SILC_COMMAND_IDENTIFY:
		break;
	case SILC_COMMAND_NICK: {
		/*SilcClientEntry local_entry =*/ va_arg( list, SilcClientEntry );
		char *nickname = va_arg( list, char * );
		/*const SilcClientID *old_client_id =*/ va_arg( list, SilcClientID * );

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nickname], @"nickname", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}	break;
	case SILC_COMMAND_LIST: {
		/* SilcChannelEntry channel = */ va_arg( list, SilcChannelEntry );
		char *channel_name = va_arg( list, char * );
		char *channel_topic = va_arg( list, char * );
		SilcUInt32 user_count = va_arg( list, SilcUInt32 );

		NSString *r = [NSString stringWithUTF8String:channel_name];
		if( ! channel_topic ) channel_topic = "";
		NSData *t = [NSData dataWithBytes:channel_topic length:strlen( channel_topic )];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:user_count], @"users", t, @"topic", [NSDate date], @"cached", r, @"room", nil];

		[self performSelectorOnMainThread:@selector( _addRoomToCache: ) withObject:info waitUntilDone:NO];
	}	break;
	case SILC_COMMAND_TOPIC:
		break;
	case SILC_COMMAND_INVITE:
		break;
	case SILC_COMMAND_KILL:
		break;
	case SILC_COMMAND_INFO:
		break;
	case SILC_COMMAND_STATS:
		break;
	case SILC_COMMAND_PING:
		break;
	case SILC_COMMAND_OPER:
		break;
	case SILC_COMMAND_JOIN: {
		char *channel_name = va_arg( list, char * );
		SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
		/* SilcUInt32 channel_mode = */ va_arg( list, SilcUInt32 );
		/* int ignored = */ va_arg( list, int );
		/* SilcBuffer key_payload = */ va_arg( list, SilcBuffer );
		/* void *null1 = */ va_arg( list, void * );
		/* void *null2 = */ va_arg( list, void * );
		char *topic = va_arg( list, char * );
		/* char *hmac_name =*/ va_arg( list, char * );
		SilcUInt32 list_count = va_arg( list, SilcUInt32 );
		SilcBuffer client_id_list = va_arg( list, SilcBuffer );
		/* SilcBuffer client_mode_list = */ va_arg( list, SilcBuffer );
		/* SilcPublicKey founder_key = */ va_arg( list, SilcPublicKey );
		/* SilcBuffer channel_pubkeys = */ va_arg( list, SilcBuffer );
		/* SilcUInt32 user_limit = */ va_arg( list, SilcUInt32 );

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel_name], @"room", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		if( ! topic ) topic = "";

		NSData *msgData = [NSData dataWithBytes:topic length:strlen( topic )];

		note = [NSNotification notificationWithName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", (id)[NSNull null], @"author", ( msgData ? (id) msgData : (id) [NSNull null] ), @"topic", [NSDate dateWithTimeIntervalSince1970:0], @"time", [NSNumber numberWithBool:YES], @"justJoined", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		[self _addChannel:[NSString stringWithUTF8String:channel_name]];
		
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:self, @"connection", [NSString stringWithUTF8String:channel_name], @"channel_name", NULL];
		silc_client_get_clients_by_list( [self _silcClient], [self _silcConn], list_count, client_id_list, silc_channel_get_clients_per_list_callback, dict );

	}	break;
	case SILC_COMMAND_MOTD:
		break;
	case SILC_COMMAND_UMODE:
		break;
	case SILC_COMMAND_CMODE:
		break;
	case SILC_COMMAND_CUMODE:
		break;
	case SILC_COMMAND_KICK:
		break;
	case SILC_COMMAND_BAN:
		break;
	case SILC_COMMAND_DETACH:
		break;
	case SILC_COMMAND_WATCH:
		break;
	case SILC_COMMAND_SILCOPER:
		break;
	case SILC_COMMAND_LEAVE: {
		SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> channel_name], @"room", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		[self _delChannel:[NSString stringWithUTF8String:channel -> channel_name]];
	}	break;
	case SILC_COMMAND_USERS:
		break;
	case SILC_COMMAND_GETKEY:
		break;
	}
}

static void silc_connected( SilcClient client, SilcClientConnection conn, SilcClientConnectionStatus status ) {
	MVSILCChatConnection *self = conn -> context;
	[self _setSilcConn:conn];

	if( status == SILC_CLIENT_CONN_SUCCESS || status == SILC_CLIENT_CONN_SUCCESS_RESUME ) {
		[[self _silcClientLock] unlock];
		[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:YES];
		[[self _silcClientLock] lock];

		[[self _queuedCommandsLock] lock];

		NSMutableArray *commands = [self _queuedCommands];
		if( [commands count] ) {
			NSEnumerator *enumerator = [commands objectEnumerator];
			NSString *command;

			while( ( command = [enumerator nextObject] ) ) {
				[self sendRawMessage:command];
			}

			[commands removeAllObjects];
		}

		[[self _queuedCommandsLock] unlock];
	} else {
		[[self _silcClientLock] lock];
		silc_client_close_connection( client, conn );
		[[self _silcClientLock] unlock];
		
		[self _setSilcConn:NULL];
		
		[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:NO];
	}	
}

static void silc_disconnected( SilcClient client, SilcClientConnection conn, SilcStatus status, const char *message ) {
	MVSILCChatConnection *self = conn -> context;
	

	[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:YES];
}

static void silc_get_auth_method( SilcClient client, SilcClientConnection conn, char *hostname, SilcUInt16 port, SilcGetAuthMeth completion, void *context ) {
	completion( TRUE, SILC_AUTH_NONE, NULL, 0, context );
}

static void silc_verify_public_key( SilcClient client, SilcClientConnection conn, SilcSocketType conn_type, unsigned char *pk, SilcUInt32 pk_len, SilcSKEPKType pk_type, SilcVerifyPublicKey completion, void *context ) {
	// we should ask the user about the servers public key, and save it somewhere if he accepts it
	completion( TRUE, context );
}

static void silc_ask_passphrase( SilcClient client, SilcClientConnection conn, SilcAskPassphrase completion, void *context ) {
}

static void silc_failure( SilcClient client, SilcClientConnection conn, SilcProtocol protocol, void *failure ) {
}

static bool silc_key_agreement( SilcClient client, SilcClientConnection conn, SilcClientEntry client_entry, const char *hostname, SilcUInt16 port, SilcKeyAgreementCallback *completion, void **context) {
	return FALSE;
}

static void silc_ftp( SilcClient client, SilcClientConnection conn, SilcClientEntry client_entry, SilcUInt32 session_id, const char *hostname, SilcUInt16 port ) {
}

static void silc_detach( SilcClient client, SilcClientConnection conn, const unsigned char *detach_data, SilcUInt32 detach_data_len ) {
}

static SilcClientOperations silcClientOps = {
	silc_say,
	silc_channel_message,
	silc_private_message,
	silc_notify,
	silc_command,
	silc_command_reply,
	silc_connected,
	silc_disconnected,
	silc_get_auth_method,
	silc_verify_public_key,
	silc_ask_passphrase,
	silc_failure,
	silc_key_agreement,
	silc_ftp,
	silc_detach
};

#pragma mark -

@implementation MVSILCChatConnection
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		silc_pkcs_register_default();
		silc_hash_register_default();
		silc_cipher_register_default();
		silc_hmac_register_default();

		tooLate = YES;
	}
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_encoding = NSUTF8StringEncoding; // the only encoding we support

		memset( &_silcClientParams, 0, sizeof( _silcClientParams ) );
		strcat( _silcClientParams.nickname_format, "%n@%h%a" );
		_silcClientParams.nickname_parse = silc_nickname_format_parse;

		_silcClientLock = [[NSRecursiveLock alloc] init];
		_silcClient = silc_client_alloc( &silcClientOps, &_silcClientParams, self, NULL );
		if( ! _silcClient) {
			// we need some error handling here.. silc conenction CAN'T work without silc client
			[self release];
			return nil;
		}

		[self setUsername:NSUserName()];
		[self setRealName:NSFullUserName()];

		_joinedChannels = [[NSMutableArray array] retain];
		_queuedCommands = [[NSMutableArray array] retain];
		_queuedCommandsLock = [[NSLock alloc] init];

		_sentCommands = [[NSMutableDictionary dictionary] retain];
		_sentCommandsLock = [[NSLock alloc] init];
	}

	return self;
}

- (void) dealloc {
	[self disconnect];

	[_silcClientLock lock];
	if( _silcClient -> realname ) free( _silcClient -> realname );
	if( _silcClient -> username ) free( _silcClient -> username );
	if( _silcClient -> hostname ) free( _silcClient -> hostname );
	if( _silcClient -> nickname ) free( _silcClient -> nickname );

	silc_client_free( _silcClient );
	[_silcClientLock unlock];
	_silcClient = NULL;

	[_silcClientLock release];
	_silcClientLock = nil;

	[_silcPassword release];
	_silcPassword = nil;

	[_silcServer release];
	_silcServer = nil;

	[_joinedChannels release];
	_joinedChannels = nil;

	[_queuedCommands release];
	_queuedCommands = nil;

	[_queuedCommandsLock release];
	_queuedCommandsLock = nil;
	
	[_sentCommands release];
	_sentCommands = nil;
	
	[_sentCommandsLock release];
	_sentCommandsLock = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatConnectionType) type {
	return MVChatConnectionSILCType;
}

- (void) connect {
	if( [self status] != MVChatConnectionDisconnectedStatus && [self status] != MVChatConnectionServerDisconnectedStatus && [self status] != MVChatConnectionSuspendedStatus ) return;

	if( ! [self _isKeyPairLoaded] ) {
		if( ! [self _loadKeyPair] ) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _connectKeyPairLoaded: ) name:MVSILCChatConnectionLoadedCertificate object:nil];
			return;
		}
	}

	if( _lastConnectAttempt && ABS( [_lastConnectAttempt timeIntervalSinceNow] ) < 5. ) {
		// prevents conencting too quick
		// cancel any reconnect attempts, this lets a user cancel the attempts with a "double connect"
		[self cancelPendingReconnectAttempts];
		return;
	}

	[_lastConnectAttempt autorelease];
	_lastConnectAttempt = [[NSDate date] retain];
	
	[self _willConnect]; // call early so other code has a chance to change our info

	_sentQuitCommand = NO;

	_silcClient -> hostname = strdup( [[[NSProcessInfo processInfo] hostName] UTF8String] );
	_silcClient -> pkcs = silcPkcs;
	_silcClient -> private_key = silcPrivateKey;
	_silcClient -> public_key = silcPublicKey;

	if( ! silc_client_init( _silcClient ) ) {
		// some error, do better reporting
		[self _didNotConnect];
		return;
	}

	BOOL errorOnConnect = NO;

	[_silcClientLock lock];
	if( silc_client_connect_to_server( [self _silcClient], NULL, [self serverPort], (char *) [[self server] UTF8String], self ) == -1 )
		errorOnConnect = YES;
	[_silcClientLock unlock];

	if( errorOnConnect) [self _didNotConnect];
	else [NSThread detachNewThreadSelector:@selector( _silcRunloop ) toTarget:self withObject:nil];
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
	[self cancelPendingReconnectAttempts];

	if( [self status] != MVChatConnectionConnectedStatus ) return;

	_sentQuitCommand = YES;
	
	if( [[reason string] length] ) {
		const char *tmp = [MVSILCChatConnection _flattenedSILCStringForMessage:reason];
		[self sendRawMessageWithFormat:@"QUIT %s", tmp];
	} else {
		[self sendRawMessage:@"QUIT"];
	}
}

#pragma mark -

- (NSString *) urlScheme {
	return @"silc";
}

#pragma mark -

- (void) setEncoding:(NSStringEncoding) encoding {
	// we don't support encodings other than UTF8.
}

- (NSStringEncoding) encoding {
	return NSUTF8StringEncoding; // we don't support encodings other than UTF8.
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	NSParameterAssert( name != nil );
	if( ! _silcClient ) return;
	if( _silcClient -> realname) free( _silcClient -> realname );
	_silcClient -> realname = strdup( [name UTF8String] );		
}

- (NSString *) realName {
	if( ! _silcClient ) return nil;
	return [NSString stringWithUTF8String:_silcClient -> realname];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	NSParameterAssert( nickname != nil );
	NSParameterAssert( [nickname length] > 0 );
	if( ! _silcClient ) return;

	if( _silcClient -> nickname) free(_silcClient -> nickname);
	_silcClient -> nickname = strdup( [nickname UTF8String] );		

	if( [self isConnected] ) {
		if( ! [nickname isEqualToString:[self nickname]] )
			[self sendRawMessageWithFormat:@"NICK %@", nickname];
	}
}

- (NSString *) nickname {
  if ( [self _silcConn] && [self _silcConn] -> nickname )
    return [NSString stringWithUTF8String:[self _silcConn] -> nickname];

	return [NSString stringWithUTF8String:_silcClient -> nickname];
}

- (NSString *) preferredNickname {
	return [NSString stringWithUTF8String:_silcClient -> nickname];
}

#pragma mark -

- (void) setAlternateNicknames:(NSArray *) nicknames {
}

- (NSArray *) alternateNicknames {
	return nil;
}

- (NSString *) nextAlternateNickname {
	return nil;
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
}

- (NSString *) nicknamePassword {
	return nil;
}

#pragma mark -

- (NSString *) certificateServiceName {
	return @"SILC Keypair";
}

- (BOOL) setCertificatePassword:(NSString *) password {
	[_certificatePassword release];
	_certificatePassword = [password copy];

	if( _waitForCertificatePassword ) {
		_waitForCertificatePassword = NO;
		return [self _loadKeyPair];
	}

	// we don't know if the password is the right one - we return YES anyway
	return YES;
}

- (NSString *) certificatePassword {
	return _certificatePassword;
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	[_silcPassword release];
	if( [password length] ) _silcPassword = [password copy];
	else _silcPassword = nil;		
}

- (NSString *) password {
	return _silcPassword;
}

#pragma mark -

- (void) setUsername:(NSString *) username {
	NSParameterAssert( username != nil );
	NSParameterAssert( [username length] > 0 );
	if( ! _silcClient ) return;

	if( _silcClient -> username ) free( _silcClient -> username );
	_silcClient -> username = strdup( [username UTF8String] );		
}

- (NSString *) username {
	if( ! _silcClient ) return nil;
	return [NSString stringWithUTF8String:_silcClient -> username];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	[_silcServer release];
	_silcServer = [server copy];
}

- (NSString *) server {
	return _silcServer;
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	_silcPort = port;
}

- (unsigned short) serverPort {
	return _silcPort;
}

#pragma mark -

- (void) setSecure:(BOOL) ssl {
// always secure
}

- (BOOL) isSecure {
	return NO;
}

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) type {
// no proxy support
}

- (MVChatConnectionProxy) proxyType {
	return 0;
}

#pragma mark -

- (void) setProxyServer:(NSString *) address {
	// no proxy support
}

- (NSString *) proxyServer {
	return nil;
}

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port {
	// no proxy support
}

- (unsigned short) proxyServerPort {
	return 0;
}

#pragma mark -

- (void) setProxyUsername:(NSString *) username {
	// no proxy support
}

- (NSString *) proxyUsername {
	return nil;
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
	// no proxy support
}

- (NSString *) proxyPassword {
	return nil;
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toUser:(NSString *) user asAction:(BOOL) action {
	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:message];
	SilcMessageFlags flags = SILC_MESSAGE_FLAG_UTF8;

	if( action) flags |= SILC_MESSAGE_FLAG_ACTION;

	SilcUInt32 clientsCount;
	[[self _silcClientLock] lock];
	SilcClientEntry *clients = silc_client_get_clients_local( [self _silcClient], [self _silcConn], [user UTF8String], _silcClientParams.nickname_format, &clientsCount );
	[[self _silcClientLock] unlock];

	if( ! clients || ! clientsCount ) {
		NSMutableDictionary *dict = [[NSMutableDictionary dictionary] retain];
		[dict setObject:message forKey:@"message"];
		[dict setObject:user forKey:@"user"];
		[dict setObject:self forKey:@"connection"];
		[dict setObject:[NSNumber numberWithInt:flags] forKey:@"flags"];

		[[self _silcClientLock] lock];
		silc_client_get_clients_whois( [self _silcClient], [self _silcConn], [user UTF8String], NULL, NULL, silc_privmessage_resolve_callback, dict );
		[[self _silcClientLock] unlock];
		return;
	}

	[[self _silcClientLock] lock];
	silc_client_send_private_message( [self _silcClient], [self _silcConn], clients[0], flags, (char *) msg, strlen( msg ), false );	
	[[self _silcClientLock] unlock];
}

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toChatRoom:(NSString *) room asAction:(BOOL) action {
	NSParameterAssert( message != nil );
	NSParameterAssert( room != nil );

	const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:message];
	SilcMessageFlags flags = SILC_MESSAGE_FLAG_UTF8;

	if( action ) flags |= SILC_MESSAGE_FLAG_ACTION;

	[[self _silcClientLock] lock];

	SilcChannelEntry channel = silc_client_get_channel( [self _silcClient], [self _silcConn], (char *) [room UTF8String] );

	if( ! channel) {
		[[self _silcClientLock] unlock];
		return;
	}

	silc_client_send_channel_message( [self _silcClient], [self _silcConn], channel, NULL, flags, (char *) msg, strlen( msg ), false );

	[[self _silcClientLock] unlock];
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );

	if( ! [self isConnected] ) {
		[[self _queuedCommandsLock] lock];
		[[self _queuedCommands] addObject:raw];
		[[self _queuedCommandsLock] unlock];
		return;
	}

	[[self _silcClientLock] lock];
	bool b = silc_client_command_call( [self _silcClient], [self _silcConn], [raw UTF8String] );
	if ( b ) [self _addCommand:raw forNumber:[self _silcConn] -> cmd_ident];
	[[self _silcClientLock] unlock];
	
	if ( ! b ) {
		[self _sendCommandFailedNotify:raw];
	}
}

#pragma mark -

- (MVUploadFileTransfer *) sendFile:(NSString *) path toUser:(NSString *) user {
	// return [self sendFile:path toUser:user passively:NO];
	return nil;
}

- (MVUploadFileTransfer *) sendFile:(NSString *) path toUser:(NSString *) user passively:(BOOL) passive {
	// return [[MVUploadFileTransfer transferWithSourceFile:path toUser:user onConnection:self passively:passive] retain];
	return nil;
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
}

- (void) sendSubcodeReply:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
}

#pragma mark -

- (void) joinChatRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	[self sendRawMessageWithFormat:@"JOIN %@", room];
}

- (void) partChatRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	[self sendRawMessageWithFormat:@"LEAVE %@", room];
}

#pragma mark -

- (NSString *) displayNameFromChatRoom:(NSString *) room {
	return room;
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room {
	NSParameterAssert( topic != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"TOPIC %@ %s", room, [MVSILCChatConnection _flattenedSILCStringForMessage:topic]];
}

#pragma mark -

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"CUMODE %@ +o %@", room, member];
}

- (void) demoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"CUMODE %@ -o %@", room, member];
}

- (void) halfopMember:(NSString *) member inRoom:(NSString *) room {
}

- (void) dehalfopMember:(NSString *) member inRoom:(NSString *) room {
}

- (void) voiceMember:(NSString *) member inRoom:(NSString *) room {
}

- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room {
}

- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( reason ) [self sendRawMessageWithFormat:@"KICK %@ %@ %@", room, member, reason];
	else [self sendRawMessageWithFormat:@"KICK %@ %@", room, member];		
}

- (void) banMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
}

- (void) unbanMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
}

#pragma mark -

- (void) addUserToNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );
}

- (void) removeUserFromNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );
}

#pragma mark -

- (void) fetchInformationForUser:(NSString *) user withPriority:(BOOL) priority fromLocalServer:(BOOL) localOnly {
	NSParameterAssert( user != nil );
	[self sendRawMessageWithFormat:@"WHOIS %@", user];
}

#pragma mark -

- (void) fetchRoomList {
	if( ! _cachedDate || [_cachedDate timeIntervalSinceNow] < -900. ) {
		[self sendRawMessage:@"LIST"];
		[_cachedDate autorelease];
		_cachedDate = [[NSDate date] retain];
	}
}

- (void) fetchRoomListWithRooms:(NSArray *) rooms {
	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *roomname = [enumerator nextObject];

	while (roomname = [enumerator nextObject]) {
		[self sendRawMessageWithFormat:@"LIST %@", roomname];
	}
}

- (void) stopFetchingRoomList {
// can't stop the list
}

- (NSMutableDictionary *) roomListResults {
	return [[_roomsCache retain] autorelease];
}

#pragma mark -

- (NSAttributedString *) awayStatusMessage {
	return _awayMessage;
}

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	[_awayMessage autorelease];
	_awayMessage = nil;

	if( [[message string] length] ) {
		_awayMessage = [message copy];

		[self sendRawMessage:@"UMODE +g"];

		[[self _silcClientLock] lock];
		silc_client_set_away_message( [self _silcClient], [self _silcConn], (char *) [MVSILCChatConnection _flattenedSILCStringForMessage:message] );
		[[self _silcClientLock] unlock];
		
		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"away", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	} else {
		[self sendRawMessage:@"UMODE -g"];

		[[self _silcClientLock] lock];
		silc_client_set_away_message( [self _silcClient], [self _silcConn], NULL );
		[[self _silcClientLock] unlock];
		
		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"away", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

- (void) clearAwayStatus {
	[self setAwayStatusWithMessage:nil];
}

#pragma mark -

- (unsigned int) lag {
	return 0;
}
@end

#pragma mark -

@implementation MVSILCChatConnection (MVSILCChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(NSAttributedString *) message {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NullTerminatedReturn", nil];
	NSData *data = [message IRCFormatWithOptions:options];
	return [data bytes];
}

- (void) _silcRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	while( [self isConnected] || [self status] == MVChatConnectionConnectingStatus ) {
		if( [_silcClientLock tryLock] ) { // prevents some deadlocks
			if( _silcClient && _silcClient -> schedule )
				silc_schedule_one(  _silcClient -> schedule, 100000 );
				// use silc_schedule_one over silc_client_run_one since we want to block a bit inside the locks
			[_silcClientLock unlock];
		}

		usleep( 500 ); // give time to other threads
	}

	[pool release];
}

#pragma mark -

- (SilcClient) _silcClient {
	return _silcClient;
}

- (NSRecursiveLock *) _silcClientLock {
	return _silcClientLock;
}

#pragma mark -

- (void) _setSilcConn:(SilcClientConnection) aSilcConn {
	_silcConn = aSilcConn;
}

- (SilcClientConnection) _silcConn {
	return _silcConn;
}

#pragma mark -

- (NSMutableArray *) _joinedChannels {
	return _joinedChannels;
}

- (void) _addChannel:(NSString *) channel_name {
	[_joinedChannels addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:channel_name, @"channel_name", NULL]];
}

- (void) _addUser:(NSString *) nick_name toChannel:(NSString *) channel_name withMode:(NSNumber *) mode {
	NSMutableDictionary *channel = [self _getChannel:channel_name];
	if( ! channel ) return;

	NSMutableArray *users = [channel objectForKey:@"users"];
	if( ! [users count] ) {
		users = [NSMutableArray array];
		[channel setObject:users forKey:@"users"];
	}

	NSMutableDictionary *user = [NSMutableDictionary dictionary];
	[user setObject:nick_name forKey:@"nick_name"];
	[user setObject:mode forKey:@"mode"];
	[users addObject:user];
}

- (void) _delUser:(NSString *)nick_name fromChannel:(NSString *)channel_name {
	NSMutableDictionary *channel = [self _getChannel:channel_name];
	if( ! channel ) return;

	NSMutableArray *users = [channel objectForKey:@"users"];
	if( ! [users count] ) return;

	NSEnumerator *enumerator = [users objectEnumerator];
	NSDictionary *dict = nil;

	while( ( dict = [enumerator nextObject] ) ) {
		if( [[dict objectForKey:@"nick_name"] isEqualToString:nick_name]) {
			[users removeObject:dict];
			return;
		}
	}
}

- (void) _delUser:(NSString *) nick_name {
	NSEnumerator *enumerator = [_joinedChannels objectEnumerator];
	NSMutableDictionary *channel = nil;

	while( ( channel = [enumerator nextObject] ) ) {
		NSMutableArray *users = [channel objectForKey:@"users"];
		if( ! [users count] ) continue;
		[self _delUser:nick_name fromChannel:[channel objectForKey:@"channel_name"]];
	}		
}

- (void) _delChannel:(NSString *) channel_name {
	NSMutableDictionary *channel = [self _getChannel:channel_name];
	if( channel ) [_joinedChannels removeObject:channel];
}

- (void) _userChangedNick:(NSString *) old_nick_name to:(NSString *) new_nick_name {
	NSEnumerator *enumerator = [_joinedChannels objectEnumerator];
	NSMutableDictionary *channel = nil;

	while( ( channel = [enumerator nextObject] ) ) {
		NSMutableArray *users = [channel objectForKey:@"users"];
		if( ! [users count] ) continue;

		NSEnumerator *userenum = [users objectEnumerator]; 
		NSMutableDictionary *user = nil;
		while( ( user = [userenum nextObject] ) ) {
			if( [[user objectForKey:@"nick_name"] isEqualToString:old_nick_name]) {
				[user setObject:new_nick_name forKey:@"nick_name"];
				break;
			}
		}
	}
}

- (NSArray *) _getChannelsForUser:(NSString *) nick_name {
	NSEnumerator *enumerator = [_joinedChannels objectEnumerator];
	NSMutableDictionary *channel = nil;
	NSMutableArray *results = [NSMutableArray array];

	while( ( channel = [enumerator nextObject] ) ) {
		NSMutableArray *users = [channel objectForKey:@"users"];
		if( ! [users count] ) continue;

		NSEnumerator *userenum = [users objectEnumerator]; 
		NSMutableDictionary *user = nil;
		while( ( user = [userenum nextObject] ) ) {
			if( [[user objectForKey:@"nick_name"] isEqualToString:nick_name]) {
				[results addObject:channel];
			}
		}
	}

	return results;
}

- (NSMutableDictionary *) _getChannel:(NSString *) channel_name {
	NSEnumerator *enumerator = [_joinedChannels objectEnumerator];
	NSMutableDictionary *dict = nil;
	while( ( dict = [enumerator nextObject] ) ) {
		if( [[dict objectForKey:@"channel_name"] isEqualToString:channel_name]) {
			return dict;
		}
	}

	return nil;
}

- (NSNumber *) _getModeForUser:(NSString *) nick_name onChannel:(NSString *) channel_name {
	NSDictionary *channel = [self _getChannel:channel_name];
	NSEnumerator *userenum = [[channel objectForKey:@"users"] objectEnumerator]; 
	NSMutableDictionary *user = nil;
	while( ( user = [userenum nextObject] ) ) {
		if( [[user objectForKey:@"nick_name"] isEqualToString:nick_name] ) {
			return [user objectForKey:@"mode"];
		}
	}

	return nil;
}

- (void) _userModeChanged:(NSString *) nick_name onChannel:(NSString *) channel_name toMode:(NSNumber *) mode {
	NSDictionary *channel = [self _getChannel:channel_name];
	NSEnumerator *userenum = [[channel objectForKey:@"users"] objectEnumerator]; 
	NSMutableDictionary *user = nil;
	while( ( user = [userenum nextObject] ) ) {
		if( [[user objectForKey:@"nick_name"] isEqualToString:nick_name]) {
			[user setObject:mode forKey:@"mode"];
			return;
		}
	}
}

#pragma mark -

- (NSMutableArray *) _queuedCommands {
	return _queuedCommands;
}

- (NSLock *) _queuedCommandsLock {
	return _queuedCommandsLock;
}

#pragma mark -

- (BOOL) _loadKeyPair {
	NSString *publicKeyPath = [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Silc/public_key.pub"] stringByExpandingTildeInPath];
	NSString *privateKeyPath = [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Silc/private_key.prv"] stringByExpandingTildeInPath];

	if( ! [[NSFileManager defaultManager] fileExistsAtPath:publicKeyPath] || ! [[NSFileManager defaultManager] fileExistsAtPath:privateKeyPath] ) {
		// create new keys .. we should propably move this somewhere else..
		silc_create_key_pair( NULL, 1024, [publicKeyPath fileSystemRepresentation], [privateKeyPath fileSystemRepresentation], NULL, "", &silcPkcs, &silcPublicKey, &silcPrivateKey, FALSE );
		return YES;
	}

	BOOL requestPassword = NO;

	if( ! silc_load_key_pair( [publicKeyPath fileSystemRepresentation], [privateKeyPath fileSystemRepresentation], "", &silcPkcs, &silcPublicKey, &silcPrivateKey ) ) {
		if( [[self certificatePassword] length] ) {
			if( ! silc_load_key_pair( [publicKeyPath fileSystemRepresentation], [privateKeyPath fileSystemRepresentation], [[self certificatePassword] UTF8String], &silcPkcs, &silcPublicKey, &silcPrivateKey ) )
				requestPassword = YES;
		} else requestPassword = YES;
	}

	if( requestPassword ) {
		_waitForCertificatePassword = YES;

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNeedCertificatePasswordNotification object:self userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotification:note];

		return NO;
	}

	NSNotification *note = [NSNotification notificationWithName:MVSILCChatConnectionLoadedCertificate object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	return YES;
}

- (BOOL) _isKeyPairLoaded {
	if( ! silcPkcs ) return NO;
	return YES;
}

- (void) _connectKeyPairLoaded:(NSNotification *) notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVSILCChatConnectionLoadedCertificate object:nil];
	[self connect];
}

- (void) _addCommand:(NSString *)raw forNumber:(SilcUInt16) cmd_ident {
	[[self _sentCommandsLock] lock];
	[[self _sentCommands] setObject:raw forKey:[NSNumber numberWithUnsignedShort:cmd_ident]];
	[[self _sentCommandsLock] unlock];
}

- (NSString *) _getCommandForNumber:(SilcUInt16) cmd_ident {
	NSString *string;
	NSNumber *number = [NSNumber numberWithUnsignedShort:cmd_ident];
	[[self _sentCommandsLock] lock];
	string = [[[self _sentCommands] objectForKey:number] retain];
	[[self _sentCommands] removeObjectForKey:number];
	[[self _sentCommandsLock] unlock];
	
	return [string autorelease];
}

- (NSLock *) _sentCommandsLock {
	return _sentCommandsLock;
}

- (NSMutableDictionary *) _sentCommands {
	return _sentCommands;
}

- (void) _sendCommandSucceededNotify:(NSString *) message {
	NSNotification *rawMessageNote = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:message, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:rawMessageNote];
}

- (void) _sendCommandFailedNotify:(NSString *) message {
	NSString *raw = [NSString stringWithFormat:@"Command failed: %@", message];
	NSNotification *rawMessageNote = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:raw, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:rawMessageNote];	
}

#pragma mark -

- (void) _didDisconnect {
	if( ! _sentQuitCommand ) {
		if( _status != MVChatConnectionSuspendedStatus )
			_status = MVChatConnectionServerDisconnectedStatus;
		if( ABS( [_lastConnectAttempt timeIntervalSinceNow] ) > 300. )
			[self performSelector:@selector( connect ) withObject:nil afterDelay:5.];
		[self scheduleReconnectAttemptEvery:30.];
	} else if( _status != MVChatConnectionSuspendedStatus ) {
		_status = MVChatConnectionDisconnectedStatus;
	}

	[super _didDisconnect];

	[self _setSilcConn:NULL];
}

@end
