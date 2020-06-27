#import "CQUITextChatTranscriptView.h"

#import "CQPrinterPage.h"

#import <ChatCore/MVChatUser.h>

#if !SYSTEM(MARZIPAN)
#import "UIPrintPageRendererAdditions.h"
#endif
#import "NSNotificationAdditions.h"

#import <JavaScriptCore/JavaScriptCore.h>

#define DefaultFontSize 14
#define HideRoomTopicDelay 30.

static NSString *const CQChatRoomTopicChangedNotification = @"CQChatRoomTopicChangedNotification";

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@interface CQUITextChatTranscriptView () <UIGestureRecognizerDelegate, UITextViewDelegate>
@end

@implementation CQUITextChatTranscriptView {
@protected
	UIView *_blockerView;
	NSMutableArray <NSDictionary *> *_pendingPreviousSessionComponents;
	NSMutableArray <NSDictionary *> *_pendingComponents;
	NSUInteger _fontSize;
	BOOL _scrolling;
	CGPoint _lastTouchLocation;
	NSMutableArray *_singleSwipeGestureRecognizers;
	CQShowRoomTopic _showRoomTopic;
	NSString *_roomTopic;
	NSString *_roomTopicSetter;
	BOOL _topicIsHidden;
	BOOL _autoscrollSuspended;
	NSMutableArray *_components;
	JSContext *_javaScriptContext;
}

@synthesize transcriptDelegate = _transcriptDelegate;

@synthesize timestampPosition = _timestampPosition;
@synthesize allowsStyleChanges = _allowsStyleChanges;
@synthesize allowSingleSwipeGesture = _allowSingleSwipeGesture;
@synthesize fontFamily = _fontFamily;
@synthesize fontSize = _fontSize;
@synthesize styleIdentifier = _styleIdentifier;
@synthesize readyForDisplay = _readyForDisplay;
@synthesize scrollbackLimit = _scrollbackLimit;

- (instancetype) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (nullable instancetype) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (void) dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[[NSNotificationCenter chatCenter] removeObserver:self name:CQChatRoomTopicChangedNotification object:nil];
	[[NSNotificationCenter chatCenter] removeObserver:self name:CQSettingsDidChangeNotification object:nil];

	super.delegate = nil;
}

#pragma mark -

- (void) setDelegate:(id <UITextViewDelegate> __nullable) delegate {
	NSAssert(NO, @"Should not be called. Use _transcriptDelegate instead.");
}

- (BOOL) isLoading {
	return NO;
}

- (void) setAllowSingleSwipeGesture:(BOOL) allowSingleSwipeGesture {
	if (allowSingleSwipeGesture == _allowSingleSwipeGesture)
		return;

	_allowSingleSwipeGesture = allowSingleSwipeGesture;

	for (UISwipeGestureRecognizer *swipeGestureRecognizer in _singleSwipeGestureRecognizers)
		swipeGestureRecognizer.enabled = _allowSingleSwipeGesture;
}

- (void) setStyleIdentifier:(NSString *) styleIdentifier {
	NSParameterAssert(styleIdentifier);
	NSParameterAssert(styleIdentifier.length);

	if (!_allowsStyleChanges || [_styleIdentifier isEqualToString:styleIdentifier])
		return;

	_styleIdentifier = [styleIdentifier copy];

	if ([styleIdentifier hasSuffix:@"-dark"])
		self.backgroundColor = [UIColor blackColor];
	else if ([styleIdentifier isEqualToString:@"notes"])
		self.backgroundColor = [UIColor colorWithRed:(253. / 255.) green:(251. / 255.) blue:(138. / 255.) alpha:1.];
	else self.backgroundColor = [UIColor whiteColor];

	UIScrollView *scrollView = self.scrollView;
	if (scrollView)
		scrollView.indicatorStyle = [styleIdentifier hasSuffix:@"-dark"] ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleDefault;

	_blockerView.backgroundColor = self.backgroundColor;

	[self reset];
}

