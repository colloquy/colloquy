#import "JVChatWindowController.h"

@class JVChatWindowController;
@class JVFScriptChatPlugin;

@interface JVFScriptConsolePanel : NSObject <JVChatViewController> {
	IBOutlet NSView *contents;
	IBOutlet FSInterpreterView *console;
	BOOL _nibLoaded;
	JVChatWindowController *_windowController;
	NSImage *_icon;
	JVFScriptChatPlugin *_plugin;
}
- (id) initWithFScriptChatPlugin:(JVFScriptChatPlugin *) plugin;
- (JVFScriptChatPlugin *) plugin;
- (FSInterpreterView *) interpreterView;
@end
