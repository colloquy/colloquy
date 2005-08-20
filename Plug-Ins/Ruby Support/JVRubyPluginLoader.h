#import "MVChatPluginManager.h"

@interface JVRubyPluginLoader : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	BOOL _rubyCocoaInstalled;
}
- (void) loadPluginNamed:(NSString *) name;
@end
