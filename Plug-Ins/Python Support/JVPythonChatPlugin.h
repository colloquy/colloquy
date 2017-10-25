#import <ChatCore/MVChatPluginManager.h>
#import <Python.h>

extern NSString *JVPythonErrorDomain;

@interface JVPythonChatPlugin : NSObject <MVChatPlugin> {
	__weak MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	NSString *_uniqueModuleName;
	PyObject *_scriptModule;
	BOOL _firstLoad;
	BOOL _errorShown;
}
- (instancetype) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

@property (readonly, weak) MVChatPluginManager *pluginManager;
@property (readonly, copy) NSString *scriptFilePath;
- (void) reloadFromDisk;

- (BOOL) reportErrorIfNeededInFunction:(NSString *) functionName;
- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
