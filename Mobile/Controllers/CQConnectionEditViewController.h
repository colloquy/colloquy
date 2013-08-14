#import "CQPreferencesTableViewController.h"

@class MVChatConnection;

@interface CQConnectionEditViewController : CQPreferencesTableViewController <UIActionSheetDelegate, UIAlertViewDelegate> {
	@protected
	MVChatConnection *_connection;
	NSArray *_servers;
	BOOL _newConnection;
}
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end
