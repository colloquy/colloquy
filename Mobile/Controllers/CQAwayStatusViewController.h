#import "CQPreferencesTextEditViewController.h"
#import "CQPreferencesListViewController.h"

@class MVChatConnection;

@interface CQAwayStatusViewController : CQPreferencesListViewController <CQPreferencesTextEditViewDelegate, UIActionSheetDelegate> {
@protected
	MVChatConnection *_connection;

	UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@property (nonatomic, strong) MVChatConnection *connection;
@end
