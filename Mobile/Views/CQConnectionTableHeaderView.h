@class MVChatConnection;
@class CQBouncerSettings;

typedef NS_ENUM(NSInteger, CQConnectionTableCellStatus) {
	CQConnectionTableCellNotConnectedStatus,
	CQConnectionTableCellServerDisconnectedStatus,
	CQConnectionTableCellReconnectingStatus,
	CQConnectionTableCellConnectingStatus,
	CQConnectionTableCellConnectedStatus
};

NS_ASSUME_NONNULL_BEGIN

@interface CQConnectionTableHeaderView : UITableViewHeaderFooterView
- (void) takeValuesFromBouncerSettings:(CQBouncerSettings *) bouncerSettings;
- (void) takeValuesFromConnection:(MVChatConnection *) connection;
- (void) updateConnectTime;

@property (nonatomic, copy) NSString *server;
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, copy) NSDate *connectDate;
@property (nonatomic) CQConnectionTableCellStatus status;
@property (nonatomic) BOOL secure;

@property (nonatomic) BOOL editing;
- (void) setEditing:(BOOL) editing animated:(BOOL) animated;

@property (nonatomic) BOOL showingDeleteConfirmation;
@property (nonatomic) BOOL showsReorderControl;

@property (atomic, copy) void (^selectedConnectionHeaderView)(void);
@end

NS_ASSUME_NONNULL_END
