#import <Foundation/NSObject.h>
#import <ChatCore/MVChatPluginManager.h>

extern unsigned long MVChatScriptPluginClass;

@interface MVChatScriptPlugin : NSObject <MVChatPlugin> {
	NSAppleScript *_script;
}
- (id) initWithScript:(NSAppleScript *) script andManager:(MVChatPluginManager *) manager;
- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments;
@end
