#import <string.h>
#import <Cocoa/Cocoa.h>
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "MVChatConnection.h"
#import "MVChatWindowController.h"
#import "NSAttributedStringAdditions.h"
#import "firetalk.h"

typedef void (*firetalk_callback)(firetalk_t, void *, ...);
typedef void (*firetalk_subcode_callback)(firetalk_t, void *, const char * const, const char * const, const char * const);

#pragma mark -

NSString *MVChatConnectionWillConnectNotification = @"MVChatConnectionWillConnectNotification";
NSString *MVChatConnectionDidConnectNotification = @"MVChatConnectionDidConnectNotification";
NSString *MVChatConnectionDidNotConnectNotification = @"MVChatConnectionDidNotConnectNotification";
NSString *MVChatConnectionWillDisconnectNotification = @"MVChatConnectionWillDisconnectNotification";
NSString *MVChatConnectionDidDisconnectNotification = @"MVChatConnectionDidDisconnectNotification";
NSString *MVChatConnectionDidGetErrorNotification = @"MVChatConnectionDidGetErrorNotification";

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
- (io_connect_t) _powerConnection;
- (firetalk_t) _firetalkConnection;
- (void) _executeRunLoopCheck:(NSTimer *) timer;
- (void) _registerCallbacks;
- (void) _registerForSleepNotifications;
- (void) _deregisterForSleepNotifications;
- (void) _confirmNewNickname:(NSString *) nickname;
- (void) _addRoomToCache:(NSString *) room withUsers:(int) users andTopic:(NSString *) topic;
- (void) _setBacklogDelay:(NSTimeInterval) delay;
- (void) _setStatus:(MVChatConnectionStatus) status;
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
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

void MVChatLoad( void *c, void *cs, const char * const nickname ) {
}

void MVChatConnected( void *c, void *cs ) {
	MVChatConnection *self = cs;
	NSEnumerator *enumerator = [[MVChatWindowController roomChatWindowsForConnection:self] keyEnumerator];
	id key = nil;
	[self _didConnect];
	while( ( key = [enumerator nextObject] ) )
		[self joinChatForRoom:key];
}

void MVChatConnectionFailed( void *c, void *cs, const int error, const char * const reason ) {
	MVChatConnection *self = cs;
	[self _didNotConnect];
	switch( error ) {
		case FE_SOCKET:
		case FE_RESOLV:
			if( NSRunCriticalAlertPanel( NSLocalizedString( @"Could not connect to Chat server", chat invalid password dialog title ), NSLocalizedString( @"The server is disconnected or refusing connections from your computer. Make sure you are conencted to the internet and have access to the server.", chat invalid password dialog message ), NSLocalizedString( @"Retry", retry connecting to server ), NSLocalizedString( @"Cancel", cancel button ), nil ) == NSOKButton )
				[self connect];
			break;
		case FE_BADUSERPASS:
			NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat password is invalid", chat invalid password dialog title ), NSLocalizedString( @"The password you specified is invalid and a connection could not be made without a proper password. Make sure you have access to the server.", chat invalid password dialog message ), nil, nil, nil );
			break;
		case FE_BADUSER:
			NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat nickname could not be used", chat invalid nickname dialog title ), [NSString stringWithFormat:NSLocalizedString( @"The nickname you specified is in use or invalid on this server. A connection could not be made with '%@' as your nickname.", chat invalid nicknames dialog message ), [self nickname]], nil, nil, nil );
			break;
		default: NSLog( @"unable to login to irc, error %d (%s)", error, reason );
	}
}

void MVChatDisconnect( void *c, void *cs, const int error ) {
	MVChatConnection *self = cs;
	MVChatConnectionStatus status = [self status];
	[self _didDisconnect];
	switch( error ) {
		case FE_USERDISCONNECT:
			break;
		case FE_DISCONNECT:
		case FE_PACKET:
		case FE_PACKETSIZE:
			if( status == MVChatConnectionConnectedStatus ) {
				if( NSRunCriticalAlertPanel( NSLocalizedString( @"You have been disconnected", title of the you have been disconnected error ), NSLocalizedString( @"The server may have shut down for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", connection droped ), NSLocalizedString( @"Reconnect", retry connecting to server button ), @"Cancel", nil ) == NSOKButton )
					[self connect];
			} else {
				if( NSRunCriticalAlertPanel( NSLocalizedString( @"Could not connect", title of the could not connect error ), NSLocalizedString( @"The server may be down for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", connection failed ), NSLocalizedString( @"Retry", connect to server button ), @"Cancel", nil ) == NSOKButton )
					[self connect];
			}
			NSLog( @"connection lost, error: %s", firetalk_strerror( error ) );
			break;
		default: NSLog( @"connection lost, error: %s", firetalk_strerror( error ) );
	}
}

