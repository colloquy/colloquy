#import "MVChatUser.h"
#import "MVChatUserPrivate.h"

@class MVXMPPChatConnection;
@class JabberID;

@interface MVXMPPChatUser : MVChatUser {
@private
	JabberID *_identifier;
}
- (id) initLocalUserWithConnection:(MVXMPPChatConnection *) connection;
- (id) initWithJabberID:(JabberID *) identifier andConnection:(MVXMPPChatConnection *) connection;
@end
