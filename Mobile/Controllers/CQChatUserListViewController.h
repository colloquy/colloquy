#import "CQPreferencesTableViewController.h"

@class CQChatUserListViewController;
@class MVChatUser;
@class MVChatRoom;

typedef NS_ENUM(NSInteger, QChatUserListMode) {
	CQChatUserListModeRoom,
	CQChatUserListModeBan
};

@protocol CQChatUserListViewDelegate <NSObject>
@optional
- (BOOL) chatUserListViewController:(CQChatUserListViewController *) chatUserListViewController shouldPresentInformationForUser:(MVChatUser *) user;
- (void) chatUserListViewController:(CQChatUserListViewController *) chatUserListViewController didSelectUser:(MVChatUser *) user;
@end

@interface CQChatUserListViewController : CQPreferencesTableViewController <UIActionSheetDelegate, UISearchDisplayDelegate> {
	@protected
	NSMutableArray *_users;
	NSString *_currentSearchString;
	MVChatRoom *_room;
	UISearchBar *_searchBar;
	UISearchDisplayController *_searchController;
	QChatUserListMode _listMode;
	id <CQChatUserListViewDelegate> __weak _chatUserDelegate;
}

- (void) setRoomUsers:(NSArray *) roomUsers;

@property (nonatomic, strong) MVChatRoom *room;
@property (nonatomic, assign) QChatUserListMode listMode;

@property (nonatomic, weak) id <CQChatUserListViewDelegate> chatUserDelegate;

- (void) filterUsersWithSearchString:(NSString *) searchString;

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index;
- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;
- (void) removeUserAtIndex:(NSUInteger) index;
- (void) updateUserAtIndex:(NSUInteger) index;
@end