void MVChatError( void *c, void *cs, const int error, const char * const roomoruser ) {
	MVChatConnection *self = cs;
	NSBeep();
	switch( error ) {
		case FE_BADUSER:
			if( roomoruser && strlen( roomoruser ) >= 1 && strchr( "#&+", roomoruser[0] ) )
				[[MVChatWindowController chatWindowForRoom:[[NSString stringWithUTF8String:roomoruser] lowercaseString] withConnection:self ifExists:YES] disconnected];
			else if( roomoruser ) [[MVChatWindowController chatWindowWithUser:[NSString stringWithUTF8String:roomoruser] withConnection:self ifExists:YES] unavailable];
			else {
				[MVChatWindowController changeSelfInChatWindowsTo:[self nickname] forConnection:self];
				NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat nickname could not be used", chat invalid nickname dialog title ), NSLocalizedString( @"The nickname you specified is in use or invalid on this server.", chat invalid nickname dialog message ), nil, nil, nil );
			}
			break;
		default: NSLog( @"error from user/room %s: %s", roomoruser, firetalk_strerror( error ) );
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidGetErrorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:( roomoruser ? [NSString stringWithUTF8String:roomoruser] : [NSNull null] ), @"target", [NSNumber numberWithInt:error], @"error", nil]];
}

void MVChatBackLog( void *c, void *cs, const double backlog ) {
	MVChatConnection *self = cs;
	[self _setBacklogDelay:backlog];
}

#pragma mark -

void MVChatNeedPassword( void *c, void *cs, char *password, const int size ) {
	MVChatConnection *self = cs;
	const char *pass = [[self password] UTF8String];
	if( ! pass ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionNeedPasswordNotification object:self userInfo:nil];
		return;
	}
	strncpy( password, pass, size );
}

#pragma mark -

void MVChatGetMessage( void *c, void *cs, const char * const who, const int automessage, const char * const message ) {
	MVChatConnection *self = cs;
	MVChatWindowController *window = nil;
	NSData *msgData = nil;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSCParameterAssert( message != NULL );

	msgData = [NSData dataWithBytes:message length:strlen( message )];

	window = [MVChatWindowController chatWindowWithUser:[NSString stringWithUTF8String:who] withConnection:self ifExists:YES];
	if( ! automessage || window ) {
		[[MVChatWindowController chatWindowWithUser:[NSString stringWithUTF8String:who] withConnection:self ifExists:NO] addHTMLMessageToDisplay:msgData fromUser:[NSString stringWithUTF8String:who] asAction:NO asAlert:NO];
	} else NSLog( @"%@ notice: %@", [NSString stringWithUTF8String:who], [NSString stringWithUTF8String:message] );
	[MVChatWindowController updateChatWindowsMember:[NSString stringWithUTF8String:who] withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:0] forKey:@"idle"] forConnection:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"from", [NSNumber numberWithBool:automessage], @"auto", msgData, @"message", nil]];
}

void MVChatGetAction( void *c, void *cs, const char * const who, const int automessage, const char * const message ) {
	MVChatConnection *self = cs;
	NSData *msgData = nil;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSCParameterAssert( message != NULL );

	msgData = [NSData dataWithBytes:message length:strlen( message )];

	if( ! automessage ) {
		[[MVChatWindowController chatWindowWithUser:[NSString stringWithUTF8String:who] withConnection:self ifExists:NO] addHTMLMessageToDisplay:msgData fromUser:[NSString stringWithUTF8String:who] asAction:YES asAlert:NO];
	} else NSLog( @"%@ notice: %@", [NSString stringWithUTF8String:who], [NSString stringWithUTF8String:message] );
	[MVChatWindowController updateChatWindowsMember:[NSString stringWithUTF8String:who] withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:0] forKey:@"idle"] forConnection:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"from", [NSNumber numberWithBool:automessage], @"auto", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
}

#pragma mark -

