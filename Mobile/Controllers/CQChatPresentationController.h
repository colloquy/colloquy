@protocol CQChatViewController;

@interface CQChatPresentationController : UIViewController {
	UIToolbar *_toolbar;
	NSArray *_standardToolbarItems;
	NSArray *_currentViewToolbarItems;
	UIViewController <CQChatViewController> *_topChatViewController;
}
@property (nonatomic, copy) NSArray *standardToolbarItems;
- (void) setStandardToolbarItems:(NSArray *) items animated:(BOOL) animated;

@property (nonatomic, retain) id <CQChatViewController> topChatViewController;
@property (nonatomic, readonly) NSArray *currentViewToolbarItems;

- (void) reloadToolbar;
@end
