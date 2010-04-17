#import "CQPreferencesTextEditViewController.h"
#import "CQPreferencesListViewController.h"

@class MVChatConnection;

@interface CQAwayStatusViewController : CQPreferencesListViewController <CQPreferencesTextEditViewDelegate> {
@protected
	MVChatConnection *_connection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
