#import "MVChatRoom.h"

@class MVSILCChatConnection;

@interface MVSILCChatRoom : MVChatRoom {}
- (id) initWithName:(NSString *) name andConnection:(MVSILCChatConnection *) connection andUniqueIdentifier:(NSString *) identifier;
@end
