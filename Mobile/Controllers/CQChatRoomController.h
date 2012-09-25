#import "CQDirectChatController.h"

@class CQChatUserListViewController;

@interface CQChatRoomController : CQDirectChatController <UIPopoverControllerDelegate> {
	@protected
	NSMutableArray *_orderedMembers;
	BOOL _showingMembersInModalController;
	BOOL _membersNeedSorted;
	BOOL _banListSynced;
	BOOL _joined;
	BOOL _parting;
	NSUInteger _joinCount;
	CQChatUserListViewController *_currentUserListViewController;
	UINavigationController *_currentUserListNavigationController;
	UIPopoverController *_currentUserListPopoverController;
}
- (MVChatRoom *) room;

- (void) join;
- (void) part;

- (void) didJoin;
@end