void MVChatBuddyOnline( void *c, void *cs, const char * const who ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSLog( @"buddy online: %s", who );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyOffline( void *c, void *cs, const char * const who ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSLog( @"buddy offline: %s", who );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyAway( void *c, void *cs, const char * const who ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSLog( @"buddy away: %s", who );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyUnaway( void *c, void *cs, const char * const who ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	NSLog( @"buddy unaway: %s", who );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsUnawayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", nil]];
}

void MVChatBuddyGotIdle( void *c, void *cs, const char * const who, const long idletime ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	[MVChatWindowController updateChatWindowsMember:[NSString stringWithUTF8String:who] withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:idletime] forKey:@"idle"] forConnection:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionBuddyIsIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", [NSNumber numberWithLong:idletime], @"idle", nil]];
	NSLog( @"buddy idle: %s, %d minute(s)", who, idletime );
}

void MVChatListBuddy( void *c, void *cs, const char * const nickname, const int online, const int away ) {
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( nickname != NULL );
	NSLog(@"listbuddy: %s online: %d, away: %d", nickname, online, away );
}

#pragma mark -

void MVChatGotInfo( void *c, void *cs, const char * const who, const char * const info, const int warning, const int idle, const int flags ) {
	MVChatConnection *self = cs;
	NSDictionary *infoDic = nil;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( who != NULL );
	infoDic = [NSDictionary dictionaryWithObjectsAndKeys:( info ? [NSString stringWithUTF8String:info] : [NSNull null] ), @"info", [NSNumber numberWithUnsignedInt:warning], @"warning", [NSNumber numberWithUnsignedInt:idle], @"idle", [NSNumber numberWithUnsignedInt:flags], @"flags", nil];
	[MVChatWindowController updateChatWindowsMember:[NSString stringWithUTF8String:who] withInfo:infoDic forConnection:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotUserInfoNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:who], @"who", infoDic, @"info", nil]];
}

void MVChatListRoom( void *c, void *cs, const char * const room, const int users, const char * const topic ) {
	MVChatConnection *self = cs;
	NSString *r = nil, *t = nil;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( topic != NULL );
	r = [NSString stringWithUTF8String:room];
	t = [NSString stringWithUTF8String:topic];
	[self _addRoomToCache:r withUsers:users andTopic:t];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomInfoNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:r, @"room", [NSNumber numberWithUnsignedInt:users], @"users", t, @"topic", nil]];
}

#pragma mark -

void MVChatJoinedRoom( void *c, void *cs, const char * const room ) {
	MVChatConnection *self = cs;
	MVChatWindowController *window = nil;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	window = [MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", nil]];
}

void MVChatLeftRoom( void *c, void *cs, const char * const room ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	[MVChatWindowController disposeWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", nil]];
}

void MVChatGetRoomMessage( void *c, void *cs, const char * const room, const char * const from, const int automessage, const char * message ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( message != NULL );
	{
		MVChatWindowController *window = [MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES];
		NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];
		[window addHTMLMessageToDisplay:msgData fromUser:[NSString stringWithUTF8String:from] asAction:NO asAlert:NO];

		[MVChatWindowController updateChatWindowsMember:[NSString stringWithUTF8String:from] withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:0] forKey:@"idle"] forConnection:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:from], @"from", [NSNumber numberWithBool:automessage], @"auto", msgData, @"message", nil]];
	}
}

void MVChatGetRoomAction( void *c, void *cs, const char * const room, const char * const from, const int automessage, const char * message ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( message != NULL );
	{
		MVChatWindowController *window = [MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES];
		NSData *msgData = [NSData dataWithBytes:message length:strlen(message)];
		[window addHTMLMessageToDisplay:msgData fromUser:[NSString stringWithUTF8String:from] asAction:YES asAlert:NO];

		[MVChatWindowController updateChatWindowsMember:[NSString stringWithUTF8String:from] withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:0] forKey:@"idle"] forConnection:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:from], @"from", [NSNumber numberWithBool:automessage], @"auto", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
	}
}

#pragma mark -

void MVChatKicked( void *c, void *cs, const char * const room, const char * const by, const char * const reason ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	{
		NSData *msgData = [NSData dataWithBytes:reason length:(reason ? strlen(reason) : 0)];
		[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] kickedFromChatBy:(by?[NSString stringWithUTF8String:by]:nil) forReason:( reason ? msgData : nil )];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", ( by ? [NSString stringWithUTF8String:by] : [NSNull null] ), @"who", ( reason ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
	}
}

