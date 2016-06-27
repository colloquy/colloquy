#import <Foundation/Foundation.h>

#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"


NS_ASSUME_NONNULL_BEGIN

@class MVIRCChatConnection;

@interface MVIRCChatRoom : MVChatRoom
- (instancetype) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection;
- (NSString *) modifyAddressForBan:(MVChatUser *) user;
@end

#pragma mark -

@interface MVChatRoom (MVIRCChatRoomPrivate)
@property (getter=_namesSynced, setter=_setNamesSynced:) BOOL namesSynced;
@property (getter=_bansSynced, setter=_setBansSynced:) BOOL bansSynced;
- (BOOL) _namesSynced;
- (void) _setNamesSynced:(BOOL) synced;
- (BOOL) _bansSynced;
- (void) _setBansSynced:(BOOL) synced;
@end

NS_ASSUME_NONNULL_END
