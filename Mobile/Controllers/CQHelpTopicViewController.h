#import "CQViewController.h"

@interface CQHelpTopicViewController : CQViewController <UIWebViewDelegate> {
	UIWebView *_webView;
	NSURL *_urlToHandle;
}
- (instancetype) initWithHTMLContent:(NSString *) content;
@end
