#import "CQDirectChatController.h"

#import "MVDelegateLogger.h"

@class MVChatConnection;

@interface CQConsoleController : CQDirectChatController <MVLoggingDelegate> {
@private
	MVChatConnection *_connection;

	MVDelegateLogger *_delegateLogger;
}
@end