- (void) setFontFamily:(NSString *) fontFamily {
	// Since _fontFamily or fontFamily can be nil we also need to check pointer equality.
	if (!_allowsStyleChanges || _fontFamily == fontFamily || [_fontFamily isEqualToString:fontFamily])
		return;

	_fontFamily = [fontFamily copy];

	[self _reloadVariantStyle];
}

- (void) setFontSize:(NSUInteger) fontSize {
	if (_fontSize == fontSize)
		return;

	_fontSize = fontSize;

	[self _reloadVariantStyle];
}

- (NSData *) PDFRepresentation {
	if (self.isLoading)
		return nil;

#if !SYSTEM(TV)
	UIPrintPageRenderer *renderer = [[UIPrintPageRenderer alloc] init];
	[renderer addPrintFormatter:self.viewPrintFormatter startingAtPageAtIndex:0];

	CQPrinterPage *page = [[CQPrinterPage alloc] init];

	UIEdgeInsets paperMargin = page.suggestedPaperMargin;
	CGSize paperSize = page.suggestedPaperSize;
	CGRect paperRect = CGRectMake(0., 0., paperSize.width, paperSize.height);
	CGRect printableRect = UIEdgeInsetsInsetRect(paperRect, paperMargin);

	@try {
		[renderer setValue:[NSValue valueWithCGRect:paperRect] forKey:@"paperRect"];
		[renderer setValue:[NSValue valueWithCGRect:printableRect] forKey:@"printableRect"];
	} @catch (NSException *e) {
		NSLog(@"Failed to set PDF size information, unable to generate document: %@", e);
		return nil;
	}

	return [renderer PDFRender];
#else
	return nil;
#endif
}

- (NSString *) selectedText {
	if (self.isLoading)
		return nil;

	if (self.selectedRange.location == NSNotFound || self.selectedRange.length == 0)
		return nil;

	return [self.text substringWithRange:self.selectedRange];
}

- (UIScrollView *) scrollView {
	return self;
}

- (void) setTimestampPosition:(CQTimestampPosition) timestampPosition {
	_timestampPosition = timestampPosition;

	if (_timestampPosition == CQTimestampPositionLeft)
		[self stringByEvaluatingJavaScriptFromString:@"setTimestampPosition(\"left\");"];
	else if (_timestampPosition == CQTimestampPositionRight)
		[self stringByEvaluatingJavaScriptFromString:@"setTimestampPosition(\"right\");"];
	else [self stringByEvaluatingJavaScriptFromString:@"setTimestampPosition(null);"];
}

#pragma mark -

- (BOOL) canBecomeFirstResponder {
	return !_scrolling;
}

- (void) setScrollbackLimit:(BOOL) scrollbackLimit {
	_scrollbackLimit = scrollbackLimit;

	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setScrollbackLimit(%tu)", scrollbackLimit]];
}

- (void) willStartScrolling {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];

	_autoscrollSuspended = YES;
	_scrolling = YES;
}

- (void) didFinishScrolling {
	_autoscrollSuspended = NO;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];
	[self performSelector:@selector(didFinishScrollingRecently) withObject:nil afterDelay:0.5];
}

- (void) didFinishScrollingRecently {
	_scrolling = NO;
}

#pragma mark -

- (BOOL) gestureRecognizer:(UIGestureRecognizer *) gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *) otherGestureRecognizer {
	return YES;
}

#pragma mark -

- (void) scrollViewWillBeginDragging:(UIScrollView *) scrollView {
	[self willStartScrolling];
}

- (void) scrollViewDidEndDragging:(UIScrollView *) scrollView willDecelerate:(BOOL) decelerate {
	if (!decelerate) [self didFinishScrolling];
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *) scrollView {
	[self didFinishScrolling];
}

#pragma mark -

