@protocol JVChatViewController;

NS_ASSUME_NONNULL_BEGIN

@interface JVChatTabItem : NSTabViewItem {
	id <JVChatViewController> _controller;
}
- (instancetype) initWithChatViewController:(id <JVChatViewController>) controller NS_DESIGNATED_INITIALIZER;
@property (readonly, strong) id<JVChatViewController> chatViewController;
@end

NS_ASSUME_NONNULL_END
