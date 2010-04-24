#import "CQModalNavigationController.h"

@class MVChatConnection;

@interface CQAwayStatusController : CQModalNavigationController {
@protected
	MVChatConnection *_connection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
