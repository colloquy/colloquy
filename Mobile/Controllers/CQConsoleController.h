#import "CQDirectChatController.h"

#import "MVDelegateLogger.h"

@class MVChatConnection;

BOOL defaultForServer(NSString *defaultName, NSString *serverName);

@interface CQConsoleController : CQDirectChatController <MVLoggingDelegate> {
@private
	MVChatConnection *_connection;

	MVDelegateLogger *_delegateLogger;
}
@end
