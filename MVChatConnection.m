#import <Cocoa/Cocoa.h>
#import <string.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOTypes.h>
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "MVChatConnection.h"
#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "firetalk.h"

typedef void (*firetalk_callback)(firetalk_t, void *, ...);
typedef void (*firetalk_subcode_callback)(firetalk_t, void *, const char * const, const char * const, const char * const);

#pragma mark -

NSString *MVChatConnectionGotRawMessageNotification = @"MVChatConnectionGotRawMessageNotification";

NSString *MVChatConnectionWillConnectNotification = @"MVChatConnectionWillConnectNotification";
NSString *MVChatConnectionDidConnectNotification = @"MVChatConnectionDidConnectNotification";
NSString *MVChatConnectionDidNotConnectNotification = @"MVChatConnectionDidNotConnectNotification";
NSString *MVChatConnectionWillDisconnectNotification = @"MVChatConnectionWillDisconnectNotification";
NSString *MVChatConnectionDidDisconnectNotification = @"MVChatConnectionDidDisconnectNotification";
NSString *MVChatConnectionErrorNotification = @"MVChatConnectionErrorNotification";

NSString *MVChatConnectionNeedPasswordNotification = @"MVChatConnectionNeedPasswordNotification";
NSString *MVChatConnectionGotPrivateMessageNotification = @"MVChatConnectionGotPrivateMessageNotification";

NSString *MVChatConnectionBuddyIsOnlineNotification = @"MVChatConnectionBuddyIsOnlineNotification";
NSString *MVChatConnectionBuddyIsOfflineNotification = @"MVChatConnectionBuddyIsOfflineNotification";
NSString *MVChatConnectionBuddyIsAwayNotification = @"MVChatConnectionBuddyIsAwayNotification";
NSString *MVChatConnectionBuddyIsUnawayNotification = @"MVChatConnectionBuddyIsUnawayNotification";
NSString *MVChatConnectionBuddyIsIdleNotification = @"MVChatConnectionBuddyIsIdleNotification";

NSString *MVChatConnectionGotUserInfoNotification = @"MVChatConnectionGotUserInfoNotification";
NSString *MVChatConnectionGotRoomInfoNotification = @"MVChatConnectionGotRoomInfoNotification";

NSString *MVChatConnectionJoinedRoomNotification = @"MVChatConnectionJoinedRoomNotification";
NSString *MVChatConnectionLeftRoomNotification = @"MVChatConnectionLeftRoomNotification";
NSString *MVChatConnectionUserJoinedRoomNotification = @"MVChatConnectionUserJoinedRoomNotification";
NSString *MVChatConnectionUserLeftRoomNotification = @"MVChatConnectionUserLeftRoomNotification";
NSString *MVChatConnectionUserNicknameChangedNotification = @"MVChatConnectionUserNicknameChangedNotification";
NSString *MVChatConnectionUserOppedInRoomNotification = @"MVChatConnectionUserOppedInRoomNotification";
NSString *MVChatConnectionUserDeoppedInRoomNotification = @"MVChatConnectionUserDeoppedInRoomNotification";
NSString *MVChatConnectionUserVoicedInRoomNotification = @"MVChatConnectionUserVoicedInRoomNotification";
NSString *MVChatConnectionUserDevoicedInRoomNotification = @"MVChatConnectionUserDevoicedInRoomNotification";
NSString *MVChatConnectionUserKickedFromRoomNotification = @"MVChatConnectionUserKickedFromRoomNotification";
NSString *MVChatConnectionUserAwayStatusNotification = @"MVChatConnectionUserAwayStatusNotification";
NSString *MVChatConnectionGotRoomModeNotification = @"MVChatConnectionGotRoomModeNotification";
NSString *MVChatConnectionGotRoomMessageNotification = @"MVChatConnectionGotRoomMessageNotification";
NSString *MVChatConnectionGotRoomTopicNotification = @"MVChatConnectionGotRoomTopicNotification";

NSString *MVChatConnectionKickedFromRoomNotification = @"MVChatConnectionKickedFromRoomNotification";
NSString *MVChatConnectionInvitedToRoomNotification = @"MVChatConnectionInvitedToRoomNotification";

NSString *MVChatConnectionNicknameAcceptedNotification = @"MVChatConnectionNicknameAcceptedNotification";
NSString *MVChatConnectionNicknameRejectedNotification = @"MVChatConnectionNicknameRejectedNotification";

NSString *MVChatConnectionFileTransferAvailableNotification = @"MVChatConnectionFileTransferAvailableNotification";
NSString *MVChatConnectionFileTransferOfferedNotification = @"MVChatConnectionFileTransferOfferedNotification";
NSString *MVChatConnectionFileTransferStartedNotification = @"MVChatConnectionFileTransferStartedNotification";
NSString *MVChatConnectionFileTransferFinishedNotification = @"MVChatConnectionFileTransferFinishedNotification";
NSString *MVChatConnectionFileTransferErrorNotification = @"MVChatConnectionFileTransferErrorNotification";
NSString *MVChatConnectionFileTransferStatusNotification = @"MVChatConnectionFileTransferStatusNotification";

NSString *MVChatConnectionSubcodeRequestNotification = @"MVChatConnectionSubcodeRequestNotification";
NSString *MVChatConnectionSubcodeReplyNotification = @"MVChatConnectionSubcodeReplyNotification";

@interface MVChatConnection (MVChatConnectionPrivate)
+ (NSData *) _flattenedHTMLDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc;
- (io_connect_t) _powerConnection;
- (firetalk_t) _firetalkConnection;
- (void) _executeRunLoopCheck:(NSTimer *) timer;
- (void) _registerCallbacks;
- (void) _registerForSleepNotifications;
- (void) _deregisterForSleepNotifications;
- (void) _confirmNewNickname:(NSString *) nickname;
- (void) _addRoomToCache:(NSString *) room withUsers:(int) users andTopic:(NSData *) topic;
- (void) _setBacklogDelay:(NSTimeInterval) delay;
- (void) _setStatus:(MVChatConnectionStatus) status;
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
- (void) _joinRooms:(id) sender;
@end

#pragma mark -

