#import <JVChatWindowController.h>

@class AICustomTabsView;
@class NSTabView;

@interface JVTabbedChatWindowController : JVChatWindowController {
	IBOutlet AICustomTabsView *customTabsView;
	IBOutlet NSTabView *tabView;
	NSMutableArray *_tabItems;
}

@end
