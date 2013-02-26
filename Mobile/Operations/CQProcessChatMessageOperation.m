#import "CQProcessChatMessageOperation.h"

#import "CQColloquyApplication.h"
#import "CQIgnoreRulesController.h"

#import "NSStringAdditions.h"
#import "RegexKitLite.h"

#import <ChatCore/MVChatUser.h>

typedef enum {
	CQMentionLinkServiceNone,
	CQMentionLinkServiceTwitter,
	CQMentionLinkServiceAppDotNet
} CQMentionLinkService;

static BOOL graphicalEmoticons;
static BOOL stripMessageFormatting;
static NSMutableDictionary *highlightRegexes;
static BOOL inlineImages;
static NSString *mentionServiceRegex;
static NSString *mentionServiceReplacementFormat;

@implementation CQProcessChatMessageOperation
@synthesize ignoreController = _ignoreController;

+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	graphicalEmoticons = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQGraphicalEmoticons"];
	stripMessageFormatting = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"];

	[highlightRegexes release];
	highlightRegexes = nil;
	highlightRegexes = [[NSMutableDictionary alloc] init];
	inlineImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQInlineImages"];

	CQMentionLinkService mentionService = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQMentionLinkService"];
	if (mentionService == CQMentionLinkServiceAppDotNet) {
		mentionServiceRegex = @"\\B@[a-zA-Z0-9_]{1,20}";
		mentionServiceReplacementFormat = @"<a href=\"https://alpha.app.net/%@\">@%@</a>";
	} else if (mentionService == CQMentionLinkServiceTwitter) {
		mentionServiceRegex = @"\\B@[a-zA-Z0-9_]{1,20}";
		mentionServiceReplacementFormat = @"<a href=\"https://twitter.com/%@\">@%@</a>";
	} else {
		mentionServiceRegex = nil;
		mentionServiceReplacementFormat = nil;
	}
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

- (id) initWithMessageData:(NSData *) messageData {
	if (messageData)
		return [self initWithMessageInfo:[NSDictionary dictionaryWithObject:messageData forKey:@"message"]];
	return [self initWithMessageInfo:[NSDictionary dictionary]];
}

- (id) initWithMessageInfo:(NSDictionary *) messageInfo {
	NSParameterAssert(messageInfo != nil);

	if (!(self = [self init]))
		return nil;

	_message = [messageInfo retain];
	_encoding = NSUTF8StringEncoding;
	_fallbackEncoding = NSISOLatin1StringEncoding;

	return self;
}

- (void) dealloc {
	[_message release];
	[_processedMessage release];
	[_highlightNickname release];
	[_target release];
	[_userInfo release];

	[super dealloc];
}

#pragma mark -

@synthesize processedMessageInfo = _processedMessage;
@synthesize highlightNickname = _highlightNickname;
@synthesize encoding = _encoding;
@synthesize fallbackEncoding = _fallbackEncoding;
@synthesize target = _target;
@synthesize action = _action;
@synthesize userInfo = _userInfo;

#pragma mark -

- (NSString *) processedMessageAsHTML {
	return [_processedMessage objectForKey:@"message"];
}

- (NSString *) processedMessageAsPlainText {
	return [_processedMessage objectForKey:@"messagePlain"];
}

#pragma mark -

