#import "MVChatRoom.h"

@class MVIRCChatConnection;

@interface MVIRCChatRoom : MVChatRoom {}
- (id) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection;
@end
