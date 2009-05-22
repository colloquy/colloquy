#import "JVChatWindowController.h"

@class MVTextView;
@class MVChatConnection;

@interface JVChatConsolePanel : NSObject <JVChatViewController, JVChatViewControllerScripting> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet NSTextView *display;
	IBOutlet MVTextView *send;
	BOOL _nibLoaded;
	BOOL _verbose;
	BOOL _ignorePRIVMSG;
	BOOL _paused;
	CGFloat _sendHeight;
	BOOL _scrollerIsAtBottom;
	BOOL _forceSplitViewPosition;
	NSInteger _historyIndex;
	NSUInteger _lastDisplayTextLength;
	NSMutableArray *_sendHistory;
	JVChatWindowController *_windowController;
	MVChatConnection *_connection;
}
- (id) initWithConnection:(MVChatConnection *) connection;

- (void) pause;
- (void) resume;
- (BOOL) isPaused;

- (void) addMessageToDisplay:(NSString *) message asOutboundMessage:(BOOL) outbound;
- (IBAction) send:(id) sender;
@end
