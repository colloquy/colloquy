#import "MVChatPluginManager.h"

extern NSString *JVFScriptErrorDomain;

@class FSInterpreter;

@interface JVFScriptChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	FSInterpreter *_scriptInterpreter;
	NSString *_path;
	NSDate *_modDate;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (MVChatPluginManager *) pluginManager;
- (FSInterpreter *) scriptInterpreter;
- (NSString *) scriptFilePath;
- (void) reloadFromDisk;
- (void) inspectVariableNamed:(NSString *) variableName;

- (id) callScriptBlockNamed:(NSString *) blockName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
