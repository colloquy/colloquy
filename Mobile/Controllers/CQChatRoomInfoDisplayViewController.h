#import "CQTableViewController.h"

@class MVChatRoom;

@interface CQChatRoomInfoDisplayViewController : CQTableViewController <UITextFieldDelegate, UITextViewDelegate> {
@private
	MVChatRoom *_room;
	NSMutableArray *_bans;
	UISegmentedControl *_segmentedControl;
}

- (instancetype) initWithRoom:(MVChatRoom *) room NS_DESIGNATED_INITIALIZER;
@end