void MVChatHandlePowerChange( void *refcon, io_service_t service, natural_t messageType, void *messageArgument ) {
	MVChatConnection *self = refcon;
	switch( messageType ) {
		case kIOMessageSystemWillRestart:
		case kIOMessageSystemWillPowerOff:
		case kIOMessageSystemWillSleep:
		case kIOMessageDeviceWillPowerOff:
			if( [self isConnected] ) {
				[self disconnect];
				[self _setStatus:MVChatConnectionSuspendedStatus];
			}
			IOAllowPowerChange( [self _powerConnection], (long) messageArgument );
			break;
		case kIOMessageCanSystemPowerOff:
		case kIOMessageCanSystemSleep:
		case kIOMessageCanDevicePowerOff:
			IOAllowPowerChange( [self _powerConnection], (long) messageArgument );
			break;
		case kIOMessageSystemWillNotSleep:
		case kIOMessageSystemWillNotPowerOff:
		case kIOMessageSystemHasPoweredOn:
		case kIOMessageDeviceWillNotPowerOff:
		case kIOMessageDeviceHasPoweredOn:
			if( [self status] == MVChatConnectionSuspendedStatus ) [self connect];
			break;
	}
}

#pragma mark -

void MVChatRawMessage( void *c, void *cs, const char * const raw, int outbound ) {
	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSData dataWithBytes:raw length:strlen( raw )], @"message", [NSNumber numberWithBool:(BOOL)outbound], @"outbound", nil]];
}

void MVChatConnected( void *c, void *cs ) {
	MVChatConnection *self = cs;
	[self _didConnect];
}

void MVChatConnectionFailed( void *c, void *cs, const int error, const char * const reason ) {
	MVChatConnection *self = cs;
	[self _didNotConnect];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionErrorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"whileConnecting", ( reason ? [NSString stringWithUTF8String:reason] : [NSNull null] ), @"reason", [NSNumber numberWithInt:error], @"error", nil]];
}

void MVChatDisconnect( void *c, void *cs, const int error ) {
	MVChatConnection *self = cs;
	[self _didDisconnect];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionErrorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"disconnected", [NSNumber numberWithInt:error], @"error", nil]];
}

void MVChatErrorOccurred( void *c, void *cs, const int error, const char * const roomoruser ) {
	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionErrorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:( roomoruser ? [NSString stringWithUTF8String:roomoruser] : [NSNull null] ), @"target", [NSNumber numberWithInt:error], @"error", nil]];
}

void MVChatBackLog( void *c, void *cs, const double backlog ) {
	MVChatConnection *self = cs;
	[self _setBacklogDelay:backlog];
}

#pragma mark -

void MVChatNeedPassword( void *c, void *cs, char *password, const int size ) {
	NSCParameterAssert( password != NULL );

	MVChatConnection *self = cs;
	const char *pass = [[self nicknamePassword] UTF8String];
	if( ! pass ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionNeedPasswordNotification object:self userInfo:nil];
		return;
	}

	strncpy( password, pass, size );
}

#pragma mark -

void MVChatGetMessage( void *c, void *cs, const char * const who, const int automessage, const char * const message ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSCParameterAssert( message != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"from", [NSNumber numberWithBool:automessage], @"auto", msgData, @"message", nil]];
}

void MVChatGetAction( void *c, void *cs, const char * const who, const int automessage, const char * const message ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSCParameterAssert( message != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"from", [NSNumber numberWithBool:automessage], @"auto", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
}

#pragma mark -

void MVChatBuddyOnline( void *c, void *cs, const char * const who ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyOffline( void *c, void *cs, const char * const who ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyAway( void *c, void *cs, const char * const who ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyUnaway( void *c, void *cs, const char * const who ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsUnawayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyGotIdle( void *c, void *cs, const char * const who, const long idletime ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", [NSNumber numberWithLong:idletime], @"idle", nil]];
}

#pragma mark -

void MVChatGotInfo( void *c, void *cs, const char * const who, const char * const username, const char * const hostname, const char * const server, const char * const realname, const int warning, const long idle, const long connected, const int flags ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	NSDictionary *infoDic = [NSDictionary dictionaryWithObjectsAndKeys:( username ? [NSString stringWithUTF8String:username] : [NSNull null] ), @"username", ( hostname ? [NSString stringWithUTF8String:hostname] : [NSNull null] ), @"hostname", ( server ? [NSString stringWithUTF8String:server] : [NSNull null] ), @"server", ( realname ? [NSString stringWithUTF8String:realname] : [NSNull null] ), @"realName", [NSNumber numberWithUnsignedInt:idle], @"idle", [NSNumber numberWithUnsignedInt:connected], @"connected", [NSNumber numberWithUnsignedInt:flags], @"flags", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotUserInfoNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", infoDic, @"info", nil]];
}

void MVChatListRoom( void *c, void *cs, const char * const room, const int users, const char * const topic ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( topic != NULL );

	MVChatConnection *self = cs;
	NSString *r = [NSString stringWithUTF8String:room];
	NSData *t = [NSData dataWithBytes:topic length:strlen( topic )];
	[self _addRoomToCache:r withUsers:users andTopic:t];
}

#pragma mark -

void MVChatJoinedRoom( void *c, void *cs, const char * const room ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", nil]];
}

void MVChatLeftRoom( void *c, void *cs, const char * const room ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", nil]];
}

void MVChatGetRoomMessage( void *c, void *cs, const char * const room, const char * const from, const int automessage, const char * message ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( message != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:from], @"from", [NSNumber numberWithBool:automessage], @"auto", msgData, @"message", nil]];
}

void MVChatGetRoomAction( void *c, void *cs, const char * const room, const char * const from, const int automessage, const char * message ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( message != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:message length:strlen(message)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:from], @"from", [NSNumber numberWithBool:automessage], @"auto", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
}

#pragma mark -

void MVChatKicked( void *c, void *cs, const char * const room, const char * const by, const char * const reason ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:reason length:(reason ? strlen(reason) : 0)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", ( by ? [NSString stringWithUTF8String:by] : [NSNull null] ), @"by", ( reason ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
}

void MVChatInvited( void *c, void *cs, const char * const room, const char * const from, const char * message ) {
#pragma unused(message)
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( from != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionInvitedToRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:from], @"from", nil]];
}

void MVChatGotTopic( void *c, void *cs, const char * const room, const char * const topic, const char * const author ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:topic length:(topic ? strlen(topic) : 0)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", ( author ? (id) [NSString stringWithUTF8String:author] : (id) [NSNull null] ), @"author", ( topic ? (id) msgData : (id) [NSNull null] ), @"topic", nil]];
}

#pragma mark -

void MVChatUserJoinedRoom( void *c, void *cs, const char * const room, const char * const who, const int previousmember ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", [NSNumber numberWithBool:previousmember], @"previousMember", nil]];
}

void MVChatUserLeftRoom( void *c, void *cs, const char * const room, const char * const who, const char * const reason ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:reason length:(reason ? strlen(reason) : 0)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", ( reason ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
}

void MVChatUserNicknameChanged( void *c, void *cs, const char * const room, const char * const oldnick, const char * const newnick ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( oldnick != NULL );
	NSCParameterAssert( newnick != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserNicknameChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:oldnick], @"oldNickname", [NSString stringWithUTF8String:newnick], @"newNickname", nil]];
}

