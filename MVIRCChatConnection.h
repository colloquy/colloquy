#import "MVChatConnection.h"
#import "common.h"

extern NSRecursiveLock *MVIRCChatConnectionThreadLock;

@interface MVIRCChatConnection : MVChatConnection {
@private
	NSMutableDictionary *_knownUsers;
	NSString *_proxyUsername;
	NSString *_proxyPassword;
	SERVER_REC *_chatConnection;
	SERVER_CONNECT_REC *_chatConnectionSettings;
}
@end
