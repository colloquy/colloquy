#import "MVChatPluginManager.h"

extern NSString *JVFScriptErrorDomain;

@interface JVFScriptChatPlugin : NSObject <MVChatPlugin> {
	FSInterpreter *_scriptInterpreter;
	NSString *_path;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (FSInterpreter *) scriptInterpreter;
- (NSString *) scriptFilePath;
- (void) inspectVariableNamed:(NSString *) variableName;

- (id) callScriptBlockNamed:(NSString *) blockName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
