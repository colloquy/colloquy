#import "MVSILCChatConnection.h"
#import "MVSILCChatRoom.h"
#import "MVSILCChatUser.h"
#import "MVFileTransfer.h"
#import "MVChatPluginManager.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "NSAttributedStringAdditions.h"
#import "NSDataAdditions.h"
#import "MVUtilities.h"
#import "MVChatString.h"

#if USE(ATTRIBUTED_CHAT_STRING)
#import "NSAttributedStringAdditions.h"
#endif

NS_ASSUME_NONNULL_BEGIN

static SilcPKCS silcPkcs;
static SilcPublicKey silcPublicKey;
static SilcPrivateKey silcPrivateKey;

NSString *MVSILCChatConnectionLoadedCertificate = @"MVSILCChatConnectionLoadedCertificate";

static const NSStringEncoding supportedEncodings[] = {
	NSUTF8StringEncoding, 0
};

static void silc_channel_get_clients_per_list_callback( SilcClient client, SilcClientConnection conn, SilcClientEntry *clients, SilcUInt32 clients_count, void *context ) {
	MVSILCChatRoom *room = (__bridge MVSILCChatRoom *)(context);
	MVSILCChatConnection *self = (MVSILCChatConnection *)[room connection];

	SilcChannelEntry channel = silc_client_get_channel( client, conn, (char *) [[room name] UTF8String]);

	NSUInteger i = 0;
	for( i = 0; i < clients_count; i++ ) {
		MVChatUser *member = [self _chatUserWithClientEntry:clients[i]];

		[self _markUserAsOnline:member];
		[room _addMemberUser:member];

		SilcChannelUser channelUser = silc_client_on_channel( channel, clients[i] );
		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANOP )
			[room _setMode:MVChatRoomMemberOperatorMode forMemberUser:member];

		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANFO )
			[room _setMode:MVChatRoomMemberFounderMode forMemberUser:member];

		if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_QUIET )
			[room _setDisciplineMode:MVChatRoomMemberDisciplineQuietedMode forMemberUser:member];

		if( clients[i] -> mode & SILC_UMODE_SERVER_OPERATOR || clients[i] -> mode & SILC_UMODE_ROUTER_OPERATOR )
			[member _setServerOperator:YES];
	}

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification object:room];
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomMemberUsersSyncedNotification object:room];
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomBannedUsersSyncedNotification object:room];
}

static void silc_say( SilcClient client, SilcClientConnection conn, SilcClientMessageType type, char *msg, ... ) {
	if( ! conn ) return;
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);
	if( msg ) {
	    va_list list;
		va_start( list, msg );

		NSString *tmp = [NSString stringWithUTF8String:msg];
		NSString *msgString = [[NSString alloc] initWithFormat:tmp arguments:list];
		va_end( list );

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
	}
}

static void silc_channel_message( SilcClient client, SilcClientConnection conn, SilcClientEntry sender, SilcChannelEntry channel, SilcMessagePayload payload, SilcChannelPrivateKey key, SilcMessageFlags flags, const unsigned char *message, SilcUInt32 message_len ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);

	BOOL action = NO;
	if( flags & SILC_MESSAGE_FLAG_ACTION ) action = YES;

	MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
	MVChatUser *user = [self _chatUserWithClientEntry:sender];
	NSString *mimeType = @"text/plain";
	NSData *msgData = nil;

	[self _markUserAsOnline:user];

	if( flags & SILC_MESSAGE_FLAG_DATA ) { // MIME object received
		char type[128], enc[128];
		unsigned char *data = NULL;
		SilcUInt32 data_len = 0;

		memset( type, 0, sizeof( type ) );
		memset( enc, 0, sizeof( enc ) );
		if( silc_mime_parse( message, message_len, NULL, 0, type, sizeof( type ) - 1, enc, sizeof( enc ) - 1, &data, &data_len ) ) {
			if( strstr( enc, "base64" ) ) {
				NSString *body = [[NSString allocWithZone:nil] initWithBytes:data length:data_len encoding:NSASCIIStringEncoding];
				msgData = [[NSData allocWithZone:nil] initWithBase64EncodedString:body];
			} else msgData = [[NSData allocWithZone:nil] initWithBytes:data length:data_len];

			mimeType = [[NSString allocWithZone:nil] initWithBytes:type length:strlen( type ) encoding:NSASCIIStringEncoding];
		}
	}

	if( ! msgData ) msgData = [[NSData allocWithZone:nil] initWithBytes:message length:message_len];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", msgData, @"message", [NSString locallyUniqueString], @"identifier", mimeType, @"mimeType", [NSNumber numberWithBool:action], @"action", nil]];
}

static void silc_private_message( SilcClient client, SilcClientConnection conn, SilcClientEntry sender, SilcMessagePayload payload, SilcMessageFlags flags, const unsigned char *message, SilcUInt32 message_len ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);

	BOOL action = NO;
	if( flags & SILC_MESSAGE_FLAG_ACTION ) action = YES;

	MVChatUser *user = [self _chatUserWithClientEntry:sender];
	NSString *mimeType = @"text/plain";
	NSData *msgData = nil;

	[self _markUserAsOnline:user];

	if( flags & SILC_MESSAGE_FLAG_DATA ) { // MIME object received
		char type[128], enc[128];
		unsigned char *data = NULL;
		SilcUInt32 data_len = 0;

		memset( type, 0, sizeof( type ) );
		memset( enc, 0, sizeof( enc ) );
		if( silc_mime_parse( message, message_len, NULL, 0, type, sizeof( type ) - 1, enc, sizeof( enc ) - 1, &data, &data_len ) ) {
			if( strstr( enc, "base64" ) ) {
				NSString *body = [[NSString allocWithZone:nil] initWithBytes:data length:data_len encoding:NSASCIIStringEncoding];
				msgData = [[NSData allocWithZone:nil] initWithBase64EncodedString:body];
			} else msgData = [[NSData allocWithZone:nil] initWithBytes:data length:data_len];

			mimeType = [[NSString allocWithZone:nil] initWithBytes:type length:strlen( type ) encoding:NSASCIIStringEncoding];
		}
	}

	if( ! msgData ) msgData = [[NSData allocWithZone:nil] initWithBytes:message length:message_len];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", [NSString locallyUniqueString], @"identifier", mimeType, @"mimeType", [NSNumber numberWithBool:action], @"action", nil]];
}

