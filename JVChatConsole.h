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
	JVChatWindowController *_windowController;
	MVChatConnection *_connection;
}
- (id) initWithConnection:(MVChatConnection *) connection;
- (void) addMessageToDisplay:(NSString *) message asOutboundMessage:(BOOL) outbound;
@end
