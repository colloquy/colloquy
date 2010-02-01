#import "CQHelpTopicViewController.h"

#import "CQColloquyApplication.h"

@implementation CQHelpTopicViewController
- (id) initWithHTMLContent:(NSString *) content {
	if (!(self = [self init]))
		return nil;

	_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	_webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	_webView.delegate = self;

	NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"help-base" ofType:@"html"];
	NSString *templateString = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];

	[_webView loadHTMLString:[NSString stringWithFormat:templateString, content] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];

	return self;
}

- (void) dealloc {
	_webView.delegate = nil;

	[_webView release];
	[_urlToHandle release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	_webView.frame = self.view.bounds;
	[self.view addSubview:_webView];
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

- (BOOL) webView:(UIWebView *) sender shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	if (navigationType == UIWebViewNavigationTypeOther)
		return YES;

	if ([[CQColloquyApplication sharedApplication] isSpecialApplicationURL:request.URL]) {
		[[UIApplication sharedApplication] openURL:request.URL];
		return NO;
	}

	id old = _urlToHandle;
	_urlToHandle = [request.URL retain];
	[old release];

	[self dismissModalViewControllerAnimated:YES];

	return NO;
}
@end
