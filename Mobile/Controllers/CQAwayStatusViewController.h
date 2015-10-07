#import "CQPreferencesTextEditViewController.h"
#import "CQPreferencesListViewController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQAwayStatusViewController : CQPreferencesListViewController <CQPreferencesTextEditViewDelegate, UIActionSheetDelegate> {
@protected
	MVChatConnection *_connection;

	UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@property (nonatomic, strong) MVChatConnection *connection;
@end

NS_ASSUME_NONNULL_END