#pragma mark -

void MVChatNewNickname( void *c, void *cs, const char * const newnick ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( newnick != NULL );

	MVChatConnection *self = cs;
	[self _confirmNewNickname:[NSString stringWithUTF8String:newnick]];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:newnick], @"nickname", nil]];
}

#pragma mark -

void MVChatGotRoomMode( void *c, void *cs, const char * const room, const char * const by, const int on, enum firetalk_room_mode mode, const char * const param ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", (param?[NSString stringWithUTF8String:param]:[NSNull null]), @"param", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", [NSNumber numberWithBool:on], @"enabled", [NSNumber numberWithUnsignedInt:(unsigned int)mode], @"mode", nil]];
}

void MVChatUserOpped( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserOppedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserDeopped( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserDeoppedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserVoiced( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserVoicedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserDevoiced( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserDevoicedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserKicked( void *c, void *cs, const char * const room, const char * const who, const char * const by, const char * const reason ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:reason length:(reason ? strlen(reason) : 0)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", msgData, @"reason", nil]];
}

void MVChatUserAway( void *c, void *cs, const char * const who, const char * const message ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );

	MVChatConnection *self = cs;
	NSData *msgData = [NSData dataWithBytes:message length:(message ? strlen(message) : 0)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", msgData, @"message", nil]];
}

#pragma mark -

void MVChatFileTransferAccept( void *c, void *cs, const void * const filehandle, const char * const from, const char * const filename, const long size ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( filename != NULL );
	NSCParameterAssert( size >= 0 );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferAvailableNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSString stringWithUTF8String:from], @"from", [NSString stringWithUTF8String:filename], @"filename", [NSNumber numberWithUnsignedLong:size], @"size", nil]];
}

void MVChatFileTransferStart( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferStartedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", nil]];
}

void MVChatFileTransferFinish( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct, const unsigned long size ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	NSCParameterAssert( size >= 0 );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferFinishedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSNumber numberWithUnsignedLong:size], @"size", nil]];
}

void MVChatFileTransferError( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct, const int error ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferErrorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSNumber numberWithInt:error], @"error", nil]];
}

void MVChatFileTransferStatus( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct, const unsigned long bytes, const unsigned long size ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	NSCParameterAssert( bytes >= 0 );
	NSCParameterAssert( size >= 0 );

	MVChatConnection *self = cs;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSNumber numberWithUnsignedLong:bytes], @"transfered", [NSNumber numberWithUnsignedLong:size], @"size", nil]];
}

#pragma mark -

void MVChatSubcodeRequest( void *c, void *cs, const char * const from, const char * const command, const char * const args ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( command != NULL );

	MVChatConnection *self = cs;
	NSString *cmd = [NSString stringWithUTF8String:command];
	NSString *ags = ( args ? [NSString stringWithUTF8String:args] : nil );
	NSString *frm = [NSString stringWithUTF8String:from];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeRequest:withArguments:fromUser:forConnection: )];
	[invocation setArgument:&cmd atIndex:2];
	[invocation setArgument:&ags atIndex:3];
	[invocation setArgument:&frm atIndex:4];
	[invocation setArgument:&self atIndex:5];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) return;

	if( ! strcasecmp( command, "VERSION" ) ) {
		NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];
		NSString *reply = [NSString stringWithFormat:@"%@ %@ - %@ %@ - %@", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductUserVisibleVersion"], [clientVersion objectForKey:@"MVChatCoreCTCPVersionReplyInfo"]];
		[self sendSubcodeReply:@"VERSION" toUser:[NSString stringWithUTF8String:from] withArguments:reply];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionSubcodeRequestNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frm, @"from", cmd, @"command", ( ags ? (id) ags : (id) [NSNull null] ), @"arguments", nil]];
}

void MVChatSubcodeReply( void *c, void *cs, const char * const from, const char * const command, const char * const args ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( command != NULL );

	MVChatConnection *self = cs;
	NSString *cmd = [NSString stringWithUTF8String:command];
	NSString *ags = ( args ? [NSString stringWithUTF8String:args] : nil );
	NSString *frm = [NSString stringWithUTF8String:from];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeReply:withArguments:fromUser:forConnection: )];
	[invocation setArgument:&cmd atIndex:2];
	[invocation setArgument:&ags atIndex:3];
	[invocation setArgument:&frm atIndex:4];
	[invocation setArgument:&self atIndex:5];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) return;

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionSubcodeReplyNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frm, @"from", cmd, @"command", ( ags ? (id) ags : (id) [NSNull null] ), @"arguments", nil]];
}

#pragma mark -

@implementation MVChatConnection
+ (void) setFileTransferPortRange:(NSRange) range {
	unsigned short min = (unsigned short)range.location;
	unsigned short max = (unsigned short)(range.location + range.length);
	firetalk_set_dcc_port_range( min, max );
}

+ (NSRange) fileTransferPortRange {
	unsigned short min = 1024;
	unsigned short max = 1048;
	firetalk_get_dcc_port_range( &min, &max );
	return NSMakeRange( (unsigned int) min, (unsigned int)( max - min ) );
}

#pragma mark -