void MVChatInvited( void *c, void *cs, const char * const room, const char * const from, const char * message ) {
	NSWindow *win = nil;
	MVChatConnection *self = cs;
#pragma unused(message)
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( from != NULL );
	win = [[MVChatWindowController chatWindowWithUser:[NSString stringWithUTF8String:from] withConnection:self ifExists:YES] window];
	if( NSRunAlertPanelRelativeToWindow( NSLocalizedString( @"Invited to Chat", invited to a chat room - sheet title ), [NSString stringWithFormat:NSLocalizedString( @"You have been invited to chat in the %@ room by %@.", invited to chat room description - sheet message ), [NSString stringWithUTF8String:room], [NSString stringWithUTF8String:from]], nil, NSLocalizedString( @"Refuse", refuse button name ), nil, win ) == NSOKButton ) {
		[self joinChatForRoom:[NSString stringWithUTF8String:room]];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionInvitedToRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:from], @"from", nil]];
}

void MVChatGotTopic( void *c, void *cs, const char * const room, const char * const topic, const char * const author ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	{
		NSData *msgData = [NSData dataWithBytes:topic length:(topic ? strlen(topic) : 0)];
		[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] changeTopic:( topic ? msgData : nil ) by:( author ? [NSString stringWithUTF8String:author] : nil )];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", ( author ? (id) [NSString stringWithUTF8String:author] : (id) [NSNull null] ), @"author", ( topic ? (id) msgData : (id) [NSNull null] ), @"topic", nil]];
	}
}

#pragma mark -

void MVChatUserJoinedRoom( void *c, void *cs, const char * const room, const char * const who, const int previousmember ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	if( previousmember ) firetalk_im_get_info( c, who );
	[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] addMemberToChat:[NSString stringWithUTF8String:who] asPreviousMember:(BOOL) previousmember];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", [NSNumber numberWithBool:previousmember], @"previousMember", nil]];
}

void MVChatUserLeftRoom( void *c, void *cs, const char * const room, const char * const who, const char * const reason ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	{
		NSData *msgData = [NSData dataWithBytes:reason length:(reason ? strlen(reason) : 0)];
		[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] removeChatMember:[NSString stringWithUTF8String:who] withReason:( reason ? msgData : nil)];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", ( reason ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
	}
}

void MVChatUserNicknameChanged( void *c, void *cs, const char * const room, const char * const oldnick, const char * const newnick ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( oldnick != NULL );
	NSCParameterAssert( newnick != NULL );

	[MVChatWindowController changeMemberInChatWindowsFrom:[NSString stringWithUTF8String:oldnick] to:[NSString stringWithUTF8String:newnick] forConnection:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserNicknameChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:oldnick], @"oldNickname", [NSString stringWithUTF8String:newnick], @"newNickname", nil]];
}

#pragma mark -

void MVChatNewNickname( void *c, void *cs, const char * const newnick ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( newnick != NULL );
	[MVChatWindowController changeSelfInChatWindowsTo:[NSString stringWithUTF8String:newnick] forConnection:self];
	[self _confirmNewNickname:[NSString stringWithUTF8String:newnick]];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionNicknameAcceptedNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:newnick], @"nickname", nil]];
}

#pragma mark -

void MVChatUserOpped( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] promoteChatMember:[NSString stringWithUTF8String:who] by:(by?[NSString stringWithUTF8String:by]:nil)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserOppedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserDeopped( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] demoteChatMember:[NSString stringWithUTF8String:who] by:(by?[NSString stringWithUTF8String:by]:nil)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserDeoppedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserVoiced( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] voiceChatMember:[NSString stringWithUTF8String:who] by:(by?[NSString stringWithUTF8String:by]:nil)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserVoicedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserDevoiced( void *c, void *cs, const char * const room, const char * const who, const char * const by ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] devoiceChatMember:[NSString stringWithUTF8String:who] by:(by?[NSString stringWithUTF8String:by]:nil)];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserDevoicedInRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", nil]];
}

