#import "MVChatPluginManager.h"

@interface JVAppleScriptChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSAppleScript *_script;
	NSString *_path;
	NSMutableSet *_doseNotRespond;
	NSTimer *_idleTimer;
}
- (id) initWithScript:(NSAppleScript *) script atPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (NSAppleScript *) script;
- (MVChatPluginManager *) pluginManager;
- (NSString *) scriptFilePath;
- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments forSelector:(SEL) selector;

- (BOOL) respondsToSelector:(SEL) selector;
- (void) doesNotRespondToSelector:(SEL) selector;
@end

@interface NSAppleScript (NSAppleScriptIdentifier)
- (NSNumber *) scriptIdentifier;
@end
