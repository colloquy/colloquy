#import "MVChatPluginManager.h"
#import <Python/Python.h>

extern NSString *JVPythonErrorDomain;

@interface JVPythonChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	NSString *_uniqueModuleName;
	PyObject *_scriptModule;
	BOOL _firstLoad;
	BOOL _errorShown;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (MVChatPluginManager *) pluginManager;
- (NSString *) scriptFilePath;
- (void) reloadFromDisk;

- (BOOL) reportErrorIfNeededInFunction:(NSString *) functionName;
- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
