#import "JVChatWindowController.h"

@class JVChatWindowController;

@interface JVFScriptConsolePanel : NSObject <JVChatViewController> {
	IBOutlet NSView *contents;
	IBOutlet FSInterpreterView *console;
	BOOL _nibLoaded;
	JVChatWindowController *_windowController;
	NSImage *_icon;
}

@end
