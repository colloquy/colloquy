#import "MVChatPluginManager.h"

@interface JVPythonPluginLoader : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	BOOL _pyobjcInstalled;
}
- (void) loadPluginNamed:(NSString *) name;
@end
