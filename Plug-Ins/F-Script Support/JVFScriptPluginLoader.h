#import "MVChatPluginManager.h"

@interface JVFScriptPluginLoader : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	BOOL _fscriptInstalled;
}
@end
