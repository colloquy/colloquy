#import "CQDirectChatController.h"

@class CQChatUserListViewController;

@interface CQChatRoomController : CQDirectChatController {
	@protected
	NSMutableArray *_orderedMembers;
	BOOL _showingMembersInNavigationController;
	BOOL _membersNeedSorted;
	BOOL _banListSynced;
	BOOL _joined;
	BOOL _parting;
	NSUInteger _joinCount;
	CQChatUserListViewController *_currentUserListViewController;
	UIPopoverController *_currentUserListPopoverController;
}
- (MVChatRoom *) room;

- (void) join;
- (void) part;

- (void) didJoin;

@property (nonatomic, readonly) UIViewController *detailViewController;

- (void) hideCurrentUserListPopoverController;
@end
