#import "MVSILCChatConnection.h"
#import "MVSILCChatRoom.h"
#import "MVSILCChatUser.h"
#import "MVFileTransfer.h"
#import "MVChatPluginManager.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "NSDataAdditions.h"

static SilcPKCS silcPkcs;
static SilcPublicKey silcPublicKey;
static SilcPrivateKey silcPrivateKey;

NSString *MVSILCChatConnectionLoadedCertificate = @"MVSILCChatConnectionLoadedCertificate";

static const NSStringEncoding supportedEncodings[] = {
	NSUTF8StringEncoding, 0
};

void silc_channel_get_clients_per_list_callback( SilcClient client, SilcClientConnection conn, SilcClientEntry *clients, SilcUInt32 clients_count, void *context ) {
	MVSILCChatRoom *room = context;
	MVSILCChatConnection *self = (MVSILCChatConnection *)[room connection];

	SilcChannelEntry channel = silc_client_get_channel( [self _silcClient], [self _silcConn], (char *) [[room name] UTF8String]);

	unsigned int i = 0;
	for( i = 0; i < clients_count; i++ ) {
		MVChatUser *member = [self _chatUserWithClientEntry:clients[i]];

		[room _addMemberUser:member];

		SilcChannelUser channelUser = silc_client_on_channel( channel, clients[i] );
		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANOP )
			[room _setMode:MVChatRoomMemberOperatorMode forMemberUser:member];

		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANFO )
			[room _setMode:MVChatRoomMemberFounderMode forMemberUser:member];

		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_QUIET )
			[room _setMode:MVChatRoomMemberQuietedMode forMemberUser:member];

		if( clients[i] -> mode & SILC_UMODE_SERVER_OPERATOR || clients[i] -> mode & SILC_UMODE_ROUTER_OPERATOR )
			[member _setServerOperator:YES];
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomJoinedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_say( SilcClient client, SilcClientConnection conn, SilcClientMessageType type, char *msg, ... ) {
	MVSILCChatConnection *self = conn -> context;
	if( msg ) {
		NSString *msgString = [NSString stringWithUTF8String:msg];
		NSNotification *rawMessageNote = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:rawMessageNote];
	}
}

