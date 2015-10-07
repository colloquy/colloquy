#import "CQModalNavigationController.h"

@class MVChatRoom;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoViewController : CQModalNavigationController {
@private
	MVChatRoom *_room;

}

- (instancetype) initWithRoom:(MVChatRoom *) room NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
