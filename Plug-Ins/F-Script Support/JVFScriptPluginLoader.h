#import <ChatCore/MVChatPluginManager.h>

@interface JVFScriptPluginLoader : NSObject <MVChatPlugin> {
	__unsafe_unretained MVChatPluginManager *_manager;
	BOOL _fscriptInstalled;
}
- (void) loadPluginNamed:(NSString *) name;
@end