static void silc_channel_message( SilcClient client, SilcClientConnection conn, SilcClientEntry sender, SilcChannelEntry channel, SilcMessagePayload payload, SilcChannelPrivateKey key, SilcMessageFlags flags, const unsigned char *message, SilcUInt32 message_len ) {
	MVSILCChatConnection *self = conn -> context;

	BOOL action = NO;
	if( flags & SILC_MESSAGE_FLAG_ACTION ) action = YES;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
	MVChatUser *user = [self _chatUserWithClientEntry:sender];
	NSString *mimeType = @"text/plain";
	NSData *msgData = nil;

	if( flags & SILC_MESSAGE_FLAG_DATA ) { // MIME object received
		char type[128], enc[128];
		unsigned char *data = NULL;
		SilcUInt32 data_len = 0;

		memset( type, 0, sizeof( type ) );
		memset( enc, 0, sizeof( enc ) );
		if( silc_mime_parse( message, message_len, NULL, 0, type, sizeof( type ) - 1, enc, sizeof( enc ) - 1, &data, &data_len ) ) {
			if( strstr( enc, "base64" ) ) {
				NSString *body = [[[NSString alloc] initWithBytes:data length:data_len encoding:NSASCIIStringEncoding] autorelease];
				msgData = [[[NSData alloc] initWithBase64EncodedString:body] autorelease];
			} else msgData = [[[NSData alloc] initWithBytes:data length:data_len] autorelease];
			mimeType = [NSString stringWithBytes:type encoding:NSASCIIStringEncoding];
		}
	}

	if( ! msgData ) msgData = [NSData dataWithBytes:message length:message_len];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", msgData, @"message", mimeType, @"mimeType", [NSNumber numberWithBool:action], @"action", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_private_message( SilcClient client, SilcClientConnection conn, SilcClientEntry sender, SilcMessagePayload payload, SilcMessageFlags flags, const unsigned char *message, SilcUInt32 message_len ) {
	MVSILCChatConnection *self = conn -> context;

	BOOL action = NO;
	if( flags & SILC_MESSAGE_FLAG_ACTION ) action = YES;

	MVChatUser *user = [self _chatUserWithClientEntry:sender];
	NSString *mimeType = @"text/plain";
	NSData *msgData = nil;

	if( flags & SILC_MESSAGE_FLAG_DATA ) { // MIME object received
		char type[128], enc[128];
		unsigned char *data = NULL;
		SilcUInt32 data_len = 0;

		memset( type, 0, sizeof( type ) );
		memset( enc, 0, sizeof( enc ) );
		if( silc_mime_parse( message, message_len, NULL, 0, type, sizeof( type ) - 1, enc, sizeof( enc ) - 1, &data, &data_len ) ) {
			if( strstr( enc, "base64" ) ) {
				NSString *body = [[[NSString alloc] initWithBytes:data length:data_len encoding:NSASCIIStringEncoding] autorelease];
				msgData = [[[NSData alloc] initWithBase64EncodedString:body] autorelease];
			} else msgData = [[[NSData alloc] initWithBytes:data length:data_len] autorelease];
			mimeType = [NSString stringWithBytes:type encoding:NSASCIIStringEncoding];
		}
	}

	if( ! msgData ) msgData = [NSData dataWithBytes:message length:message_len];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", mimeType, @"mimeType", [NSNumber numberWithBool:action], @"action", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_notify( SilcClient client, SilcClientConnection conn, SilcNotifyType type, ... ) {
	va_list list;
	MVSILCChatConnection *self = conn -> context;

	va_start( list, type );

	switch( type ) {
		case SILC_NOTIFY_TYPE_MOTD: {
			char *message = va_arg( list, char * );
			if( message ) {
				NSString *msgString = [NSString stringWithUTF8String:message];
				NSNotification *rawMessageNote = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:rawMessageNote];
			}
		}	break;
		case SILC_NOTIFY_TYPE_NONE: {
			char *message = va_arg( list, char * );
			if( message ) {
				NSString *msgString = [NSString stringWithUTF8String:message];
				NSNotification *rawMessageNote = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:rawMessageNote];
			}
		}	break;
		case SILC_NOTIFY_TYPE_SIGNOFF: {
			SilcClientEntry signoff_client = va_arg( list, SilcClientEntry );
			char *signoff_message = va_arg( list, char * );

			MVChatUser *member = [self _chatUserWithClientEntry:signoff_client];
			NSData *reasonData = ( signoff_message ? [NSData dataWithBytes:signoff_message length:strlen( signoff_message )] : nil );
			NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
			MVChatRoom *room = nil;

			[member _setDateDisconnected:[NSDate date]];

			while( ( room = [enumerator nextObject] ) ) {
				if( ! [room isJoined] || ! [room hasUser:member] ) continue;
				[room _removeMemberUser:member];
				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			}
		}	break;
		case SILC_NOTIFY_TYPE_NICK_CHANGE: {
			SilcClientEntry oldclient = va_arg( list, SilcClientEntry );
			SilcClientEntry newclient = va_arg( list, SilcClientEntry );

			NSString *oldNickname = [NSString stringWithUTF8String:oldclient -> nickname];
			MVChatUser *user = [self _chatUserWithClientEntry:oldclient];
			[self _updateKnownUser:user withClientEntry:newclient];

			NSNotification *note = [NSNotification notificationWithName:MVChatUserNicknameChangedNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldNickname, @"oldNickname", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}	break;
		case SILC_NOTIFY_TYPE_SERVER_SIGNOFF: {
			va_arg( list, void * );
			SilcClientEntry *clients = va_arg( list, SilcClientEntry * );
			SilcUInt32 clients_count = va_arg( list, int );

			if( ! clients ) break;

			const char *reason = "Server signoff";
			NSData *reasonData = [NSData dataWithBytes:reason length:strlen( reason )];

			unsigned int i = 0;
			for( i = 0; i < clients_count; i++ ) {
				SilcClientEntry signoff_client = clients[i];

				MVChatUser *member = [self _chatUserWithClientEntry:signoff_client];
				NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
				MVChatRoom *room = nil;

				while( ( room = [enumerator nextObject] ) ) {
					if( ! [room isJoined] || ! [room hasUser:member] ) continue;
					[room _removeMemberUser:member];
					NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil]];
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
				}
			}

		}	break;
		case SILC_NOTIFY_TYPE_WATCH:
			break;
		case SILC_NOTIFY_TYPE_JOIN: {
			SilcClientEntry joining_client = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );

			if( ! joining_client || ! channel ) break;

			// we send a notification that we joined the channel in the COMMAND callback, no need to do it here too.
			if( joining_client == conn -> local_entry ) break;

			MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
			MVChatUser *member = [self _chatUserWithClientEntry:joining_client];

			[member _setDateDisconnected:nil];
			[room _addMemberUser:member];

			SilcChannelUser channelUser = silc_client_on_channel( channel, joining_client );
			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANOP )
				[room _setMode:MVChatRoomMemberOperatorMode forMemberUser:member];

			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANFO )
				[room _setMode:MVChatRoomMemberFounderMode forMemberUser:member];

			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_QUIET )
				[room _setMode:MVChatRoomMemberQuietedMode forMemberUser:member];

			if( joining_client -> mode & SILC_UMODE_SERVER_OPERATOR || joining_client -> mode & SILC_UMODE_ROUTER_OPERATOR )
				[member _setServerOperator:YES];

			NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserJoinedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}	break;
		case SILC_NOTIFY_TYPE_LEAVE: {
			SilcClientEntry leaving_client = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );
			
			if( ! leaving_client || ! channel ) break;

			MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
			MVChatUser *member = [self _chatUserWithClientEntry:leaving_client];

			[room _removeMemberUser:member];

			NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", nil]];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}	break;
		case SILC_NOTIFY_TYPE_TOPIC_SET: {
			SilcIdType setter_id_type = va_arg( list, int );
			void *setter_entry = va_arg( list, void * );
			char *topic = va_arg( list, char * );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );

			if( ! setter_entry || ! channel ) break;

			MVChatUser *authorUser = nil;
			if( setter_id_type == SILC_ID_CLIENT )
				authorUser = [self _chatUserWithClientEntry:(SilcClientEntry)setter_entry];

			MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
			NSData *msgData = ( topic ? [NSData dataWithBytes:topic length:strlen( topic )] : nil );
			[room _setTopic:msgData byAuthor:authorUser withDate:[NSDate date]];

			NSNotification *note = [NSNotification notificationWithName:MVChatRoomTopicChangedNotification object:room userInfo:nil];
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

			if( ! changer_entry || ! target_client || ! channel ) break;

			MVChatUser *changerUser = nil;
			if( changer_id_type == SILC_ID_CLIENT )
				changerUser = [self _chatUserWithClientEntry:(SilcClientEntry)changer_entry];

			MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
			MVChatUser *member = [self _chatUserWithClientEntry:target_client];

			BOOL enabled = NO;
			unsigned int m = MVChatRoomMemberNoModes;
			unsigned int oldModes = [room modesForMemberUser:member];

			if( ( oldModes & MVChatRoomMemberFounderMode ) && ! ( mode & SILC_CHANNEL_UMODE_CHANFO ) ) {
				enabled = NO;
				m = MVChatRoomMemberFounderMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", changerUser, @"by", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			} else if( ! ( oldModes & MVChatRoomMemberFounderMode ) && ( mode & SILC_CHANNEL_UMODE_CHANFO ) ) {
				enabled = YES;
				m = MVChatRoomMemberFounderMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", changerUser, @"by", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			}

			if( ( oldModes & MVChatRoomMemberOperatorMode ) && ! ( mode & SILC_CHANNEL_UMODE_CHANOP ) ) {
				enabled = NO;
				m = MVChatRoomMemberOperatorMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", changerUser, @"by", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			} else if( ! ( oldModes & MVChatRoomMemberOperatorMode ) && ( mode & SILC_CHANNEL_UMODE_CHANOP ) ) {
				enabled = YES;
				m = MVChatRoomMemberOperatorMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", changerUser, @"by", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			}

			if( ( oldModes & MVChatRoomMemberQuietedMode ) && ! ( mode & SILC_CHANNEL_UMODE_QUIET ) ) {
				enabled = NO;
				m = MVChatRoomMemberQuietedMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", changerUser, @"by", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			} else if( ! ( oldModes & MVChatRoomMemberQuietedMode ) && ( mode & SILC_CHANNEL_UMODE_QUIET ) ) {
				enabled = YES;
				m = MVChatRoomMemberQuietedMode;

				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", changerUser, @"by", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			}
		}	break;
		case SILC_NOTIFY_TYPE_CHANNEL_CHANGE:
			break;
		case SILC_NOTIFY_TYPE_KICKED: {
			SilcClientEntry kicked = va_arg( list, SilcClientEntry );
			char *kick_message = va_arg( list, char * );
			SilcClientEntry kicker = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );

			if( ! kicked || ! kicker || ! channel ) break;

			NSData *msgData = ( kick_message ? [NSData dataWithBytes:kick_message length:strlen( kick_message )] : nil );
			NSNotification *note = nil;

			MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
			MVChatUser *member = [self _chatUserWithClientEntry:kicked];
			MVChatUser *byMember = [self _chatUserWithClientEntry:kicker];
			[room _removeMemberUser:member];

			if( kicked == conn -> local_entry ) {
				note = [NSNotification notificationWithName:MVChatRoomKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:byMember, @"byUser", msgData, @"reason", nil]];		
			} else {
				note = [NSNotification notificationWithName:MVChatRoomUserKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", byMember, @"byUser", msgData, @"reason", nil]];
			}

			[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		}	break;
		case SILC_NOTIFY_TYPE_KILLED: {
			SilcClientEntry killed = va_arg( list, SilcClientEntry );
			char *kill_message = va_arg( list, char * );
			SilcIdType killer_type = va_arg( list, int );
			void *killer = va_arg( list, void * );

			if( ! killed || ! killer ) break;

			SilcClientEntry client_killer = NULL;
			SilcChannelEntry channel_killer = NULL;
			SilcServerEntry server_killer = NULL;

			NSString *killerNickname = nil;
			switch( killer_type ) {
			case SILC_ID_CLIENT:
				client_killer = killer;
				if( ! client_killer -> nickname ) killerNickname = @"Unknown user";
				else killerNickname = [NSString stringWithUTF8String:client_killer -> nickname];
				break;
			case SILC_ID_CHANNEL:
				channel_killer = killer;
				if( ! channel_killer -> channel_name ) killerNickname = @"Unknown chat room";
				else killerNickname = [NSString stringWithUTF8String:channel_killer -> channel_name];
				break;
			case SILC_ID_SERVER:
				server_killer = killer;
				if( ! server_killer -> server_name ) killerNickname = @"Unknown server";
				else killerNickname = [NSString stringWithUTF8String:server_killer -> server_name];
				break;
			default:
				killerNickname = @"Unknown";
			}

			if( ! kill_message ) kill_message = "";
			NSString *killMessage = [NSString stringWithUTF8String:kill_message];

			NSString *quitReason = [NSString stringWithFormat:@"Killed by %@ (%@)", killerNickname, killMessage];
			const char *quitReasonString = [quitReason UTF8String];

			NSData *reasonData = [NSData dataWithBytes:quitReasonString length:strlen( quitReasonString )];
			MVChatUser *member = [self _chatUserWithClientEntry:killed];
			NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
			MVChatRoom *room = nil;

			[member _setDateDisconnected:[NSDate date]];

			while( ( room = [enumerator nextObject] ) ) {
				if( ! [room isJoined] || ! [room hasUser:member] ) continue;
				[room _removeMemberUser:member];
				NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil]];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
			}
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
			if( channel && channel -> channel_name ) channelName = [NSString stringWithUTF8String:channel -> channel_name];
			if( ! channelName && channel_name ) channelName = [NSString stringWithUTF8String:channel_name];
			if( ! channelName ) break;

			MVChatUser *user = [self _chatUserWithClientEntry:inviter];
			NSNotification *note = [NSNotification notificationWithName:MVChatRoomInvitedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", channelName, @"room", nil]];		
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
	if( ! rawCommand ) rawCommand = @"Unknown command";
	
	if( ! success ) {
		char *error_message = (char *)silc_get_status_message( status );
		if( error_message ) {
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
		/* char *nickname = */ va_arg( list, char * );
		/* char *username = */ va_arg( list, char * );
		/* char *realname = */ va_arg( list, char * );
		SilcBuffer channels = va_arg( list, SilcBuffer );
		/* SilcUInt32 usermode = */ va_arg( list, int );
		SilcUInt32 idletime = va_arg( list, int );
		/* unsigned char *fingerprint = */ va_arg( list, unsigned char * );
		/* SilcBuffer user_modes = */ va_arg( list, SilcBuffer );
		/* SilcDList attrs = */ va_arg( list, SilcDList );

		MVSILCChatUser *user = (MVSILCChatUser *)[self _chatUserWithClientEntry:client_entry];
		[user updateWithClientEntry:client_entry];
		[user _setIdleTime:idletime];
		[user _setDateDisconnected:nil];

		if( channels ) {
			NSMutableArray *chanArray = [NSMutableArray array];
			SilcDList list = silc_channel_payload_parse_list( channels -> data, channels -> len );
			if( list ) {
				silc_dlist_start( list );

				SilcChannelPayload entry = NULL;
				while( ( entry = silc_dlist_get( list ) ) != SILC_LIST_END ) {
					SilcUInt32 name_len = 0;
					char *name = silc_channel_get_name( entry, &name_len );
					[chanArray addObject:[NSString stringWithCharacters:(const unichar *)name length:name_len]];
				}

				silc_channel_payload_list_free( list );
				//	store this info in MVChatUserKnownRoomsAttribute
			}
		}

		NSNotification *note = [NSNotification notificationWithName:MVChatUserInformationUpdatedNotification object:user userInfo:nil];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
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
		/* char *channel_name = */ va_arg( list, char * );
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

		MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
		if( ! room ) {
			room = [[[MVSILCChatRoom allocWithZone:[self zone]] initWithChannelEntry:channel andConnection:self] autorelease];
			[self _addJoinedRoom:room];
		}

		[room _setDateJoined:[NSDate date]];
		[room _setDateParted:nil];
		[room _clearMemberUsers];
		[room _clearBannedUsers];

		if( ! topic ) topic = "";

		NSData *msgData = [NSData dataWithBytes:topic length:strlen( topic )];
		[room _setTopic:msgData byAuthor:nil withDate:nil];

		silc_client_get_clients_by_list( [self _silcClient], [self _silcConn], list_count, client_id_list, silc_channel_get_clients_per_list_callback, room );
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
		MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> channel_name]];
		[room _setDateParted:[NSDate date]];
		NSNotification *note = [NSNotification notificationWithName:MVChatRoomPartedNotification object:room userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
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
		[[self _silcClientLock] unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
		[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:YES];
		[[self _silcClientLock] lock]; // lock back up like nothing happened
		
		@synchronized( [self _queuedCommands] ) {
			NSEnumerator *enumerator = [[self _queuedCommands] objectEnumerator];
			NSString *command = nil;

			while( ( command = [enumerator nextObject] ) )
				[self sendRawMessage:command];

			[[self _queuedCommands] removeAllObjects];
		}
	} else {
		silc_client_close_connection( client, conn );
		[[self _silcClientLock] unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
		[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:YES];
		[[self _silcClientLock] lock]; // lock back up like nothing happened
	}
}

static void silc_disconnected( SilcClient client, SilcClientConnection conn, SilcStatus status, const char *message ) {
	MVSILCChatConnection *self = conn -> context;
	[[self _silcClientLock] unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:YES];
	[[self _silcClientLock] lock]; // lock back up like nothing happened
}

static void silc_get_auth_method( SilcClient client, SilcClientConnection conn, char *hostname, SilcUInt16 port, SilcGetAuthMeth completion, void *context ) {
	completion( TRUE, SILC_AUTH_NONE, NULL, 0, context );
}

static void silc_verify_public_key( SilcClient client, SilcClientConnection conn, SilcSocketType conn_type, unsigned char *pk, SilcUInt32 pk_len, SilcSKEPKType pk_type, SilcVerifyPublicKey completion, void *context ) {
	MVSILCChatConnection *self = conn -> context;

	char *tmp;
	
	tmp = silc_hash_fingerprint( NULL, pk, pk_len );
	NSString *asciiFingerprint = [NSString stringWithUTF8String:tmp];
	silc_free( tmp );
	
	tmp = silc_hash_babbleprint( NULL, pk, pk_len );
	NSString *asciiBabbleprint = [NSString stringWithUTF8String:tmp];
	silc_free(tmp);
	
	NSString *filename = NULL;
	MVChatConnectionPublicKeyType publicKeyType = MVChatConnectionClientPublicKeyType;
	
	switch ( conn_type ) {
		case SILC_SOCKET_TYPE_UNKNOWN:
			completion( FALSE, context );
			return;
			
		case SILC_SOCKET_TYPE_CLIENT:
			publicKeyType = MVChatConnectionClientPublicKeyType;
			break;
			
		case SILC_SOCKET_TYPE_SERVER:
		case SILC_SOCKET_TYPE_ROUTER:
			publicKeyType = MVChatConnectionServerPublicKeyType;
			break;
	}
	
	filename = [self _publicKeyFilename:conn_type andPublicKey:pk withLen:pk_len usingSilcConn:conn];
	
	BOOL needVerify = YES;
	
	if ( [[NSFileManager defaultManager] fileExistsAtPath:filename] ) {
		SilcPublicKey publicKey = NULL;
		unsigned char *encodedPublicKey;
		SilcUInt32 encodedPublicKeyLen;
		
		if ( silc_pkcs_load_public_key( [filename fileSystemRepresentation], &publicKey, SILC_PKCS_FILE_PEM ) ||
			 silc_pkcs_load_public_key( [filename fileSystemRepresentation], &publicKey, SILC_PKCS_FILE_BIN ) ) {
			encodedPublicKey = silc_pkcs_public_key_encode( publicKey, &encodedPublicKeyLen );
			if ( encodedPublicKey ) {
				if ( ! memcmp( encodedPublicKey, pk, encodedPublicKeyLen ) ) {
					needVerify = NO;
				}
				
				silc_free( encodedPublicKey );
			}
			
			silc_pkcs_public_key_free( publicKey );
		}
	}

	if ( ! needVerify ) {
		completion( TRUE, context );
		return;
	}
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[dict setObject:[NSNumber numberWithUnsignedInt:publicKeyType] forKey:@"publicKeyType"];
	[dict setObject:asciiFingerprint forKey:@"fingerprint"];
	[dict setObject:asciiBabbleprint forKey:@"babbleprint"];
	
	if ( conn_type == SILC_SOCKET_TYPE_SERVER || conn_type == SILC_SOCKET_TYPE_ROUTER ) {
		if ( conn -> sock -> hostname && strlen( conn -> sock -> hostname ) ) {
			[dict setObject:[NSString stringWithUTF8String:conn -> sock -> hostname] forKey:@"name"];
		} else if ( conn -> sock -> ip && strlen( conn -> sock -> ip ) ) {
			[dict setObject:[NSString stringWithUTF8String:conn -> sock -> ip] forKey:@"name"];
		} else {
			[dict setObject:@"unknown server" forKey:@"name"];
		}
	} else if ( conn_type == SILC_SOCKET_TYPE_CLIENT ) {
		[dict setObject:@"unknown user" forKey:@"name"];
	}
	
	[dict setObject:[NSNumber numberWithUnsignedInt:SILC_PTR_TO_32(completion)] forKey:@"completition"];
	[dict setObject:[NSNumber numberWithUnsignedInt:SILC_PTR_TO_32(context)] forKey:@"completitionContext"];
	[dict setObject:self forKey:@"connection"];
	[dict setObject:[NSData dataWithBytes:pk length:pk_len] forKey:@"pk"];
	[dict setObject:[NSNumber numberWithUnsignedInt:conn_type] forKey:@"connType"];
	[dict setObject:[NSNumber numberWithUnsignedInt:SILC_PTR_TO_32(conn)] forKey:@"silcConn"];
	
	// we release it in the verfied callback
	[dict retain];
	
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNeedPublicKeyVerificationNotification object:dict userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void silc_ask_passphrase( SilcClient client, SilcClientConnection conn, SilcAskPassphrase completion, void *context ) {
}

static void silc_failure( SilcClient client, SilcClientConnection conn, SilcProtocol protocol, void *failure ) {
}

static bool silc_key_agreement( SilcClient client, SilcClientConnection conn, SilcClientEntry client_entry, const char *hostname, SilcUInt16 port, SilcKeyAgreementCallback *completion, void **context) {
#if 0
	if ( hostname ) {
		silc_client_perform_key_agreement( client, conn, client_entry, hostname, port, silcgaim_buddy_keyagr_cb, ai );
	} else {
		// other user didn't supply hostname - we need to make the connection
		NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
		NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
		NSMutableData *result = [[[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL] mutableCopy] autorelease];
		[result appendBytes:"\0" length:1];
		
		silc_client_send_key_agreement( client, conn, client_entry, [result bytes], NULL, 0, 60, silcgaim_buddy_keyagr_cb, a );
	}
#endif
	
	return FALSE;
}

static void silc_ftp( SilcClient client, SilcClientConnection conn, SilcClientEntry client_entry, SilcUInt32 session_id, const char *hostname, SilcUInt16 port ) {
/*	MVSILCChatConnection *self = conn -> context;
	
	MVChatUser *user = [self _chatUserWithClientEntry:client_entry];
	MVSILCDownloadFileTransfer *transfer = [[[MVSILCDownloadFileTransfer alloc] initWithSessionID:session_id toUser:user]
	NSNotification *note = [NSNotification notificationWithName:MVDownloadFileTransferOfferNotification object:transfer];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note]; */
}

static void silc_detach( SilcClient client, SilcClientConnection conn, const unsigned char *detach_data, SilcUInt32 detach_data_len ) {
	MVSILCChatConnection *self = conn -> context;
	[self _setDetachInfo:[NSData dataWithBytes:detach_data length:detach_data_len]];
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

+ (NSArray *) defaultServerPorts {
	return [NSArray arrayWithObject:[NSNumber numberWithUnsignedShort:706]];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_encoding = NSUTF8StringEncoding; // the only encoding we support

		memset( &_silcClientParams, 0, sizeof( _silcClientParams ) );

		_silcClientLock = [[NSRecursiveLock alloc] init];
		_silcClient = silc_client_alloc( &silcClientOps, &_silcClientParams, self, NULL );
		if( ! _silcClient) {
			// we need some error handling here.. silc conenction CAN'T work without silc client
			[self release];
			return nil;
		}

		[self setUsername:NSUserName()];
		[self setRealName:NSFullUserName()];

		_knownUsers = [[NSMutableDictionary dictionaryWithCapacity:200] retain];
		_queuedCommands = [[NSMutableArray arrayWithCapacity:5] retain];
		_sentCommands = [[NSMutableDictionary dictionaryWithCapacity:2] retain];
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

	[_queuedCommands release];
	_queuedCommands = nil;

	[_sentCommands release];
	_sentCommands = nil;

	[_knownUsers release];
	_knownUsers = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatConnectionType) type {
	return MVChatConnectionSILCType;
}

- (NSSet *) supportedFeatures {
	return nil;
}

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

#pragma mark -

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

	NSData *detachInfo = [[self persistentInformation] objectForKey:@"detachData"];
	SilcClientConnectionParams params;
	memset( &params, 0, sizeof( params ) );
	params.detach_data = ( detachInfo ? (unsigned char *)[detachInfo bytes] : NULL );
	params.detach_data_len = ( detachInfo ? [detachInfo length] : 0 );

	[_silcClientLock lock];
	if( silc_client_connect_to_server( [self _silcClient], &params, [self serverPort], (char *) [[self server] UTF8String], self ) == -1 )
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
		const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:reason];
		[self sendRawMessageWithFormat:@"QUIT %s", msg];
	} else {
		[self sendRawMessage:@"QUIT"];
	}
}

#pragma mark -

- (NSString *) urlScheme {
	return @"silc";
}

#pragma mark -

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
	if( [self isConnected] && [self _silcConn] && [self _silcConn] -> nickname )
		return [NSString stringWithUTF8String:[self _silcConn] -> nickname];

	return [NSString stringWithUTF8String:_silcClient -> nickname];
}

- (NSString *) preferredNickname {
	return [NSString stringWithUTF8String:_silcClient -> nickname];
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

- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept {
	SilcVerifyPublicKey completition;
	void *context;
	SilcClientConnection conn;
	
	completition = SILC_32_TO_PTR([[dictionary objectForKey:@"completition"] unsignedIntValue]);
	context = SILC_32_TO_PTR([[dictionary objectForKey:@"completitionContext"] unsignedIntValue]);
	conn = SILC_32_TO_PTR([[dictionary objectForKey:@"silcConn"] unsignedIntValue]);
	
	if ( accepted ) {
		completition( TRUE, context );
	} else {
		completition( FALSE, context );
	}
	
	if ( alwaysAccept ) {
		NSData *pk = [dictionary objectForKey:@"pk"];
		NSString *filename = [self _publicKeyFilename:[[dictionary objectForKey:@"connType"] unsignedIntValue] andPublicKey:(unsigned char *)[pk bytes] withLen:[pk length] usingSilcConn:conn];
		silc_pkcs_save_public_key_data( [filename fileSystemRepresentation], (unsigned char *)[pk bytes], [pk length], SILC_PKCS_FILE_PEM);
	}
	
	[dictionary release];
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );

	if( ! [self isConnected] ) {
		@synchronized( _queuedCommands ) {
			[_queuedCommands addObject:raw];
		} return;
	}

	[[self _silcClientLock] lock];
	bool b = silc_client_command_call( [self _silcClient], [self _silcConn], [raw UTF8String] );
	if( b ) [self _addCommand:raw forNumber:[self _silcConn] -> cmd_ident];
	[[self _silcClientLock] unlock];

	if( ! b ) [self _sendCommandFailedNotify:raw];
}

#pragma mark -

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	if( [passphrase length] ) [self sendRawMessageWithFormat:@"JOIN %@ %@", [self properNameForChatRoomNamed:room], passphrase];
	else [self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return nil;
}

#pragma mark -

- (NSSet *) chatUsersWithNickname:(NSString *) nickname {
	// do silc_client_get_clients_local first, then if no local matches
	// do a silc_client_get_clients_whois on another thread and wait for the callback to return
	return nil;
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSData class]] );

	if( [identifier isEqualToData:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:identifier];
		if( user ) return [[user retain] autorelease];

		SilcClientID *clientID = silc_id_str2id( [(NSData *)identifier bytes], [(NSData *)identifier length], SILC_ID_CLIENT );
		if( clientID ) {
			[[self _silcClientLock] lock];
			SilcClientEntry client = silc_client_get_client_by_id( [self _silcClient], [self _silcConn], clientID );
			[[self _silcClientLock] unlock];
			if( client ) {
				user = [[[MVSILCChatUser allocWithZone:[self zone]] initWithClientEntry:client andConnection:self] autorelease];
				[_knownUsers setObject:user forKey:identifier];
			}
		}
	}

	return [[user retain] autorelease];
}

