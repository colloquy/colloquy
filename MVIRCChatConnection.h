#import "MVChatConnection.h"

@interface MVIRCChatConnection : MVChatConnection {
@private
	NSString *_proxyUsername;
	NSString *_proxyPassword;
	void *_chatConnection /* SERVER_REC */;
	void *_chatConnectionSettings /* SERVER_CONNECT_REC */;
	BOOL _nickIdentified;
}
@end
