#import <ChatCore/MVChatPluginManager.h>

extern NSString *JVFScriptErrorDomain;

@class FSInterpreter;

@interface JVFScriptChatPlugin : NSObject <MVChatPlugin> {
	__unsafe_unretained MVChatPluginManager *_manager;
	FSInterpreter *_scriptInterpreter;
	NSString *_path;
	NSDate *_modDate;
	BOOL _errorShown;
}
- (instancetype) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

@property (readonly, assign) MVChatPluginManager *pluginManager;
@property (readonly, strong) FSInterpreter *scriptInterpreter;
@property (readonly, copy) NSString *scriptFilePath;
- (void) reloadFromDisk;
- (void) inspectVariableNamed:(NSString *) variableName;

- (id) callScriptBlockNamed:(NSString *) blockName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
