#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@class MVIRCChatConnection;

@interface MVIRCChatRoom : MVChatRoom {
@private
	BOOL _namesSynced;
	BOOL _bansSynced;
}
- (id) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection;
- (NSString *) modifyAddressForBan:(MVChatUser *) user;
@end

#pragma mark -

@interface MVChatRoom (MVIRCChatRoomPrivate)
- (BOOL) _namesSynced;
- (void) _setNamesSynced:(BOOL) synced;
- (BOOL) _bansSynced;
- (void) _setBansSynced:(BOOL) synced;
@end

NS_ASSUME_NONNULL_END