static void silc_notify( SilcClient client, SilcClientConnection conn, SilcNotifyType type, ... ) {
	va_list list;
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);

	va_start( list, type );

	switch( type ) {
		case SILC_NOTIFY_TYPE_MOTD: {
			char *message = va_arg( list, char * );
			if( message ) {
				NSString *msgString = [NSString stringWithUTF8String:message];
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
			}
		}	break;
		case SILC_NOTIFY_TYPE_NONE: {
			char *message = va_arg( list, char * );
			if( message ) {
				NSString *msgString = [NSString stringWithUTF8String:message];
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
			}
		}	break;
		case SILC_NOTIFY_TYPE_SIGNOFF: {
			SilcClientEntry signoff_client = va_arg( list, SilcClientEntry );
			char *signoff_message = va_arg( list, char * );

			MVChatUser *member = [self _chatUserWithClientEntry:signoff_client];
			NSData *reasonData = ( signoff_message ? [[NSData allocWithZone:nil] initWithBytes:signoff_message length:strlen( signoff_message )] : nil );

			[self _markUserAsOffline:member];

			NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil];
			for( MVChatRoom *room in [self joinedChatRooms] ) {
				if( ! [room isJoined] || ! [room hasUser:member] ) continue;
				[room _removeMemberUser:member];
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:info];
			}

		}	break;
		case SILC_NOTIFY_TYPE_NICK_CHANGE: {
			SilcClientEntry oldclient = va_arg( list, SilcClientEntry );
			SilcClientEntry newclient = va_arg( list, SilcClientEntry );

			NSString *oldNickname = [NSString stringWithUTF8String:oldclient -> nickname];
			MVChatUser *user = [self _chatUserWithClientEntry:oldclient];
			if( ! user ) break;

			NSData *oldIdentifier = [user uniqueIdentifier];

			[self _updateKnownUser:user withClientEntry:newclient];

			for( MVChatRoom *room in [self joinedChatRooms] ) {
				if( ! [room isJoined] || ! [room hasUser:user] ) continue;
				[room _updateMemberUser:user fromOldUniqueIdentifier:oldIdentifier];
			}

			// only client id changed, don't display nick change to user
			if ( [oldNickname isEqualToString:[NSString stringWithUTF8String:newclient -> nickname]] )
				break;

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserNicknameChangedNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldNickname, @"oldNickname", nil]];
		}	break;
		case SILC_NOTIFY_TYPE_SERVER_SIGNOFF: {
			va_arg( list, void * );
			SilcClientEntry *clients = va_arg( list, SilcClientEntry * );
			SilcUInt32 clients_count = va_arg( list, int );

			if( ! clients ) break;

			const char *reason = "Server signoff";
			NSData *reasonData = [[NSData allocWithZone:nil] initWithBytes:reason length:strlen( reason )];
			NSSet *joinedRooms = [self joinedChatRooms];

			NSUInteger i = 0;
			for( i = 0; i < clients_count; i++ ) {
				SilcClientEntry signoff_client = clients[i];

				MVChatUser *member = [self _chatUserWithClientEntry:signoff_client];
				NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil];

				[self _markUserAsOffline:member];

				for( MVChatRoom *room in joinedRooms ) {
					if( ! [room isJoined] || ! [room hasUser:member] ) continue;
					[room _removeMemberUser:member];
					[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:info];
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

			MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
			MVChatUser *member = [self _chatUserWithClientEntry:joining_client];

			[self _markUserAsOnline:member];
			[room _addMemberUser:member];

			SilcChannelUser channelUser = silc_client_on_channel( channel, joining_client );
			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANOP )
				[room _setMode:MVChatRoomMemberOperatorMode forMemberUser:member];

			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_CHANFO )
				[room _setMode:MVChatRoomMemberFounderMode forMemberUser:member];

			if( channelUser && channelUser -> mode & SILC_CHANNEL_UMODE_QUIET )
				[room _setDisciplineMode:MVChatRoomMemberDisciplineQuietedMode forMemberUser:member];

			if( joining_client -> mode & SILC_UMODE_SERVER_OPERATOR || joining_client -> mode & SILC_UMODE_ROUTER_OPERATOR )
				[member _setServerOperator:YES];

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", nil]];
		}	break;
		case SILC_NOTIFY_TYPE_LEAVE: {
			SilcClientEntry leaving_client = va_arg( list, SilcClientEntry );
			SilcChannelEntry channel = va_arg( list, SilcChannelEntry );

			if( ! leaving_client || ! channel ) break;

			MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
			MVChatUser *member = [self _chatUserWithClientEntry:leaving_client];

			[room _removeMemberUser:member];

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", nil]];
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

			MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
			NSData *msgData = ( topic ? [[NSData allocWithZone:nil] initWithBytes:topic length:strlen( topic )] : nil );
			[room _setTopic:msgData];

			[room _setTopicAuthor:authorUser];
			[room _setTopicDate:[NSDate date]];

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification object:room];
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

			MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
			MVChatUser *member = [self _chatUserWithClientEntry:target_client];

			BOOL enabled = NO;
			MVChatRoomMemberMode chatRoomMemberMode;
			NSUInteger oldModes = [room modesForMemberUser:member];

			if( ( oldModes & MVChatRoomMemberFounderMode ) && ! ( mode & SILC_CHANNEL_UMODE_CHANFO ) ) {
				enabled = NO;
				chatRoomMemberMode = MVChatRoomMemberFounderMode;

				[room _removeMode:chatRoomMemberMode forMemberUser:member];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:chatRoomMemberMode], @"mode", changerUser, @"by", nil]];
			} else if( ! ( oldModes & MVChatRoomMemberFounderMode ) && ( mode & SILC_CHANNEL_UMODE_CHANFO ) ) {
				enabled = YES;
				chatRoomMemberMode = MVChatRoomMemberFounderMode;

				[room _setMode:chatRoomMemberMode forMemberUser:member];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:chatRoomMemberMode], @"mode", changerUser, @"by", nil]];
			}

			if( ( oldModes & MVChatRoomMemberOperatorMode ) && ! ( mode & SILC_CHANNEL_UMODE_CHANOP ) ) {
				enabled = NO;
				chatRoomMemberMode = MVChatRoomMemberOperatorMode;

				[room _removeMode:chatRoomMemberMode forMemberUser:member];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:chatRoomMemberMode], @"mode", changerUser, @"by", nil]];
			} else if( ! ( oldModes & MVChatRoomMemberOperatorMode ) && ( mode & SILC_CHANNEL_UMODE_CHANOP ) ) {
				enabled = YES;
				chatRoomMemberMode = MVChatRoomMemberOperatorMode;

				[room _setMode:chatRoomMemberMode forMemberUser:member];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:chatRoomMemberMode], @"mode", changerUser, @"by", nil]];
			}

			MVChatRoomMemberDisciplineMode chatRoomMemberDiciplineMode;
			oldModes = [room disciplineModesForMemberUser:member];

			if( ( oldModes & MVChatRoomMemberDisciplineQuietedMode ) && ! ( mode & SILC_CHANNEL_UMODE_QUIET ) ) {
				enabled = NO;
				chatRoomMemberDiciplineMode = MVChatRoomMemberDisciplineQuietedMode;

				[room _removeDisciplineMode:chatRoomMemberDiciplineMode forMemberUser:member];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:chatRoomMemberDiciplineMode], @"mode", changerUser, @"by", nil]];
			} else if( ! ( oldModes & MVChatRoomMemberDisciplineQuietedMode ) && ( mode & SILC_CHANNEL_UMODE_QUIET ) ) {
				enabled = YES;
				chatRoomMemberDiciplineMode = MVChatRoomMemberDisciplineQuietedMode;

				[room _setDisciplineMode:chatRoomMemberDiciplineMode forMemberUser:member];

				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:enabled], @"enabled", [NSNumber numberWithUnsignedLong:chatRoomMemberDiciplineMode], @"mode", changerUser, @"by", nil]];
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

			NSData *msgData = ( kick_message ? [[NSData allocWithZone:nil] initWithBytes:kick_message length:strlen( kick_message )] : nil );

			MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
			MVChatUser *member = [self _chatUserWithClientEntry:kicked];
			MVChatUser *byMember = [self _chatUserWithClientEntry:kicker];
			[room _removeMemberUser:member];

			if( kicked == conn -> local_entry ) {
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:byMember, @"byUser", msgData, @"reason", nil]];
			} else {
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", byMember, @"byUser", msgData, @"reason", nil]];
			}

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

			if( ! kill_message ) kill_message = (char *) "";
			NSString *killMessage = [NSString stringWithUTF8String:kill_message];

			NSString *quitReason = [NSString stringWithFormat:@"Killed by %@ (%@)", killerNickname, killMessage];
			const char *quitReasonString = [quitReason UTF8String];

			NSData *reasonData = [[NSData allocWithZone:nil] initWithBytes:quitReasonString length:strlen( quitReasonString )];
			MVChatUser *member = [self _chatUserWithClientEntry:killed];
			NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil];

			[self _markUserAsOffline:member];

			for( MVChatRoom *room in [self joinedChatRooms] ) {
				if( ! [room isJoined] || ! [room hasUser:member] ) continue;
				[room _removeMemberUser:member];
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification object:room userInfo:info];
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
			[self _markUserAsOnline:user];
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomInvitedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", channelName, @"room", nil]];
		}	break;
	}

	va_end( list );
}

