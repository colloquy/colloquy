#import "CQViewController.h"

@interface CQHelpTopicViewController : CQViewController <UIWebViewDelegate> {
	UIWebView *_webView;
	NSURL *_urlToHandle;
}
- (id) initWithHTMLContent:(NSString *) content;
@end
