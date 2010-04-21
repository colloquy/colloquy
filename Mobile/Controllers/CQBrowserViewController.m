#import "CQBrowserViewController.h"

#import "CQColloquyApplication.h"

#import "CQAlertView.h"

#define DoneButtonItem 1 // This isn't used, just here for record, since the tag exists.
#define BlankSpaceItem 2 // This isn't used, just here for record, since the tag exists.
#define SendLinkToChatToolbarItem 3
#define SaveSiteToInstapaperItem 4
#define OpenSiteInSafariItem 5
#define InstapaperAlertTag 1

#define InstapaperUsernameTextField 1
#define InstapaperPasswordTextField 2

static NSURL *lastURL;

@implementation CQBrowserViewController
- (id) init {
	if (!(self = [super initWithNibName:@"Browser" bundle:nil]))
		return nil;
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[backButton release];
	[stopReloadButton release];
	[doneButtonItem release];
	[locationField release];
	[webView release];
	[navigationBar release];
	[toolbar release];
	[_urlToLoad release];
	[_urlToHandle release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;
	toolbar.tintColor = [CQColloquyApplication sharedApplication].tintColor;

	locationField.font = [UIFont systemFontOfSize:15.];
	locationField.clearsOnBeginEditing = NO;
	locationField.clearButtonMode = UITextFieldViewModeWhileEditing;

	backButton.accessibilityLabel = NSLocalizedString(@"Back", @"Voiceover back label");

	for (UIBarButtonItem *item in toolbar.items) {
		if (item.tag == SendLinkToChatToolbarItem)
			item.accessibilityLabel = NSLocalizedString(@"Send link to chat.", @"Voiceover send link to active chat label");
		if (item.tag == SaveSiteToInstapaperItem)
			item.accessibilityLabel = NSLocalizedString(@"Save to Instapaper.", @"Voiceover save to instapaper label");
		if (item.tag == OpenSiteInSafariItem)
			item.accessibilityLabel = NSLocalizedString(@"Open in Safari.", @"Voiceover open in safari label");
	}

	if (_urlToLoad.absoluteString.length) {
		[self loadURL:_urlToLoad];
		[_urlToLoad release];
		_urlToLoad = nil;
	} else [locationField becomeFirstResponder];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	if (!_urlToHandle)
		return;

	[[UIApplication sharedApplication] performSelector:@selector(openURL:) withObject:_urlToHandle afterDelay:0.];

	[_urlToHandle release];
	_urlToHandle = nil;
}

#pragma mark -

@synthesize delegate = _delegate;

#pragma mark -

- (void) loadLastURL {
	self.url = lastURL;
}

- (void) loadURL:(NSURL *) url {
	if (!webView) {
		id old = _urlToLoad;
		_urlToLoad = [url retain];
		[old release];
		return;
	}

	if (!url) return;

	locationField.text = url.absoluteString;

	[webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void) close:(id) sender {
	if (webView.loading)
		[webView stopLoading];

	id old = lastURL;
	lastURL = [self.url retain];
	[old release];

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}

- (void) goBack:(id) sender {
	[webView goBack];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLocationField) object:nil];
	[self performSelector:@selector(updateLocationField) withObject:nil afterDelay:1.];
}

- (void) reloadOrStop:(id) sender {
	if (webView.loading)
		[webView stopLoading];
	else [webView reload];
}

- (void) openInSafari:(id) sender {
	[[CQColloquyApplication sharedApplication] openURL:self.url usingBuiltInBrowser:NO withBrowserDelegate:nil promptForExternal:YES];
}

- (NSURL *) url {
	NSURL *url = [NSURL URLWithString:locationField.text];
	if (!url.scheme.length && locationField.text.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:locationField.text]];
	return url;
}

- (IBAction) sendURL:(id) sender {
	if (!locationField.text.length)
		return;

	if ([_delegate respondsToSelector:@selector(browserViewController:sendURL:)])
		[_delegate browserViewController:self sendURL:self.url];
}

