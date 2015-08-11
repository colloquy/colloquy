#import "CQWKChatTranscriptView.h"

#import <ChatCore/MVChatUser.h>

#import "NSNotificationAdditions.h"

#define DefaultFontSize 14
#define HideRoomTopicDelay 30.

static NSString *const CQRoomTopicChangedNotification = @"CQRoomTopicChangedNotification";

#pragma mark -

@implementation CQWKChatTranscriptView
@synthesize transcriptDelegate = _transcriptDelegate;

@synthesize timestampPosition = _timestampPosition;
@synthesize allowsStyleChanges = _allowsStyleChanges;
@synthesize allowSingleSwipeGesture = _allowSingleSwipeGesture;
@synthesize fontFamily = _fontFamily;
@synthesize fontSize = _fontSize;
@synthesize styleIdentifier = _styleIdentifier;

- (instancetype) initWithFrame:(CGRect) frame {
	WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
	configuration.allowsInlineMediaPlayback = YES;
	configuration.processPool = [[WKProcessPool alloc] init];

	if (!(self = [super initWithFrame:frame configuration:configuration]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (void) dealloc {
	self.scrollView.delegate = nil;
	self.navigationDelegate = nil;

	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[[NSNotificationCenter chatCenter] removeObserver:self name:CQRoomTopicChangedNotification object:nil];
	[[NSNotificationCenter chatCenter] removeObserver:self name:CQSettingsDidChangeNotification object:nil];
}

#pragma mark -

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

	[self resetSoon];
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

- (void) willStartScrolling {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];

	[self stringByEvaluatingJavaScriptFromString:@"suspendAutoscroll()"];

	_scrolling = YES;
}

- (void) didFinishScrolling {
	[self stringByEvaluatingJavaScriptFromString:@"resumeAutoscroll()"];

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
	point = [self convertPoint:point toView:self.scrollView];

	__block NSString *tappedURL = nil;
#define TappedPointOffset 20
	for (int x = point.x - TappedPointOffset, i = 0; i < 3 && !tappedURL.length; x += TappedPointOffset, i++)
		for (int y = point.y - TappedPointOffset, j = 0; j < 3 && !tappedURL.length; y += TappedPointOffset, j++) {
			[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"urlUnderTapAtPoint(%d, %d)", x, y] completionHandler:^(NSString *result) {
				if (tappedURL.length) // if a different execution found a URL already, don't call the delegate again
					return;

				tappedURL = [result copy];
#undef TappedPointOffset

				if (!tappedURL.length)
					return;

				if (transcriptDelegate && [transcriptDelegate respondsToSelector:@selector(transcriptView:handleLongPressURL:atLocation:)])
					[transcriptDelegate transcriptView:self handleLongPressURL:[NSURL URLWithString:tappedURL] atLocation:_lastTouchLocation];
			}];
		}
}

- (void) swipeGestureRecognized:(UISwipeGestureRecognizer *) swipeGestureRecognizer {
	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	if (transcriptDelegate && [transcriptDelegate respondsToSelector:@selector(transcriptView:receivedSwipeWithTouchCount:leftward:)])
		[transcriptDelegate transcriptView:self receivedSwipeWithTouchCount:swipeGestureRecognizer.numberOfTouches leftward:(swipeGestureRecognizer.direction & UISwipeGestureRecognizerDirectionLeft)];
}

#pragma mark -

- (UIView *) hitTest:(CGPoint) point withEvent:(UIEvent *) event {
	_lastTouchLocation = [[UIApplication sharedApplication].keyWindow.rootViewController.view convertPoint:point fromView:self];

	return [super hitTest:point withEvent:event];;
}

#pragma mark -

- (void) webView:(WKWebView *) webView decidePolicyForNavigationAction:(WKNavigationAction *) navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy)) decisionHandler {
	if (navigationAction.navigationType == WKNavigationTypeOther) {
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}

	if (navigationAction.navigationType != WKNavigationTypeLinkActivated) {
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}

	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	if ([navigationAction.request.URL.scheme isCaseInsensitiveEqualToString:@"colloquy"]) {
		if ([transcriptDelegate respondsToSelector:@selector(transcriptView:handleNicknameTap:atLocation:)]) {
			NSRange endOfSchemeRange = [navigationAction.request.URL.absoluteString rangeOfString:@"://"];
			if (endOfSchemeRange.location == NSNotFound) {
				decisionHandler(WKNavigationActionPolicyCancel);
				return;
			}

			NSString *nickname = [[navigationAction.request.URL.absoluteString substringFromIndex:(endOfSchemeRange.location + endOfSchemeRange.length)] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[transcriptDelegate transcriptView:self handleNicknameTap:nickname atLocation:_lastTouchLocation];
		}

		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}

	if ([transcriptDelegate respondsToSelector:@selector(transcriptView:handleOpenURL:)]) {
		if ([transcriptDelegate transcriptView:self handleOpenURL:navigationAction.request.URL]) {
			decisionHandler(WKNavigationActionPolicyCancel);
			return;
		}
	}

	[[UIApplication sharedApplication] openURL:navigationAction.request.URL];

	decisionHandler(WKNavigationActionPolicyCancel);
}

- (void) webView:(WKWebView *) webView didFinishNavigation:(WKNavigation *) navigation {
	[self performSelector:@selector(_checkIfLoadingFinished) withObject:nil afterDelay:0.];

//	[self stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];

	if (UIAccessibilityIsBoldTextEnabled())
		[self stringByEvaluatingJavaScriptFromString:@"document.body.style.fontWeight='bold';"];
	else [self stringByEvaluatingJavaScriptFromString:@"document.body.style.fontWeight='';"];
}

#pragma mark -

- (void) addPreviousSessionComponents:(NSArray *) components {
	NSParameterAssert(components != nil);

	if (_loading || _resetPending) {
		if (_pendingPreviousSessionComponents) [_pendingPreviousSessionComponents addObjectsFromArray:components];
		else _pendingPreviousSessionComponents = [components mutableCopy];
		return;
	}

#if !defined(CQ_GENERATING_SCREENSHOTS)
	[self _addComponentsToTranscript:components fromPreviousSession:YES animated:NO];
#else
	[self _addComponentsToTranscript:components fromPreviousSession:NO animated:NO];
#endif
}

- (void) addComponents:(NSArray *) components animated:(BOOL) animated {
	NSParameterAssert(components != nil);

	if (_loading || _resetPending) {
		if (_pendingComponents) [_pendingComponents addObjectsFromArray:components];
		else _pendingComponents = [components mutableCopy];
		return;
	}

	[self _addComponentsToTranscript:components fromPreviousSession:NO animated:animated];
}

- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated {
	NSParameterAssert(component != nil);

	if (_loading || _resetPending) {
		if (!_pendingComponents)
			_pendingComponents = [[NSMutableArray alloc] init];
		[_pendingComponents addObject:component];
		return;
	}

	[self _addComponentsToTranscript:@[component] fromPreviousSession:NO animated:animated];
}

- (void) noteNicknameChangedFrom:(NSString *) oldNickname to:(NSString *) newNickname {
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"nicknameChanged(\"%@\", \"%@\")", oldNickname, newNickname]];
}