+ (NSString *) descriptionForError:(MVChatError) error {
	return [NSString stringWithUTF8String:firetalk_strerror( (enum firetalk_error) error )];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_server = @"irc.javelin.cc";
		_nickname = [NSUserName() copy];
		_username = [NSUserName() copy];
		_realName = [NSFullUserName() copy];
		_npassword = nil;
		_password = nil;
		_cachedDate = nil;
		_floodIntervals = nil;
		_awayMessage = nil;
		_backlogDelay = 0.;
		_port = 6667;

		_status = MVChatConnectionDisconnectedStatus;
		_proxy = MVChatConnectionNoProxy;
		_chatConnection = firetalk_create_handle( FP_IRC, (void *) self );
		_joinList = [[NSMutableArray array] retain];
		_roomsCache = [[NSMutableDictionary dictionary] retain];

		[self setFloodControlIntervals:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:6.], @"messages", [NSNumber numberWithDouble:1.], @"delay", [NSNumber numberWithDouble:1.5], @"factor", [NSNumber numberWithDouble:3.], @"ceiling", nil]];

		[self _registerCallbacks];
		[self _registerForSleepNotifications];

		_firetalkSelectTimer = [[NSTimer scheduledTimerWithTimeInterval:.100 target:self selector:@selector( _executeRunLoopCheck: ) userInfo:nil repeats:YES] retain];
		_pingTimer = [[NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector( _pingServer: ) userInfo:nil repeats:YES] retain];
	}
	return self;
}

- (id) initWithURL:(NSURL *) url {
	if( ! [url isChatURL] ) return nil;
	if( ( self = [self initWithServer:[url host] port:[[url port] unsignedShortValue] user:[url user]] ) ) {
		[self setNicknamePassword:[url password]];

		if( [url fragment] && [[url fragment] length] > 0 ) {
			[self joinChatRoom:[url fragment]];
		} else if( [url path] && [[url path] length] >= 2 && ( [[[url path] substringFromIndex:1] hasPrefix:@"&"] || [[[url path] substringFromIndex:1] hasPrefix:@"+"] ) ) {
			[self joinChatRoom:[[url path] substringFromIndex:1]];
		}
	}
	return self;
}

- (id) initWithServer:(NSString *) server port:(unsigned short) port user:(NSString *) nickname {
	if( ( self = [self init] ) ) {
		if( [nickname length] ) [self setNickname:nickname];
		if( [server length] ) [self setServer:server];
		[self setServerPort:port];
	}
	return self;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 2 ) {
		[_firetalkSelectTimer invalidate];
		[_pingTimer invalidate];
	}
	[super release];
}

- (void) dealloc {
	[self disconnect];
	[self _deregisterForSleepNotifications];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_nickname release];
	[_npassword release];
	[_password release];
	[_server release];
	[_joinList release];
	[_roomsCache release];
	[_cachedDate release];
	[_floodIntervals release];
	[_awayMessage release];
	[_firetalkSelectTimer release];
	[_pingTimer release];

	firetalk_destroy_handle( _chatConnection );
	_chatConnection = NULL;
	_nickname = nil;
	_npassword = nil;
	_password = nil;
	_server = nil;
	_joinList = nil;
	_roomsCache = nil;
	_cachedDate = nil;
	_floodIntervals = nil;
	_awayMessage = nil;
	_firetalkSelectTimer = nil;
	_pingTimer = nil;

	[super dealloc];
}

#pragma mark -

- (void) connect {
	if( [self status] == MVChatConnectionConnectingStatus ) return;

	if( ! [_server length] || ! [_nickname length] ) {
		[self _didNotConnect];
		return;
	}

	[self _willConnect];

	firetalk_set_username( _chatConnection, [_username UTF8String] );
	firetalk_set_real_name( _chatConnection, [_realName UTF8String] );
	firetalk_set_password( _chatConnection, NULL, [_password UTF8String] );

	if( firetalk_signon( _chatConnection, [_server UTF8String], _port, [_nickname UTF8String] ) != FE_SUCCESS )
		[self _didNotConnect];
}

- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname {
	if( [nickname length] ) [self setNickname:nickname];
	if( [server length] ) [self setServer:server];
	[self setServerPort:port];
	[self connect];
}

- (void) disconnect {
	if( [self status] != MVChatConnectionDisconnectedStatus ) {
		[self _willDisconnect];
		firetalk_disconnect( _chatConnection );
	}
}

#pragma mark -

- (NSURL *) url {
	NSString *url = nil;
	if( ! _server ) return nil;
	if( _nickname && _port ) url = [NSString stringWithFormat:@"irc://%@@%@:%hu", MVURLEncodeString( _nickname ), MVURLEncodeString( _server ), _port];
	else if( _nickname && ! _port ) url = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( _nickname ), MVURLEncodeString( _server )];
	else url = [NSString stringWithFormat:@"irc://%@", MVURLEncodeString( _server )];
	return [[[NSURL URLWithString:url] retain] autorelease];
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	[_realName autorelease];
	_realName = [name copy];
}

- (NSString *) realName {
	return [[_realName retain] autorelease];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	if( [self isConnected] ) {
		if( nickname && ! [nickname isEqualToString:_nickname] )
			firetalk_set_nickname( _chatConnection, [nickname UTF8String] );
	} else [self _confirmNewNickname:nickname];
}

- (NSString *) nickname {
	return [[_nickname retain] autorelease];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
	if( [self isConnected] && [password length] && ! [password isEqualToString:_npassword] )
		firetalk_set_password( _chatConnection, NULL, [password UTF8String] );
	[_npassword autorelease];
	if( [password length] ) _npassword = [password copy];
	else _npassword = nil;
}

- (NSString *) nicknamePassword {
	return [[_npassword retain] autorelease];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	if( ! [self isConnected] && [password length] && ! [password isEqualToString:_password] )
		firetalk_set_password( _chatConnection, NULL, [password UTF8String] );
	[_password autorelease];
	if( [password length] ) _password = [password copy];
	else _password = nil;
}

- (NSString *) password {
	return [[_password retain] autorelease];
}

#pragma mark -

- (void) setUsername:(NSString *) username {
	[_username autorelease];
	_username = [username copy];
}

- (NSString *) username {
	return [[_username retain] autorelease];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	[_server autorelease];
	_server = [server copy];
}