static void silc_command( SilcClient client, SilcClientConnection conn, SilcClientCommandContext cmd_context, bool success, SilcCommand command, SilcStatus status ) {
}

static void silc_command_reply( SilcClient client, SilcClientConnection conn, SilcCommandPayload cmd_payload, bool success, SilcCommand command, SilcStatus status, ... ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);

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
		[user _setDateUpdated:[NSDate date]];
		[self _markUserAsOnline:user];

		if( channels ) {
			NSMutableArray *chanArray = [[NSMutableArray allocWithZone:nil] init];
			SilcDList silcDList = silc_channel_payload_parse_list( channels -> data, channels -> len );
			if( silcDList ) {
				silc_dlist_start( silcDList );

				SilcChannelPayload entry = NULL;
				while( ( entry = silc_dlist_get( silcDList ) ) != SILC_LIST_END ) {
					SilcUInt32 name_len = 0;
					unsigned char *name = silc_channel_get_name( entry, &name_len );
					[chanArray addObject:[NSString stringWithUTF8String:(char *)name]];
				}

				silc_channel_payload_list_free( silcDList );

				if( chanArray.count ) [user setAttribute:chanArray forKey:MVChatUserKnownRoomsAttribute];
			}

		} else [user setAttribute:nil forKey:MVChatUserKnownRoomsAttribute];

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserInformationUpdatedNotification object:user];
	}	break;
	case SILC_COMMAND_WHOWAS:
		break;
	case SILC_COMMAND_IDENTIFY:
		break;
	case SILC_COMMAND_NICK: {
		char *nickname = va_arg( list, char * );
		/*const SilcClientID *old_client_id =*/ va_arg( list, SilcClientID * );

		NSData *oldIdentifier = [[self localUser] uniqueIdentifier];

		[(MVSILCChatUser *)[self localUser] updateWithClientEntry:conn -> local_entry];

		for( MVChatRoom *room in [self joinedChatRooms] ) {
			if( ! [room isJoined] || ! [room hasUser:[self localUser]] ) continue;
			[room _updateMemberUser:[self localUser] fromOldUniqueIdentifier:oldIdentifier];
		}

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nickname], @"nickname", nil]];
	}	break;
	case SILC_COMMAND_LIST: {
		/* SilcChannelEntry channel = */ va_arg( list, SilcChannelEntry );
		char *channel_name = va_arg( list, char * );
		char *channel_topic = va_arg( list, char * );
		SilcUInt32 user_count = va_arg( list, SilcUInt32 );

		if( ! channel_name ) break;
		if( ! channel_topic ) channel_topic = (char *) "";

		NSString *r = [[NSString allocWithZone:nil] initWithUTF8String:channel_name];
		NSData *t = [[NSData allocWithZone:nil] initWithBytes:channel_topic length:strlen( channel_topic )];
		NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithUnsignedLong:user_count], @"users", t, @"topic", [NSDate date], @"cached", r, @"room", nil];

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

		// The room is released in silc_channel_get_clients_per_list_callback.
		MVSILCChatRoom *room = (MVSILCChatRoom *)[self joinedChatRoomWithChannel:channel];
		if( ! room ) {
			room = [[MVSILCChatRoom allocWithZone:nil] initWithChannelEntry:channel andConnection:self];
		} else {
			[room updateWithChannelEntry:channel];
		}

		[room _setDateJoined:[NSDate date]];
		[room _setDateParted:nil];
		[room _clearMemberUsers];
		[room _clearBannedUsers];

		if( ! topic ) topic = (char *) "";

		NSData *msgData = [[NSData allocWithZone:nil] initWithBytes:topic length:strlen( topic )];
		[room _setTopic:msgData];

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification object:room];

		silc_client_get_clients_by_list( client, conn, list_count, client_id_list, silc_channel_get_clients_per_list_callback, (__bridge void *)room );

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
		MVChatRoom *room = [self joinedChatRoomWithChannel:channel];
		[room _setDateParted:[NSDate date]];
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomPartedNotification object:room];
	}	break;
	case SILC_COMMAND_USERS:
		break;
	case SILC_COMMAND_GETKEY:
		break;
	}
}

