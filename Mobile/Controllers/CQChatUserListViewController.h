#import "CQPreferencesTableViewController.h"

@class CQChatUserListViewController;
@class MVChatUser;
@class MVChatRoom;

typedef NS_ENUM(NSInteger, QChatUserListMode) {
	CQChatUserListModeRoom,
	CQChatUserListModeBan
};

NS_ASSUME_NONNULL_BEGIN

@protocol CQChatUserListViewDelegate <NSObject>
@optional
- (BOOL) chatUserListViewController:(CQChatUserListViewController *) chatUserListViewController shouldPresentInformationForUser:(MVChatUser *) user;
- (void) chatUserListViewController:(CQChatUserListViewController *) chatUserListViewController didSelectUser:(MVChatUser *) user;
@end

@interface CQChatUserListViewController : CQPreferencesTableViewController
- (void) setRoomUsers:(NSArray <MVChatUser *> *) roomUsers;

@property (nonatomic, strong) MVChatRoom *room;
@property (nonatomic, assign) QChatUserListMode listMode;

@property (nonatomic, nullable, weak) id <CQChatUserListViewDelegate> chatUserDelegate;

- (void) filterUsersWithSearchString:(NSString *) searchString;

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index;
- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;
- (void) removeUserAtIndex:(NSUInteger) index;
- (void) updateUserAtIndex:(NSUInteger) index;
@end

NS_ASSUME_NONNULL_END
