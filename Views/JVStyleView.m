#import "JVStyleView.h"
#import "JVMarkedScroller.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "NSDateAdditions.h"

#import <objc/objc-runtime.h>

NSString *JVStyleViewDidClearNotification = @"JVStyleViewDidClearNotification";
NSString *JVStyleViewDidChangeStylesNotification = @"JVStyleViewDidChangeStylesNotification";

@interface WebCoreCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

@interface WebCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

@interface WebView (WebViewLeopard)
- (void) setDrawsBackground:(BOOL) draws; // supported in 10.3.9/Tiger
- (BOOL) drawsBackground; // supported in 10.3.9/Tiger
- (void) setBackgroundColor:(NSColor *) color; // new in Safari 3/Leopard
- (void) setProhibitsMainFrameScrolling:(BOOL) prohibit; // new in Safari 3/Leopard
- (WebFrame *) selectedFrame;
@end

#pragma mark -

@interface WebView (WebViewPrivate)
- (WebFrame *) _frameForCurrentSelection;
@end

#pragma mark -

@interface DOMNode (DOMNodeLeopard)
- (DOMNode *) insertBefore:(DOMNode *) newChild refChild:(DOMNode *) refChild;
@end

#pragma mark -

@interface DOMElement (DOMElementLeopard)
- (void) setAttribute:(NSString *) name value:(NSString *) value;
@end

#pragma mark -

@interface DOMHTMLElement (DOMHTMLElementLeopard)
- (int) offsetTop;
- (int) offsetHeight;
- (int) scrollHeight;
@end

#pragma mark -

@interface NSScrollView (NSScrollViewWebKitPrivate)
- (void) setAllowsHorizontalScrolling:(BOOL) allow;
@end

#pragma mark -

@interface DOMHTMLElement (DOMHTMLElementExtras)
- (NSUInteger) childElementLength;
- (DOMNode *) childElementAtIndex:(NSUInteger) index;
- (NSInteger) integerForDOMProperty:(NSString *) property;
- (void) setInteger:(NSInteger) value forDOMProperty:(NSString *) property;
@end

#pragma mark -

@implementation DOMHTMLElement (DOMHTMLElementExtras)
- (NSUInteger) childElementLength {
	unsigned length = 0;

	DOMNode *node = [self firstChild];
	while (node) {
		if( [node nodeType] == DOM_ELEMENT_NODE ) ++length;
		node = [node nextSibling];
	}

	return length;
}

- (DOMNode *) childElementAtIndex:(NSUInteger) index {
	unsigned count = 0;
	DOMNode *node = [self firstChild];
	while (node) {
		if( [node nodeType] == DOM_ELEMENT_NODE && count++ == index )
			return node;
		node = [node nextSibling];
	}

	return nil;
}

- (NSInteger) integerForDOMProperty:(NSString *) property {
	SEL selector = NSSelectorFromString( property );
	if( [self respondsToSelector:selector] )
		return ((int(*)(id, SEL))objc_msgSend)(self, selector);
	NSNumber *value = [self valueForKey:property];
	if( [value isKindOfClass:[NSNumber class]] )
		return [value intValue];
	return 0;
}

- (void) setInteger:(NSInteger) value forDOMProperty:(NSString *) property {
	SEL selector = NSSelectorFromString( [@"set" stringByAppendingString:[property capitalizedString]] );
	if( [self respondsToSelector:selector] ) {
		((void(*)(id, SEL, int))objc_msgSend)(self, selector, value);
	} else {
		NSNumber *number = [NSNumber numberWithLong:value];
		[self setValue:number forKey:property];
	}
}
@end

#pragma mark -

@interface JVStyleView (JVStyleViewPrivate)
- (void) _resetDisplay;
- (void) _switchStyle;
- (void) _appendMessage:(NSString *) message;
- (void) _prependMessages:(NSString *) messages;
- (void) _styleError;
- (NSString *) _contentHTMLWithBody:(NSString *) html;
- (NSURL *) _baseURL;
- (NSUInteger) _visibleMessageCount;
- (NSUInteger) _locationOfMessage:(JVChatMessage *) message;
- (NSUInteger) _locationOfElementAtIndex:(NSUInteger) index;
- (void) _setupMarkedScroller;
@end

#pragma mark -