- (void) longPressGestureRecognizerRecognized:(UILongPressGestureRecognizer *) longPressGestureRecognizer {
	if (longPressGestureRecognizer.state != UIGestureRecognizerStateBegan)
		return;

	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	BOOL shouldBecomeFirstResponder = YES;
	if ([transcriptDelegate respondsToSelector:@selector(transcriptViewShouldBecomeFirstResponder:)])
		shouldBecomeFirstResponder = [transcriptDelegate transcriptViewShouldBecomeFirstResponder:self];

	if (shouldBecomeFirstResponder)
		[self performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.];

	CGPoint point = [longPressGestureRecognizer locationInView:self];

	UITextRange *range = [self characterRangeAtPoint:point];
	NSInteger location = [self offsetFromPosition:self.beginningOfDocument toPosition:range.start];
	NSString *tappedURL = [[self.attributedText attribute:NSLinkAttributeName atIndex:location effectiveRange:NULL] absoluteString];

	if (!tappedURL.length)
		return;

	if (transcriptDelegate && [transcriptDelegate respondsToSelector:@selector(transcriptView:handleLongPressURL:atLocation:)])
		[transcriptDelegate transcriptView:self handleLongPressURL:[NSURL URLWithString:tappedURL] atLocation:_lastTouchLocation];
}

- (void) swipeGestureRecognized:(UISwipeGestureRecognizer *) swipeGestureRecognizer {
	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	if (transcriptDelegate && [transcriptDelegate respondsToSelector:@selector(transcriptView:receivedSwipeWithTouchCount:leftward:)])
		[transcriptDelegate transcriptView:self receivedSwipeWithTouchCount:swipeGestureRecognizer.numberOfTouches leftward:(swipeGestureRecognizer.direction & UISwipeGestureRecognizerDirectionLeft)];
}

#pragma mark -

- (UIView *__nullable) hitTest:(CGPoint) point withEvent:(UIEvent *__nullable) event {
	_lastTouchLocation = [[UIApplication sharedApplication].keyWindow.rootViewController.view convertPoint:point fromView:self];

	return [super hitTest:point withEvent:event];;
}

#pragma mark -

- (BOOL)textView:(UITextView *) textView shouldInteractWithURL:(NSURL *) URL inRange:(NSRange) characterRange interaction:(UITextItemInteraction) interaction {
#if SYSTEM(TV)
	return NO;
#else
	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	if ([URL.scheme isCaseInsensitiveEqualToString:@"colloquy-nav"]) {
		if ([transcriptDelegate respondsToSelector:@selector(transcriptView:handleNicknameTap:atLocation:)]) {
			NSRange endOfSchemeRange = [URL.absoluteString rangeOfString:@"://"];
			if (endOfSchemeRange.location == NSNotFound)
				return NO;

			NSString *nickname = [[URL.absoluteString substringFromIndex:(endOfSchemeRange.location + endOfSchemeRange.length)] stringByRemovingPercentEncoding];
			[transcriptDelegate transcriptView:self handleNicknameTap:nickname atLocation:_lastTouchLocation];
		}

		return NO;
	}

	if ([transcriptDelegate respondsToSelector:@selector(transcriptView:handleOpenURL:)])
		if ([transcriptDelegate transcriptView:self handleOpenURL:URL])
			return NO;

	[[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];

	return NO;
#endif
}

- (void) willMoveToSuperview:(UIView *__nullable) newSuperview {
	[super willMoveToSuperview:newSuperview];

	if (!newSuperview)
		return;

	[self _finishedLoading];
}

#pragma mark -

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) string {
	id result = [_javaScriptContext evaluateScript:string].toString;
	NSLog(@"evaluating: %@, result: %@, body: %@", string, result, [_javaScriptContext evaluateScript:@"document.body"].toString);
	return result;
}

#pragma mark -

- (void) addPreviousSessionComponents:(NSArray <NSDictionary *> *) components {
	NSParameterAssert(components != nil);

	if (_pendingPreviousSessionComponents)
		[_pendingPreviousSessionComponents addObjectsFromArray:components];
	else _pendingPreviousSessionComponents = [components mutableCopy];

#if !defined(CQ_GENERATING_SCREENSHOTS)
	[self _addComponentsToTranscript:components fromPreviousSession:YES animated:NO];
#else
	[self _addComponentsToTranscript:components fromPreviousSession:NO animated:NO];
#endif
}

