#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>
#import "MVChatConnection.h"

@interface MVSILCChatConnection : MVChatConnection {
@private
	SilcClient _silcClient;
    SilcClientParams _silcClientParams;
	NSRecursiveLock *_silcClientLock;

	NSMutableArray *_joinedChannels;
	NSMutableArray *_queuedCommands;
	NSLock *_queuedCommandsLock;

	SilcClientConnection _silcConn;

	NSString *_silcServer;
	unsigned short _silcPort;

	NSString *_silcPassword;
	
	NSString *_certificatePassword;
	
	BOOL _waitForCertificatePassword;
}
@end