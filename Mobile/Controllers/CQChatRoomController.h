#import "CQDirectChatController.h"

@class CQChatUserListViewController;

typedef NS_ENUM(NSInteger, CQChatRoomBatchType) {
	CQBatchTypeJoins = CQBatchTypeBuffer + 1,
	CQBatchTypeParts
};

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
	NSDictionary *_topicInformation;
}
- (MVChatRoom *) room;

- (void) join;
- (void) part;

- (void) didJoin;
@end
