#import <ChatCore/MVChatPluginManager.h>

@interface MVChatScriptPlugin : NSObject <MVChatPlugin> {
	NSAppleScript *_script;
	NSString *_path;
	NSMutableSet *_doseNotRespond;
}
- (id) initWithScript:(NSAppleScript *) script atPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (NSAppleScript *) script;
- (NSString *) scriptFilePath;
- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments forSelector:(SEL) selector;

- (BOOL) respondsToSelector:(SEL) selector;
- (void) doesNotRespondToSelector:(SEL) selector;
@end

@interface NSAppleScript (NSAppleScriptIdentifier)
- (NSNumber *) scriptIdentifier;
@end
