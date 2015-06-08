#import "CQTableViewController.h"

@class MVChatRoom;

@interface CQChatRoomInfoDisplayViewController : CQTableViewController <UITextFieldDelegate, UITextViewDelegate> {
@private
	MVChatRoom *_room;
	NSMutableArray *_bans;
	UISegmentedControl *_segmentedControl;
}

- (instancetype) initWithNibName:(NSString *) nibNameOrNil bundle:(NSBundle *) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithRoom:(MVChatRoom *) room NS_DESIGNATED_INITIALIZER;
@end