- (NSString *) server {
	return [[_server retain] autorelease];
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	_port = ( port ? port : 6667 );
}

- (unsigned short) serverPort {
	return _port;
}

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) type {
	firetalk_set_proxy_type( _chatConnection, (enum firetalk_proxy) type );
	_proxy = type;
}

- (MVChatConnectionProxy) proxyType {
	return _proxy;
}

#pragma mark -

- (NSDictionary *) floodControlIntervals {
	return [[_floodIntervals retain] autorelease];
}

- (void) setFloodControlIntervals:(NSDictionary *) intervals {
	firetalk_set_flood_intervals( _chatConnection, [[intervals objectForKey:@"messages"] doubleValue], [[intervals objectForKey:@"delay"] doubleValue], [[intervals objectForKey:@"factor"] doubleValue], [[intervals objectForKey:@"ceiling"] doubleValue] );
	[_floodIntervals autorelease];
	_floodIntervals = [intervals copy];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toUser:(NSString *) user asAction:(BOOL) action {
	if( [self isConnected] ) {
		NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:message withEncoding:encoding] mutableCopy] autorelease];
		[encodedData appendBytes:"\0" length:1];

		if( action ) firetalk_im_send_action( _chatConnection, [user UTF8String], (char *) [encodedData bytes], 0 );
		else firetalk_im_send_message( _chatConnection, [user UTF8String], (char *) [encodedData bytes], 0 );
	}
}

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toChatRoom:(NSString *) room asAction:(BOOL) action {
	if( [self isConnected] ) {
		NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:message withEncoding:encoding] mutableCopy] autorelease];
		[encodedData appendBytes:"\0" length:1];

		if( action ) firetalk_chat_send_action( _chatConnection, [[room lowercaseString] UTF8String], (char *) [encodedData bytes], 0 );
		else firetalk_chat_send_message( _chatConnection, [[room lowercaseString] UTF8String], (char *) [encodedData bytes], 0 );
	}
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw {
	if( [self isConnected] )
		firetalk_send_raw( _chatConnection, [raw UTF8String] );
}

#pragma mark -

- (void) sendFile:(NSString *) path toUser:(NSString *) user {
	if( [user isEqualToString:_nickname] ) return;
	if( ! [[NSFileManager defaultManager] isReadableFileAtPath:path] ) return;
	if( [self isConnected] ) {
		NSNumber *size = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:@"NSFileSize"];
		void *handle = NULL;
		firetalk_file_offer( _chatConnection, &handle, [user UTF8String], [path fileSystemRepresentation] );
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferOfferedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", handle], @"identifier", user, @"to", path, @"path", size, @"size", nil]];
	}
}

- (void) acceptFileTransfer:(NSString *) identifier saveToPath:(NSString *) path resume:(BOOL) resume  {
	if( [self isConnected] ) {
		void *pointer = NULL;
		sscanf( [identifier UTF8String], "%8lx", (unsigned long int *) &pointer );
		if( resume ) firetalk_file_resume( _chatConnection, pointer, NULL, [path fileSystemRepresentation] );
		else firetalk_file_accept( _chatConnection, pointer, NULL, [path fileSystemRepresentation] );
	}
}

- (void) cancelFileTransfer:(NSString *) identifier {
	if( [self isConnected] ) {
		void *pointer = NULL;
		sscanf( [identifier UTF8String], "%8lx", (unsigned long int *) &pointer );
		firetalk_file_cancel( _chatConnection, pointer );
	}
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSParameterAssert( user != nil );
	if( [self isConnected] ) {
		firetalk_subcode_send_request( _chatConnection, [user UTF8String], [command UTF8String], [arguments UTF8String] );
	}
}

- (void) sendSubcodeReply:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSParameterAssert( user != nil );
	if( [self isConnected] ) {
		firetalk_subcode_send_reply( _chatConnection, [user UTF8String], [command UTF8String], [arguments UTF8String] );
	}
}

#pragma mark -

- (void) joinChatRooms:(NSArray *) rooms {
	[_joinList addObjectsFromArray:rooms];
	if( [self isConnected] ) [self _joinRooms:nil];
}

- (void) joinChatRoom:(NSString *) room {
	if( [self isConnected] ) firetalk_chat_join( _chatConnection, [[room lowercaseString] UTF8String] );
	else [_joinList addObject:room];
}

- (void) partChatRoom:(NSString *) room {
	if( [self isConnected] ) firetalk_chat_part( _chatConnection, [[room lowercaseString] UTF8String] );
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	if( [self isConnected] ) {
		NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:topic withEncoding:encoding] mutableCopy] autorelease];
		[encodedData appendBytes:"\0" length:1];

		firetalk_chat_set_topic( _chatConnection, [[room lowercaseString] UTF8String], (char *) [encodedData bytes] );
	}
}

#pragma mark -

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( [self isConnected] ) firetalk_chat_op( _chatConnection, [[room lowercaseString] UTF8String], [member UTF8String] );
}

- (void) demoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( [self isConnected] ) firetalk_chat_deop( _chatConnection, [[room lowercaseString] UTF8String], [member UTF8String] );
}

- (void) voiceMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( [self isConnected] ) firetalk_chat_voice( _chatConnection, [[room lowercaseString] UTF8String], [member UTF8String] );
}

- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( [self isConnected] ) firetalk_chat_devoice( _chatConnection, [[room lowercaseString] UTF8String], [member UTF8String] );
}

- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( [self isConnected] ) firetalk_chat_kick( _chatConnection, [[room lowercaseString] UTF8String], [member UTF8String], [reason UTF8String] );
}

#pragma mark -

- (void) addUserToNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );
	firetalk_im_internal_add_buddy( _chatConnection, [user UTF8String] );
}

- (void) removeUserFromNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );
	firetalk_im_internal_remove_buddy( _chatConnection, [user UTF8String] );
}

#pragma mark -

- (void) fetchInformationForUser:(NSString *) user withPriority:(BOOL) priority fromLocalServer:(BOOL) localOnly {
	NSParameterAssert( user != nil );
	if( [self isConnected] ) firetalk_im_get_info( _chatConnection, [user UTF8String], priority, localOnly );
}

#pragma mark -