static void silc_connected( SilcClient client, SilcClientConnection conn, SilcClientConnectionStatus status ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);
	[self _setSilcConn:conn];

	if( status == SILC_CLIENT_CONN_SUCCESS || status == SILC_CLIENT_CONN_SUCCESS_RESUME ) {
		[self _initLocalUser];

		SilcUnlock( [self _silcClient] );

		// we need to wait for this to complete, otherwise sendRawMessage will queue the commands again
		[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:YES];

		SilcLock( [self _silcClient] );

		@synchronized( [self _queuedCommands] ) {
			for( NSString *command in [self _queuedCommands] )
				[self sendRawMessage:command];

			[[self _queuedCommands] removeAllObjects];
		}
	} else {
		silc_client_close_connection( client, conn );
		[self _stopSilcRunloop];
		[self _setSilcConn:NULL];
		[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:NO];
	}
}

static void silc_disconnected( SilcClient client, SilcClientConnection conn, SilcStatus status, const char *message ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);
	[self _stopSilcRunloop];
	[self _setSilcConn:NULL];
	[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:NO];
}

static void silc_get_auth_method_callback( SilcClient client, SilcClientConnection conn, SilcAuthMethod auth_method, void *context ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);
	NSDictionary *dict = (__bridge NSDictionary *)(context);
	SilcGetAuthMeth completion = SILC_32_TO_PTR( [(NSNumber *)[dict objectForKey:@"completion"] unsignedIntValue] );
	void *completionContext = SILC_32_TO_PTR( [(NSNumber *)[dict objectForKey:@"context"] unsignedIntValue] );

	switch( auth_method ) {
	case SILC_AUTH_NONE:
		completion( TRUE, auth_method, NULL, 0, completionContext );
		break;
	case SILC_AUTH_PASSWORD:
		if( ! [self password] ) {
			completion( TRUE, auth_method, NULL, 0, completionContext );
			break;
		}

		completion( TRUE, auth_method, (unsigned char *)[[self password] UTF8String], [[self password] length], completionContext );
		break;
	case SILC_AUTH_PUBLIC_KEY:
		completion( TRUE, auth_method, NULL, 0, completionContext );
		break;
	}
}

static void silc_get_auth_method( SilcClient client, SilcClientConnection conn, char *hostname, SilcUInt16 port, SilcGetAuthMeth completion, void *context ) {
	// The dictionary is released in silc_get_auth_method_callback.
	NSDictionary *dict = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@(SILC_PTR_TO_32( completion )), @"completion", @(SILC_PTR_TO_32( context )), @"context", nil];
	silc_client_request_authentication_method( client, conn, silc_get_auth_method_callback, (__bridge void *)dict );
}

static void silc_verify_public_key( SilcClient client, SilcClientConnection conn, SilcSocketType conn_type, unsigned char *pk, SilcUInt32 pk_len, SilcSKEPKType pk_type, SilcVerifyPublicKey completion, void *context ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);

	char *tmp = silc_hash_fingerprint( NULL, pk, pk_len );
	NSString *asciiFingerprint = [NSString stringWithUTF8String:tmp];
	silc_free( tmp );

	tmp = silc_hash_babbleprint( NULL, pk, pk_len );
	NSString *asciiBabbleprint = [NSString stringWithUTF8String:tmp];
	silc_free(tmp);

	NSString *filename = NULL;
	MVChatConnectionPublicKeyType publicKeyType = MVChatConnectionClientPublicKeyType;

	switch( conn_type ) {
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

	if( [[NSFileManager defaultManager] fileExistsAtPath:filename] ) {
		SilcPublicKey publicKey = NULL;
		unsigned char *encodedPublicKey;
		SilcUInt32 encodedPublicKeyLen;

		if( silc_pkcs_load_public_key( [filename fileSystemRepresentation], &publicKey, SILC_PKCS_FILE_PEM ) ||
			 silc_pkcs_load_public_key( [filename fileSystemRepresentation], &publicKey, SILC_PKCS_FILE_BIN ) ) {
			encodedPublicKey = silc_pkcs_public_key_encode( publicKey, &encodedPublicKeyLen );
			if( encodedPublicKey ) {
				if( ! memcmp( encodedPublicKey, pk, encodedPublicKeyLen ) )
					needVerify = NO;
				silc_free( encodedPublicKey );
			}

			silc_pkcs_public_key_free( publicKey );
		}
	}

	if( ! needVerify ) {
		completion( TRUE, context );
		return;
	}

	NSMutableDictionary *dict = [[NSMutableDictionary allocWithZone:nil] init];
	[dict setObject:[NSNumber numberWithUnsignedInt:publicKeyType] forKey:@"publicKeyType"];
	[dict setObject:asciiFingerprint forKey:@"fingerprint"];
	[dict setObject:asciiBabbleprint forKey:@"babbleprint"];

	if( conn_type == SILC_SOCKET_TYPE_SERVER || conn_type == SILC_SOCKET_TYPE_ROUTER ) {
		if( conn -> sock -> hostname && strlen( conn -> sock -> hostname ) ) {
			[dict setObject:[NSString stringWithUTF8String:conn -> sock -> hostname] forKey:@"name"];
		} else if( conn -> sock -> ip && strlen( conn -> sock -> ip ) ) {
			[dict setObject:[NSString stringWithUTF8String:conn -> sock -> ip] forKey:@"name"];
		} else {
			[dict setObject:@"unknown server" forKey:@"name"];
		}
	} else if( conn_type == SILC_SOCKET_TYPE_CLIENT ) {
		[dict setObject:@"unknown user" forKey:@"name"];
	}

	[dict setObject:@(SILC_PTR_TO_32(completion)) forKey:@"completition"];
	[dict setObject:@(SILC_PTR_TO_32(context)) forKey:@"completitionContext"];
	[dict setObject:self forKey:@"connection"];
	[dict setObject:[NSData dataWithBytes:pk length:pk_len] forKey:@"pk"];
	[dict setObject:@(conn_type) forKey:@"connType"];
	[dict setObject:@(SILC_PTR_TO_32(conn)) forKey:@"silcConn"];

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedPublicKeyVerificationNotification object:self userInfo:dict];
}

