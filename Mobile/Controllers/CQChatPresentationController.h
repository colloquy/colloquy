#import "CQViewController.h"

@protocol CQChatViewController;

@interface CQChatPresentationController : CQViewController {
	UIToolbar *_toolbar;
	NSArray *_standardToolbarItems;
	UIViewController <CQChatViewController> *_topChatViewController;
}
@property (nonatomic, copy) NSArray *standardToolbarItems;
- (void) setStandardToolbarItems:(NSArray *) items animated:(BOOL) animated;

@property (nonatomic, retain) id <CQChatViewController> topChatViewController;

- (void) updateToolbarAnimated:(BOOL) animated;
- (void) updateToolbarForInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation animated:(BOOL) animated;
@end
