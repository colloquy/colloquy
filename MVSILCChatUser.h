#import "MVChatUser.h"

@class MVSILCChatConnection;

@interface MVSILCChatUser : MVChatUser {}
- (id) initLocalUserWithConnection:(MVSILCChatConnection *) connection;
- (id) initWithNickname:(NSString *) nickname andConnection:(MVSILCChatConnection *) connection andUniqueIdentifier:(NSString *) identifier;
@end