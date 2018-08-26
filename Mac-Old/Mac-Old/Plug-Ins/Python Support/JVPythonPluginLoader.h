#import "MVChatPluginManager.h"

COLLOQUY_EXPORT
@interface JVPythonPluginLoader : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	BOOL _pyobjcInstalled;
}
- (void) loadPluginNamed:(NSString *) name;
@end
