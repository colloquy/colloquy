#import "CQDirectChatController.h"

@interface CQChatRoomController : CQDirectChatController {
	BOOL _showingMembers;
	BOOL _needsMembersSorted;

	NSMutableArray *_orderedMembers;

	UIView *_membersMainView;
	UINavigationBar *_membersNavigationBar;

	UITableView *_membersTable;
	UITableView *_memberInfoTable;
}
- (MVChatRoom *) room;

- (void) joined;
- (void) close;

- (void) showMembers;
- (void) hideMembers;
@end
