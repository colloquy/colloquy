#import "CQChatTranscriptView.h"

#import "NSStringAdditions.h"

#import <AGRegex/AGRegex.h>
#import <ChatCore/MVChatUser.h>

@interface UIScroller : UIView
@property (nonatomic) BOOL showBackgroundShadow;
@property (nonatomic) CGPoint offset;
- (void) displayScrollerIndicators;
@end

#pragma mark -

@interface UIWebView (UIWebViewPrivate)
- (void) scrollerWillStartDragging:(UIScroller *) scroller;
- (void) scrollerDidEndDragging:(UIScroller *) scroller willSmoothScroll:(BOOL) smooth;
- (void) scrollerDidEndSmoothScrolling:(UIScroller *) scroller;
- (UIScroller *) _scroller;
@end

#pragma mark -

@interface CQChatTranscriptView (Internal)
- (void) _addMessagesToTranscript:(NSArray *) messages asFormerMessages:(BOOL) former;
- (void) _commonInitialization;
- (void) _reset;
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
	[_pendingMessages release];
	[_pendingFormerMessages release];
	[super dealloc];
}

@synthesize delegate;

#pragma mark -

- (BOOL) canBecomeFirstResponder {
	return !_scrolling;
}

- (void) didFinishScrolling {
	if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(offset)]) {
		NSString *command = [NSString stringWithFormat:@"updateScrollPosition(%f)", [self _scroller].offset.y];
		[self stringByEvaluatingJavaScriptFromString:command];
	}

	_scrolling = NO;
}

#pragma mark -

- (void) scrollerWillStartDragging:(UIScroller *) scroller {
	[super scrollerWillStartDragging:scroller];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrolling) object:nil];
	_scrolling = YES;
}

- (void) scrollerDidEndDragging:(UIScroller *) scroller willSmoothScroll:(BOOL) smooth {
	[super scrollerDidEndDragging:scroller willSmoothScroll:smooth];
	if (!smooth)
		[self performSelector:@selector(didFinishScrolling) withObject:nil afterDelay:0.5];
}

- (void) scrollerDidEndSmoothScrolling:(UIScroller *) scroller {
	[super scrollerDidEndSmoothScrolling:scroller];
	[self performSelector:@selector(didFinishScrolling) withObject:nil afterDelay:0.5];
}

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
	_loading = NO;

	[self _addMessagesToTranscript:_pendingFormerMessages asFormerMessages:YES];

	[_pendingFormerMessages release];
	_pendingFormerMessages = nil;

	[self _addMessagesToTranscript:_pendingMessages asFormerMessages:NO];

	[_pendingMessages release];
	_pendingMessages = nil;
}

#pragma mark -

- (void) addFormerMessages:(NSArray *) messages {
	NSParameterAssert(messages != nil);

	if (_loading) {
		if (_pendingFormerMessages) [_pendingFormerMessages addObjectsFromArray:messages];
		else _pendingFormerMessages = [messages mutableCopy];
		return;
	}

	[self _addMessagesToTranscript:messages asFormerMessages:YES];
}

- (void) addMessages:(NSArray *) messages {
	NSParameterAssert(messages != nil);

	if (_loading) {
		if (_pendingMessages) [_pendingMessages addObjectsFromArray:messages];
		else _pendingMessages = [messages mutableCopy];
		return;
	}

	[self _addMessagesToTranscript:messages asFormerMessages:NO];
}

- (void) addMessage:(NSDictionary *) message {
	NSParameterAssert(message != nil);

	if (_loading) {
		if (!_pendingMessages)
			_pendingMessages = [[NSMutableArray alloc] init];
		[_pendingMessages addObject:message];
		return;
	}

	[self _addMessagesToTranscript:[NSArray arrayWithObject:message] asFormerMessages:NO];
}

- (void) scrollToBottomAnimated:(BOOL) animated {
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollToBottom(%@)", (animated ? @"true" : @"false")]];
}

- (void) flashScrollIndicators {
	if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(displayScrollerIndicators)])
		[[self _scroller] displayScrollerIndicators];
}

#pragma mark -

- (void) _addMessagesToTranscript:(NSArray *) messages asFormerMessages:(BOOL) former {
	NSMutableString *command = [[NSMutableString alloc] initWithString:@"appendMessages(["];

	for (NSDictionary *message in messages) {
		MVChatUser *user = [message objectForKey:@"user"];
		NSString *messageString = [message objectForKey:@"message"];
		if (!user || !messageString)
			continue;

		BOOL action = [[message objectForKey:@"action"] boolValue];
		BOOL highlighted = [[message objectForKey:@"highlighted"] boolValue];

		NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];
		NSString *escapedMessage = [messageString stringByEscapingCharactersInSet:escapedCharacters];
		NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapedCharacters];

		[command appendFormat:@"{sender:'%@',message:'%@',highlighted:%@,action:%@,self:%@},", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false")];
	}

	[command appendFormat:@"],%@)", (former ? @"true" : @"false")];

	[self stringByEvaluatingJavaScriptFromString:command];

	[command release];
}

- (void) _commonInitialization {
	super.delegate = self;

	[self setBackgroundColor:[UIColor whiteColor]];

	if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(setShowBackgroundShadow:)])
		[self _scroller].showBackgroundShadow = NO;

	[self _reset];
}

- (NSString *) _contentHTML {
	return [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"base" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];
}

- (void) _reset {
	[self stopLoading];

	_loading = YES;
	[self loadHTMLString:[self _contentHTML] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
}
@end