- (void) addComponents:(NSArray <NSDictionary *> *) components animated:(BOOL) animated {
	NSParameterAssert(components != nil);

	if (_pendingComponents)
		[_pendingComponents addObjectsFromArray:components];
	else _pendingComponents = [components mutableCopy];

	[self _addComponentsToTranscript:components fromPreviousSession:NO animated:animated];
}

- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated {
	NSParameterAssert(component != nil);

	[self _addComponentsToTranscript:@[ component ] fromPreviousSession:NO animated:animated];
}

- (void) noteNicknameChangedFrom:(NSString *) oldNickname to:(NSString *) newNickname {
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"nicknameChanged(\"%@\", \"%@\")", oldNickname, newNickname]];
}

- (void) noteTopicChangeTo:(NSString *) newTopic by:(NSString *) username {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideRoomTopic) object:nil];

	_roomTopic = [newTopic copy];
	_roomTopicSetter = [username copy];

	BOOL shouldHideTopic = YES;
	if (_showRoomTopic != CQShowRoomTopicNever && newTopic.length) {
		shouldHideTopic = NO;

		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"changeTopic('%@', '%@', '%@')", newTopic, username, newTopic.length ? @"false" : @"true"]];

		if (_showRoomTopic == CQShowRoomTopicOnChange)
			[self performSelector:@selector(_hideRoomTopic) withObject:nil afterDelay:HideRoomTopicDelay];
	}

	if (shouldHideTopic) {
		[self _hideRoomTopic];
	} else if (_topicIsHidden && !shouldHideTopic) {
		_topicIsHidden = NO;

		[self stringByEvaluatingJavaScriptFromString:@"showTopic()"];
		[self stringByEvaluatingJavaScriptFromString:@"addOffsetForTopicToFirstElement()"];
	}
}

- (void) insertImage:(NSString *) image forElementWithIdentifier:(NSString *) elementIdentifier {
	NSString *command = [NSString stringWithFormat:@"var imageElement = document.getElementById('%@'); imageElement.src = '%@';", elementIdentifier, image];
	[self stringByEvaluatingJavaScriptFromString:command];
}

- (void) scrollToBottomAnimated:(BOOL) animated {
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollToBottom(%@)", (animated ? @"true" : @"false")]];
}

- (void) markScrollback {
	[self stringByEvaluatingJavaScriptFromString:@"markScrollback()"];
}

- (void) reset {
	_blockerView.hidden = NO;

	self.attributedText = nil;

	NSString *newBodyJS = [NSString stringWithFormat:@"document.body = '%@';", [self _contentHTML]];
	[_javaScriptContext evaluateScript:newBodyJS withSourceURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];

	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	if ([transcriptDelegate respondsToSelector:@selector(transcriptViewWasReset:)])
		[transcriptDelegate transcriptViewWasReset:self];

	_readyForDisplay = YES;
}

- (void) resetSoon {
	[self reset];
}

#pragma mark -

