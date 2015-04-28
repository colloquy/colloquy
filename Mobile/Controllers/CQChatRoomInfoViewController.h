#import "CQModalNavigationController.h"

@class MVChatRoom;

@interface CQChatRoomInfoViewController : CQModalNavigationController {
@private
	MVChatRoom *_room;

}

- (instancetype) initWithRoom:(MVChatRoom *) room NS_DESIGNATED_INITIALIZER;
@end
