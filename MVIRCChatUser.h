#import "MVChatUser.h"

@class MVIRCChatConnection;

@interface MVIRCChatUser : MVChatUser {}
- (id) initLocalUserWithConnection:(MVIRCChatConnection *) connection;
- (id) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection;
@end