#import "CQModalNavigationController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQAwayStatusController : CQModalNavigationController {
@protected
	MVChatConnection *_connection;
}
@property (nonatomic, strong) MVChatConnection *connection;
@end

NS_ASSUME_NONNULL_END
