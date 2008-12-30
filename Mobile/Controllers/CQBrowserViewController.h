@interface CQBrowserViewController : UIViewController <UIWebViewDelegate, UITextFieldDelegate> {
	IBOutlet UIButton *backButton;
	IBOutlet UIButton *stopReloadButton;
	IBOutlet UIBarButtonItem *safariButtonItem;
	IBOutlet UIBarButtonItem *doneButtonItem;
	IBOutlet UITextField *locationField;
	IBOutlet UIWebView *webView;
	NSURL *_urlToLoad;
}

- (void) loadURL:(NSURL *) url;
- (void) reloadOrStop:(id) sender;
- (void) openInSafari:(id) sender;
- (void) close:(id) sender;
@end
