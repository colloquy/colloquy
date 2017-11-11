#import "MVChatPluginManager.h"

@interface JVJavaScriptPluginLoader : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
}
- (void) loadPluginNamed:(NSString *) name;
@end
