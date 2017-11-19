@class MVChatRoom;

typedef NS_ENUM(NSUInteger, CQChatRoomInfo) {
	CQChatRoomInfoModes,
	CQChatRoomInfoTopic,
	CQChatRoomInfoBans
};

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoDisplayViewController : UITableViewController
- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithRoom:(MVChatRoom *) room showingInfoType:(CQChatRoomInfo) infoType NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
