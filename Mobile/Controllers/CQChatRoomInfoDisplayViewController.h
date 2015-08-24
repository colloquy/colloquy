#import "CQTableViewController.h"

@class MVChatRoom;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoDisplayViewController : CQTableViewController
- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (__nullable instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithRoom:(MVChatRoom *) room NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