- (void) fetchRoomList {
	if( [self isConnected] ) {
		if( ! _cachedDate || [_cachedDate timeIntervalSinceNow] < -900. ) {
			firetalk_im_get_roomlist( _chatConnection, NULL );
			[_cachedDate autorelease];
			_cachedDate = [[NSDate date] retain];
		}
	}
}

- (void) fetchRoomListWithRooms:(NSArray *) rooms {
	if( [self isConnected] ) {
		NSString *search = [rooms componentsJoinedByString:@","];
		firetalk_im_get_roomlist( _chatConnection, [search UTF8String] );
	}
}

- (void) stopFetchingRoomList {
	if( [self isConnected] ) {
		firetalk_im_stop_roomlist( _chatConnection );
	}
}

- (NSMutableDictionary *) roomListResults {
	return [[_roomsCache retain] autorelease];
}

#pragma mark -

- (NSAttributedString *) awayStatusMessage {
	return _awayMessage;
}

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	if( [self isConnected] ) {
		[_awayMessage autorelease];
		_awayMessage = nil;

		if( [[message string] length] ) {
			_awayMessage = [message copy];

			NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:message withEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
			[encodedData appendBytes:"\0" length:1];
			firetalk_set_away( _chatConnection, [encodedData bytes] );
		} else firetalk_set_away( _chatConnection, NULL );
	}
}

- (void) clearAwayStatus {
	[self setAwayStatusWithMessage:nil];
}

#pragma mark -

- (BOOL) isConnected {
	return (BOOL) ( _status == MVChatConnectionConnectedStatus );
}

- (MVChatConnectionStatus) status {
	return _status;
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionPrivate)
+ (NSData *) _flattenedHTMLDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"]], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"]], @"NSHTMLIgnoreFontTraits", nil];
	NSData *encodedData = [message HTMLWithOptions:options usingEncoding:enc allowLossyConversion:YES];
	return [[encodedData retain] autorelease];
}

#pragma mark -

- (io_connect_t) _powerConnection {
	return _powerConnection;
}

- (firetalk_t) _firetalkConnection {
	return _chatConnection;
}

#pragma mark -

- (void) _pingServer:(NSTimer *) timer {
	[self sendRawMessage:[NSString stringWithFormat:@"PING %@", _server]];
}

- (void) _executeRunLoopCheck:(NSTimer *) timer {
	struct timeval timeout = { 0, 050 };
	if( firetalk_select_custom( 0, NULL, NULL, NULL, &timeout ) < 0 ) {
		NSLog( @"firetalk_select: %s", firetalk_strerror( firetalkerror ) );
	}
}

- (void) _registerCallbacks {
	if( ! _chatConnection ) return;
	firetalk_register_callback( _chatConnection, FC_RAW_MESSAGE, (firetalk_callback) MVChatRawMessage );
	firetalk_register_callback( _chatConnection, FC_CONNECTED, (firetalk_callback) MVChatConnected );
	firetalk_register_callback( _chatConnection, FC_CONNECTFAILED, (firetalk_callback) MVChatConnectionFailed );
	firetalk_register_callback( _chatConnection, FC_DISCONNECT, (firetalk_callback) MVChatDisconnect );
	firetalk_register_callback( _chatConnection, FC_ERROR, (firetalk_callback) MVChatErrorOccurred );
	firetalk_register_callback( _chatConnection, FC_BACKLOG, (firetalk_callback) MVChatBackLog );
	firetalk_register_callback( _chatConnection, FC_NEWNICK, (firetalk_callback) MVChatNewNickname );
	firetalk_register_callback( _chatConnection, FC_NEEDPASS, (firetalk_callback) MVChatNeedPassword );
	firetalk_register_callback( _chatConnection, FC_IM_GETMESSAGE, (firetalk_callback) MVChatGetMessage );
	firetalk_register_callback( _chatConnection, FC_IM_GETACTION, (firetalk_callback) MVChatGetAction );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYONLINE, (firetalk_callback) MVChatBuddyOnline );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYOFFLINE, (firetalk_callback) MVChatBuddyOffline );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYAWAY, (firetalk_callback) MVChatBuddyAway );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYUNAWAY, (firetalk_callback) MVChatBuddyUnaway );
	firetalk_register_callback( _chatConnection, FC_IM_LISTROOM, (firetalk_callback) MVChatListRoom );
	firetalk_register_callback( _chatConnection, FC_IM_GOTINFO, (firetalk_callback) MVChatGotInfo );
	firetalk_register_callback( _chatConnection, FC_IM_IDLEINFO, (firetalk_callback) MVChatBuddyGotIdle );
	firetalk_register_callback( _chatConnection, FC_CHAT_ROOM_MODE, (firetalk_callback) MVChatGotRoomMode );
	firetalk_register_callback( _chatConnection, FC_CHAT_JOINED, (firetalk_callback) MVChatJoinedRoom );
	firetalk_register_callback( _chatConnection, FC_CHAT_LEFT, (firetalk_callback) MVChatLeftRoom );
	firetalk_register_callback( _chatConnection, FC_CHAT_KICKED, (firetalk_callback) MVChatKicked );
	firetalk_register_callback( _chatConnection, FC_CHAT_GETMESSAGE, (firetalk_callback) MVChatGetRoomMessage );
	firetalk_register_callback( _chatConnection, FC_CHAT_GETACTION, (firetalk_callback) MVChatGetRoomAction );
	firetalk_register_callback( _chatConnection, FC_CHAT_INVITED, (firetalk_callback) MVChatInvited );
	firetalk_register_callback( _chatConnection, FC_CHAT_GOTTOPIC, (firetalk_callback) MVChatGotTopic );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_JOINED, (firetalk_callback) MVChatUserJoinedRoom );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_LEFT, (firetalk_callback) MVChatUserLeftRoom );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_OPPED, (firetalk_callback) MVChatUserOpped );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_DEOPPED, (firetalk_callback) MVChatUserDeopped );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_VOICED, (firetalk_callback) MVChatUserVoiced );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_DEVOICED, (firetalk_callback) MVChatUserDevoiced );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_KICKED, (firetalk_callback) MVChatUserKicked );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_NICKCHANGED, (firetalk_callback) MVChatUserNicknameChanged );
	firetalk_register_callback( _chatConnection, FC_CHAT_USER_AWAY, (firetalk_callback) MVChatUserAway );
	firetalk_register_callback( _chatConnection, FC_FILE_OFFER, (firetalk_callback) MVChatFileTransferAccept );
	firetalk_register_callback( _chatConnection, FC_FILE_START, (firetalk_callback) MVChatFileTransferStart );
	firetalk_register_callback( _chatConnection, FC_FILE_FINISH, (firetalk_callback) MVChatFileTransferFinish );
	firetalk_register_callback( _chatConnection, FC_FILE_ERROR, (firetalk_callback) MVChatFileTransferError );
	firetalk_register_callback( _chatConnection, FC_FILE_PROGRESS, (firetalk_callback) MVChatFileTransferStatus );
	firetalk_subcode_register_request_callback( _chatConnection, "VERSION", (firetalk_subcode_callback) MVChatSubcodeRequest );
	firetalk_subcode_register_request_callback( _chatConnection, "USERINFO", (firetalk_subcode_callback) MVChatSubcodeRequest );
	firetalk_subcode_register_request_callback( _chatConnection, "URL", (firetalk_subcode_callback) MVChatSubcodeRequest );
	firetalk_subcode_register_request_callback( _chatConnection, NULL, (firetalk_subcode_callback) MVChatSubcodeRequest );
	firetalk_subcode_register_reply_callback( _chatConnection, NULL, (firetalk_subcode_callback) MVChatSubcodeReply );
}