@implementation JVStyleView
+ (void) emptyCache {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"] )
		return;

	Class webCacheClass = NSClassFromString( @"WebCache" );
	if( ! webCacheClass ) webCacheClass = NSClassFromString( @"WebCoreCache" );\

	[webCacheClass setDisabled:YES];
	[webCacheClass setDisabled:NO];
}

#pragma mark -

- (id) initWithCoder:(NSCoder *) coder {
	if( ( self = [super initWithCoder:coder] ) ) {
		_switchingStyles = NO;
		_forwarding = NO;
		_ready = NO;
		_contentFrameReady = NO;
		_requiresFullMessage = YES;
		_scrollbackLimit = 600;
		_transcript = nil;
		_style = nil;
		_styleVariant = nil;
		_styleParameters = [[NSMutableDictionary dictionary] retain];
		_emoticons = nil;
		_domDocument = nil;
		nextTextView = nil;
	}

	return self;
}

- (void) awakeFromNib {
	[self setFrameLoadDelegate:self];
	if( [self respondsToSelector:@selector(setProhibitsMainFrameScrolling:)] )
		[self setProhibitsMainFrameScrolling:YES];
	[self performSelector:@selector( _reallyAwakeFromNib ) withObject:nil afterDelay:0.];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];

	[nextTextView release];
	[_transcript release];
	[_style release];
	[_styleVariant release];
	[_styleParameters release];
	[_emoticons release];
	[_mainDocument release];
	[_domDocument release];
	[_body release];
	[_bodyTemplate release];

	nextTextView = nil;
	_transcript = nil;
	_style = nil;
	_styleVariant = nil;
	_styleParameters = nil;
	_emoticons = nil;
	_mainDocument = nil;
	_domDocument = nil;
	_body = nil;
	_bodyTemplate = nil;

	[super dealloc];
}

#pragma mark -

- (void) forwardSelector:(SEL) selector withObject:(id) object {
	if( [self nextTextView] ) {
		[[self window] makeFirstResponder:[self nextTextView]];
		[[self nextTextView] tryToPerform:selector with:object];
	}
}

#pragma mark -

- (void) keyDown:(NSEvent *) event {
	if( _forwarding ) return;
	_forwarding = YES;
	[self forwardSelector:@selector( keyDown: ) withObject:event];
	_forwarding = NO;
}

- (void) pasteAsPlainText:(id) sender {
	if( _forwarding ) return;
	_forwarding = YES;
	[self forwardSelector:@selector( pasteAsPlainText: ) withObject:sender];
	_forwarding = NO;
}

- (void) pasteAsRichText:(id) sender {
	if( _forwarding ) return;
	_forwarding = YES;
	[self forwardSelector:@selector( pasteAsRichText: ) withObject:sender];
	_forwarding = NO;
}

#pragma mark -

- (NSTextView *) nextTextView {
	return nextTextView;
}

- (void) setNextTextView:(NSTextView *) textView {
	[nextTextView autorelease];
	nextTextView = [textView retain];
}

#pragma mark -

- (void) setTranscript:(JVChatTranscript *) transcript {
	[_transcript autorelease];
	_transcript = [transcript retain];
}

- (JVChatTranscript *) transcript {
	return _transcript;
}

#pragma mark -

- (void) setStyle:(JVStyle *) style {
	[self setStyle:style withVariant:[style defaultVariantName]];
}

- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant {
	if( [style isEqualTo:[self style]] ) {
		[self setStyleVariant:variant];
		return;
	}

	[_style autorelease];
	_style = [style retain];

	[_styleVariant autorelease];
	_styleVariant = [variant copyWithZone:[self zone]];

	// add single-quotes so that these are not interpreted as XPath expressions
	[_styleParameters setObject:@"'/tmp/'" forKey:@"buddyIconDirectory"];
	[_styleParameters setObject:@"'.tif'" forKey:@"buddyIconExtension"];

	NSString *timeFormatParameter = [NSString stringWithFormat:@"'%@'", [NSDate formattedShortTimeStringForDate:[NSDate date]]];
	[_styleParameters setObject:timeFormatParameter forKey:@"timeFormat"];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _styleVariantChanged: ) name:JVStyleVariantChangedNotification object:style];

	_switchingStyles = YES;
	_requiresFullMessage = YES;

	if( ! _ready ) return;

	[self _resetDisplay];
}

