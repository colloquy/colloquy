@protocol JVChatViewController;

@interface JVChatTabItem : NSTabViewItem {
	id <JVChatViewController> _controller;
}
- (instancetype) initWithChatViewController:(id <JVChatViewController>) controller NS_DESIGNATED_INITIALIZER;
@property (readonly, strong) id<JVChatViewController> chatViewController;
@end
