#import "JVChatWindowController.h"

@class JVChatWindowController;
@class JVAppleScriptChatPlugin;

@interface JVAppleScriptEditorPanel : NSObject <JVChatViewController> {
	IBOutlet NSView *contents;
	IBOutlet NSTextView *editor;
	BOOL _nibLoaded;
	JVChatWindowController *_windowController;
	NSImage *_icon;
	NSAppleScript *_script;
	JVAppleScriptChatPlugin *_plugin;
	BOOL _unsavedChanges;
}
- (id) initWithAppleScriptChatPlugin:(JVAppleScriptChatPlugin *) plugin;
- (JVAppleScriptChatPlugin *) plugin;
@end