- (JVStyle *) style {
	return _style;
}

#pragma mark -

- (void) setStyleVariant:(NSString *) variant {
	[_styleVariant autorelease];
	_styleVariant = [variant copyWithZone:[self zone]];

	if( _contentFrameReady ) {
		[[self class] emptyCache];

		NSString *styleSheetLocation = [[[self style] variantStyleSheetLocationWithName:_styleVariant] absoluteString];
		DOMHTMLLinkElement *element = (DOMHTMLLinkElement *)[_domDocument getElementById:@"variantStyle"];
		if( ! styleSheetLocation ) [element setHref:@""];
		else [element setHref:styleSheetLocation];

		[self performSelector:@selector( _checkForTransparantStyle ) withObject:nil afterDelay:0.];
	} else {
		[self performSelector:_cmd withObject:variant afterDelay:0.25];
	}
}

- (NSString *) styleVariant {
	return _styleVariant;
}

#pragma mark -

- (void) setBodyTemplate:(NSString *) bodyTemplate {
	[_bodyTemplate autorelease];
	_bodyTemplate = [bodyTemplate retain];
}

- (NSString *) bodyTemplate {
	return _bodyTemplate;
}

#pragma mark -

- (void) setStyleParameters:(NSDictionary *) parameters {
	id old = _styleParameters;
	_styleParameters = [parameters mutableCopyWithZone:[self zone]];
	[old release];
}

- (NSDictionary *) styleParameters {
	return [NSDictionary dictionaryWithDictionary:_styleParameters];
}

#pragma mark -

- (void) setEmoticons:(JVEmoticonSet *) emoticons {
	[_emoticons autorelease];
	_emoticons = [emoticons retain];

	if( _contentFrameReady ) {
		[[self class] emptyCache];

		NSString *styleSheetLocation = [[[self emoticons] styleSheetLocation] absoluteString];
		DOMHTMLLinkElement *element = (DOMHTMLLinkElement *)[_domDocument getElementById:@"emoticonStyle"];
		if( ! styleSheetLocation ) [element setHref:@""];
		else [element setHref:styleSheetLocation];
	} else {
		[self performSelector:_cmd withObject:emoticons afterDelay:0.25];
	}
}

- (JVEmoticonSet *) emoticons {
	return _emoticons;
}

#pragma mark -

- (void) setScrollbackLimit:(NSUInteger) limit {
	_scrollbackLimit = limit;
}

- (NSUInteger) scrollbackLimit {
	return _scrollbackLimit;
}

#pragma mark -

- (void) reloadCurrentStyle {
	[_style reload];

	_switchingStyles = YES;
	_requiresFullMessage = YES;
	_rememberScrollPosition = YES;

	[[self class] emptyCache];

	[self _resetDisplay];
}

- (void) clear {
	_switchingStyles = NO;
	_requiresFullMessage = YES;
	[self _resetDisplay];
}

- (void) mark {
	if( _contentFrameReady ) {
		DOMHTMLElement *elt = (DOMHTMLElement *)[_domDocument getElementById:@"mark"];
		if( elt ) [[elt parentNode] removeChild:elt];
		elt = (DOMHTMLElement *)[_domDocument createElement:@"hr"];
		[elt setAttribute:@"id" value:@"mark"];
		[_body appendChild:elt];
		[self scrollToBottom];

		NSInteger location = [elt integerForDOMProperty:@"offsetTop"];

		JVMarkedScroller *scroller = [self verticalMarkedScroller];
		[scroller removeMarkWithIdentifier:@"mark"];
		[scroller addMarkAt:location withIdentifier:@"mark" withColor:[NSColor redColor]];

		_requiresFullMessage = YES;
	} else {
		[self performSelector:_cmd withObject:nil afterDelay:0.25];
	}
}

#pragma mark -

- (void) addBanner:(NSString *) name {
	if( ! _mainFrameReady ) {
		[self performSelector:_cmd withObject:name afterDelay:0.25];
		return;
	}

	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];

	DOMHTMLElement *element = (DOMHTMLElement *)[_mainDocument createElement:@"div"];
	[element setClassName:@"banner"];
	if( [shell length] ) [element setInnerHTML:shell];

	[[_mainDocument body] insertBefore:element refChild:[[_mainDocument body] firstChild]];
}