- (void) noteTopicChangeTo:(NSString *) newTopic by:(NSString *) username {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideRoomTopic) object:nil];

	_roomTopic = [newTopic copy];
	_roomTopicSetter = [username copy];

	if (_loading || _resetPending) {
		return;
	}

	BOOL shouldHideTopic = YES;
	if (_showRoomTopic != CQShowRoomTopicNever && newTopic.length) {
		shouldHideTopic = NO;

		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"changeTopic('%@', '%@', '%@')", newTopic, username, newTopic.length ? @"false" : @"true"]];

		if (_showRoomTopic == CQShowRoomTopicOnChange)
			[self performSelector:@selector(_hideRoomTopic) withObject:nil afterDelay:HideRoomTopicDelay];
	}

	if (shouldHideTopic) {
		[self _hideRoomTopic];
	} else if (_topicIsHidden && !shouldHideTopic && !_addedMessage) {
		_topicIsHidden = NO;
		_addedMessage = YES;

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

- (void) flashScrollIndicators {
	[self.scrollView flashScrollIndicators];
}

- (void) markScrollback {
	[self stringByEvaluatingJavaScriptFromString:@"markScrollback()"];
}

- (void) resetSoon {
	if (_resetPending)
		return;

	_resetPending = YES;
	[self performSelector:@selector(reset) withObject:nil afterDelay:0];
}

- (void) reset {
	_resetPending = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reset) object:nil];

	[self stopLoading];

	_blockerView.hidden = NO;

	_loading = YES;
	[self loadHTMLString:[self _contentHTML] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];

	__strong __typeof__((_transcriptDelegate)) transcriptDelegate = _transcriptDelegate;
	if ([transcriptDelegate respondsToSelector:@selector(transcriptViewWasReset:)])
		[transcriptDelegate transcriptViewWasReset:self];
}

#pragma mark -

- (void) evaluateJavaScript:(NSString *) script completionHandler:(void (^)(id, NSError *)) completionHandler {
	NSLog(@"Refusing to evaluate %@\n%@", script, [NSThread callStackSymbols]);
}

- (void) stringByEvaluatingJavaScriptFromString:(NSString *) script {
	[self stringByEvaluatingJavaScriptFromString:script completionHandler:NULL];
}

- (void) stringByEvaluatingJavaScriptFromString:(NSString *) script completionHandler:(void (^)(NSString *)) completionHandler {
	if (!script.length)
		return;

	[super evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
		if (!result && error)
			NSLog(@"Error executing JavaScript: %@, %@", script, error);
		else if (result) {
			if ([result isKindOfClass:[NSNumber class]])
				result = [result stringValue];
			else if ([result isKindOfClass:[NSNull class]])
				result = @"null";

			if (completionHandler)
				completionHandler(result);
		}
	}];
}

