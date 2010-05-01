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
	id _target;
	SEL _action;
}
@property (nonatomic, retain) MVChatConnection *connection;
@property (nonatomic, copy) NSString *selectedRoom;

@property (nonatomic, assign) id target;
@property (nonatomic) SEL action;

- (void) filterRoomsWithSearchString:(NSString *) searchString;
@end
