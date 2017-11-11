#import "MVChatPluginManager.h"
#import "nanohttpd.h"

@interface JVWebInterfacePlugin : NSObject <MVChatPlugin> {
	http_server_t *_httpServer;
	NSMutableDictionary *_clients;
}
@end
