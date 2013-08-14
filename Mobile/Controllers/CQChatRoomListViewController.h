#import "CQTableViewController.h"

@class MVChatConnection;

@interface CQChatRoomListViewController : CQTableViewController <UISearchBarDelegate> {
	@protected
	MVChatConnection *_connection;
	NSMutableArray *_rooms;
	NSMutableArray *_matchedRooms;
	NSMutableSet *_processedRooms;
	NSString *_currentSearchString;
	UISearchBar *_searchBar;
	BOOL _updatePending;
	BOOL _showingUpdateRow;
	NSString *_selectedRoom;
	id __weak _target;
	SEL _action;
}
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, copy) NSString *selectedRoom;

@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;

- (void) filterRoomsWithSearchString:(NSString *) searchString;
@end
