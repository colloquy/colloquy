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

static void commonChatReplacment(NSMutableString *string, NSRangePointer textRange) {
	[string substituteEmoticonsForEmojiInRange:textRange];

	// Catch IRC rooms like "#room" but not HTML colors like "#ab12ef" nor HTML entities like "&#135;" or "&amp;".
	// Catch well-formed urls like "http://www.apple.com", "www.apple.com" or "irc://irc.javelin.cc".
	// Catch well-formed email addresses like "user@example.com" or "user@example.co.uk".
	static AGRegex *urlRegex;
	if (!urlRegex)
		urlRegex = [[AGRegex alloc] initWithPattern:@"(?P<room>\\B(?<!&amp;)#(?![\\da-fA-F]{6}\\b|\\d{1,3}\\b)[\\w-_.+&;#]{2,}\\b)|(?P<url>(?:[a-zA-Z][a-zA-Z0-9+.-]{2,}://|www\\.)[\\p{L}\\p{N}$\\-_+*'=\\|/\\\\(){}[\\]%@&#~,:;.!?]{4,}[\\p{L}\\p{N}$\\-_+*=\\|/\\\\({%@&;#~])|(?P<email>[\\p{L}\\p{N}.+\\-_]+@(?:[\\p{L}\\-_]+\\.)+[\\w]{2,})" options:AGRegexCaseInsensitive];

	AGRegexMatch *match = [urlRegex findInString:string range:*textRange];
	while (match) {
		NSString *room = [match groupNamed:@"room"];
		NSString *url = [match groupNamed:@"url"];
		NSString *email = [match groupNamed:@"email"];

		NSString *linkHTMLString = nil;
		if (room.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"irc:///%@\">%1$@</a>", room];
		} else if (url.length) {
			NSString *fullURL = ([url hasPrefix:@"www."] ? [@"http://" stringByAppendingString:url] : url);
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", fullURL, url];
		} else if (email.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"mailto:%@\">%1$@</a>", email];
		}

		if (linkHTMLString) {
			[string replaceCharactersInRange:match.range withString:linkHTMLString];

			textRange->length += (linkHTMLString.length - match.range.length);
		}

		NSRange matchRange = NSMakeRange(match.range.location + linkHTMLString.length, (NSMaxRange(*textRange) - match.range.location - linkHTMLString.length));
		if (!matchRange.length)
			break;

		match = [urlRegex findInString:string range:matchRange];
	}
}

static void applyFunctionToTextInMutableHTMLString(NSMutableString *html, NSRangePointer range, void (*function)(NSMutableString *, NSRangePointer)) {
	if (!html || !function || !range)
		return;

	NSRange tagEndRange = NSMakeRange(range->location, 0);
	while (1) {
		NSRange tagStartRange = [html rangeOfString:@"<" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(tagEndRange), (NSMaxRange(*range) - NSMaxRange(tagEndRange)))];
		if (tagStartRange.location == NSNotFound) {
			NSUInteger length = (NSMaxRange(*range) - NSMaxRange(tagEndRange));
			NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), length);
			if (length) {
				function(html, &textRange);
				range->length += (textRange.length - length);
			}

			break;
		}

		NSUInteger length = (tagStartRange.location - NSMaxRange(tagEndRange));
		NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), length);
		if (length) {
			function(html, &textRange);
			range->length += (textRange.length - length);
		}

		tagEndRange = [html rangeOfString:@">" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(textRange), (NSMaxRange(*range) - NSMaxRange(textRange)))];
		if (tagEndRange.location == NSNotFound || NSMaxRange(tagEndRange) == NSMaxRange(*range))
			break;
	}
}

static NSString *applyFunctionToTextInHTMLString(NSString *html, void (*function)(NSMutableString *, NSRangePointer)) {
	if (!html || !function)
		return html;

	NSMutableString *result = [html mutableCopy];

	NSRange range = NSMakeRange(0, result.length);
	applyFunctionToTextInMutableHTMLString(result, &range, function);

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

	if ([delegate respondsToSelector:@selector(transcriptView:handleOpenURL:)])
		if ([delegate transcriptView:self handleOpenURL:request.URL])
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

	BOOL highlighted = NO;
	if ([self.delegate respondsToSelector:@selector(highlightWordsForTranscriptView:)]) {
		NSArray *highlightWords = [self.delegate highlightWordsForTranscriptView:self];
		if (highlightWords.count) {
			NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
			NSCharacterSet *trimCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\"'"];
			NSArray *messageStrings = [transformedMessageString componentsSeparatedByXMLTags];
			NSString *singleMessageString = [messageStrings componentsJoinedByString:@""];

			for (NSString *highlightWord in highlightWords) {
				if (!highlightWord.length)
					continue;

				NSString *originalHighlightWord = highlightWord;
				AGRegex *regex = nil;
				if( [highlightWord hasPrefix:@"/"] && [highlightWord hasSuffix:@"/"] && highlightWord.length > 1 ) {
					regex = [[AGRegex alloc] initWithPattern:[highlightWord substringWithRange:NSMakeRange( 1, highlightWord.length - 2 )] options:AGRegexCaseInsensitive];
				} else {
					highlightWord = [highlightWord stringByTrimmingCharactersInSet:trimCharacters];
					highlightWord = [highlightWord stringByEscapingCharactersInSet:escapedCharacters];
					regex = [[AGRegex alloc] initWithPattern:[NSString stringWithFormat:@"(?<=^|\\s|[^\\w])%@(?=$|\\s|[^\\w])", highlightWord] options:AGRegexCaseInsensitive];
				}

				if ([regex findInString:singleMessageString]) {
					highlighted = YES;

					if ([self.delegate respondsToSelector:@selector(transcriptView:highlightedMessageWithWord:)])
						[self.delegate transcriptView:self highlightedMessageWithWord:originalHighlightWord];
				}

				[regex release];

				if (highlighted)
					break;
			}
		}
	}

	BOOL action = [[info objectForKey:@"action"] boolValue];

	NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];
	NSString *escapedMessage = [transformedMessageString stringByEscapingCharactersInSet:escapedCharacters];
	NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapedCharacters];
	NSString *command = [NSString stringWithFormat:@"appendMessage('%@', '%@', %@, %@, %@)", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false")];

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