static void silc_ask_passphrase( SilcClient client, SilcClientConnection conn, SilcAskPassphrase completion, void *context ) {
}

static void silc_failure( SilcClient client, SilcClientConnection conn, SilcProtocol protocol, void *failure ) {
}

static bool silc_key_agreement( SilcClient client, SilcClientConnection conn, SilcClientEntry client_entry, const char *hostname, SilcUInt16 port, SilcKeyAgreementCallback *completion, void **context) {
#if 0
	if( hostname ) {
		silc_client_perform_key_agreement( client, conn, client_entry, hostname, port, silcgaim_buddy_keyagr_cb, ai );
	} else {
		// other user didn't supply hostname - we need to make the connection
		NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
		NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
		NSMutableData *result = [[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL] mutableCopy];
		[result appendBytes:"\0" length:1];

		silc_client_send_key_agreement( client, conn, client_entry, [result bytes], NULL, 0, 60, silcgaim_buddy_keyagr_cb, a );

		[result release];
	}
#endif

	return FALSE;
}

static void silc_ftp( SilcClient client, SilcClientConnection conn, SilcClientEntry client_entry, SilcUInt32 session_id, const char *hostname, SilcUInt16 port ) {
/*	MVSILCChatConnection *self = conn -> context;

	MVChatUser *user = [self _chatUserWithClientEntry:client_entry];
	MVSILCDownloadFileTransfer *transfer = [[[MVSILCDownloadFileTransfer allocWithZone:nil] initWithSessionID:session_id toUser:user]
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVDownloadFileTransferOfferNotification object:transfer]; */
}

static void silc_detach( SilcClient client, SilcClientConnection conn, const unsigned char *detach_data, SilcUInt32 detach_data_len ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)(conn -> context);
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

@interface MVSILCChatConnection (Private)
- (void) _silcRunloop;
@end

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
		_silcClientParams.dont_register_crypto_library = TRUE;

		_silcClient = silc_client_alloc( &silcClientOps, &_silcClientParams, (void *)CFBridgingRetain(self), NULL );
		if( ! _silcClient) {
			// we need some error handling here.. silc connection CAN'T work without silc client
			return nil;
		}

		[self setUsername:NSUserName()];
		[self setRealName:NSFullUserName()];

		_queuedCommands = [[NSMutableArray allocWithZone:nil] initWithCapacity:5];
		_sentCommands = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];

	[self disconnect];

	// if we don't have a scheduler, we don't have a lock. but we don't need to
	// lock anything anyway, because silc can't be connected without scheduler ...
	if( _silcClient -> schedule ) SilcLock( _silcClient );
	if( _silcClient -> realname ) free( _silcClient -> realname );
	if( _silcClient -> username ) free( _silcClient -> username );
	if( _silcClient -> hostname ) free( _silcClient -> hostname );
	if( _silcClient -> nickname ) free( _silcClient -> nickname );
	if( _silcClient -> schedule ) SilcUnlock( _silcClient );

	// we only stop if we have an scheduler - silc client is actually running
	if( _silcClient -> schedule ) silc_client_stop( _silcClient );
	if( _silcClient ) silc_client_free( _silcClient );
	_silcClient = NULL;
}

#pragma mark -

- (MVChatConnectionType) type {
	return MVChatConnectionSILCType;
}

- (NSSet *) supportedFeatures {
	return [NSSet setWithObjects:MVChatRoomMemberQuietedFeature, MVChatRoomMemberVoicedFeature, MVChatRoomMemberOperatorFeature, MVChatRoomMemberFounderFeature, nil];
}

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

#pragma mark -

