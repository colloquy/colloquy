@protocol CQChatViewController;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatPresentationController : UIViewController
@property (nonatomic, copy) NSArray <UIBarButtonItem *> *standardToolbarItems;
- (void) setStandardToolbarItems:(NSArray <UIBarButtonItem *> *) items animated:(BOOL) animated;

@property (nonatomic, strong) id <CQChatViewController> topChatViewController;

- (void) updateToolbarAnimated:(BOOL) animated;
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
- (void) updateToolbarForInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation animated:(BOOL) animated;
#endif
@end

NS_ASSUME_NONNULL_END
