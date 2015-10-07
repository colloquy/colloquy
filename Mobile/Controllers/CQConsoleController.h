#import "CQDirectChatController.h"

#import "MVDelegateLogger.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQConsoleController : CQDirectChatController <MVLoggingDelegate> {
@private
	MVChatConnection *_connection;

	MVDelegateLogger *_delegateLogger;
}
@end

NS_ASSUME_NONNULL_END