#pragma mark -

- (BOOL) appendChatMessage:(JVChatMessage *) message {
	if( ! _contentFrameReady ) return YES; // don't schedule this to fire later since the transcript will be processed

	if( _requiresFullMessage ) {
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[_domDocument getElementById:@"consecutiveInsert"];
		if( replaceElement ) _requiresFullMessage = NO; // a full message was assumed, but we can do a consecutive one
	}

	unsigned consecutiveOffset = [message consecutiveOffset];
	NSString *result = nil;

	if( _requiresFullMessage && consecutiveOffset > 0 ) {
		NSArray *elements = [[NSArray allocWithZone:nil] initWithObjects:message, nil];
		result = [[self style] transformChatTranscriptElements:elements withParameters:_styleParameters];
		[elements release];
	} else {
		if( ! _requiresFullMessage && consecutiveOffset > 0 )
			[_styleParameters setObject:@"'yes'" forKey:@"consecutiveMessage"];
		result = [[self style] transformChatMessage:message withParameters:_styleParameters];
		[_styleParameters removeObjectForKey:@"consecutiveMessage"];
	}

	if( [result length] ) {
		[self _appendMessage:result];
		_requiresFullMessage = NO;
	}

	return ( [result length] ? YES : NO );
}

- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element {
	if( ! _contentFrameReady ) return YES; // don't schedule this to fire later since the transcript will be processed

	NSString *result = [[self style] transformChatTranscriptElement:element withParameters:_styleParameters];

	if( [result length] ) [self _appendMessage:result];

	return ( [result length] ? YES : NO );
}

#pragma mark -

- (void) highlightMessage:(JVChatMessage *) message {
/*	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument getElementById:[message messageIdentifier]];
	NSString *class = [element className];
	if( [[element className] rangeOfString:@"searchHighlight"].location != NSNotFound ) return;
	if( [class length] ) [element setClassName:[class stringByAppendingString:@" searchHighlight"]];
	else [element setClassName:@"searchHighlight"];
*/}

- (void) clearHighlightForMessage:(JVChatMessage *) message {
/*	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument getElementById:[message messageIdentifier]];
	NSMutableString *class = [[[element className] mutableCopy] autorelease];
	[class replaceOccurrencesOfString:@"searchHighlight" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [class length] )];
	[element setClassName:class];
*/}

- (void) clearAllMessageHighlights {
//	[[self windowScriptObject] callWebScriptMethod:@"resetHighlightMessage" withArguments:[NSArray arrayWithObject:[NSNull null]]];
}

#pragma mark -

- (void) highlightString:(NSString *) string inMessage:(JVChatMessage *) message {
	[[self windowScriptObject] callWebScriptMethod:@"searchHighlight" withArguments:[NSArray arrayWithObjects:[message messageIdentifier], string, nil]];
}

- (void) clearStringHighlightsForMessage:(JVChatMessage *) message {
	[[self windowScriptObject] callWebScriptMethod:@"resetSearchHighlight" withArguments:[NSArray arrayWithObject:[message messageIdentifier]]];
}

- (void) clearAllStringHighlights {
	[[self windowScriptObject] callWebScriptMethod:@"resetSearchHighlight" withArguments:[NSArray arrayWithObject:[NSNull null]]];
}

#pragma mark -

- (void) markScrollbarForMessage:(JVChatMessage *) message {
	if( _switchingStyles || ! _contentFrameReady ) {
		[self performSelector:_cmd withObject:message afterDelay:0.25];
		return;
	}

	NSInteger loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) [[self verticalMarkedScroller] addMarkAt:loc];
}

- (void) markScrollbarForMessage:(JVChatMessage *) message usingMarkIdentifier:(NSString *) identifier andColor:(NSColor *) color {
	if( _switchingStyles || ! _contentFrameReady ) return; // can't queue, too many args. NSInvocation?

	NSInteger loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) [[self verticalMarkedScroller] addMarkAt:loc withIdentifier:identifier withColor:color];
}

