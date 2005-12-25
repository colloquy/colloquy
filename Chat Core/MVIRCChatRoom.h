#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"

@class MVIRCChatConnection;

@interface MVIRCChatRoom : MVChatRoom {
	BOOL _namesSynced;
}
- (id) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection;
@end

#pragma mark -

@interface MVChatRoom (MVIRCChatRoomPrivate)
- (BOOL) _namesSynced;
- (void) _setNamesSynced:(BOOL) synced;
@end