- (void) connect {
	if( [self status] != MVChatConnectionDisconnectedStatus && [self status] != MVChatConnectionServerDisconnectedStatus && [self status] != MVChatConnectionSuspendedStatus ) return;

	if( ! [self _isKeyPairLoaded] ) {
		if( ! [self _loadKeyPair] ) {
			[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _connectKeyPairLoaded: ) name:MVSILCChatConnectionLoadedCertificate object:nil];
			return;
		}
	}

	if( _lastConnectAttempt && ABS( [_lastConnectAttempt timeIntervalSinceNow] ) < 5. ) {
		// prevents connecting too quick
		// cancel any reconnect attempts, this lets a user cancel the attempts with a "double connect"
		[self cancelPendingReconnectAttempts];
		return;
	}

	_lastConnectAttempt = [[NSDate allocWithZone:nil] init];

	[self _willConnect]; // call early so other code has a chance to change our info

	_sentQuitCommand = NO;

	[self _silcClient] -> hostname = strdup( [[[NSProcessInfo processInfo] hostName] UTF8String] );
	[self _silcClient] -> pkcs = silcPkcs;
	[self _silcClient] -> private_key = silcPrivateKey;
	[self _silcClient] -> public_key = silcPublicKey;

	if( ! silc_client_init( [self _silcClient] ) ) {
		// some error, do better reporting
		[self _didNotConnect];
		return;
	}

	BOOL errorOnConnect = NO;

	NSData *detachInfo = [[self persistentInformation] objectForKey:@"detachData"];
	SilcClientConnectionParams params;
	memset( &params, 0, sizeof( params ) );
	params.detach_data = ( detachInfo ? (unsigned char *)[detachInfo bytes] : NULL );
	params.detach_data_len = ( detachInfo ? detachInfo.length : 0 );

	SilcLock( [self _silcClient] );
	if( silc_client_connect_to_server( [self _silcClient], &params, [self serverPort], (char *) [[self server] UTF8String], (void *)CFBridgingRetain(self) ) == -1 )
		errorOnConnect = YES;
	SilcUnlock( [self _silcClient] );

	if( errorOnConnect) [self _didNotConnect];
	else [NSThread detachNewThreadSelector:@selector( _silcRunloop ) toTarget:self withObject:nil];
}

- (void) disconnectWithReason:(MVChatString * __nullable) reason {
	[self cancelPendingReconnectAttempts];

	if( [self status] != MVChatConnectionConnectedStatus ) return;

	_sentQuitCommand = YES;

	if( reason.length ) {
		const char *msg = [MVSILCChatConnection _flattenedSILCStringForMessage:reason andChatFormat:[self outgoingChatFormat]];
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
	if( ! [self _silcClient] ) return;
	if( [self _silcClient] -> realname) free( [self _silcClient] -> realname );
	[self _silcClient] -> realname = strdup( [name UTF8String] );
}

- (NSString *) realName {
	if( ! [self _silcClient] ) return nil;
	return [NSString stringWithUTF8String:[self _silcClient] -> realname];
}

#pragma mark -

- (void) setNickname:(NSString *) newNickname {
	NSParameterAssert( newNickname != nil );
	NSParameterAssert( newNickname.length > 0 );
	if( ! [self _silcClient] ) return;

	if( [self _silcClient] -> nickname) free( [self _silcClient] -> nickname );
	[self _silcClient] -> nickname = strdup( [newNickname UTF8String] );

	if( [self isConnected] ) {
		if( ! [newNickname isEqualToString:[self nickname]] )
			[self sendRawMessageWithFormat:@"NICK %@", newNickname];
	}
}

- (NSString *) nickname {
	if( [self isConnected] && [self _silcConn] && [self _silcConn] -> nickname )
		return [NSString stringWithUTF8String:[self _silcConn] -> nickname];

	return [NSString stringWithUTF8String:[self _silcClient] -> nickname];
}

- (NSString *) preferredNickname {
	return [NSString stringWithUTF8String:[self _silcClient] -> nickname];
}

#pragma mark -

- (NSString *) certificateServiceName {
	return @"SILC Keypair";
}

- (BOOL) authenticateCertificateWithPassword:(NSString *) newPassword {
	_certificatePassword = [newPassword copyWithZone:nil];

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

- (void) setPassword:(NSString *) newPassword {
	if( newPassword.length ) _silcPassword = [newPassword copyWithZone:nil];
	else _silcPassword = nil;
}

- (NSString *) password {
	return _silcPassword;
}

#pragma mark -

- (void) setUsername:(NSString *) newUsername {
	NSParameterAssert( newUsername != nil );
	NSParameterAssert( newUsername.length > 0 );
	if( ! [self _silcClient] ) return;

	if( [self _silcClient] -> username ) free( [self _silcClient] -> username );
	[self _silcClient] -> username = strdup( [newUsername UTF8String] );
}

- (NSString *) username {
	if( ! [self _silcClient] ) return nil;
	return [NSString stringWithUTF8String:[self _silcClient] -> username];
}

#pragma mark -

- (void) setServer:(NSString *) newServer {
	if( newServer.length >= 7 && [newServer hasPrefix:@"silc://"] )
		newServer = [newServer substringFromIndex:7];
	MVSafeCopyAssign( _silcServer, newServer );

	[super setServer:newServer];
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

	if( accepted ) completition( TRUE, context );
	else completition( FALSE, context );

	if( alwaysAccept ) {
		NSData *pk = [dictionary objectForKey:@"pk"];
		NSString *filename = [self _publicKeyFilename:[dictionary[@"connType"] intValue] andPublicKey:(unsigned char *)[pk bytes] withLen:pk.length usingSilcConn:conn];
		silc_pkcs_save_public_key_data( [filename fileSystemRepresentation], (unsigned char *)[pk bytes], pk.length, SILC_PKCS_FILE_PEM);
	}
}

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString * __nullable) arguments {
#if USE(ATTRIBUTED_CHAT_STRING)
	NSString *argumentsString = [arguments string];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	NSString *argumentsString = arguments;
#endif

	if( [command hasPrefix:@"/"] )
		command = [command substringFromIndex:1];

	if( argumentsString && argumentsString.length > 0 )
		[self sendRawMessage:[NSString stringWithFormat:@"%@ %@", command, argumentsString]];
	else
		[self sendRawMessage:command];
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );

	if( ! [self isConnected] ) {
		@synchronized( _queuedCommands ) {
			[_queuedCommands addObject:raw];
		} return;
	}

	SilcLock( [self _silcClient] );

	BOOL sent = NO;
	if( [self _silcConn] ) {
		sent = silc_client_command_call( [self _silcClient], [self _silcConn], [raw UTF8String] );
		if( sent ) [self _addCommand:raw forNumber:[self _silcConn] -> cmd_ident];
		silc_schedule_wakeup( [self _silcClient] -> schedule );
	}

	SilcUnlock( [self _silcClient] );

	if( ! sent ) [self _sendCommandFailedNotify:raw];
}

