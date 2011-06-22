#import "CQPreferencesTableViewController.h"

@class MVChatUser;
@class MVChatRoom;

@interface CQChatUserListViewController : CQPreferencesTableViewController <UIActionSheetDelegate, UISearchDisplayDelegate> {
	@protected
	NSMutableArray *_users;
	NSMutableArray *_matchedUsers;
	NSString *_currentSearchString;
	MVChatRoom *_room;
	UISearchBar *_searchBar;
	UISearchDisplayController *_searchController;
}
@property (nonatomic, copy) NSArray *users;
@property (nonatomic, retain) MVChatRoom *room;

- (void) filterUsersWithSearchString:(NSString *) searchString;

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index;
- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;
- (void) removeUserAtIndex:(NSUInteger) index;
- (void) updateUserAtIndex:(NSUInteger) index;
@end
