#import "CQTableViewController.h"

@class MVChatConnection;

@interface CQConnectionPushEditController : CQTableViewController {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
