#import "JVChatWindowController.h"
#import "AICustomTabsView.h"

@class JVSideSplitView;

@interface JVSidebarChatWindowController : JVChatWindowController <AICustomTabsViewDelegate> {
	IBOutlet JVSideSplitView *splitView;
	IBOutlet NSView *bodyView;
	IBOutlet NSView *sideView;
	BOOL _forceSplitViewPosition;
}
@end
