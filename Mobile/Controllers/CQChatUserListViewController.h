@class MVChatUser;
@class MVChatRoom;

@interface CQChatUserListViewController : UITableViewController <UIActionSheetDelegate, UISearchBarDelegate> {
	@protected
	NSMutableArray *_users;
	NSMutableArray *_matchedUsers;
	NSString *_currentSearchString;
	MVChatRoom *_room;
	UISearchBar *_searchBar;
}
@property (nonatomic, copy) NSArray *users;
@property (nonatomic, retain) MVChatRoom *room;

- (void) beginUpdates;
- (void) endUpdates;

- (void) filterUsersWithSearchString:(NSString *) searchString;

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index;
- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;
- (void) removeUserAtIndex:(NSUInteger) index;
- (void) updateUserAtIndex:(NSUInteger) index;
@end
