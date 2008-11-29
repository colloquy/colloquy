#import "CQDirectChatController.h"

@interface CQChatRoomController : CQDirectChatController {
	NSMutableArray *_orderedMembers;
}
- (MVChatRoom *) room;

- (void) joined;
- (void) close;
@end