#pragma mark -

- (void) _registerForSleepNotifications {
	IONotificationPortRef sleepNotePort = NULL;
	CFRunLoopSourceRef rls = NULL;
	_powerConnection = IORegisterForSystemPower( (void *) self, &sleepNotePort, MVChatHandlePowerChange, &_sleepNotifier );
	if( ! _powerConnection ) return;
	rls = IONotificationPortGetRunLoopSource( sleepNotePort );
	CFRunLoopAddSource( CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode );
	CFRelease( rls );
}

- (void) _deregisterForSleepNotifications {
	IODeregisterForSystemPower( &_sleepNotifier );
	_powerConnection = NULL;
}

#pragma mark -

- (void) _confirmNewNickname:(NSString *) nickname {
	[_nickname autorelease];
	_nickname = [nickname copy];
}

- (void) _addRoomToCache:(NSString *) room withUsers:(int) users andTopic:(NSData *) topic {
	if( room ) {
		NSDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:users], @"users", topic, @"topic", [NSDate date], @"cached", nil];
		[_roomsCache setObject:info forKey:room];

		NSNotification *notification = [NSNotification notificationWithName:MVChatConnectionGotRoomInfoNotification object:self];
		[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
	}
}

- (void) _setBacklogDelay:(NSTimeInterval) delay {
	_backlogDelay = delay;
}

#pragma mark -

- (void) _setStatus:(MVChatConnectionStatus) status {
	_status = status;
}

- (void) _willConnect {
	_status = MVChatConnectionConnectingStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillConnectNotification object:self];
}

- (void) _didConnect {
	_status = MVChatConnectionConnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidConnectNotification object:self];
	[self performSelector:@selector( _joinRooms: ) withObject:nil afterDelay:0.25];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( connected: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didNotConnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidNotConnectNotification object:self];
}

- (void) _willDisconnect {
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillDisconnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( disconnecting: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didDisconnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidDisconnectNotification object:self];
}

- (void) _joinRooms:(id) sender {
	NSEnumerator *enumerator = [_joinList objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) )
		[self joinChatRoom:room];

	[_joinList removeAllObjects];	
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (void) connectScriptCommand:(NSScriptCommand *) command {
	[self connect];
}

- (void) disconnectScriptCommand:(NSScriptCommand *) command {
	[self disconnect];
}

- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSString *message = [[command evaluatedArguments] objectForKey:@"message"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];
	NSString *room = [[command evaluatedArguments] objectForKey:@"room"];
	BOOL action = [[[command evaluatedArguments] objectForKey:@"action"] boolValue];
	unsigned long enc = [[[command evaluatedArguments] objectForKey:@"encoding"] unsignedLongValue];
	NSStringEncoding encoding = NSUTF8StringEncoding;

	if( ! [message isKindOfClass:[NSString class]] || ! [message length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid message."];
		return;
	}

	if( ! user && ( ! [room isKindOfClass:[NSString class]] || ! [room length] ) ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid room."];
		return;
	}

	if( ! room && ( ! [user isKindOfClass:[NSString class]] || ! [user length] ) ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user."];
		return;
	}

	switch( enc ) {
		default:
		case 'utF8': encoding = NSUTF8StringEncoding; break;
		case 'ascI': encoding = NSASCIIStringEncoding; break;
		case 'nlAs': encoding = NSNonLossyASCIIStringEncoding; break;

		case 'isL1': encoding = NSISOLatin1StringEncoding; break;
		case 'isL2': encoding = NSISOLatin2StringEncoding; break;
		case 'isL3': encoding = (NSStringEncoding) 0x80000203; break;
		case 'isL4': encoding = (NSStringEncoding) 0x80000204; break;
		case 'isL5': encoding = (NSStringEncoding) 0x80000205; break;
		case 'isL9': encoding = (NSStringEncoding) 0x8000020F; break;

		case 'cp50': encoding = NSWindowsCP1250StringEncoding; break;
		case 'cp51': encoding = NSWindowsCP1251StringEncoding; break;
		case 'cp52': encoding = NSWindowsCP1252StringEncoding; break;

		case 'mcRo': encoding = NSMacOSRomanStringEncoding; break;
		case 'mcEu': encoding = (NSStringEncoding) 0x8000001D; break;
		case 'mcCy': encoding = (NSStringEncoding) 0x80000007; break;
		case 'mcJp': encoding = (NSStringEncoding) 0x80000001; break;
		case 'mcSc': encoding = (NSStringEncoding) 0x80000019; break;
		case 'mcTc': encoding = (NSStringEncoding) 0x80000002; break;
		case 'mcKr': encoding = (NSStringEncoding) 0x80000003; break;

		case 'ko8R': encoding = (NSStringEncoding) 0x80000A02; break;

		case 'wnSc': encoding = (NSStringEncoding) 0x80000421; break;
		case 'wnTc': encoding = (NSStringEncoding) 0x80000423; break;
		case 'wnKr': encoding = (NSStringEncoding) 0x80000422; break;

		case 'jpUC': encoding = NSJapaneseEUCStringEncoding; break;
		case 'sJiS': encoding = (NSStringEncoding) 0x80000A01; break;

		case 'krUC': encoding = (NSStringEncoding) 0x80000940; break;

		case 'scUC': encoding = (NSStringEncoding) 0x80000930; break;
		case 'tcUC': encoding = (NSStringEncoding) 0x80000931; break;
		case 'gb30': encoding = (NSStringEncoding) 0x80000632; break;
		case 'gbKK': encoding = (NSStringEncoding) 0x80000631; break;
		case 'biG5': encoding = (NSStringEncoding) 0x80000A03; break;
		case 'bG5H': encoding = (NSStringEncoding) 0x80000A06; break;
	}

	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	if( [user length] ) [self sendMessage:attributeMsg withEncoding:encoding toUser:user asAction:action];
	else if( [room length] ) [self sendMessage:attributeMsg withEncoding:encoding toChatRoom:room asAction:action];
}

