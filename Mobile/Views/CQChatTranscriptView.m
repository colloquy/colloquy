#import "CQChatTranscriptView.h"

#import <ChatCore/MVChatUser.h>

#if ENABLE(SECRETS)
@interface UIScroller : UIView
@property (nonatomic) BOOL showBackgroundShadow;
@property (nonatomic) CGPoint offset;
- (void) displayScrollerIndicators;
@end

#pragma mark -

@interface UIScrollView (Private)
@property (nonatomic) BOOL showBackgroundShadow;
@end

#pragma mark -

@interface UIWebView (UIWebViewPrivate)
- (void) scrollerWillStartDragging:(UIScroller *) scroller;
- (void) scrollerDidEndDragging:(UIScroller *) scroller willSmoothScroll:(BOOL) smooth;
- (void) scrollerDidEndSmoothScrolling:(UIScroller *) scroller;
- (UIScroller *) _scroller;
- (UIScrollView *) _scrollView;
@end
#endif

#pragma mark -

@interface CQChatTranscriptView (Internal)
- (void) _addComponentsToTranscript:(NSArray *) components fromPreviousSession:(BOOL) previous animated:(BOOL) animated;
- (NSString *) _contentHTML;
- (void) _commonInitialization;
@end

#pragma mark -

@implementation CQChatTranscriptView
- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (void) dealloc {
	super.delegate = nil;

	[_blockerView release];
	[_styleIdentifier release];
	[_pendingComponents release];
	[_pendingPreviousSessionComponents release];

	[super dealloc];
}

#pragma mark -

@synthesize delegate;
@synthesize styleIdentifier = _styleIdentifier;

- (void) setStyleIdentifier:(NSString *) styleIdentifier {
	if ([_styleIdentifier isEqualToString:styleIdentifier])
		return;

	id old = _styleIdentifier;
	_styleIdentifier = [styleIdentifier copy];
	[old release];

	if ([styleIdentifier hasSuffix:@"-dark"])
		self.backgroundColor = [UIColor blackColor];
	else if ([styleIdentifier isEqualToString:@"notes"])
		self.backgroundColor = [UIColor colorWithRed:(253. / 255.) green:(251. / 255.) blue:(138. / 255.) alpha:1.];
	else self.backgroundColor = [UIColor whiteColor];

	_blockerView.backgroundColor = self.backgroundColor;

	[self reset];
}

#pragma mark -

- (BOOL) canBecomeFirstResponder {
	return !_scrolling;
}

- (void) willStartScrolling {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];

	[self stringByEvaluatingJavaScriptFromString:@"suspendAutoscroll()"];

	_scrolling = YES;
}

- (void) didFinishScrolling {
#if ENABLE(SECRETS)
	CGPoint offset = CGPointZero;
	if ([self respondsToSelector:@selector(_scrollView)])
		offset = [self _scrollView].contentOffset;
	else if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(offset)])
		offset = [self _scroller].offset;

	NSString *command = [NSString stringWithFormat:@"updateScrollPosition(%f)", offset.y];
	[self stringByEvaluatingJavaScriptFromString:command];
#endif

	[self stringByEvaluatingJavaScriptFromString:@"resumeAutoscroll()"];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];
	[self performSelector:@selector(didFinishScrollingRecently) withObject:nil afterDelay:0.5];
}

- (void) didFinishScrollingRecently {
	_scrolling = NO;
}

#pragma mark -

#if ENABLE(SECRETS)
- (void) scrollerWillStartDragging:(UIScroller *) scroller {
	[super scrollerWillStartDragging:scroller];

	[self willStartScrolling];
}

- (void) scrollerDidEndDragging:(UIScroller *) scroller willSmoothScroll:(BOOL) smooth {
	[super scrollerDidEndDragging:scroller willSmoothScroll:smooth];

	if (!smooth) [self didFinishScrolling];
}

- (void) scrollerDidEndSmoothScrolling:(UIScroller *) scroller {
	[super scrollerDidEndSmoothScrolling:scroller];

	[self didFinishScrolling];
}

- (void) scrollViewWillBeginDragging:(UIScrollView *) scrollView {
	[super scrollViewWillBeginDragging:scrollView];

	[self willStartScrolling];
}

- (void) scrollViewDidEndDragging:(UIScrollView *) scrollView willDecelerate:(BOOL) decelerate {
	[super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];

	if (!decelerate) [self didFinishScrolling];
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *) scrollView {
	[super scrollViewDidEndDecelerating:scrollView];

	[self didFinishScrolling];
}
#endif

#pragma mark -

- (BOOL) webView:(UIWebView *) webView shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	if (navigationType == UIWebViewNavigationTypeOther)
		return YES;

	if (navigationType != UIWebViewNavigationTypeLinkClicked)
		return NO;

	if ([delegate respondsToSelector:@selector(transcriptView:handleOpenURL:)])
		if ([delegate transcriptView:self handleOpenURL:request.URL])
			return NO;

	[[UIApplication sharedApplication] openURL:request.URL];

	return NO;
}

- (void) webViewDidFinishLoad:(UIWebView *) webView {
	[self performSelector:@selector(_checkIfLoadingFinished) withObject:nil afterDelay:0.];
}

