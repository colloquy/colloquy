#import "CQPreferencesTableViewController.h"

@class MVChatConnection;

@interface CQConnectionAdvancedEditController : CQPreferencesTableViewController {
	@protected
	MVChatConnection *_connection;
	BOOL _newConnection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end
