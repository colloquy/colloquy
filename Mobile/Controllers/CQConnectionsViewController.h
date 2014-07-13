#import "CQTableViewController.h"

@class MVChatConnection;
@class CQBouncerSettings;
@class CQConnectionsNavigationController;

@interface CQConnectionsViewController : CQTableViewController <UIActionSheetDelegate> {
	@protected
	NSTimer *_connectTimeUpdateTimer;
	BOOL _active;
	BOOL _ignoreNotifications;
}
@property (nonatomic, readonly, strong) CQConnectionsNavigationController *navigationController;
@end
