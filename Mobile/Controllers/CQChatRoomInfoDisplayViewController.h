#import "CQTableViewController.h"

@class MVChatRoom;

@interface CQChatRoomInfoDisplayViewController : CQTableViewController <UITextFieldDelegate, UITextViewDelegate> {
@private
	MVChatRoom *_room;
	NSArray *_bans;
	UISegmentedControl *_segmentedControl;
}

- (id) initWithRoom:(MVChatRoom *) room;
@end
