#import "CQDirectChatController.h"

@class CQChatUserListViewController;

typedef NS_ENUM(NSInteger, CQChatRoomBatchType) {
	CQBatchTypeJoins = CQBatchTypeBuffer + 1,
	CQBatchTypeParts
};

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomController : CQDirectChatController {
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
@property (readonly, strong) MVChatRoom *room;

- (void) join;
- (void) part;

- (void) didJoin;
@end

NS_ASSUME_NONNULL_END
