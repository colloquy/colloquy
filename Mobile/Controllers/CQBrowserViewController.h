@interface CQBrowserViewController : UIViewController <UIWebViewDelegate, UITextFieldDelegate> {
	IBOutlet UIButton *backButton;
	IBOutlet UIButton *stopReloadButton;
	IBOutlet UIBarButtonItem *safariButtonItem;
	IBOutlet UIBarButtonItem *doneButtonItem;
	IBOutlet UITextField *locationField;
	IBOutlet UIWebView *webView;
	IBOutlet UINavigationBar *navigationBar;
	IBOutlet UIToolbar *toolbar;
	NSURL *_urlToLoad;
}

- (void) loadURL:(NSURL *) url;
- (void) goBack:(id) sender;
- (void) reloadOrStop:(id) sender;
- (void) openInSafari:(id) sender;
- (void) close:(id) sender;
@end
