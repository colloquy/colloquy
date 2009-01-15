#import "CQDirectChatController.h"

@class CQChatUserListViewController;

@interface CQChatRoomController : CQDirectChatController {
	@protected
	NSMutableArray *_orderedMembers;
	BOOL _membersNeedSorted;
	BOOL _banListSynced;
	NSUInteger _joinCount;
	CQChatUserListViewController *_currentUserListViewController;
}
- (MVChatRoom *) room;

- (void) joined;
- (void) close;
@end