#pragma mark -

- (void) addPreviousSessionComponents:(NSArray *) components {
	NSParameterAssert(components != nil);

	if (_loading) {
		if (_pendingPreviousSessionComponents) [_pendingPreviousSessionComponents addObjectsFromArray:components];
		else _pendingPreviousSessionComponents = [components mutableCopy];
		return;
	}

	[self _addComponentsToTranscript:components fromPreviousSession:YES animated:NO];
}

- (void) addComponents:(NSArray *) components animated:(BOOL) animated {
	NSParameterAssert(components != nil);

	if (_loading) {
		if (_pendingComponents) [_pendingComponents addObjectsFromArray:components];
		else _pendingComponents = [components mutableCopy];
		return;
	}

	[self _addComponentsToTranscript:components fromPreviousSession:NO animated:animated];
}

- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated {
	NSParameterAssert(component != nil);

	if (_loading) {
		if (!_pendingComponents)
			_pendingComponents = [[NSMutableArray alloc] init];
		[_pendingComponents addObject:component];
		return;
	}

	[self _addComponentsToTranscript:[NSArray arrayWithObject:component] fromPreviousSession:NO animated:animated];
}

- (void) scrollToBottomAnimated:(BOOL) animated {
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollToBottom(%@)", (animated ? @"true" : @"false")]];
}

- (void) flashScrollIndicators {
#if ENABLE(SECRETS)
	if ([self respondsToSelector:@selector(_scrollView)])
		[[self _scrollView] flashScrollIndicators];
	else if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(displayScrollerIndicators)])
		[[self _scroller] displayScrollerIndicators];
#endif
}

- (void) reset {
	[self stopLoading];

	_blockerView.hidden = NO;

	_loading = YES;
	[self loadHTMLString:[self _contentHTML] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
}

#pragma mark -

- (void) _addComponentsToTranscript:(NSArray *) components fromPreviousSession:(BOOL) previousSession animated:(BOOL) animated {
	NSMutableString *command = [[NSMutableString alloc] initWithString:@"appendComponents(["];
	NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];

	for (NSDictionary *component in components) {
		NSString *type = [component objectForKey:@"type"];
		if ([type isEqualToString:@"message"]) {
			MVChatUser *user = [component objectForKey:@"user"];
			NSString *messageString = [component objectForKey:@"message"];
			if (!user || !messageString)
				continue;

			BOOL action = [[component objectForKey:@"action"] boolValue];
			BOOL highlighted = [[component objectForKey:@"highlighted"] boolValue];

			NSString *escapedMessage = [messageString stringByEscapingCharactersInSet:escapedCharacters];
			NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapedCharacters];

			[command appendFormat:@"{type:'message',sender:'%@',message:'%@',highlighted:%@,action:%@,self:%@},", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false")];
		} else if ([type isEqualToString:@"event"]) {
			NSString *messageString = [component objectForKey:@"message"];
			NSString *identifier = [component objectForKey:@"identifier"];
			if (!messageString || !identifier)
				continue;

			NSString *escapedMessage = [messageString stringByEscapingCharactersInSet:escapedCharacters];
			NSString *escapedIdentifer = [identifier stringByEscapingCharactersInSet:escapedCharacters];

			[command appendFormat:@"{type:'event',message:'%@',identifier:'%@'},", escapedMessage, escapedIdentifer];
		}
	}

	[command appendFormat:@"],%@,false,%@)", (previousSession ? @"true" : @"false"), (animated ? @"false" : @"true")];

	[self stringByEvaluatingJavaScriptFromString:command];

	[command release];
}

- (void) _commonInitialization {
	super.delegate = self;

#if ENABLE(SECRETS)
	if ([self respondsToSelector:@selector(_scrollView)] && [[self _scrollView] respondsToSelector:@selector(setShowBackgroundShadow:)])
		[self _scrollView].showBackgroundShadow = NO;
	else if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(setShowBackgroundShadow:)])
		[self _scroller].showBackgroundShadow = NO;
#endif

	_blockerView = [[UIView alloc] initWithFrame:self.bounds];
	_blockerView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	[self addSubview:_blockerView];

	self.styleIdentifier = @"standard";
}

- (NSString *) _contentHTML {
	NSString *templateString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"base" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];
	return [NSString stringWithFormat:templateString, _styleIdentifier];
}

- (void) _checkIfLoadingFinished {
	NSString *result = [self stringByEvaluatingJavaScriptFromString:@"isDocumentReady()"];
	if (![result isEqualToString:@"true"]) {
		[self performSelector:_cmd withObject:nil afterDelay:0.05];
		return;
	}

	_loading = NO;

	[self _addComponentsToTranscript:_pendingPreviousSessionComponents fromPreviousSession:YES animated:NO];

	[_pendingPreviousSessionComponents release];
	_pendingPreviousSessionComponents = nil;

	[self _addComponentsToTranscript:_pendingComponents fromPreviousSession:NO animated:NO];

	[_pendingComponents release];
	_pendingComponents = nil;

	[self performSelector:@selector(_unhideBlockerView) withObject:nil afterDelay:0.05];
}

- (void) _unhideBlockerView {
	_blockerView.hidden = YES;
}
@end
