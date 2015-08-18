NS_ASSUME_NONNULL_BEGIN

@interface CQHelpTopicViewController : UIViewController <UIWebViewDelegate> {
	UIWebView *_webView;
	NSURL *_urlToHandle;
}
- (instancetype) initWithHTMLContent:(NSString *) content;
@end

NS_ASSUME_NONNULL_END
