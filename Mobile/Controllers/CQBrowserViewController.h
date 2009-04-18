@protocol CQBrowserViewControllerDelegate;

@interface CQBrowserViewController : UIViewController <UIWebViewDelegate, UITextFieldDelegate> {
	@protected
	IBOutlet UIButton *backButton;
	IBOutlet UIButton *stopReloadButton;
	IBOutlet UIBarButtonItem *doneButtonItem;
	IBOutlet UITextField *locationField;
	IBOutlet UIWebView *webView;
	IBOutlet UINavigationBar *navigationBar;
	IBOutlet UIToolbar *toolbar;
	NSURL *_urlToLoad;
	id _delegate;
	NSURL *_irc;
}
@property (nonatomic, assign) id <CQBrowserViewControllerDelegate> delegate;
@property (nonatomic, retain, setter=loadURL:) NSURL *url;

- (void) loadLastURL;
- (void) loadURL:(NSURL *) url;

- (IBAction) goBack:(id) sender;
- (IBAction) reloadOrStop:(id) sender;
- (IBAction) openInSafari:(id) sender;
- (IBAction) sendURL:(id) sender;
- (IBAction) sendToInstapaper:(id) sender;
- (IBAction) close:(id) sender;
@end

@protocol CQBrowserViewControllerDelegate <NSObject>
@optional
- (void) browserViewController:(CQBrowserViewController *) browserViewController sendURL:(NSURL *) url;
@end
