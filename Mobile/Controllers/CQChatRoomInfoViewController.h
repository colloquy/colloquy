#import "CQModalNavigationController.h"

@class MVChatRoom;

@interface CQChatRoomInfoViewController : CQModalNavigationController {
@private
	MVChatRoom *_room;

}

- (id) initWithRoom:(MVChatRoom *) room;
@end