- (void) markScrollbarForMessages:(NSArray *) messages {
	if( _switchingStyles || ! _contentFrameReady ) {
		[self performSelector:_cmd withObject:messages afterDelay:0.25];
		return;
	}

	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	for( JVChatMessage *message in messages ) {
		NSInteger loc = [self _locationOfMessage:message];
		if( loc != NSNotFound ) [scroller addMarkAt:loc];
	}
}

#pragma mark -

- (void) clearScrollbarMarks {
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	[scroller removeAllMarks];
	[scroller removeAllShadedAreas];
}

- (void) clearScrollbarMarksWithIdentifier:(NSString *) identifier {
	[[self verticalMarkedScroller] removeMarkWithIdentifier:identifier];
}

#pragma mark -

- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
	if( frame == [self mainFrame] ) {
		_mainFrameReady = YES;

		[_mainDocument autorelease];
		_mainDocument = (DOMHTMLDocument *)[[frame DOMDocument] retain];

		WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
		[contentFrame loadHTMLString:[self _contentHTMLWithBody:@""] baseURL:[self _baseURL]];
	} else if( _mainFrameReady ) {
		if( [[[[[frame dataSource] response] URL] absoluteString] isEqualToString:@"about:blank"] ) {
			// this was a false content frame load, try again
			[frame loadHTMLString:[self _contentHTMLWithBody:@""] baseURL:[self _baseURL]];
			return;
		}

		[self performSelector:@selector( _contentFrameIsReady ) withObject:nil afterDelay:0.];
	}
}

- (IBAction) copySelectionToFindPboard:(id) sender {
	WebFrame *frame = nil;
	if( [self respondsToSelector:@selector( selectedFrame )] )
		frame = [self selectedFrame];
	else if( [self respondsToSelector:@selector( _frameForCurrentSelection )] )
		frame = [self _frameForCurrentSelection];

	if( ! frame ) return;

	NSString *selectedString = [(id <WebDocumentText>)[[frame frameView] documentView] selectedString];

	if( [selectedString length] ) {
		NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSFindPboard];
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
		[pboard setString:selectedString forType:NSStringPboardType];
	}
}

- (void) drawRect:(NSRect) rect {
	if( ! [self drawsBackground] ) {
		[[NSColor clearColor] set];
		NSRectFill( rect ); // allows poking holes in the window with rgba background colors
	}

	[super drawRect:rect];
}

#pragma mark -
#pragma mark Highlight/Message Jumping

- (JVMarkedScroller *) verticalMarkedScroller {
	WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
	NSScrollView *scrollView = [[[contentFrame frameView] documentView] enclosingScrollView];
	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		[self _setupMarkedScroller];
		scroller = (JVMarkedScroller *)[scrollView verticalScroller];
		if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] )
			return nil; // not sure, but somthing is wrong
	}

	return scroller;
}

- (IBAction) jumpToMark:(id) sender {
    [[self verticalMarkedScroller] jumpToMarkWithIdentifier:@"mark"];
}

- (IBAction) jumpToPreviousHighlight:(id) sender {
    [[self verticalMarkedScroller] jumpToPreviousMark:sender];
}

- (IBAction) jumpToNextHighlight:(id) sender {
    [[self verticalMarkedScroller] jumpToNextMark:sender];
}

- (void) jumpToMessage:(JVChatMessage *) message {
	NSInteger loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) {
		JVMarkedScroller *scroller = [self verticalMarkedScroller];
		float shift = [scroller shiftAmountToCenterAlign];
		[scroller setLocationOfCurrentMark:loc];

		[[_domDocument body] setInteger:( loc - shift ) forDOMProperty:@"scrollTop"];
	}
}

- (void) scrollToBottom {
	if( ! _contentFrameReady ) {
		[self performSelector:_cmd withObject:nil afterDelay:0.25];
		return;
	}

	DOMHTMLElement *body = [_domDocument body];
	[body setInteger:[body integerForDOMProperty:@"scrollHeight"] forDOMProperty:@"scrollTop"];
}

- (BOOL) scrolledNearBottom {
	WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
	DOMHTMLElement *contentFrameElement = [contentFrame frameElement];
	NSInteger frameHeight = [contentFrameElement integerForDOMProperty:@"offsetHeight"];

	DOMHTMLElement *body = [_domDocument body];
	NSInteger scrollHeight = [body integerForDOMProperty:@"scrollHeight"];
	NSInteger scrollTop = [body integerForDOMProperty:@"scrollTop"];

	// check if we are near the bottom 15 pixels of the chat area
	return ( ( frameHeight + scrollTop ) >= ( scrollHeight - 15 ) );
}
@end