- (IBAction) sendToInstapaper:(id) sender {
	NSString *url = locationField.text;
	if (!url.length)
		return;

	BOOL success = YES;
	BOOL showRetry = NO;
	BOOL showUsernameAndPasswordTextFields = NO;

	CQAlertView *alert = [[CQAlertView alloc] init];
	alert.delegate = self;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:@"CQInstapaperUsername"];
	if (!username.length) {
		alert.title = NSLocalizedString(@"No Instapaper Username", "No Instapaper username alert title");
		alert.message = NSLocalizedString(@"You need to enter an Instapaper username in Colloquy's Settings.", "No Instapaper username alert message");

		success = NO;
		showRetry = YES;
		showUsernameAndPasswordTextFields = YES;
	}

	NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:@"CQInstapaperPassword"];

	if (success) {
		url = [url stringByEncodingIllegalURLCharacters];
		username = [username stringByEncodingIllegalURLCharacters];
		password = [password stringByEncodingIllegalURLCharacters];

		success = NO;

		[CQColloquyApplication sharedApplication].networkActivityIndicatorVisible = YES;

		NSError *error = nil;
		NSString *instapaperURL = [NSString stringWithFormat:@"https://www.instapaper.com/api/add?username=%@&password=%@&url=%@&auto-title=1", username, password, url];
		NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:instapaperURL] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.];
		NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:&error];

		[request release];

		[CQColloquyApplication sharedApplication].networkActivityIndicatorVisible = NO;

		if (!error) {
			NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

			if ([response isEqualToString:@"201"]) {
				success = YES;
			} else if ([response isEqualToString:@"403"]) {
				alert.title = NSLocalizedString(@"Couldn't Authenticate with Instapaper", "Could not authenticate title");
				alert.message = NSLocalizedString(@"Make sure your Instapaper username and password are correct.", "Make sure your Instapaper username and password are correct alert message");
				showRetry = YES;
				showUsernameAndPasswordTextFields = YES;
			} else if ([response isEqualToString:@"500"]) {
				alert.title = NSLocalizedString(@"Instapaper Unavailable", "Instapaper Temporarily Unavailable title");
				alert.message = NSLocalizedString(@"Unable to send the URL because Instapaper is temporarily unavailable.", "Unable to send URL because Instapaper is temporarily unavailable alert message");
				showRetry = YES;
			}

			[response release];
		} else {
			alert.title = NSLocalizedString(@"Unable To Send URL", "Unable to send URL alert title");
			alert.message = NSLocalizedString(@"Unable to send the URL to Instapaper.", "Unable to send the URL to Instapaper alert message");
		}
	}

	if (showRetry)
		[alert addButtonWithTitle:NSLocalizedString(@"Retry", @"Retry button title")];

	if (!success) {
		alert.tag = InstapaperAlertTag;

		if (showUsernameAndPasswordTextFields) {
			[alert addTextFieldWithPlaceholder:NSLocalizedString(@"Username", @"Username textfield placeholder") tag:InstapaperUsernameTextField];
			[alert addTextFieldWithPlaceholder:NSLocalizedString(@"Password (Optional)", @"Password (Optional) textfield placeholder") tag:InstapaperPasswordTextField];
		}

		[alert show];
	}

	[alert release];
}

#pragma mark -

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	NSURL *url = [NSURL URLWithString:locationField.text];
	if (!url.scheme.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:locationField.text]];

	[self loadURL:url];

	[locationField resignFirstResponder];

	return YES;
}

#pragma mark -

- (void) updateLocationField {
	NSString *location = webView.request.URL.absoluteString;
	if ([location isCaseInsensitiveEqualToString:@"about:blank"])
		locationField.text = @"";
	else if (location.length)
		locationField.text = webView.request.URL.absoluteString;
}

- (void) updateLoadingStatus {
	UIImage *image = nil;
	if (webView.loading) {
		image = [UIImage imageNamed:@"browserStop.png"];

		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

		stopReloadButton.accessibilityLabel = NSLocalizedString(@"Stop", @"Voiceover stop label");
	} else {
		image = [UIImage imageNamed:@"browserReload.png"];

		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

		stopReloadButton.accessibilityLabel = NSLocalizedString(@"Reload", @"voiceover reload label");
	}

	[stopReloadButton setImage:image forState:UIControlStateNormal];
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;

	if (alertView.tag == InstapaperAlertTag) {
		NSArray *inputFields = ((CQAlertView *)alertView).inputFields;
		NSString *username = ((UITextField *)[inputFields objectAtIndex:0]).text;
		if (!username.length) {
			[alertView show];
			return;
		}

		NSString *password = ((UITextField *)[inputFields objectAtIndex:1]).text;

		[[NSUserDefaults standardUserDefaults] setObject:username forKey:@"CQInstapaperUsername"];
		[[NSUserDefaults standardUserDefaults] setObject:password forKey:@"CQInstapaperPassword"];

		[self sendToInstapaper:nil];
	}
}

