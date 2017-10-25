#import <Cocoa/Cocoa.h>
#import "JVChatWindowController.h"

@class MVTextView;
@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface JVChatConsolePanel : NSObject <JVChatViewController, JVChatViewControllerScripting, NSLayoutManagerDelegate> {
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
- (instancetype) initWithConnection:(MVChatConnection *) connection;

- (void) pause;
- (void) resume;
@property (getter=isPaused, readonly) BOOL paused;

- (void) addMessageToDisplay:(NSString *) message asOutboundMessage:(BOOL) outbound;
- (IBAction) send:(nullable id) sender;
@end

NS_ASSUME_NONNULL_END
