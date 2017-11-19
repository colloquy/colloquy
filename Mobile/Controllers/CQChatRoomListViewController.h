@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomListViewController : UITableViewController
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, copy) NSString *selectedRoom;

@property (nonatomic, nullable, weak) id target;
@property (nonatomic) SEL action;

- (void) filterRoomsWithSearchString:(NSString *) searchString;
@end

NS_ASSUME_NONNULL_END