#pragma mark -

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString * __nullable) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( room.length > 0 );
	if( passphrase.length ) [self sendRawMessageWithFormat:@"JOIN %@ %@", [self properNameForChatRoomNamed:room], passphrase];
	else [self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
}

- (MVChatRoom *) joinedChatRoomWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSData class]] );
	return [super joinedChatRoomWithUniqueIdentifier:identifier];
}

- (MVChatRoom *) joinedChatRoomWithChannel:(SilcChannelEntry) channel {
	if( ! channel ) return nil;

	MVChatRoom *room = nil;
	unsigned char *identifier = silc_id_id2str( channel -> id, SILC_ID_CHANNEL );
	if( identifier ) {
		SilcUInt32 length = silc_id_get_len( channel -> id, SILC_ID_CHANNEL );
		NSData *uniqueIdentifier = [[NSData allocWithZone:nil] initWithBytesNoCopy:identifier length:length freeWhenDone:NO];
		room = [self joinedChatRoomWithUniqueIdentifier:uniqueIdentifier];
	}

	if( ! room && channel -> channel_name )
		room = [self joinedChatRoomWithName:[NSString stringWithUTF8String:channel -> channel_name]];

	return room;
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return nil;
}

#pragma mark -

static void usersFoundCallback( SilcClient client, SilcClientConnection conn, SilcClientEntry *clients, SilcUInt32 clients_count, void *context ) {
	MVSILCChatConnection *self = (__bridge MVSILCChatConnection *)context;
	self -> _lookingUpUsers = NO;
}

#pragma mark -

- (NSSet *) chatUsersWithNickname:(NSString *) findNickname {
	if( ! [self _silcConn] ) return nil;

	SilcLock( [self _silcClient] );
	silc_client_get_clients_whois( [self _silcClient], [self _silcConn], [findNickname UTF8String], NULL, NULL, usersFoundCallback, (void *)CFBridgingRetain(self) );
	silc_schedule_wakeup( [self _silcClient] -> schedule );
	SilcUnlock( [self _silcClient] );

	_lookingUpUsers = YES;

	NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:8.];
	while( _lookingUpUsers && [timeout timeIntervalSinceNow] >= 0 ) // asynchronously look up the users
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

	SilcLock( [self _silcClient] );

	SilcUInt32 clientsCount = 0;
	SilcClientEntry *clients = silc_client_get_clients_local( [self _silcClient], [self _silcConn], [findNickname UTF8String], NULL, &clientsCount );

	NSUInteger i = 0;
	NSMutableSet *results = [[NSMutableSet allocWithZone:nil] initWithCapacity:clientsCount];
	for( i = 0; i < clientsCount; i++ ) {
		MVChatUser *user = [self _chatUserWithClientEntry:clients[i]];
		[self _markUserAsOnline:user];
		if( user ) [results addObject:user];
	}

	SilcUnlock( [self _silcClient] );

	return ( results.count ? results : nil );
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSData class]] || [identifier isKindOfClass:[NSString class]] );

	if( ! [self _silcConn] ) return nil;

	NSData *data = nil;
	if( [identifier isKindOfClass:[NSString class]] ) {
		data = [NSData dataWithBase64EncodedString:identifier];
	} else data = identifier;

	if( [data isEqualToData:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:data];
		if( user ) return user;

		SilcClientID *clientID = silc_id_str2id( [(NSData *)data bytes], [(NSData *)data length], SILC_ID_CLIENT );
		if( clientID ) {
			SilcLock( [self _silcClient] );
			SilcClientEntry client = silc_client_get_client_by_id( [self _silcClient], [self _silcConn], clientID );
			SilcUnlock( [self _silcClient] );
			if( client )
				user = [[MVSILCChatUser allocWithZone:nil] initWithClientEntry:client andConnection:self];
		}
	}

	return user;
}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 900. ) {
		[self sendRawMessage:@"LIST"];
		_cachedDate = [[NSDate allocWithZone:nil] init];
	}
}

- (void) setAwayStatusMessage:(MVChatString * __nullable) message {
	if( ! [self _silcConn] ) return;

	_awayMessage = nil;

	if( message.length ) {
		_awayMessage = [message copy];

		[self sendRawMessage:@"UMODE +g"];

		SilcLock( [self _silcClient] );
		silc_client_set_away_message( [self _silcClient], [self _silcConn], (char *) [MVSILCChatConnection _flattenedSILCStringForMessage:message andChatFormat:[self outgoingChatFormat]] );
		SilcUnlock( [self _silcClient] );

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self];
	} else {
		[self sendRawMessage:@"UMODE -g"];

		SilcLock( [self _silcClient] );
		silc_client_set_away_message( [self _silcClient], [self _silcConn], NULL );
		SilcUnlock( [self _silcClient] );

		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self];
	}
}

#pragma mark -

- (NSUInteger) lag {
	return 0;
}
@end

#pragma mark -

@implementation MVSILCChatConnection (MVSILCChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(MVChatString *) message andChatFormat:(MVChatMessageFormat) format {
	NSString *cformat = nil;

	switch( format ) {
		case MVChatConnectionDefaultMessageFormat:
		case MVChatWindowsIRCMessageFormat:
			cformat = NSChatWindowsIRCFormatType;
			break;
		case MVChatCTCPTwoMessageFormat:
			cformat = NSChatCTCPTwoFormatType;
			break;
		default:
		case MVChatNoMessageFormat:
			cformat = nil;
	}

	NSDictionary *options = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NullTerminatedReturn", cformat, @"FormatType", [NSNumber numberWithUnsignedInt:NSUTF8StringEncoding], @"StringEncoding", nil];
	NSData *data = [message chatFormatWithOptions:options];

	return [data bytes];
}

- (void) _silcRunloop {
    @autoreleasepool {
		if( [[NSThread currentThread] respondsToSelector:@selector( setName: )] )
			[[NSThread currentThread] setName:[[self url] absoluteString]];
	}

	while( _status == MVChatConnectionConnectedStatus || _status == MVChatConnectionConnectingStatus ) {
		@autoreleasepool {
			silc_schedule_one( _silcClient -> schedule, -1 );
		}
	}
}

- (void) _stopSilcRunloop {
	silc_schedule_wakeup( [self _silcClient] -> schedule );
}

#pragma mark -

- (void) _initLocalUser {
	MVSafeAdoptAssign( _localUser, [[MVSILCChatUser allocWithZone:nil] initLocalUserWithConnection:self] );
}

#pragma mark -

- (SilcClient) _silcClient {
	return _silcClient;
}

#pragma mark -

- (void) _setSilcConn:(SilcClientConnection __nullable) aSilcConn {
	_silcConn = aSilcConn;
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
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionNeedCertificatePasswordNotification object:self];
		return NO;
	}

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVSILCChatConnectionLoadedCertificate object:self];

	return YES;
}