#pragma mark -

- (void) addUserToNotificationList:(MVChatUser *) user {
}

- (void) removeUserFromNotificationList:(MVChatUser *) user {
}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 900. ) {
		[self sendRawMessage:@"LIST"];
		[_cachedDate autorelease];
		_cachedDate = [[NSDate date] retain];
	}
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

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	} else {
		[self sendRawMessage:@"UMODE -g"];

		[[self _silcClientLock] lock];
		silc_client_set_away_message( [self _silcClient], [self _silcConn], NULL );
		[[self _silcClientLock] unlock];
		
		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
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
	[[self _silcClientLock] lock];
	_silcConn = aSilcConn;
	[[self _silcClientLock] unlock];
}

- (SilcClientConnection) _silcConn {
	return _silcConn;
}

#pragma mark -

- (SilcClientParams *) _silcClientParams {
	return &_silcClientParams;
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

#pragma mark -

- (NSMutableArray *) _queuedCommands {
	return _queuedCommands;
}

- (NSMutableDictionary *) _sentCommands {
	return _sentCommands;
}

#pragma mark -

- (void) _setDetachInfo:(NSData *) info {
	@synchronized( _persistentInformation ) {
		if( info ) [_persistentInformation setObject:info forKey:@"detachData"];
		else [_persistentInformation removeObjectForKey:@"detachData"];
	}
}

#pragma mark -

- (void) _addCommand:(NSString *) raw forNumber:(SilcUInt16) cmd_ident {
	@synchronized( _sentCommands ) {
		[_sentCommands setObject:raw forKey:[NSNumber numberWithUnsignedShort:cmd_ident]];
	}
}

- (NSString *) _getCommandForNumber:(SilcUInt16) cmd_ident {
	NSNumber *number = [NSNumber numberWithUnsignedShort:cmd_ident];
	NSString *string = nil;

	@synchronized( _sentCommands ) {
		string = [[_sentCommands objectForKey:number] retain];
		[_sentCommands removeObjectForKey:number];
	}

	return [string autorelease];
}

#pragma mark -

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

- (void) _didConnect {
	[_localUser release];
	_localUser = [[MVSILCChatUser allocWithZone:[self zone]] initLocalUserWithConnection:self];

	[self _setDetachInfo:nil];

	[super _didConnect];
}

- (void) _didNotConnect {
	[self _setSilcConn:NULL];
	[self _setDetachInfo:nil];
	[super _didNotConnect];
}

- (void) _didDisconnect {
	if( ! _sentQuitCommand || ! [[self persistentInformation] objectForKey:@"detachData"] ) {
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

- (void) _systemWillSleep:(NSNotification *) notification {
	if( [self isConnected] ) {
		[self sendRawMessage:@"DETACH"];
		_status = MVChatConnectionSuspendedStatus;
		usleep( 2500000 );
	}
}

#pragma mark -

- (MVChatUser *) _chatUserWithClientEntry:(SilcClientEntry) clientEntry  {
	NSParameterAssert( clientEntry != NULL );

	unsigned char *identifier = silc_id_id2str( clientEntry -> id, SILC_ID_CLIENT );
	unsigned len = silc_id_get_len( clientEntry -> id, SILC_ID_CLIENT );
	NSData *uniqueIdentfier = [NSData dataWithBytes:identifier length:len];

	if( [uniqueIdentfier isEqualToData:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:uniqueIdentfier];
		if( user ) return [[user retain] autorelease];

		user = [[[MVSILCChatUser allocWithZone:[self zone]] initWithClientEntry:clientEntry andConnection:self] autorelease];
		[_knownUsers setObject:user forKey:uniqueIdentfier];
	}

	return [[user retain] autorelease];
}

- (void) _updateKnownUser:(MVChatUser *) user withClientEntry:(SilcClientEntry) clientEntry {
	NSParameterAssert( user != nil );
	NSParameterAssert( clientEntry != NULL );

	unsigned char *identifier = silc_id_id2str( clientEntry -> id, SILC_ID_CLIENT );
	unsigned len = silc_id_get_len( clientEntry -> id, SILC_ID_CLIENT );
	NSData *uniqueIdentfier = [NSData dataWithBytes:identifier length:len];

	@synchronized( _knownUsers ) {
		[user retain];
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:uniqueIdentfier];
		[user _setNickname:[NSString stringWithUTF8String:clientEntry -> nickname]];
		[_knownUsers setObject:user forKey:uniqueIdentfier];
		[user release];
	}
}

- (NSString *) _publicKeyFilename:(SilcSocketType) connType andPublicKey:(unsigned char *) pk withLen:(SilcUInt32) pkLen usingSilcConn:(SilcClientConnection) conn {
	NSString *filename = NULL;
	
	switch ( connType ) {
		case SILC_SOCKET_TYPE_UNKNOWN:
			return nil;
			
		case SILC_SOCKET_TYPE_CLIENT: {
			char *tmp;
			tmp = silc_hash_fingerprint( NULL, pk, pkLen );
			NSString *asciiFingerprint = [NSString stringWithUTF8String:tmp];
			silc_free( tmp );
			
			filename = [NSString stringWithFormat:@"%@/%@.pub", [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Silc/Client Keys/"] stringByExpandingTildeInPath], asciiFingerprint];
		}	break;
			
		case SILC_SOCKET_TYPE_SERVER:
		case SILC_SOCKET_TYPE_ROUTER: {
			NSString *host;
			
			if ( conn -> sock -> hostname && strlen( conn -> sock -> hostname ) ) {
				host = [NSString stringWithUTF8String:conn -> sock -> hostname];
			} else if ( conn -> sock -> ip && strlen( conn -> sock -> ip ) ) {
				host = [NSString stringWithUTF8String:conn -> sock -> ip];
			} else {
				char *tmp;
				tmp = silc_hash_fingerprint( NULL, pk, pkLen );
				host = [NSString stringWithUTF8String:tmp];
				silc_free( tmp );
			}
			
			filename = [NSString stringWithFormat:@"%@/%@.pub", [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Silc/Server Keys/"] stringByExpandingTildeInPath], host];
		}	break;
	}
	
	return filename;
}
@end