#pragma mark -

@implementation JVStyleView (JVStyleViewPrivate)
- (void) _checkForTransparantStyle {
	DOMCSSStyleDeclaration *style = [self computedStyleForElement:_body pseudoElement:nil];
	DOMCSSValue *value = [style getPropertyCSSValue:@"background-color"];
	BOOL transparent = ( value && [[value cssText] rangeOfString:@"rgba"].location != NSNotFound );

	if( [self respondsToSelector:@selector(setBackgroundColor:)] ) {
		if( transparent ) [self setBackgroundColor:[NSColor clearColor]]; // allows rgba backgrounds to see through to the Desktop
		else [self setBackgroundColor:[NSColor whiteColor]];
	} else {
		if( transparent ) [self setDrawsBackground:NO]; // allows rgba backgrounds to see through to the Desktop
		else [self setDrawsBackground:YES];
	}
}

- (void) _contentFrameIsReady {
	WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];

	id old = _domDocument;
	_domDocument = (DOMHTMLDocument *)[[contentFrame DOMDocument] retain];
	[old release];

	old = _body;
	_body = (DOMHTMLElement *)[[_domDocument getElementById:@"contents"] retain];
	if( ! _body ) _body = (DOMHTMLElement *)[[_domDocument body] retain];
	[old release];

	if( ! _body ) {
		// try again soon, the DOM is not ready yet
		[self performSelector:@selector( _contentFrameIsReady ) withObject:nil afterDelay:0.25];
		return;
	}

	[self _checkForTransparantStyle];

	[self setPreferencesIdentifier:[[self style] identifier]];

	[self clearScrollbarMarks];

	if( [[self window] isFlushWindowDisabled] )
		[[self window] enableFlushWindow];

	_contentFrameReady = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName:JVStyleViewDidClearNotification object:self];
	if( _switchingStyles )
		[NSThread detachNewThreadSelector:@selector( _switchStyle ) toTarget:self withObject:nil];
}

- (void) _reallyAwakeFromNib {
	_ready = YES;
	[self _resetDisplay];
}

- (void) _resetDisplay {
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	[self stopLoading:nil];
	[self clearScrollbarMarks];

	_contentFrameReady = NO;
	if( _rememberScrollPosition ) {
		_lastScrollPosition = [[_domDocument body] integerForDOMProperty:@"scrollTop"];
	} else _lastScrollPosition = 0;

	if( ! [[self window] isFlushWindowDisabled] )
		[[self window] disableFlushWindow];

	if( _mainFrameReady ) {
		WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
		[contentFrame loadHTMLString:[self _contentHTMLWithBody:@""] baseURL:[self _baseURL]];
	} else {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"base" ofType:@"html"];
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.];
		[[self mainFrame] loadRequest:request];
	}
}

- (void) _switchStyle {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NSThread setThreadPriority:0.25];

	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.00025]]; // wait, WebKit might not be ready.

	JVStyle *style = [[self style] retain];
	JVChatTranscript *transcript = [[self transcript] retain];
	NSMutableArray *highlightedMsgs = [[NSMutableArray allocWithZone:nil] initWithCapacity:( [self scrollbackLimit] / 8 )];
	NSMutableDictionary *parameters = [[NSMutableDictionary allocWithZone:nil] initWithDictionary:_styleParameters copyItems:NO];
	unsigned long elementCount = [transcript elementCount];

	[parameters setObject:@"'yes'" forKey:@"bulkTransform"];

	for( unsigned long i = elementCount; i > ( elementCount - MIN( [self scrollbackLimit], elementCount ) ); i -= MIN( 25u, i ) ) {
		NSArray *elements = [transcript elementsInRange:NSMakeRange( i - MIN( 25u, i ), MIN( 25u, i ) )];

		for( id element in elements )
			if( [element isKindOfClass:[JVChatMessage class]] && [element isHighlighted] )
				[highlightedMsgs addObject:element];

		NSString *result = [style transformChatTranscriptElements:elements withParameters:parameters];

		if( [self style] != style ) goto quickEnd;
		if( result ) {
			[self performSelectorOnMainThread:@selector( _prependMessages: ) withObject:result waitUntilDone:YES];
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.]]; // give time to other threads
		}
	}

	_switchingStyles = NO;
	[self performSelectorOnMainThread:@selector( markScrollbarForMessages: ) withObject:highlightedMsgs waitUntilDone:YES];

