#import <ChatCore/MVChatPluginManager.h>

@interface JVJavaScriptPluginLoader : NSObject <MVChatPlugin> {
	__unsafe_unretained MVChatPluginManager *_manager;
}
- (void) loadPluginNamed:(NSString *) name;
@end
