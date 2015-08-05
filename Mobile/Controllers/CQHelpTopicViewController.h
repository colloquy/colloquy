@interface CQHelpTopicViewController : UIViewController <UIWebViewDelegate> {
	UIWebView *_webView;
	NSURL *_urlToHandle;
}
- (instancetype) initWithHTMLContent:(NSString *) content;
@end