#pragma mark -

- (BOOL) webView:(UIWebView *) sender shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	if ([[CQColloquyApplication sharedApplication] isSpecialApplicationURL:request.URL]) {
		[[UIApplication sharedApplication] openURL:request.URL];
		return NO;
	}

	if ([[CQColloquyApplication sharedApplication].handledURLSchemes containsObject:[request.URL.scheme lowercaseString]]) {
		id old = _urlToHandle;
		_urlToHandle = [request.URL retain];
		[old release];

		[self close:nil];

		return NO;
	}

	if (![request.URL.absoluteString isCaseInsensitiveEqualToString:@"about:blank"])
		locationField.text = request.URL.absoluteString;

	return YES;
}

- (void) webViewDidStartLoad:(UIWebView *) sender {
	[self updateLoadingStatus];
}

- (void) webViewDidFinishLoad:(UIWebView *) sender {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLocationField) object:nil];
	[self performSelector:@selector(updateLocationField) withObject:nil afterDelay:1.];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLoadingStatus) object:nil];
	[self performSelector:@selector(updateLoadingStatus) withObject:nil afterDelay:1.];
}

- (void) webView:(UIWebView *) sender didFailLoadWithError:(NSError *) error {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLocationField) object:nil];
	[self performSelector:@selector(updateLocationField) withObject:nil afterDelay:1.];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLoadingStatus) object:nil];
	[self performSelector:@selector(updateLoadingStatus) withObject:nil afterDelay:1.];
}

#pragma mark -

- (void) keyboardWillShow:(NSNotification *) notification {
	CGPoint endCenterPoint = CGPointZero;
	CGRect keyboardBounds = CGRectZero;

	[[[notification userInfo] objectForKey:UIKeyboardCenterEndUserInfoKey] getValue:&endCenterPoint];
	[[[notification userInfo] objectForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardBounds];

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.25];

#if TARGET_IPHONE_SIMULATOR
	[UIView setAnimationDelay:0.06];
#else
	[UIView setAnimationDelay:0.175];
#endif

	BOOL landscape = UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
	CGFloat windowOffset = (landscape ? [UIApplication sharedApplication].statusBarFrame.size.width : [UIApplication sharedApplication].statusBarFrame.size.height);

	CGRect bounds = webView.bounds;
	CGPoint center = webView.center;
	CGFloat keyboardTop = MAX(0., endCenterPoint.y - (keyboardBounds.size.height / 2.));

	bounds.size.height = keyboardTop - navigationBar.bounds.size.height - windowOffset;
	webView.bounds = bounds;

	center.y = navigationBar.bounds.size.height + (bounds.size.height / 2.);
	webView.center = center;

	[UIView commitAnimations];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	CGPoint beginCenterPoint = CGPointZero;
	CGPoint endCenterPoint = CGPointZero;

	[[[notification userInfo] objectForKey:UIKeyboardCenterBeginUserInfoKey] getValue:&beginCenterPoint];
	[[[notification userInfo] objectForKey:UIKeyboardCenterEndUserInfoKey] getValue:&endCenterPoint];

	if (beginCenterPoint.y == endCenterPoint.y)
		return;

	[UIView beginAnimations:nil context:NULL];

	[UIView setAnimationDuration:0.25];

	CGRect bounds = webView.bounds;
	CGPoint center = webView.center;
	CGFloat viewHeight = self.view.bounds.size.height;

	bounds.size.height = viewHeight - navigationBar.bounds.size.height - toolbar.bounds.size.height;
	webView.bounds = bounds;

	center.y = navigationBar.bounds.size.height + (bounds.size.height / 2.);
	webView.center = center;

	[UIView commitAnimations];
}
@end
