#import "JVChatWindowController.h"

@class JVChatWindowController;
@class JVAppleScriptChatPlugin;

@interface JVAppleScriptEditorPanel : NSObject <JVChatViewController> {
	BOOL _nibLoaded;
	JVChatWindowController *_windowController;
	NSImage *_icon;
	NSAppleScript *_script;
	JVAppleScriptChatPlugin *_plugin;
	BOOL _unsavedChanges;
}
@property (assign) IBOutlet NSView *contents;
@property (assign) IBOutlet NSTextView *editor;
@property (readonly, retain) JVAppleScriptChatPlugin *plugin;

- (instancetype) initWithAppleScriptChatPlugin:(JVAppleScriptChatPlugin *) plugin;
@end
