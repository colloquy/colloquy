#import "MVChatPluginManager.h"

extern NSString *JVRubyErrorDomain;

@interface JVRubyChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	RBObject *_script;
	BOOL _firstLoad;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (MVChatPluginManager *) pluginManager;
- (NSString *) scriptFilePath;
- (void) reloadFromDisk;
@end
