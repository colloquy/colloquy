@interface CQBrowserViewController : UIViewController <UIWebViewDelegate, UITextFieldDelegate> {
	IBOutlet UIButton *backButton;
	IBOutlet UIButton *stopReloadButton;
	IBOutlet UIBarButtonItem *doneButtonItem;
	IBOutlet UITextField *locationField;
	IBOutlet UIWebView *webView;
	IBOutlet UINavigationBar *navigationBar;
	IBOutlet UIToolbar *toolbar;
	NSURL *_urlToLoad;
}
- (void) loadURL:(NSURL *) url;

- (IBAction) goBack:(id) sender;
- (IBAction) reloadOrStop:(id) sender;
- (IBAction) openInSafari:(id) sender;
- (IBAction) close:(id) sender;
@end
