#import "CQPreferencesTextEditViewController.h"
#import "CQPreferencesListViewController.h"

@class MVChatConnection;

@interface CQAwayStatusViewController : CQPreferencesListViewController <CQPreferencesTextEditViewDelegate, UIActionSheetDelegate> {
@protected
	MVChatConnection *_connection;

	UILongPressGestureRecognizer *_longPressGestureRecognizer;
	NSMutableDictionary *_defaultAwayStatusCache;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
