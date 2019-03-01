#import "CQHelpTopicViewController.h"

#import "CQColloquyApplication.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQHelpTopicViewController {
	UIView *_webView;
	NSURL *_urlToHandle;
}

- (instancetype) initWithHTMLContent:(NSString *) content {
	if (!(self = [self init]))
		return nil;

	UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	webView.delegate = self;

	NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"help-base" ofType:@"html"];
	NSString *templateString = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];

	[webView loadHTMLString:[NSString stringWithFormat:templateString, content] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];

	_webView = webView;

	return self;
}

- (void) dealloc {
	((UIWebView *)_webView).delegate = nil;
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

	[[CQColloquyApplication sharedApplication] openURL:_urlToHandle options:@{} completionHandler:nil];

	_urlToHandle = nil;
}

#pragma mark -

- (BOOL) webView:(UIWebView *) sender shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	if (navigationType == UIWebViewNavigationTypeOther)
		return YES;

	if ([[CQColloquyApplication sharedApplication] isSpecialApplicationURL:request.URL]) {
		[[CQColloquyApplication sharedApplication] openURL:request.URL options:@{} completionHandler:nil];
		return NO;
	}

	_urlToHandle = request.URL;

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];

	return NO;
}
@end

NS_ASSUME_NONNULL_END
