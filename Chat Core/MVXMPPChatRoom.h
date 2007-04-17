#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"

@class MVXMPPChatConnection;
@class MVXMPPChatUser;
@class JabberID;

@interface MVXMPPChatRoom : MVChatRoom {
@private
	MVChatUser *_localMemberUser;
}
- (id) initWithJabberID:(JabberID *) identifier andConnection:(MVXMPPChatConnection *) connection;
@end

@interface MVXMPPChatRoom (MVXMPPChatRoomPrivate)
- (void) _setLocalMemberUser:(MVChatUser *) user;
@end
