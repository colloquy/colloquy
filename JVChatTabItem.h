#import <AppKit/NSTabViewItem.h>

@protocol JVChatViewController;

@interface JVChatTabItem : NSTabViewItem {
	id <JVChatViewController> _controller;
}
- (id) initWithChatViewController:(id <JVChatViewController>) controller;
- (id) chatViewController;
@end
