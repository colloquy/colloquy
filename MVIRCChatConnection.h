#import "MVChatConnection.h"
#import "common.h"

@interface MVIRCChatConnection : MVChatConnection {
@private
	NSString *_proxyUsername;
	NSString *_proxyPassword;
	SERVER_REC *_chatConnection;
	SERVER_CONNECT_REC *_chatConnectionSettings;
	BOOL _nickIdentified;
}
@end
