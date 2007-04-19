#import "MVChatUser.h"
#import "MVChatUserPrivate.h"

@class MVXMPPChatConnection;
@class JabberID;

@interface MVXMPPChatUser : MVChatUser {
@private
	BOOL _roomMember;
}
- (id) initWithJabberID:(JabberID *) identifier andConnection:(MVXMPPChatConnection *) connection;
@end

@interface MVXMPPChatUser (MVXMPPChatUserPrivate)
- (void) _setRoomMember:(BOOL) member;
- (BOOL) _isRoomMember;
@end