- (void) _addComponentsToTranscript:(NSArray *) components fromPreviousSession:(BOOL) previousSession animated:(BOOL) animated {
	if (!components.count)
		return;

	NSMutableAttributedString *componentsString = [self.attributedText mutableCopy] ?: [[NSMutableAttributedString alloc] init];

	for (NSDictionary *component in components) {
		NSString *type = component[@"type"];
		NSString *messageString = component[@"message"];
		if (!messageString)
			continue;

		NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
		attributes[@"message"] = messageString;
		attributes[@"type"] = type;

		BOOL isMessage = [type isEqualToString:@"message"];
		BOOL isNotice = [component[@"notice"] boolValue];

		NSTextAlignment alignment = NSTextAlignmentNatural;
		if (isMessage || isNotice) {
			MVChatUser *user = component[@"user"];
			if (!user)
				continue;

			BOOL action = [component[@"action"] boolValue];
			BOOL highlighted = [component[@"highlighted"] boolValue];

			attributes[@"type"] = isNotice ? @"notice" : @"message";
			attributes[@"sender"] = user.nickname;
			attributes[@"highlighted"] = @(highlighted);
			attributes[@"action"] = @(action);
			attributes[@"self"] = @(user.localUser);
			attributes[@"timestamp"] = component[@"timestamp"] ?: @"";
		} else if ([type isEqualToString:@"event"]) {
			NSString *identifier = component[@"identifier"];
			if (!identifier)
				continue;

			alignment = NSTextAlignmentCenter;
			attributes[@"identifier"] = identifier;
		} else if ([type isEqualToString:@"console"]) {
			attributes[@"outbound"] = @([component[@"outbound"] boolValue]);
		}

		NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		paragraphStyle.lineSpacing = 1.12;
		paragraphStyle.lineHeightMultiple = 1.12;
		paragraphStyle.hyphenationFactor = 0.45;
		paragraphStyle.allowsDefaultTighteningForTruncation = YES;
		paragraphStyle.alignment = alignment;

		attributes[NSParagraphStyleAttributeName] = paragraphStyle;
		attributes[NSFontAttributeName] = [UIFont fontWithName:self.fontFamily size:self.fontSize];

		NSString *string = nil;
		if (attributes[@"sender"]) {
			if ([attributes[@"action"] boolValue])
				string = [NSString stringWithFormat:@"• %@: ", attributes[@"sender"]];
			else string = [NSString stringWithFormat:@"%@: ", attributes[@"sender"]];

			UIColor *textColor = nil;
			if ([attributes[@"self"] boolValue])
				textColor = [UIColor colorWithRed:170. / 255. green:34. / 255. blue:17. / 255. alpha:1.];
			else textColor =[UIColor colorWithRed:1. green:.5 blue:0. alpha:1.];

			[componentsString appendAttributedString:[[NSAttributedString alloc] initWithString:string attributes:@{
				NSFontAttributeName: attributes[NSFontAttributeName],
				NSForegroundColorAttributeName: textColor
			}]];
		}

		NSMutableAttributedString *messageAttributedString = [[NSMutableAttributedString alloc] initWithData:[messageString dataUsingEncoding:NSUTF8StringEncoding] options:@{
			NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType
		} documentAttributes:nil error:nil];
#if SYSTEM(TV)
		[[messageAttributedString copy] enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, messageAttributedString.length) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(id value, NSRange range, BOOL *stop) {
			[messageAttributedString removeAttribute:NSLinkAttributeName range:range];
		}];
#endif
		[messageAttributedString addAttributes:attributes range:NSMakeRange(0, messageAttributedString.length)];
		[componentsString appendAttributedString:messageAttributedString];
		[componentsString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
	}

	self.attributedText = componentsString;
}

- (void) _commonInitialization {
	_components = [NSMutableArray array];

	_javaScriptContext = [[JSContext alloc] init];
	_javaScriptContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
		NSLog(@"exception in %@: %@", context, exception);
	};

	NSURL *transcriptJSURL = [[NSBundle mainBundle] URLForResource:@"transcript" withExtension:@"js"];
	NSString *transcriptJS = [NSString stringWithContentsOfURL:transcriptJSURL.filePathURL encoding:NSUTF8StringEncoding error:nil];
	[_javaScriptContext evaluateScript:transcriptJS];

	super.delegate = self;

	[self.scrollView performPrivateSelector:@"setShowBackgroundShadow:" withBoolean:NO];

	_allowsStyleChanges = YES;
	_blockerView = [[UIView alloc] initWithFrame:self.bounds];
	_blockerView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	[self addSubview:_blockerView];

	self.styleIdentifier = @"standard";

	[self reset];

