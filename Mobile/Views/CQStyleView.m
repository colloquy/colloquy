#import "CQStyleView.h"

@implementation CQStyleView
- (id) initWithFrame:(CGRect) frame {
	if( ! ( self = [super initWithFrame:frame] ) )
		return nil;

	frame.origin.x = frame.origin.y = 0.;

	_webView = [[UIWebView alloc] initWithFrame:frame];
	[_webView setDelegate:self];
	[[_webView webView] setPolicyDelegate:self];

	[self addSubview:_webView];

	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"base" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];
	NSString *styleURL = [[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"standard" ofType:@"css"]] absoluteString];
	NSString *baseURL = [[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]] absoluteString];
	NSString *html = [NSString stringWithFormat:shell, styleURL, baseURL];

	[_webView loadHTMLString:html baseURL:nil];

	return self;
}

/*
- (BOOL) respondsToSelector:(SEL) selector {
	NSLog(@"respondsToSelector: %s", selector);
	return [super respondsToSelector:selector];
}
*/

- (void) mouseDown:(struct __GSEvent *) event {
	_wasScrolling = NO;
	_clickedLink = NO;

	[super mouseDown:event];
}

- (void) mouseDragged:(struct __GSEvent *) event {
	[super mouseDragged:event];

	_wasScrolling = [self isScrolling];
}

- (void) mouseUp:(struct __GSEvent *) event {
	if( ! _wasScrolling && ! [self isDecelerating] && !_clickedLink ) {
		if( [[self delegate] respondsToSelector:@selector( styleViewDidAcceptFocusClick: )] )
			[[self delegate] styleViewDidAcceptFocusClick:self];
	}

	_wasScrolling = NO;
	_clickedLink = NO;

	[super mouseUp:event];
}

- (void) updateWebViewHeight {
	DOMHTMLElement *body = [self body];
	CGRect frame = [_webView frame];
	frame.size.height = [body offsetHeight];
	[_webView setFrame:frame];
	[self setContentSize:frame.size];
}

- (CGPoint) bottomScrollOffset {
	[self updateWebViewHeight];

	CGRect contentSize = [[_webView webView] frame];
	return CGPointMake(0, contentSize.size.height - [self frame].size.height);
}

- (void) scrollToBottom {
	[self scrollToBottomAnimated:YES];
}

- (void) scrollToBottomAnimated:(BOOL) animate {
	[self scrollPointVisibleAtTopLeft:[self bottomScrollOffset] animated:animate];
}

- (DOMHTMLElement *) body {
	return [(DOMHTMLDocument *)[[[_webView webView] mainFrame] DOMDocument] body];
}

- (void) webView:(WebView *) webView decidePolicyForNewWindowAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request newFrameName:(NSString *) newFrameName decisionListener:(id) listener {
	[listener performSelector:@selector( ignore )];
	[UIApp openURL:[actionInformation objectForKey:@"WebActionOriginalURLKey"] asPanel:YES];
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id) listener {
	NSURL *url = [actionInformation objectForKey:@"WebActionOriginalURLKey"];
	if( [[url scheme] isEqualToString:@"about"] ) {
		[listener performSelector:@selector( use )];
	} else {
		_clickedLink = YES;
		[listener performSelector:@selector( ignore )];
		[UIApp openURL:url asPanel:YES];
	}
}
@end