quickEnd:
	[self performSelectorOnMainThread:@selector( _switchingStyleFinished: ) withObject:nil waitUntilDone:YES];

	NSNotification *note = [NSNotification notificationWithName:JVStyleViewDidChangeStylesNotification object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	[highlightedMsgs release];
	[parameters release];
	[style release];
	[transcript release];
	[pool release];
}

- (void) _switchingStyleFinished:(id) sender {
	_switchingStyles = NO;

	if( _rememberScrollPosition ) {
		_rememberScrollPosition = NO;
		[[_domDocument body] setInteger:_lastScrollPosition forDOMProperty:@"scrollTop"];
	}
}

- (void) _appendMessage:(NSString *) message {
	if( ! _body ) return;

	unsigned messageCount = [self _visibleMessageCount] + 1;
	unsigned scrollbackLimit = [self scrollbackLimit];
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	BOOL consecutive = ( [message rangeOfString:@"<?message type=\"consecutive\"?>"].location != NSNotFound );
	if( ! consecutive ) consecutive = ( [message rangeOfString:@"<?message type=\"subsequent\"?>"].location != NSNotFound );

	// check if we are near the bottom of the chat area, and if we should scroll down later
	BOOL scrollToBottomNeeded = [self scrolledNearBottom];

	NSMutableString *transformedMessage = [message mutableCopyWithZone:nil];
	[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];

	DOMHTMLElement *consecutiveReplaceElement = (DOMHTMLElement *)[_domDocument getElementById:@"consecutiveInsert"];
	if( consecutive && consecutiveReplaceElement ) {  // append as a consecutive message
		[consecutiveReplaceElement setOuterHTML:transformedMessage]; // replace the consecutiveInsert node
	} else { // append message normally
		if( consecutiveReplaceElement ) // remove the consecutiveReplaceElement node
			[[consecutiveReplaceElement parentNode] removeChild:consecutiveReplaceElement];

		DOMHTMLElement *insertElement = (DOMHTMLElement *)[_domDocument getElementById:@"insert"];
		if( ! insertElement ) {
			DOMHTMLElement *newElement = (DOMHTMLElement *)[_body appendChild:[_domDocument createElement:@"span"]];
			[newElement setOuterHTML:transformedMessage]; // replace the newElement node
		} else {
			[insertElement setOuterHTML:transformedMessage]; // replace the insertElement node
		}
	}

	[transformedMessage release];
	transformedMessage = nil;

	// enforce the scrollback limit and shift scrollbar marks
	if( scrollToBottomNeeded && scrollbackLimit > 0 && messageCount > scrollbackLimit ) {
		NSUInteger limit = ( messageCount - scrollbackLimit );
		NSInteger shiftAmount = [self _locationOfElementAtIndex:limit];

		DOMNode *node = [_body firstChild];
		for( NSUInteger i = 0; node && i < limit; ) {
			DOMNode *next = [node nextSibling];

			if( [node nodeType] == DOM_ELEMENT_NODE ) {
				[_body removeChild:node];
				++i;
			}

			node = next;
		}

		NSInteger firstItemShift = [self _locationOfElementAtIndex:0];
		if( firstItemShift != NSNotFound ) shiftAmount -= firstItemShift;

		if( scrollToBottomNeeded && shiftAmount > 0 && shiftAmount != NSNotFound )
			[scroller shiftMarksAndShadedAreasBy:( shiftAmount * -1 )];
	}

	if( scrollToBottomNeeded ) [self scrollToBottom];
}

- (void) _prependMessages:(NSString *) messages {
	if( ! _body ) return;

	NSMutableString *result = [messages mutableCopy];
	[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];

	// check if we are near the bottom of the chat area, and if we should scroll down later
	BOOL scrollNeeded = [self scrolledNearBottom];

	// parses the message so we can get the DOM tree
	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument createElement:@"span"];
	if( [result length] ) [element setInnerHTML:result];

	[result release];
	result = nil;

	DOMNode *firstMessage = [_body firstChild];

	while( [element hasChildNodes] ) { // append all children
		if( firstMessage ) [_body insertBefore:[element firstChild] refChild:firstMessage];
		else [_body appendChild:[element firstChild]];
	}

	if( scrollNeeded ) [self scrollToBottom];
}

