#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVChatWindowController.h"

@class NSView;
@class NSTextView;
@class MVTextView;
@class MVChatConnection;

@interface JVChatConsole : NSObject <JVChatViewController> {
	@protected
	IBOutlet NSView *contents;
	IBOutlet NSTextView *display;
	IBOutlet MVTextView *send;
	BOOL _nibLoaded;
	BOOL _verbose;
	BOOL _ignorePRIVMSG;
	int _historyIndex;
	NSMutableArray *_sendHistory;
	JVChatWindowController *_windowController;
	MVChatConnection *_connection;
}
- (id) initWithConnection:(MVChatConnection *) connection;
- (void) addMessageToDisplay:(NSData *) message asOutboundMessage:(BOOL) outbound;
- (IBAction) send:(id) sender;
@end
