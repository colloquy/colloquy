#import "CQTableViewController.h"

@class MVChatConnection;

@interface CQConsoleSettingsViewController : CQTableViewController {
@private
	MVChatConnection *_connection;
}

- (id) initWithConnection:(MVChatConnection *) connection;
@end
