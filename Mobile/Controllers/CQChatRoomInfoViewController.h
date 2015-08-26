#import "CQModalNavigationController.h"
#import "CQChatRoomInfoDisplayViewController.h"

@class MVChatRoom;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoViewController : CQModalNavigationController
- (instancetype) initWithRoom:(MVChatRoom *) room showingInfoType:(CQChatRoomInfo) infoType NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
