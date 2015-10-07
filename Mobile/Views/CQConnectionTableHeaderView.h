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

@interface CQConnectionTableHeaderView : UITableViewHeaderFooterView {
	@protected
	UIImageView *_iconImageView;
	UIImageView *_badgeImageView;
	UILabel *_serverLabel;
	UILabel *_nicknameLabel;
	UILabel *_timeLabel;
	NSDate *_connectDate;
	CQConnectionTableCellStatus _status;
	UIButton *_disclosureButton;

	UIColor *_originalBackgroundColor;
}

- (void) takeValuesFromBouncerSettings:(CQBouncerSettings *) bouncerSettings;
- (void) takeValuesFromConnection:(MVChatConnection *) connection;
- (void) updateConnectTime;

@property (nonatomic, copy) NSString *server;
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, copy) NSDate *connectDate;
@property (nonatomic) CQConnectionTableCellStatus status;

@property (nonatomic) BOOL editing;
- (void) setEditing:(BOOL) editing animated:(BOOL) animated;

@property (nonatomic) BOOL showingDeleteConfirmation;
@property (nonatomic) BOOL showsReorderControl;

@property (atomic, copy) void (^selectedConnectionHeaderView)();
@end

NS_ASSUME_NONNULL_END
