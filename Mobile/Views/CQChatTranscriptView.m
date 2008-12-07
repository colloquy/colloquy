#import "CQChatTranscriptView.h"

#import "NSStringAdditions.h"

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

	[[UIApplication sharedApplication] openURL:request.URL];

	return NO;
}

#pragma mark -

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type {
	NSString *messageString = [[NSString alloc] initWithChatData:message encoding:NSUTF8StringEncoding];
	BOOL action = [[msgAttributes objectForKey:@"action"] boolValue];

	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];
	NSString *escapedMessage = [messageString stringByEscapingCharactersInSet:escapeSet];
	NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapeSet];
	NSString *command = [NSString stringWithFormat:@"appendMessage('%@', '%@', %@, %@, %@)", escapedNickname, escapedMessage, @"false", (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false")];

	[messageString release];

	[self stringByEvaluatingJavaScriptFromString:command];
}

- (void) scrollToBottom {
	[self stringByEvaluatingJavaScriptFromString:@"scrollToBottom()"];
}

- (void) flashScrollIndicators {
	if ([self respondsToSelector:@selector(_scroller)] && [[self _scroller] respondsToSelector:@selector(displayScrollerIndicators)])
		[[self _scroller] displayScrollerIndicators];
}

#pragma mark -

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

	[self loadHTMLString:[self _contentHTML] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
}
@end