void MVChatUserKicked( void *c, void *cs, const char * const room, const char * const who, const char * const by, const char * const reason ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( room != NULL );
	NSCParameterAssert( who != NULL );
	{
		NSData *msgData = [NSData dataWithBytes:reason length:(reason ? strlen(reason) : 0)];
		[[MVChatWindowController chatWindowForRoom:[NSString stringWithUTF8String:room] withConnection:self ifExists:YES] chatMemberKicked:[NSString stringWithUTF8String:who] by:(by?[NSString stringWithUTF8String:by]:nil) forReason:( reason ? msgData : nil )];
		[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionUserKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:room], @"room", [NSString stringWithUTF8String:who], @"who", (by?[NSString stringWithUTF8String:by]:[NSNull null]), @"by", msgData, @"reason", nil]];
	}
}

#pragma mark -

void MVChatFileTransferAccept( void *c, void *cs, const void * const filehandle, const char * const from, const char * const filename, const long size ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( filename != NULL );
	NSCParameterAssert( size >= 0 );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferAvailableNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSString stringWithUTF8String:from], @"from", [NSString stringWithUTF8String:filename], @"filename", [NSNumber numberWithUnsignedLong:size], @"size", nil]];
}

void MVChatFileTransferStart( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferStartedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", nil]];
}

void MVChatFileTransferFinish( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct, const long size ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	NSCParameterAssert( size >= 0 );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferFinishedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSNumber numberWithUnsignedLong:size], @"size", nil]];
}

void MVChatFileTransferError( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct, const int error ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferErrorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSNumber numberWithInt:error], @"error", nil]];
}

void MVChatFileTransferStatus( void *c, void *cs, const void * const filehandle, const void * const clientfilestruct, const long bytes, const long size ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( filehandle != NULL );
	NSCParameterAssert( bytes >= 0 );
	NSCParameterAssert( size >= 0 );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", filehandle], @"identifier", [NSNumber numberWithUnsignedLong:bytes], @"transfered", [NSNumber numberWithUnsignedLong:size], @"size", nil]];
}

#pragma mark -

void MVChatSubcodeRequest( void *c, void *cs, const char * const from, const char * const command, const char * const args ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( command != NULL );

	if( ! strcasecmp( command, "VERSION" ) ) {
		NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];
		NSString *reply = [NSString stringWithFormat:@"%@ %@ - %@ %@ - http://www.javelin.cc?colloquy", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductUserVisibleVersion"]];
		firetalk_subcode_send_reply( c, from, "VERSION", [reply UTF8String] );
		return;
	} else 	if( ! strcasecmp( command, "USERINFO" ) ) {
//		firetalk_subcode_send_reply( c, from, "USERINFO", "" );
	} else 	if( ! strcasecmp( command, "URL" ) ) {
//		firetalk_subcode_send_reply( c, from, "URL", "" );
	}

	NSLog( @"subcode request from '%s' for '%s' with args '%s'", from, command, args );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionSubcodeRequestNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:from], @"from", [NSString stringWithUTF8String:command], @"command", (args ? (id) [NSString stringWithUTF8String:args] : (id) [NSNull null]), @"arguments", nil]];
}

void MVChatSubcodeReply( void *c, void *cs, const char * const from, const char * const command, const char * const args ) {
	MVChatConnection *self = cs;
	NSCParameterAssert( c != NULL );
	NSCParameterAssert( from != NULL );
	NSCParameterAssert( command != NULL );

	NSLog( @"subcode reply from '%s' for '%s' with args '%s'", from, command, args );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionSubcodeReplyNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:from], @"from", [NSString stringWithUTF8String:command], @"command", (args ? (id) [NSString stringWithUTF8String:args] : (id) [NSNull null]), @"arguments", nil]];
}

#pragma mark -

@implementation MVChatConnection
- (id) init {
	self = [super init];

	_status = MVChatConnectionDisconnectedStatus;
	_chatConnection = firetalk_create_handle( FP_IRC, (void *) self );
	_joinList = [[NSMutableArray array] retain];
	_roomsCache = [[NSMutableDictionary dictionary] retain];

	[self _registerCallbacks];
	[self _registerForSleepNotifications];

	_firetalkSelectTimer = [[NSTimer scheduledTimerWithTimeInterval:.100 target:self selector:@selector( _executeRunLoopCheck: ) userInfo:nil repeats:YES] retain];

	return self;
}

- (id) initWithURL:(NSURL *) url {
	if( ! [[url scheme] isEqualToString:@"irc"] ) return nil;
	self = [self initWithServer:[url host] port:[[url port] unsignedShortValue] user:[url user]];
	[self setPassword:[url password]];
	return self;
}