- (void) sendRawMessageScriptCommand:(NSScriptCommand *) command {
	NSString *msg = [[command evaluatedArguments] objectForKey:@"message"];

	if( ! [msg isKindOfClass:[NSString class]] || ! [msg length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid raw message."];
		return;
	}

	[self sendRawMessage:[[command evaluatedArguments] objectForKey:@"message"]];
}

- (void) sendSubcodeMessageScriptCommand:(NSScriptCommand *) command {
	NSString *cmd = [[command evaluatedArguments] objectForKey:@"command"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];
	id arguments = [[command evaluatedArguments] objectForKey:@"arguments"];
	unsigned long type = [[[command evaluatedArguments] objectForKey:@"type"] unsignedLongValue];

	if( ! [cmd isKindOfClass:[NSString class]] || ! [cmd length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode command."];
		return;
	}

	if( ! [user isKindOfClass:[NSString class]] || ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode user."];
		return;
	}

	if( [arguments isKindOfClass:[NSNull class]] ) arguments = nil;

	if( arguments && ! [arguments isKindOfClass:[NSString class]] && ! [arguments isKindOfClass:[NSArray class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode arguments."];
		return;
	}

	NSString *argumnentsString = nil;
	if( [arguments isKindOfClass:[NSArray class]] ) {
		NSEnumerator *enumerator = [arguments objectEnumerator];
		id arg = nil;

		argumnentsString = [NSMutableString stringWithFormat:@"%@", [enumerator nextObject]];

		while( ( arg = [enumerator nextObject] ) )
			[(NSMutableString *)argumnentsString appendFormat:@" %@", arg];
	} else argumnentsString = arguments;

	if( type == 'srpL' ) [self sendSubcodeReply:cmd toUser:user withArguments:argumnentsString];
	else [self sendSubcodeRequest:cmd toUser:user withArguments:argumnentsString];
}

- (void) returnFromAwayStatusScriptCommand:(NSScriptCommand *) command {
	[self clearAwayStatus];
}

- (void) joinChatRoomScriptCommand:(NSScriptCommand *) command {
	id rooms = [[command evaluatedArguments] objectForKey:@"room"];

	if( rooms && ! [rooms isKindOfClass:[NSString class]] && ! [rooms isKindOfClass:[NSArray class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid chat room to join."];
		return;
	}

	NSArray *rms = nil;
	if( [rooms isKindOfClass:[NSString class]] )
		rms = [NSArray arrayWithObject:rooms];
	else rms = rooms;

	[self joinChatRooms:rms];
}

- (void) sendFileScriptCommand:(NSScriptCommand *) command {
	NSString *path = [[command evaluatedArguments] objectForKey:@"path"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];

	if( ! [path isKindOfClass:[NSString class]] || ! [path length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid file path."];
		return;
	}

	if( ! [user isKindOfClass:[NSString class]] || ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user."];
		return;
	}

	[self sendFile:path toUser:user];
}

- (NSString *) urlString {
	return [[self url] absoluteString];
}

- (NSTextStorage *) scriptTypedAwayMessage {
	return [[[NSTextStorage alloc] initWithAttributedString:_awayMessage] autorelease];
}

- (void) setScriptTypedAwayMessage:(NSString *) message {
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	[self setAwayStatusWithMessage:attributeMsg];
}
@end

#pragma mark -

@implementation MVChatScriptPlugin (MVChatScriptPluginConnectionSupport)
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psR1", user, @"psR2", connection, @"psR3", nil];
	id result = [self callScriptHandler:'psRX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psL1", user, @"psL2", connection, @"psL3", nil];
	id result = [self callScriptHandler:'psLX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	if( ! [self callScriptHandler:'cTsX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	if( ! [self callScriptHandler:'dFsX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}
@end

#pragma mark -

@implementation NSURL (NSURLChatAdditions)
- (BOOL) isChatURL {
	if( [[self scheme] isEqualToString:@"irc"] ) return YES;
	return NO;
}

- (BOOL) isChatRoomURL {
	BOOL isRoom = NO;
	if( [[self scheme] isEqualToString:@"irc"] ) {
		if( [self fragment] ) {
			if( [[self fragment] length] > 0 ) isRoom = YES;
		} else if( [self path] && [[self path] length] >= 2 ) {
			if( [[[self path] substringFromIndex:1] hasPrefix:@"&"] || [[[self path] substringFromIndex:1] hasPrefix:@"+"] )
				isRoom = YES;
		}
	}
	return isRoom;
}

- (BOOL) isDirectChatURL {
	BOOL isDirect = NO;
	if( [[self scheme] isEqualToString:@"irc"] ) {
		if( [self fragment] ) {
			if( [[self fragment] length] > 0 ) isDirect = NO;
		} else if( [self path] ) {
			if( [[self path] length] >= 2 && [[[self path] substringFromIndex:1] hasPrefix:@"&"] || [[[self path] substringFromIndex:1] hasPrefix:@"+"] ) {
				isDirect = NO;
			} else isDirect = YES;
		}
	}
	return isDirect;
}
@end
