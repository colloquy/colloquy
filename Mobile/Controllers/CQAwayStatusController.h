#import "CQModalNavigationController.h"

@class MVChatConnection;

@interface CQAwayStatusController : CQModalNavigationController {
@protected
	MVChatConnection *_connection;
}
@property (nonatomic, strong) MVChatConnection *connection;
@end
