#import <ChatCore/MVChatPluginManager.h>

@interface JVPythonPluginLoader : NSObject <MVChatPlugin> {
	__unsafe_unretained MVChatPluginManager *_manager;
	BOOL _pyobjcInstalled;
}
- (void) loadPluginNamed:(NSString *) name;
@end