static void commonChatReplacment(NSMutableString *string, NSRangePointer textRange) {
	if (graphicalEmoticons)
		[string substituteEmoticonsForEmojiInRange:textRange withXMLSpecialCharactersEncodedAsEntities:YES];

	// Catch IRC rooms like "#room" but not HTML colors like "#ab12ef" nor HTML entities like "&#135;" or "&amp;".
	// Catch well-formed urls like "http://www.apple.com", "www.apple.com" or "irc://irc.javelin.cc".
	// Catch well-formed email addresses like "user@example.com" or "user@example.co.uk".
	static NSString *urlRegex = @"(\\B(?<!&amp;)#(?![\\da-fA-F]{6}\\b|\\d{1,3}\\b)[\\w-_.+&;#]{2,}\\b)|(\\b(?:[a-zA-Z][a-zA-Z0-9+.-]{2,6}:(?://){0,1}|www\\.)[\\p{L}\\p{N}\\p{P}\\p{M}\\p{S}\\p{C}]+[\\p{L}\\p{N}\\p{M}\\p{S}\\p{C}]\\)?)|([\\p{L}\\p{N}\\p{P}\\p{M}\\p{S}\\p{C}]+@(?:[\\p{L}\\p{N}\\p{P}\\p{M}\\p{S}\\p{C}]+\\.)+[\\w]{2,})"; 

	NSRange matchedRange = [string rangeOfRegex:urlRegex options:NSRegularExpressionCaseInsensitive inRange:*textRange capture:0 error:NULL];
	while (matchedRange.location != NSNotFound && (matchedRange.location + matchedRange.length) > 0) {
		NSArray *components = [string cq_captureComponentsMatchedByRegex:urlRegex options:RKLCaseless range:matchedRange error:NULL];
		NSCAssert(components.count == 4, @"component count needs to be 4");

		NSString *room = [components objectAtIndex:1];
		NSString *url = [components objectAtIndex:2];
		NSString *email = [components objectAtIndex:3];

		NSString *linkHTMLString = nil;
		if (room.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"irc:///%@\">%@</a>", room, room];
		} else if (url.length) {
			if (matchedRange.location != 0) {
				if (([string characterAtIndex:(matchedRange.location - 1)] == '(') && [url characterAtIndex:(url.length - 1)] == ')') {
					url = [url substringToIndex:(url.length - 1)];
					matchedRange = NSMakeRange(matchedRange.location, matchedRange.length - 1);
				}
			}

			NSURL *fullURL = [NSURL URLWithString:url];
			if (!fullURL.scheme.length)
				fullURL = [NSURL URLWithString:[@"http://" stringByAppendingString:url]];

			if ([[CQColloquyApplication sharedApplication] canOpenURL:fullURL]) {
				if (inlineImages && [NSFileManager isValidImageFormat:fullURL.pathExtension]) {
					linkHTMLString = [NSString stringWithFormat:@"<a href=\"%@\"><img src=\"%@\" style=\"max-width: 100%%; max-height: 100%%\"></a>", [fullURL absoluteString], [fullURL absoluteString]];
				} else {
					url = [url stringByReplacingOccurrencesOfString:@"/" withString:@"/\u200b"];
					url = [url stringByReplacingOccurrencesOfString:@"?" withString:@"?\u200b"];
					url = [url stringByReplacingOccurrencesOfString:@"=" withString:@"=\u200b"];
					url = [url stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&amp;\u200b"];
					linkHTMLString = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", [fullURL absoluteString], url];
				}
			} else linkHTMLString = url;
		} else if (email.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"mailto:%@\">%@</a>", email, email];
		}

		if (linkHTMLString || (url && linkHTMLString.length != url.length)) {
			[string replaceCharactersInRange:matchedRange withString:linkHTMLString];

			textRange->length += (linkHTMLString.length - matchedRange.length);
		}

		NSRange matchRange = NSMakeRange(matchedRange.location + linkHTMLString.length, (NSMaxRange(*textRange) - matchedRange.location - linkHTMLString.length));
		if (!matchRange.length)
			break;

		matchedRange = [string rangeOfRegex:urlRegex options:NSRegularExpressionCaseInsensitive inRange:matchRange capture:0 error:NULL];
	}
}

static void mentionChatReplacment(NSMutableString *string, NSRangePointer textRange) {
	if (!mentionServiceRegex)
		return;

	NSRange matchedRange = [string rangeOfRegex:mentionServiceRegex options:NSRegularExpressionCaseInsensitive inRange:*textRange capture:0 error:NULL];
	while (matchedRange.location != NSNotFound && (matchedRange.location + matchedRange.length) > 0) {
		NSString *matchedText = [string substringWithRange:NSMakeRange(matchedRange.location + 1, matchedRange.length - 1)]; // trim off leading @
		NSString *replacementString = [NSString stringWithFormat:mentionServiceReplacementFormat, matchedText, matchedText];
		[string replaceCharactersInRange:matchedRange withString:replacementString];

		NSRange matchRange = NSMakeRange(matchedRange.location + replacementString.length, (NSMaxRange(*textRange) - matchedRange.location - replacementString.length));
		if (!matchRange.length || matchRange.length > string.length)
			break;

		matchedRange = [string rangeOfRegex:mentionServiceRegex options:NSRegularExpressionCaseInsensitive inRange:matchRange capture:0 error:NULL];
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
			if (!length)
				break;

			NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), length);

			function(html, &textRange);
			range->length += (textRange.length - length);

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

#pragma mark -

- (NSMutableString *) _processMessageData:(NSData *) messageData {
	if (!messageData)
		return nil;

	NSMutableString *messageString = [[NSMutableString alloc] initWithChatData:messageData encoding:_encoding];
	if (!messageString && _fallbackEncoding != _encoding)
		messageString = [[NSMutableString alloc] initWithChatData:messageData encoding:_fallbackEncoding];
	if (!messageString && _encoding != NSISOLatin1StringEncoding && _fallbackEncoding != NSISOLatin1StringEncoding)
		messageString = [[NSMutableString alloc] initWithChatData:messageData encoding:NSISOLatin1StringEncoding];
	if (!messageString)
		messageString = [[NSMutableString alloc] initWithChatData:messageData encoding:NSASCIIStringEncoding];

	return [messageString autorelease];
}

