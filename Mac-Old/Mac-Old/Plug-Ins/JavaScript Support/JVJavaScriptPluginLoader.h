#import "MVChatPluginManager.h"

COLLOQUY_EXPORT
@interface JVJavaScriptPluginLoader : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
}
- (void) loadPluginNamed:(NSString *) name;
@end
