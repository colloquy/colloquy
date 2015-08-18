#import "CQHelpTopicViewController.h"

#import "CQColloquyApplication.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  CQHelpTopicViewController
- (instancetype) initWithHTMLContent:(NSString *) content {
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

	_urlToHandle = request.URL;

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];

	return NO;
}
@end

NS_ASSUME_NONNULL_END
