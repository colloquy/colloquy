#import "CQBrowserViewController.h"

#import "CQColloquyApplication.h"
#import "NSStringAdditions.h"

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

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	locationField.font = [UIFont systemFontOfSize:15.];
	locationField.clearsOnBeginEditing = NO;
	locationField.clearButtonMode = UITextFieldViewModeWhileEditing;

	if (_urlToLoad.absoluteString.length) {
		[self loadURL:_urlToLoad];
		[_urlToLoad release];
		_urlToLoad = nil;
	} else [locationField becomeFirstResponder];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return (UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) viewDidDisappear:(BOOL) animated {
	if (_irc != nil) {
		[[UIApplication sharedApplication] performSelector:@selector(openURL:) withObject:_irc afterDelay:0.0];
		[_irc release];
		_irc = nil;
	}
}

#pragma mark -

@synthesize delegate = _delegate;

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
	id old = lastURL;
	lastURL = [self.url retain];
	[old release];

	[self dismissModalViewControllerAnimated:YES];
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
	[[UIApplication sharedApplication] openURL:self.url];
}

- (NSURL *) url {
	NSURL *url = [NSURL URLWithString:locationField.text];
	if (!url.scheme.length && locationField.text.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:locationField.text]];
	return url;
}

- (IBAction) sendURL:(id) sender {
	if ([_delegate respondsToSelector:@selector(browserViewController:sendURL:)])
		[_delegate browserViewController:self sendURL:self.url];
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
	} else {
		image = [UIImage imageNamed:@"browserReload.png"];
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}

	[stopReloadButton setImage:image forState:UIControlStateNormal];
}

#pragma mark -

- (BOOL) webView:(UIWebView *) sender shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	
	static NSMutableArray *schemes = nil;
	if (schemes == nil) {
		schemes = [[NSMutableArray alloc] init];
		NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
		NSArray *array = [info objectForKey:@"CFBundleURLTypes"];
		if (array != nil) {
			for (NSDictionary *dict in array) {
				NSArray *items = [dict objectForKey:@"CFBundleURLSchemes"];
				if (items != nil) {
					for (NSString *item in items) {
						[schemes addObject:[item lowercaseString]];
					}
				}
			}
		}
	}
	
	if ([schemes containsObject:[request.URL.scheme lowercaseString]]) {
		_irc = [request.URL retain];
		[self close:self];
		return NO;
	}
	else {
		if ([[CQColloquyApplication sharedApplication] isSpecialApplicationURL:request.URL]) {
			[[UIApplication sharedApplication] openURL:request.URL];
			return NO;
		}
		
		if (![request.URL.absoluteString isCaseInsensitiveEqualToString:@"about:blank"])
			locationField.text = request.URL.absoluteString;
		
		return YES;
	}
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

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
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
