#import "CQBrowserViewController.h"

@implementation CQBrowserViewController
- (id) init {
	if (!(self = [super initWithNibName:@"Browser" bundle:nil]))
		return nil;
	return self;
}

- (void) dealloc {
	[_urlToLoad release];
	[super dealloc];
}

- (void) viewDidLoad {
	[super viewDidLoad];

	locationField.font = [UIFont systemFontOfSize:16.];
	locationField.clearsOnBeginEditing = NO;
	locationField.clearButtonMode = UITextFieldViewModeWhileEditing;

	if (_urlToLoad) {
		[self loadURL:_urlToLoad];
		[_urlToLoad release];
		_urlToLoad = nil;
	}
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIDeviceOrientationPortrait || interfaceOrientation == UIDeviceOrientationLandscapeRight);
}

- (void) loadURL:(NSURL *) url {
	if (!webView) {
		id old = _urlToLoad;
		_urlToLoad = [url retain];
		[old release];
		return;
	}

	locationField.text = url.absoluteString;

	[webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void) close:(id) sender {
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void) reloadOrStop:(id) sender {
	if (webView.loading)
		[webView stopLoading];
	else [webView reload];
}

- (void) openInSafari:(id) sender {
	[[UIApplication sharedApplication] openURL:webView.request.URL];
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	NSURL *url = [NSURL URLWithString:locationField.text];
	if (!url.scheme.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:locationField.text]];

	[self loadURL:url];

	[locationField resignFirstResponder];

	return YES;
}

- (void) updateStopButton {
	if (webView.loading)
		[stopReloadButton setImage:[UIImage imageNamed:@"browserStop.png"] forState:UIControlStateNormal];
	else [stopReloadButton setImage:[UIImage imageNamed:@"browserReload.png"] forState:UIControlStateNormal];
}

- (BOOL) webView:(UIWebView *) sender shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	if (![request.URL.absoluteString isEqualToString:@"about:blank"])
		locationField.text = request.URL.absoluteString;
	return YES;
}

- (void) webViewDidStartLoad:(UIWebView *) sender {
	[self updateStopButton];
}

- (void) webViewDidFinishLoad:(UIWebView *) sender {
	locationField.text = webView.request.URL.absoluteString;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateStopButton) object:nil];
	[self performSelector:@selector(updateStopButton) withObject:nil afterDelay:1.];
}

- (void) webView:(UIWebView *) sender didFailLoadWithError:(NSError *) error {
	locationField.text = webView.request.URL.absoluteString;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateStopButton) object:nil];
	[self performSelector:@selector(updateStopButton) withObject:nil afterDelay:1.];
}
@end
