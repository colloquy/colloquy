@class MVChatConnection;

@interface CQChatRoomListViewController : UITableViewController <UISearchBarDelegate> {
	@protected
	MVChatConnection *_connection;
	NSMutableArray *_rooms;
	NSMutableArray *_matchedRooms;
	NSString *_currentSearchString;
	UISearchBar *_searchBar;
}
@property (nonatomic, retain) MVChatConnection *connection;

- (void) filterRoomsWithSearchString:(NSString *) searchString;
@end