- (id) initWithServer:(NSString *) server port:(unsigned short) port user:(NSString *) nickname {
	self = [self init];
	[self setNickname:nickname];
	[self setServer:server];
	[self setServerPort:port];
	return self;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 ) {
		[_firetalkSelectTimer invalidate];
	}
	[super release];
}

- (void) dealloc {
	[self _deregisterForSleepNotifications];

	[_nickname autorelease];
	[_password autorelease];
	[_server autorelease];
	[_joinList autorelease];
	[_roomsCache autorelease];
	[_firetalkSelectTimer autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	firetalk_destroy_handle( _chatConnection );
	_chatConnection = NULL;
	_nickname = nil;
	_password = nil;
	_server = nil;
	_joinList = nil;
	_roomsCache = nil;
	_firetalkSelectTimer = nil;

	[super dealloc];
}

#pragma mark -

- (void) connect {
	if( ! _server ) return;
	if( ! _nickname ) return;
	if( [self status] == MVChatConnectionConnectingStatus ) return;
	if( [self isConnected] ) [self disconnect];
	[self _willConnect];
	firetalk_signon( _chatConnection, [_server UTF8String], _port, [_nickname UTF8String] );
}

- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname {
	if( [self isConnected] ) [self disconnect];

	[self setNickname:nickname];
	[self setServer:server];
	[self setServerPort:port];

	[self _willConnect];
	firetalk_signon( _chatConnection, [server UTF8String], port, [nickname UTF8String] );
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
	if( _nickname && _port ) url = [NSString stringWithFormat:@"irc://%@@%@:%hu", _nickname, _server, _port];
	else if( _nickname && ! _port ) url = [NSString stringWithFormat:@"irc://%@@%@", _nickname, _server];
	else url = [NSString stringWithFormat:@"irc://%@", _server];
	return [[[NSURL URLWithString:url] retain] autorelease];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	if( [self isConnected] ) {
		if( nickname && ! [nickname isEqualToString:_nickname] ) {
			firetalk_set_nickname( _chatConnection, [nickname UTF8String] );
		}
	} else [self _confirmNewNickname:nickname];
}

- (NSString *) nickname {
	return [[_nickname copy] autorelease];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	if( [self isConnected] && [password length] && ! [password isEqualToString:_password] ) {
		firetalk_set_password( _chatConnection, [_password UTF8String], [password UTF8String] );
	}
	[_password autorelease];
	if( [password length] ) _password = [password copy];
	else _password = nil;
}

- (NSString *) password {
	return [[_password copy] autorelease];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	[_server autorelease];
	_server = [server copy];
}

- (NSString *) server {
	return [[_server copy] autorelease];
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	_port = ( port ? port : 6667 );
}

- (unsigned short) serverPort {
	return _port;
}

#pragma mark -

- (void) sendMessageToUser:(NSString *) user attributedMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	if( [self isConnected] ) {
		NSData *encodedData = [MVChatWindowController flattenedHTMLDataForMessage:message withEncoding:encoding];

		if( action ) firetalk_im_send_action( _chatConnection, [user UTF8String], (char *) [encodedData bytes], 0 );
		else firetalk_im_send_message( _chatConnection, [user UTF8String], (char *) [encodedData bytes], 0 );

		[MVChatWindowController updateChatWindowsMember:_nickname withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:0] forKey:@"idle"] forConnection:self];
	} else [[MVChatWindowController chatWindowWithUser:user withConnection:self ifExists:YES] disconnected];
}

- (void) sendMessageToChatRoom:(NSString *) room attributedMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	if( [self isConnected] ) {
		NSData *encodedData = [MVChatWindowController flattenedHTMLDataForMessage:message withEncoding:encoding];

		if( action ) firetalk_chat_send_action( _chatConnection, [[room lowercaseString] UTF8String], (char *) [encodedData bytes], 0 );
		else firetalk_chat_send_message( _chatConnection, [[room lowercaseString] UTF8String], (char *) [encodedData bytes], 0 );

		[MVChatWindowController updateChatWindowsMember:_nickname withInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:0] forKey:@"idle"] forConnection:self];
	} else [[MVChatWindowController chatWindowForRoom:[room lowercaseString] withConnection:self ifExists:YES] disconnected];
}

#pragma mark -