- (void) _processMessageString:(NSMutableString *) messageString {
	if (!messageString.length)
		return;

	NSRange range = NSMakeRange(0, messageString.length);
	if (stripMessageFormatting) {
		[messageString stripXMLTags];

		range = NSMakeRange(0, messageString.length);
		commonChatReplacment(messageString, &range);

		range = NSMakeRange(0, messageString.length);
		mentionChatReplacment(messageString, &range);
		return;
	}

	applyFunctionToTextInMutableHTMLString(messageString, &range, commonChatReplacment);
	applyFunctionToTextInMutableHTMLString(messageString, &range, mentionChatReplacment);
}

#pragma mark -

- (void) main {
	NSArray *highlightWords = [[CQColloquyApplication sharedApplication].highlightWords retain];
	if (_highlightNickname.length && ![highlightWords containsObject:_highlightNickname]) {
		NSMutableArray *mutableHighlightWords = [highlightWords mutableCopy];
		[mutableHighlightWords insertObject:_highlightNickname atIndex:0];

		[highlightWords release];
		highlightWords = mutableHighlightWords;
	}

	NSMutableString *messageString = [self _processMessageData:[_message objectForKey:@"message"]];
	MVChatUser *user = [_message objectForKey:@"user"];

	if ([_ignoreController shouldIgnoreMessage:messageString fromUser:user inRoom:_target]) {
		[highlightWords release];
		return;
	}

	BOOL highlighted = NO;

	NSString *regex = [[highlightRegexes objectForKey:_highlightNickname] retain];
	if (user && !regex && !user.localUser && highlightWords.count) {
		NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];

		NSMutableArray *processedHighlightWords = [NSMutableArray array];
		NSMutableArray *processedHighlightCommands = [NSMutableArray array];
		for (NSString *highlightWord in highlightWords) {
			if (!highlightWord.length)
				continue;

			if ([highlightWord hasPrefix:@"/"] && [highlightWord hasSuffix:@"/"] && highlightWord.length > 1)
				[processedHighlightCommands addObject:[highlightWord substringWithRange:NSMakeRange(1, highlightWord.length - 2)]];
			else [processedHighlightWords addObject:[highlightWord stringByEscapingCharactersInSet:escapedCharacters]];
		}

		NSMutableString *processingRegex = [NSMutableString string];
		for (NSString *processedCommand in processedHighlightCommands)
			[processingRegex appendFormat:@"(%@)|", processedCommand];

		if (processingRegex.length)
			[processingRegex deleteCharactersInRange:NSMakeRange(processingRegex.length - 1, 1)];

		if (processedHighlightWords.count) {
			[processingRegex appendString:@"(\\b)("];
			for (NSString *processedWord in processedHighlightWords)
				[processingRegex appendFormat:@"(%@)|", processedWord];
			if (processingRegex.length)
				[processingRegex deleteCharactersInRange:NSMakeRange(processingRegex.length - 1, 1)];
			[processingRegex appendString:@")(\\b)"];
		}

		if (processingRegex.length)
			[highlightRegexes setObject:processingRegex forKey:_highlightNickname];
		regex = [processingRegex copy];
	}

	if (regex.length) {
		NSString *stylelessMessageString = [messageString stringByStrippingXMLTags];
		highlighted = [stylelessMessageString isMatchedByRegex:regex options:NSRegularExpressionCaseInsensitive inRange:NSMakeRange(0, stylelessMessageString.length) error:NULL];
	}
	[regex release];

	[self _processMessageString:messageString];

	static NSArray *sameKeys = nil;
	if (!sameKeys)
		sameKeys = [[NSArray alloc] initWithObjects:@"user", @"action", @"notice", @"identifier", nil];

	_processedMessage = [[NSMutableDictionary alloc] initWithKeys:sameKeys fromDictionary:_message];

	[_processedMessage setObject:@"message" forKey:@"type"];
	[_processedMessage setObject:messageString forKey:@"message"];

	NSString *plainMessage = [messageString stringByStrippingXMLTags];
	plainMessage = [plainMessage stringByDecodingXMLSpecialCharacterEntities];

	[_processedMessage setObject:plainMessage forKey:@"messagePlain"];

	if (highlighted)
		[_processedMessage setObject:[NSNumber numberWithBool:YES] forKey:@"highlighted"];

	[highlightWords release];

	if (_target && _action)
		[_target performSelectorOnMainThread:_action withObject:self waitUntilDone:NO];
}
@end
