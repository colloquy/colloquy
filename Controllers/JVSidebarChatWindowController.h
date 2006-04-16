#import "JVChatWindowController.h"

@class JVSideSplitView;

@interface JVSidebarChatWindowController : JVChatWindowController {
	IBOutlet JVSideSplitView *splitView;
	IBOutlet NSView *sideView;
	IBOutlet NSView *bodyView;
	float _sideWidth;
	BOOL _forceSplitViewPosition;
}
@end