- (void) sendFileToUser:(NSString *) user withFilePath:(NSString *) path {
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

- (void) joinChatForRoom:(NSString *) room {
	if( [self isConnected] ) firetalk_chat_join( _chatConnection, [[room lowercaseString] UTF8String] );
	else [_joinList addObject:room];
}

- (void) partChatForRoom:(NSString *) room {
	if( [self isConnected] ) firetalk_chat_part( _chatConnection, [[room lowercaseString] UTF8String] );
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

- (void) fetchInformationForUser:(NSString *) user {
	NSParameterAssert( user != nil );
	if( [self isConnected] ) firetalk_im_get_info( _chatConnection, [user UTF8String] );
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

- (NSDictionary *) roomListResults {
	return [[_roomsCache retain] autorelease];
}

#pragma mark -

- (void) setAwayStatusWithMessage:(NSString *) message {
	if( [self isConnected] ) {
		if( [message length] ) firetalk_set_away( _chatConnection, [message UTF8String] );
		else firetalk_set_away( _chatConnection, NULL );
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
- (io_connect_t) _powerConnection {
	return _powerConnection;
}

- (firetalk_t) _firetalkConnection {
	return _chatConnection;
}

#pragma mark -

- (void) _executeRunLoopCheck:(NSTimer *) timer {
	struct timeval timeout = { 0, 050 };
	if( firetalk_select_custom( 0, NULL, NULL, NULL, &timeout ) < 0 ) {
		NSLog( @"firetalk_select: %s", firetalk_strerror( firetalkerror ) );
	}
}

- (void) _registerCallbacks {
	if( ! _chatConnection ) return;
	firetalk_register_callback( _chatConnection, FC_DOINIT, (firetalk_callback) MVChatLoad );
	firetalk_register_callback( _chatConnection, FC_CONNECTED, (firetalk_callback) MVChatConnected );
	firetalk_register_callback( _chatConnection, FC_CONNECTFAILED, (firetalk_callback) MVChatConnectionFailed );
	firetalk_register_callback( _chatConnection, FC_DISCONNECT, (firetalk_callback) MVChatDisconnect );
	firetalk_register_callback( _chatConnection, FC_ERROR, (firetalk_callback) MVChatError );
	firetalk_register_callback( _chatConnection, FC_BACKLOG, (firetalk_callback) MVChatBackLog );
	firetalk_register_callback( _chatConnection, FC_NEWNICK, (firetalk_callback) MVChatNewNickname );
	firetalk_register_callback( _chatConnection, FC_NEEDPASS, (firetalk_callback) MVChatNeedPassword );
	firetalk_register_callback( _chatConnection, FC_IM_GETMESSAGE, (firetalk_callback) MVChatGetMessage );
	firetalk_register_callback( _chatConnection, FC_IM_GETACTION, (firetalk_callback) MVChatGetAction );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYONLINE, (firetalk_callback) MVChatBuddyOnline );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYOFFLINE, (firetalk_callback) MVChatBuddyOffline );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYAWAY, (firetalk_callback) MVChatBuddyAway );
	firetalk_register_callback( _chatConnection, FC_IM_BUDDYUNAWAY, (firetalk_callback) MVChatBuddyUnaway );
	firetalk_register_callback( _chatConnection, FC_IM_LISTBUDDY, (firetalk_callback) MVChatListBuddy );
	firetalk_register_callback( _chatConnection, FC_IM_LISTROOM, (firetalk_callback) MVChatListRoom );
	firetalk_register_callback( _chatConnection, FC_IM_GOTINFO, (firetalk_callback) MVChatGotInfo );
	firetalk_register_callback( _chatConnection, FC_IM_IDLEINFO, (firetalk_callback) MVChatBuddyGotIdle );
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

- (void) _addRoomToCache:(NSString *) room withUsers:(int) users andTopic:(NSString *) topic {
	if( room ) {
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:users], @"users", ( topic ? (id) topic : (id) [NSNull null] ), @"topic", [NSDate date], @"cached", nil];
		[_roomsCache setObject:info forKey:room];
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
	NSEnumerator *enumerator = [_joinList objectEnumerator];
	NSString *room = nil;

	_status = MVChatConnectionConnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidConnectNotification object:self];

	while( ( room = [enumerator nextObject] ) )
		[self joinChatForRoom:room];

	[_joinList removeAllObjects];
}

- (void) _didNotConnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidNotConnectNotification object:self];
}

- (void) _willDisconnect {
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillDisconnectNotification object:self];
}

- (void) _didDisconnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidDisconnectNotification object:self];
}
@end
