#import <ChatCore/MVChatPluginManager.h>

@interface JVAppleScriptChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSAppleScript *_script;
	NSString *_path;
	NSMutableSet *_doseNotRespond;
	NSTimer *_idleTimer;
	NSDate *_modDate;
}
- (instancetype) initWithScript:(NSAppleScript *) script atPath:(NSString *) path withManager:(MVChatPluginManager *) manager;
- (instancetype) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

@property (strong) NSAppleScript *script;

- (void) reloadFromDisk;

@property (readonly, strong) MVChatPluginManager *pluginManager;

@property (copy) NSString *scriptFilePath;

- (id) callScriptHandler:(FourCharCode) handler withArguments:(NSDictionary *) arguments forSelector:(SEL) selector;

- (BOOL) respondsToSelector:(SEL) selector;
- (void) doesNotRespondToSelector:(SEL) selector;
@end

@interface NSAppleScript (NSAppleScriptIdentifier)
@property (readonly, copy) NSNumber *scriptIdentifier;
@end
