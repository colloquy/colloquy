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
- (void) _addPendingMessagesToDiaply;
- (void) _commonInitialization;
- (void) _reset;
@end

#pragma mark -

struct CQEmoticonEmoji {
	NSString *emoticon;
	unichar emoji;
};

static struct CQEmoticonEmoji emoticonEmojiMap[] = {
	{ @":)", 0xe056 },
	{ @":-)", 0xe056 },
	{ @"=)", 0xe056 },
	{ @"=-)", 0xe056 },
	{ @":D", 0xe057 },
	{ @":-D", 0xe057 },
	{ @"=D", 0xe057 },
	{ @"=-D", 0xe057 },
	{ @":(", 0xe058 },
	{ @":-(", 0xe058 },
	{ @"=(", 0xe058 },
	{ @"=-(", 0xe058 },
	{ @":[", 0xe414 },
	{ @":-[", 0xe414 },
	{ @"=[", 0xe414 },
	{ @"=-[", 0xe414 },
	{ @";p", 0xe105 },
	{ @";-p", 0xe105 },
	{ @";P", 0xe105 },
	{ @";-P", 0xe105 },
	{ @";)", 0xe405 },
	{ @";-)", 0xe405 },
	{ @":p", 0xe409 },
	{ @":P", 0xe409 },
	{ @":-p", 0xe409 },
	{ @":-P", 0xe409 },
	{ @"=p", 0xe409 },
	{ @"=P", 0xe409 },
	{ @"=-p", 0xe409 },
	{ @"=-P", 0xe409 },
	{ @"^.^", 0xe415 },
	{ @"^-^", 0xe415 },
	{ @":*", 0xe417 },
	{ @":-*", 0xe417 },
	{ @"=*", 0xe417 },
	{ @"=-*", 0xe417 },
	{ @"*:", 0xe417 },
	{ @"*-:", 0xe417 },
	{ @"*=", 0xe417 },
	{ @"*-=", 0xe417 },
	{ @";*", 0xe418 },
	{ @";-*", 0xe418 },
	{ @"*;", 0xe418 },
	{ @"*-;", 0xe418 },
	{ @":&apos;(", 0xe401 },
	{ @"=&apos;(", 0xe401 },
	{ @")&apos;:", 0xe401 },
	{ @")&apos;=", 0xe401 },
	{ @":!", 0xe404 },
	{ @":-!", 0xe404 },
	{ @"=!", 0xe404 },
	{ @"=-!", 0xe404 },
	{ @"!:", 0xe404 },
	{ @"!-:", 0xe404 },
	{ @"!=", 0xe404 },
	{ @"!-=", 0xe404 },
	{ @"(&lt;3", 0xe106 },
	{ @"&lt;3", 0xe022 },
	{ @"&lt;/3", 0xe023 },
	{ @"&lt;\3", 0xe023 },
	{ @":&quot;o", 0xe411 },
	{ @"=&quot;o", 0xe411 },
	{ @":&quot;O", 0xe411 },
	{ @"=&quot;O", 0xe411 },
	{ @":&apos;D", 0xe412 },
	{ @"=&apos;D", 0xe412 },
	{ @"d:", 0xe409 },
	{ @"d=", 0xe409 },
	{ @"d-:", 0xe409 },
	{ @"(:", 0xe056 },
	{ @"(-:", 0xe056 },
	{ @"(=", 0xe056 },
	{ @"(-=", 0xe056 },
	{ @"):", 0xe058 },
	{ @")-:", 0xe058 },
	{ @")=", 0xe058 },
	{ @")-=", 0xe058 },
	{ @"]:", 0xe414 },
	{ @"]-:", 0xe414 },
	{ @"]=", 0xe414 },
	{ @"]-=", 0xe414 },
	{ @":o", 0xe410 },
	{ @":O", 0xe410 },
	{ @":-o", 0xe410 },
	{ @":-O", 0xe410 },
	{ @"=o", 0xe410 },
	{ @"=O", 0xe410 },
	{ @"=-o", 0xe410 },
	{ @"=-O", 0xe410 },
	{ @"o:", 0xe410 },
	{ @"O:", 0xe410 },
	{ @"o-:", 0xe410 },
	{ @"O-:", 0xe410 },
	{ @"o=", 0xe410 },
	{ @"O=", 0xe410 },
	{ @"o-=", 0xe410 },
	{ @"O-=", 0xe410 },
	{ @":0", 0xe410 },
	{ @":-0", 0xe410 },
	{ @"=0", 0xe410 },
	{ @"=-0", 0xe410 },
	{ @"0:", 0xe410 },
	{ @"0-:", 0xe410 },
	{ @"0=", 0xe410 },
	{ @"0-=", 0xe410 },
	{ @"(Y)", 0xe00e },
	{ @"(N)", 0xe421 },
	{ nil, 0 }
};

