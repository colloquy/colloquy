#import <WebKit/WebKit.h>

#import "CQHelpTopicViewController.h"

#import "CQColloquyApplication.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQHelpTopicViewController () <WKNavigationDelegate>
@end

@implementation CQHelpTopicViewController {
	UIView *_webView;
	NSURL *_urlToHandle;
}

- (instancetype) initWithHTMLContent:(NSString *) content {
	if (!(self = [self init]))
		return nil;

	WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero];
	webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	webView.navigationDelegate = self;

	NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"help-base" ofType:@"html"];
	NSString *templateString = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];

	[webView loadHTMLString:[NSString stringWithFormat:templateString, content] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];

	_webView = webView;

	return self;
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

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	if (navigationAction.navigationType == WKNavigationTypeOther) {
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}

	if ([[CQColloquyApplication sharedApplication] isSpecialApplicationURL:navigationAction.request.URL]) {
		[[CQColloquyApplication sharedApplication] openURL:navigationAction.request.URL options:@{} completionHandler:nil];
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}

	_urlToHandle = navigationAction.request.URL;

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];

	decisionHandler(WKNavigationActionPolicyAllow);
}
@end

NS_ASSUME_NONNULL_END