#pragma mark -

- (void) _addComponentsToTranscript:(NSArray *) components fromPreviousSession:(BOOL) previousSession animated:(BOOL) animated {
	if (!components.count)
		return;

	NSMutableString *command = [[NSMutableString alloc] initWithString:@"appendComponents(["];
	NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];

	for (NSDictionary *component in components) {
		NSString *type = component[@"type"];
		NSString *messageString = component[@"message"];
		if (!messageString)
			continue;

		NSString *escapedMessage = [messageString stringByEscapingCharactersInSet:escapedCharacters];
		BOOL isMessage = [type isEqualToString:@"message"];
		BOOL isNotice = [component[@"notice"] boolValue];

		if (isMessage || isNotice) {
			MVChatUser *user = component[@"user"];
			if (!user)
				continue;

			BOOL action = [component[@"action"] boolValue];
			BOOL highlighted = [component[@"highlighted"] boolValue];

			NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapedCharacters];
			NSString *timestamp = component[@"timestamp"];

			if (isNotice)
				[command appendFormat:@"{type:'notice',sender:'%@',message:'%@',highlighted:%@,action:%@,self:%@,timestamp:'%@'},", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false"), timestamp ? timestamp : @""];
			else [command appendFormat:@"{type:'message',sender:'%@',message:'%@',highlighted:%@,action:%@,self:%@,timestamp:'%@'},", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false"), timestamp ? timestamp : @""];
		} else if ([type isEqualToString:@"event"]) {
			NSString *identifier = component[@"identifier"];
			if (!identifier)
				continue;

			NSString *escapedIdentifer = [identifier stringByEscapingCharactersInSet:escapedCharacters];

			[command appendFormat:@"{type:'event',message:'%@',identifier:'%@'},", escapedMessage, escapedIdentifer];
		} else if ([type isEqualToString:@"console"]) {
			[command appendFormat:@"{type:'console',message:'%@',outbound:%@},", escapedMessage, ([component[@"outbound"] boolValue] ? @"true" : @"false")];
		}
	}

	[command appendFormat:@"],%@,false,%@)", (previousSession ? @"true" : @"false"), (animated ? @"false" : @"true")];

	[self stringByEvaluatingJavaScriptFromString:command];
	if (_showRoomTopic && !_addedMessage) {
		_addedMessage = YES;
		[self stringByEvaluatingJavaScriptFromString:@"addOffsetForTopicToFirstElement()"];
	}
}

- (void) _commonInitialization {
	self.scrollView.delegate = self;
	self.navigationDelegate = self;

	[self.scrollView performPrivateSelector:@"setShowBackgroundShadow:" withBoolean:NO];

	_allowsStyleChanges = YES;
	_blockerView = [[UIView alloc] initWithFrame:self.bounds];
	_blockerView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	[self addSubview:_blockerView];

	self.styleIdentifier = @"standard";

	[self resetSoon];

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

	UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognizerRecognized:)];
	longPressGestureRecognizer.delegate = self;

	[self addGestureRecognizer:longPressGestureRecognizer];

	_showRoomTopic = (CQShowRoomTopic)[[CQSettingsController settingsController] integerForKey:@"CQShowRoomTopic"];
	_addedMessage = NO;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userDefaultsChanged:) name:CQSettingsDidChangeNotification object:nil];
}

- (void) _userDefaultsChanged:(NSNotification *) notification {
	CQShowRoomTopic shouldShowRoomTopic = (CQShowRoomTopic)[[CQSettingsController settingsController] integerForKey:@"CQShowRoomTopic"];
	if (_showRoomTopic == shouldShowRoomTopic)
		return;

	_showRoomTopic = shouldShowRoomTopic;
	_addedMessage = NO;

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

	if ([[CQSettingsController settingsController] boolForKey:@"CQTimestampOnLeft"])
		[styleString appendFormat:@".timestamp { float: none; }"];

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

- (void) _checkIfLoadingFinished {
	[self stringByEvaluatingJavaScriptFromString:@"isDocumentReady()" completionHandler:^(NSString *result) {
		if (![result boolValue]) {
			[self performSelector:_cmd withObject:nil afterDelay:0.05];
			return;
		}

		_loading = NO;

		[self _addComponentsToTranscript:_pendingPreviousSessionComponents fromPreviousSession:YES animated:NO];

		_pendingPreviousSessionComponents = nil;

		[self _addComponentsToTranscript:_pendingComponents fromPreviousSession:NO animated:NO];

		_pendingComponents = nil;

		[self performSelector:@selector(_unhideBlockerView) withObject:nil afterDelay:0.05];

		[self noteTopicChangeTo:_roomTopic by:_roomTopicSetter];

		// initialize this here as well because if first we set it before the document finishes loading, it won't take.
		self.timestampPosition = _timestampPosition;
	}];
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
