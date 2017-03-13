#import "CQDirectChatController.h"

@class CQChatUserListViewController;

typedef NS_ENUM(NSInteger, CQChatRoomBatchType) {
	CQBatchTypeJoins = 1000,
	CQBatchTypeParts
};

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomController : CQDirectChatController {
	@protected
	NSMutableArray <MVChatUser *> *_orderedMembers;
	BOOL _membersNeedSorted;
	BOOL _banListSynced;
	BOOL _joined;
	BOOL _parting;
	NSUInteger _joinCount;
	CQChatUserListViewController *_currentUserListViewController;
	UINavigationController *_currentUserListNavigationController;
	NSDictionary *_topicInformation;
}
@property (readonly, strong, nullable) MVChatUser *user;
@property (readonly, strong) MVChatRoom *room;

- (void) join;
- (void) part;

- (void) didJoin;
@end

NS_ASSUME_NONNULL_END