#if !SYSTEM(TV)
	_allowSingleSwipeGesture = YES;
	_singleSwipeGestureRecognizers = [[NSMutableArray alloc] init];

	for (NSUInteger i = 1; i <= 3; i++) {
		UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
		swipeGestureRecognizer.numberOfTouchesRequired = i;
		swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
		swipeGestureRecognizer.cancelsTouchesInView = NO;

		[self addGestureRecognizer:swipeGestureRecognizer];
		[_singleSwipeGestureRecognizers addObject:swipeGestureRecognizer];

		swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
		swipeGestureRecognizer.numberOfTouchesRequired = i;
		swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
		swipeGestureRecognizer.cancelsTouchesInView = NO;

		[self addGestureRecognizer:swipeGestureRecognizer];
		[_singleSwipeGestureRecognizers addObject:swipeGestureRecognizer];
	}
#else
	_allowSingleSwipeGesture = NO;
#endif

	UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognizerRecognized:)];
	longPressGestureRecognizer.delegate = self;

	[self addGestureRecognizer:longPressGestureRecognizer];

	_showRoomTopic = (CQShowRoomTopic)[[CQSettingsController settingsController] integerForKey:@"CQShowRoomTopic"];

#if !SYSTEM(TV)
	self.dataDetectorTypes = UIDataDetectorTypeNone;
	self.editable = NO;
#endif

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userDefaultsChanged:) name:CQSettingsDidChangeNotification object:nil];
}

- (void) _userDefaultsChanged:(NSNotification *) notification {
	CQShowRoomTopic shouldShowRoomTopic = (CQShowRoomTopic)[[CQSettingsController settingsController] integerForKey:@"CQShowRoomTopic"];
	if (_showRoomTopic == shouldShowRoomTopic)
		return;

	_showRoomTopic = shouldShowRoomTopic;

	[self noteTopicChangeTo:_roomTopic by:_roomTopicSetter];
}

- (NSString *) _variantStyleString {
	NSMutableString *styleString = [[NSMutableString alloc] init];

	if (_fontFamily.length)
		[styleString appendFormat:@"font-family: %@; ", _fontFamily];
	if (_fontSize && _fontSize != DefaultFontSize)
		[styleString appendFormat:@"font-size: %zdpx; ", _fontSize];

	if (styleString.length) {
		[styleString insertString:@"body { " atIndex:0];
		[styleString appendString:@"}"];
	}

	return styleString;
}

- (void) _reloadVariantStyle {
	NSString *javascript = [NSString stringWithFormat:@"document.getElementById('custom').innerHTML = '%@';", [self _variantStyleString]];

	[self stringByEvaluatingJavaScriptFromString:javascript];
}

- (NSString *) _contentHTML {
	NSString *templateString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"base" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];
	return [NSString stringWithFormat:templateString, _styleIdentifier, [self _variantStyleString], @"topicSeven"];
}

- (void) _finishedLoading {
#if !defined(CQ_GENERATING_SCREENSHOTS)
	[self _addComponentsToTranscript:_pendingPreviousSessionComponents fromPreviousSession:YES animated:NO];
#else
	[self _addComponentsToTranscript:_pendingPreviousSessionComponents fromPreviousSession:NO animated:NO];
#endif

	_pendingPreviousSessionComponents = nil;

	[self _addComponentsToTranscript:_pendingComponents fromPreviousSession:NO animated:NO];

	_pendingComponents = nil;

	[self performSelector:@selector(_unhideBlockerView) withObject:nil afterDelay:CQWebViewMagicNumber];

	[self noteTopicChangeTo:_roomTopic by:_roomTopicSetter];

	// initialize this here as well because if first we set it before the document finishes loading, it won't take.
	self.timestampPosition = _timestampPosition;
}

- (void) _hideRoomTopic {
	[self stringByEvaluatingJavaScriptFromString:@"hideTopic()"];
	[self stringByEvaluatingJavaScriptFromString:@"removeOffsetForTopicFromFirstElement()"];
	_topicIsHidden = YES;
}

- (void) _unhideBlockerView {
	_blockerView.hidden = YES;
}
@end

NS_ASSUME_NONNULL_END
