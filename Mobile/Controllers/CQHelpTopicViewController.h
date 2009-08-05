@interface CQHelpTopicViewController : UIViewController <UIWebViewDelegate> {
	UIWebView *_webView;
	NSURL *_urlToHandle;
}
- (id) initWithHTMLContent:(NSString *) content;
@end
