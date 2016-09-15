#import <ChatCore/MVChatPluginManager.h>
#import "JVChatWindowController.h"

@class FSInterpreterView;
@class JVChatWindowController;
@class JVFScriptChatPlugin;

@interface JVFScriptConsolePanel : NSObject <JVChatViewController, NSToolbarDelegate> {
	IBOutlet NSView *contents;
	IBOutlet FSInterpreterView *console;
	BOOL _nibLoaded;
	JVChatWindowController *_windowController;
	NSImage *_icon;
	JVFScriptChatPlugin *_plugin;
}
- (instancetype) initWithFScriptChatPlugin:(JVFScriptChatPlugin *) plugin;
@property (readonly, strong) JVFScriptChatPlugin *plugin;
@property (readonly, strong) FSInterpreterView *interpreterView;
@end
