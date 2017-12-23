#import "JVChatWindowController.h"

@class JVSideSplitView;

@interface JVSidebarChatWindowController : JVChatWindowController {
	IBOutlet JVSideSplitView *mainSplitView;
	IBOutlet NSImageView *additionalDividerHandle;
	IBOutlet NSView *bodyView;
	BOOL _forceSplitViewPosition;
}
@end