- (BOOL) _isKeyPairLoaded {
	if( ! silcPkcs ) return NO;
	return YES;
}

- (void) _connectKeyPairLoaded:(NSNotification *) notification {
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVSILCChatConnectionLoadedCertificate object:nil];
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

- (void) _setDetachInfo:(NSData * __nullable) info {
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
		string = [_sentCommands objectForKey:number];
		[_sentCommands removeObjectForKey:number];
	}

	return string;
}

#pragma mark -

- (void) _sendCommandSucceededNotify:(NSString *) message {
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:message, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
}

- (void) _sendCommandFailedNotify:(NSString *) message {
	NSString *raw = [NSString stringWithFormat:@"Command failed: %@", message];
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:raw, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
}

#pragma mark -

- (void) _didConnect {
	[self _setDetachInfo:nil];
	[super _didConnect];
}

- (void) _didNotConnect {
	[self _stopSilcRunloop];
	[self _setSilcConn:NULL];
	[self _setDetachInfo:nil];
	[super _didNotConnect];
}

- (void) _didDisconnect {
	[self _stopSilcRunloop];
	[self _setSilcConn:NULL];

	if( ! _sentQuitCommand /* || ! [[self persistentInformation] objectForKey:@"detachData"] */ ) {
		if( _status != MVChatConnectionSuspendedStatus )
			_status = MVChatConnectionServerDisconnectedStatus;
		if( ABS( [_lastConnectAttempt timeIntervalSinceNow] ) > 300. )
			[self performSelector:@selector( connect ) withObject:nil afterDelay:5.];
		[self scheduleReconnectAttempt];
	}

	[_sentCommands removeAllObjects];
	[_queuedCommands removeAllObjects];

	_lookingUpUsers = NO;

	[super _didDisconnect];
}

// FIXME optional detach/reattach support
/*
- (void) _systemWillSleep:(NSNotification *) notification {
	if( [self isConnected] ) {
		[self sendRawMessage:@"DETACH"];
		_status = MVChatConnectionSuspendedStatus;
		usleep( 2500000 );
	}
}
*/

#pragma mark -

- (MVChatUser *) _chatUserWithClientEntry:(SilcClientEntry) clientEntry  {
	NSParameterAssert( clientEntry != NULL );

	unsigned char *identifier = silc_id_id2str( clientEntry -> id, SILC_ID_CLIENT );
	SilcUInt32 len = silc_id_get_len( clientEntry -> id, SILC_ID_CLIENT );
	NSData *uniqueIdentfier = [NSData dataWithBytes:identifier length:len];

	if( [uniqueIdentfier isEqualToData:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:uniqueIdentfier];
		if( user ) return user;

		user = [[MVSILCChatUser allocWithZone:nil] initWithClientEntry:clientEntry andConnection:self];
	}

	return user;
}

- (void) _updateKnownUser:(MVChatUser *) user withClientEntry:(SilcClientEntry) clientEntry {
	NSParameterAssert( user != nil );
	NSParameterAssert( clientEntry != NULL );

	unsigned char *identifier = silc_id_id2str( clientEntry -> id, SILC_ID_CLIENT );
	SilcUInt32 len = silc_id_get_len( clientEntry -> id, SILC_ID_CLIENT );
	NSData *uniqueIdentfier = [NSData dataWithBytes:identifier length:len];

	@synchronized( _knownUsers ) {
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:uniqueIdentfier];
		[user _setNickname:[NSString stringWithUTF8String:clientEntry -> nickname]];
		[_knownUsers setObject:user forKey:uniqueIdentfier];
	}
}

- (NSString *) _publicKeyFilename:(SilcSocketType) connType andPublicKey:(unsigned char *) pk withLen:(SilcUInt32) pkLen usingSilcConn:(SilcClientConnection) conn {
	NSString *filename = NULL;

	switch ( connType ) {
		case SILC_SOCKET_TYPE_UNKNOWN:
			return nil;

		case SILC_SOCKET_TYPE_CLIENT: {
			char *tmp = NULL;
			tmp = silc_hash_fingerprint( NULL, pk, pkLen );
			NSString *asciiFingerprint = [NSString stringWithUTF8String:tmp];
			silc_free( tmp );

			filename = [NSString stringWithFormat:@"%@/%@.pub", [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Silc/Client Keys/"] stringByExpandingTildeInPath], asciiFingerprint];
		}	break;

		case SILC_SOCKET_TYPE_SERVER:
		case SILC_SOCKET_TYPE_ROUTER: {
			NSString *host = nil;

			if( conn -> sock -> hostname && strlen( conn -> sock -> hostname ) ) {
				host = [NSString stringWithUTF8String:conn -> sock -> hostname];
			} else if( conn -> sock -> ip && strlen( conn -> sock -> ip ) ) {
				host = [NSString stringWithUTF8String:conn -> sock -> ip];
			} else {
				char *tmp = NULL;
				tmp = silc_hash_fingerprint( NULL, pk, pkLen );
				host = [NSString stringWithUTF8String:tmp];
				silc_free( tmp );
			}

			filename = [@"~/Library/Application Support/Colloquy/Silc/Server Keys" stringByAppendingPathComponent:host];
			filename = [filename stringByAppendingPathExtension:@"pub"];
			filename = [filename stringByExpandingTildeInPath];
		}	break;
	}

	return filename;
}
@end

NS_ASSUME_NONNULL_END

