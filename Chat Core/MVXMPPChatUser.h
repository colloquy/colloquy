#import "MVChatUser.h"
#import "MVChatUserPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class MVXMPPChatConnection;
@class XMPPJID;

@interface MVXMPPChatUser : MVChatUser {
@private
	BOOL _roomMember;
}
- (id) initWithJabberID:(XMPPJID *) identifier andConnection:(MVXMPPChatConnection *) connection;
@end

@interface MVXMPPChatUser (MVXMPPChatUserPrivate)
- (void) _setRoomMember:(BOOL) member;
- (BOOL) _isRoomMember;
@end

NS_ASSUME_NONNULL_END
