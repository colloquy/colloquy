#import "JVChatWindowController.h"

@class JVSideSplitView;

@interface JVSidebarChatWindowController : JVChatWindowController {
	IBOutlet JVSideSplitView *splitView;
	IBOutlet NSView *bodyView;
	BOOL _forceSplitViewPosition;
}
@end