static void commonChatReplacment(NSMutableString *string, NSRange *textRange) {
	static NSCharacterSet *typicalEmoticonCharacters;
	if (!typicalEmoticonCharacters)
		typicalEmoticonCharacters = [[NSCharacterSet characterSetWithCharactersInString:@";:=()^"] retain];

	// Do a quick check for typical characters that are in every emoticon in emoticonEmojiMap.
	// If any of these characters are found, do the full fid and replace loop.
	if ([string rangeOfCharacterFromSet:typicalEmoticonCharacters].location != NSNotFound) {
		NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];

		for (struct CQEmoticonEmoji *entry = emoticonEmojiMap; entry && entry->emoticon; ++entry) {
			if ([string rangeOfString:entry->emoticon options:NSLiteralSearch range:*textRange].location == NSNotFound)
				continue;

			NSMutableString *emoticon = [entry->emoticon mutableCopy];
			[emoticon escapeCharactersInSet:escapedCharacters];

			NSString *emojiString = [[NSString alloc] initWithCharacters:&entry->emoji length:1];
			AGRegex *regex = [[AGRegex alloc] initWithPattern:[NSString stringWithFormat:@"(?<=\\s|^)%@(?=\\s|$)", emoticon]];

			AGRegexMatch *match = [regex findInString:string range:*textRange];
			while (match) {
				[string replaceCharactersInRange:match.range withString:emojiString];
				textRange->length -= (entry->emoticon.length - 1);

				NSRange matchRange = NSMakeRange(match.range.location + 1, (NSMaxRange(*textRange) - match.range.location - 1));
				if (!matchRange.length)
					break;

				match = [regex findInString:string range:matchRange];
			}

			[regex release];
			[emoticon release];
			[emojiString release];

			// Check for the typical characters again, if none are found then there are no more emoticons to replace.
			if ([string rangeOfCharacterFromSet:typicalEmoticonCharacters].location == NSNotFound)
				break;
		}
	}
}

static NSString *applyFunctionToTextInHTMLString(NSString *html, void (*function)(NSMutableString *, NSRange *)) {
	if (!function)
		return html;

	NSMutableString *result = [html mutableCopy];

	NSRange tagEndRange = NSMakeRange(0, 0);
	while (1) {
		NSRange tagStartRange = [result rangeOfString:@"<" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(tagEndRange), (result.length - NSMaxRange(tagEndRange)))];
		if (tagStartRange.location == NSNotFound) {
			NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), (result.length - NSMaxRange(tagEndRange)));
			if (textRange.length)
				function(result, &textRange);
			break;
		}

		NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), (tagStartRange.location - NSMaxRange(tagEndRange)));
		if (textRange.length)
			function(result, &textRange);

		tagEndRange = [result rangeOfString:@">" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(textRange), (result.length - NSMaxRange(textRange)))];
		if (tagEndRange.location == NSNotFound || NSMaxRange(tagEndRange) == result.length)
			break;
	}

	return [result autorelease];
}

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

- (void) webViewDidFinishLoad:(UIWebView *) webView {
	_loading = NO;

	[self _addPendingMessagesToDiaply];
}

#pragma mark -

- (void) addMessages:(NSArray *) messages {
	if (_pendingMessages) [_pendingMessages addObjectsFromArray:messages];
	else _pendingMessages = [messages mutableCopy];

	if (!_loading) [self _addPendingMessagesToDiaply];
}

- (void) addMessage:(NSDictionary *) info {
	if (_loading) {
		if (!_pendingMessages)
			_pendingMessages = [[NSMutableArray alloc] init];
		[_pendingMessages addObject:info];
		return;
	}

	MVChatUser *user = [info objectForKey:@"user"];
	NSData *message = [info objectForKey:@"message"];
	NSString *messageString = [[NSString alloc] initWithChatData:message encoding:NSUTF8StringEncoding];
	NSString *transformedMessageString = applyFunctionToTextInHTMLString(messageString, commonChatReplacment);

	BOOL action = [[info objectForKey:@"action"] boolValue];

	NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];
	NSString *escapedMessage = [transformedMessageString stringByEscapingCharactersInSet:escapedCharacters];
	NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapedCharacters];
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

- (void) _addPendingMessagesToDiaply {
	for (NSDictionary *info in _pendingMessages)
		[self addMessage:info];
	[_pendingMessages release];
	_pendingMessages = nil;
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
