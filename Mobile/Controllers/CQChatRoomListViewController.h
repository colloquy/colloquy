@class MVChatConnection;

@interface CQChatRoomListViewController : UITableViewController <UISearchBarDelegate> {
	@protected
	MVChatConnection *_connection;
	NSMutableArray *_rooms;
	NSMutableArray *_matchedRooms;
	NSMutableSet *_processedRooms;
	NSString *_currentSearchString;
	UISearchBar *_searchBar;
	BOOL _updatePending;
	BOOL _showingUpdateRow;
}
@property (nonatomic, retain) MVChatConnection *connection;

- (void) filterRoomsWithSearchString:(NSString *) searchString;
@end
