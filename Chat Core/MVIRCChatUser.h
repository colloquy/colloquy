#import "MVChatUser.h"
#import "MVChatUserPrivate.h"

@class MVIRCChatConnection;

@interface MVIRCChatUser : MVChatUser {
	BOOL _hasPendingRefreshInformationRequest : 1;
}
- (id) initLocalUserWithConnection:(MVIRCChatConnection *) connection;
- (id) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection;
@end