- (void) _styleError {
	NSRunCriticalAlertPanel( NSLocalizedString( @"An internal Style error occurred.", "the stylesheet parse failed" ), NSLocalizedString( @"The %@ Style has been damaged or has an internal error preventing new messages from displaying. Please contact the %@ author about this.", "the style contains and error" ), @"OK", nil, nil, [[self style] displayName], [[self style] displayName] );
}

- (void) _styleVariantChanged:(NSNotification *) notification {
	NSString *variant = [[notification userInfo] objectForKey:@"variant"];
	if( [variant isEqualToString:[self styleVariant]] )
		[self setStyleVariant:variant];
}

- (void) _setupMarkedScroller {
	if( ! _mainFrameReady ) {
		[self performSelector:_cmd withObject:nil afterDelay:0.25];
		return;
	}

	WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
	NSScrollView *scrollView = [[[contentFrame frameView] documentView] enclosingScrollView];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setAllowsHorizontalScrolling:NO];

	if ([scrollView respondsToSelector:@selector(setVerticalScrollElasticity:)]) {
		[scrollView setVerticalScrollElasticity:NSScrollElasticityNone];
		[scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
	}

	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		NSRect scrollerFrame = [[scrollView verticalScroller] frame];
		NSScroller *oldScroller = scroller;
		scroller = [[[JVMarkedScroller alloc] initWithFrame:scrollerFrame] autorelease];
		[scroller setKnobProportion:[oldScroller knobProportion]];
		[scroller setDoubleValue:[oldScroller floatValue]];
		[scrollView setVerticalScroller:scroller];
	}
}

#pragma mark -

- (NSString *) _contentHTMLWithBody:(NSString *) html {
	NSString *variantStyleSheetLocation = [[[self style] variantStyleSheetLocationWithName:[self styleVariant]] absoluteString];
	if( ! variantStyleSheetLocation ) variantStyleSheetLocation = @"";

	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];

	NSString *bodyTemplate = [[self style] contentsOfBodyTemplateWithName:[self bodyTemplate]];
	if( [bodyTemplate length] && [html length] ) {
		if( [bodyTemplate rangeOfString:@"%@"].location != NSNotFound )
			bodyTemplate = [NSString stringWithFormat:bodyTemplate, html];
		else bodyTemplate = [bodyTemplate stringByAppendingString:html];
	} else if( ! [bodyTemplate length] && [html length] ) {
		bodyTemplate = html;
	}

	NSString *baseURL = [[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]] absoluteString];

	return [NSString stringWithFormat:shell, @"", @"", baseURL, [[[self emoticons] styleSheetLocation] absoluteString], [[[self style] mainStyleSheetLocation] absoluteString], variantStyleSheetLocation, [[[self style] baseLocation] absoluteString], bodyTemplate];
}

- (NSURL *) _baseURL {
	return [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
}

#pragma mark -

- (NSUInteger) _locationOfMessageWithIdentifier:(NSString *) identifier {
	if( ! _contentFrameReady ) return NSNotFound;
	if( ! [identifier length] ) return NSNotFound;

	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument getElementById:identifier];
	return [element integerForDOMProperty:@"offsetTop"];
}

- (NSUInteger) _locationOfMessage:(JVChatMessage *) message {
	return [self _locationOfMessageWithIdentifier:[message messageIdentifier]];
}

- (NSUInteger) _locationOfElementAtIndex:(NSUInteger) index {
	if( ! _contentFrameReady )
		return NSNotFound;
	DOMHTMLElement *element = (DOMHTMLElement *)[_body childElementAtIndex:index];
	if( ! element || ! [element isKindOfClass:[DOMHTMLElement class]] )
		return NSNotFound;
	return [element integerForDOMProperty:@"offsetTop"];
}

- (NSUInteger) _visibleMessageCount {
	if( ! _contentFrameReady ) return 0;
	return [_body childElementLength];
}
@end
