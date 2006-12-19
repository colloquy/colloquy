#import "JVStyleView.h"
#import "JVMarkedScroller.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"

NSString *JVStyleViewDidClearNotification = @"JVStyleViewDidClearNotification";
NSString *JVStyleViewDidChangeStylesNotification = @"JVStyleViewDidChangeStylesNotification";

@interface WebCoreCache
+ (void) empty;
@end

#pragma mark -

@interface WebCache
+ (void) empty;
@end

#pragma mark -

@interface WebView (WebViewLeopard)
- (void) setDrawsBackground:(BOOL) draws; // supported in 10.3.9/Tiger
- (BOOL) drawsBackground; // supported in 10.3.9/Tiger
- (void) setBackgroundColor:(NSColor *) color; // new in Leopard
- (WebFrame *) selectedFrame;
@end

@interface WebView (WebViewPrivate)
- (WebFrame *) _frameForCurrentSelection;
@end

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

@interface JVStyleView (JVStyleViewPrivate)
- (void) _resetDisplay;
- (void) _switchStyle;
- (void) _appendMessage:(NSString *) message;
- (void) _prependMessages:(NSString *) messages;
- (void) _styleError;
- (NSString *) _contentHTMLWithBody:(NSString *) html;
- (NSURL *) _baseURL;
- (unsigned long) _visibleMessageCount;
- (long) _locationOfMessage:(JVChatMessage *) message;
- (long) _locationOfElementAtIndex:(unsigned long) index;
- (void) _setupMarkedScroller;
@end

#pragma mark -

@implementation JVStyleView
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

	NSString *timeFormatParameter = [NSString stringWithFormat:@"'%@'", [[NSUserDefaults standardUserDefaults] stringForKey:NSTimeFormatString]];
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
		if( NSClassFromString( @"WebCoreCache" ) )
			[NSClassFromString( @"WebCoreCache" ) empty];
		else if( NSClassFromString( @"WebCache" ) )
			[NSClassFromString( @"WebCache" ) empty];

		NSString *styleSheetLocation = [[[self style] variantStyleSheetLocationWithName:_styleVariant] absoluteString];
		DOMHTMLLinkElement *element = (DOMHTMLLinkElement *)[_domDocument getElementById:@"variantStyle"];
		if( ! styleSheetLocation ) [element setHref:@""];
		else [element setHref:styleSheetLocation];

		[self performSelector:@selector( _checkForTransparantStyle ) withObject:nil afterDelay:0.];
	} else {
		[self performSelector:_cmd withObject:variant afterDelay:0.];
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
		if( NSClassFromString( @"WebCoreCache" ) )
			[NSClassFromString( @"WebCoreCache" ) empty];
		else if( NSClassFromString( @"WebCache" ) )
			[NSClassFromString( @"WebCache" ) empty];

		NSString *styleSheetLocation = [[[self emoticons] styleSheetLocation] absoluteString];
		DOMHTMLLinkElement *element = (DOMHTMLLinkElement *)[_domDocument getElementById:@"emoticonStyle"];
		if( ! styleSheetLocation ) [element setHref:@""];
		else [element setHref:styleSheetLocation];
	} else {
		[self performSelector:_cmd withObject:emoticons afterDelay:0.];
	}
}

- (JVEmoticonSet *) emoticons {
	return _emoticons;
}

#pragma mark -

- (void) setScrollbackLimit:(unsigned long) limit {
	_scrollbackLimit = limit;
}

- (unsigned long) scrollbackLimit {
	return _scrollbackLimit;
}

#pragma mark -

- (void) reloadCurrentStyle {
	_switchingStyles = YES;
	_requiresFullMessage = YES;
	_rememberScrollPosition = YES;

	if( NSClassFromString( @"WebCoreCache" ) )
		[NSClassFromString( @"WebCoreCache" ) empty];
	else if( NSClassFromString( @"WebCache" ) )
		[NSClassFromString( @"WebCache" ) empty];

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
		[elt setAttribute:@"id" :@"mark"];
		[_body appendChild:elt];
		[self scrollToBottom];

		unsigned int location = 0;
		if( [elt respondsToSelector:@selector( offsetTop )] )
			location = [elt offsetTop];
		else location = [[elt valueForKey:@"offsetTop"] longValue];

		JVMarkedScroller *scroller = [self verticalMarkedScroller];
		[scroller removeMarkWithIdentifier:@"mark"];
		[scroller addMarkAt:location withIdentifier:@"mark" withColor:[NSColor redColor]];

		_requiresFullMessage = YES;
	} else {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
	}
}

#pragma mark -

- (void) addBanner:(NSString *) name {
	if( ! _mainFrameReady ) {
		[self performSelector:_cmd withObject:name afterDelay:0.];
		return;
	}

	NSString *shell = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
		shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"html"]];
	else shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];

	DOMHTMLElement *element = (DOMHTMLElement *)[_mainDocument createElement:@"div"];
	[element setClassName:@"banner"];
	[element setInnerHTML:shell];

	[[_mainDocument body] insertBefore:element :[[_mainDocument body] firstChild]];
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
		[self performSelector:_cmd withObject:message afterDelay:0.];
		return;
	}

	long loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) [[self verticalMarkedScroller] addMarkAt:loc];
}

- (void) markScrollbarForMessage:(JVChatMessage *) message usingMarkIdentifier:(NSString *) identifier andColor:(NSColor *) color {
	if( _switchingStyles || ! _contentFrameReady ) return; // can't queue, too many args. NSInvocation?

	long loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) [[self verticalMarkedScroller] addMarkAt:loc withIdentifier:identifier withColor:color];
}

- (void) markScrollbarForMessages:(NSArray *) messages {
	if( _switchingStyles || ! _contentFrameReady ) {
		[self performSelector:_cmd withObject:messages afterDelay:0.];
		return;
	}

	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	NSEnumerator *enumerator = [messages objectEnumerator];
	JVChatMessage *message = nil;

	while( ( message = [enumerator nextObject] ) ) {
		long loc = [self _locationOfMessage:message];
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

		id old = _domDocument;
		_domDocument = (DOMHTMLDocument *)[[frame DOMDocument] retain];
		[old release];

		old = _body;
		_body = (DOMHTMLElement *)[[_domDocument getElementById:@"contents"] retain];
		if( ! _body ) _body = (DOMHTMLElement *)[[_domDocument body] retain];
		[old release];

		[self performSelector:@selector( _checkForTransparantStyle ) withObject:nil afterDelay:0.];

		[self setPreferencesIdentifier:[[self style] identifier]];

		[self clearScrollbarMarks];

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
	unsigned long loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) {
		JVMarkedScroller *scroller = [self verticalMarkedScroller];
		long shift = [scroller shiftAmountToCenterAlign];
		[scroller setLocationOfCurrentMark:loc];
		[_body setValue:[NSNumber numberWithUnsignedLong:( loc - shift )] forKey:@"scrollTop"];
	}
}

- (void) scrollToBottom {
	if( ! _contentFrameReady ) {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
		return;
	}

	if( [_body respondsToSelector:@selector( scrollHeight )] )
		[_body setValue:[NSNumber numberWithUnsignedInt:[_body scrollHeight]] forKey:@"scrollTop"];
	else [_body setValue:[_body valueForKey:@"scrollHeight"] forKey:@"scrollTop"];
}

- (BOOL) scrolledNearBottom {
	WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
	DOMHTMLElement *contentFrameElement = [contentFrame frameElement];
	unsigned int frameHeight = 0;
	if( [contentFrameElement respondsToSelector:@selector( offsetHeight )] )
		frameHeight = [contentFrameElement offsetHeight];
	else frameHeight = [[contentFrameElement valueForKey:@"offsetHeight"] unsignedIntValue];

	unsigned int scrollHeight = 0;
	if( [_body respondsToSelector:@selector( scrollHeight )] )
		scrollHeight = [_body scrollHeight];
	else scrollHeight = [[_body valueForKey:@"scrollHeight"] unsignedIntValue];

	unsigned int scrollTop = [[_body valueForKey:@"scrollTop"] unsignedIntValue];

	// check if we are near the bottom 10 pixels of the chat area
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
		_lastScrollPosition = [[_body valueForKey:@"scrollTop"] longValue];
	} else _lastScrollPosition = 0;

	if( [self respondsToSelector:@selector(setBackgroundColor:)] )
		[self setBackgroundColor:[NSColor whiteColor]];
	else [self setDrawsBackground:YES];

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

		id element = nil;
		NSEnumerator *enumerator = [elements objectEnumerator];
		while( ( element = [enumerator nextObject] ) )
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
		[_body setValue:[NSNumber numberWithUnsignedLong:_lastScrollPosition] forKey:@"scrollTop"];
	}
}

- (void) _appendMessage:(NSString *) message {
	if( ! _body ) return;

	long shiftAmount = 0;
	unsigned int messageCount = [self _visibleMessageCount] + 1;
	unsigned int scrollbackLimit = [self scrollbackLimit];
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	BOOL consecutive = ( [message rangeOfString:@"<?message type=\"consecutive\"?>"].location != NSNotFound );
	if( ! consecutive ) consecutive = ( [message rangeOfString:@"<?message type=\"subsequent\"?>"].location != NSNotFound );

	// check if we are near the bottom of the chat area, and if we should scroll down later
	BOOL scrollNeeded = [self scrolledNearBottom];

	// check how much we need to shift the scrollbar marks
	if( ! consecutive && messageCount > scrollbackLimit ) {
		shiftAmount = [self _locationOfElementAtIndex:( messageCount - scrollbackLimit )];
		if( shiftAmount > 0 && shiftAmount != NSNotFound )
			[scroller shiftMarksAndShadedAreasBy:( shiftAmount * -1 )];
	}

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

	// enforce the scrollback limit
	if( scrollbackLimit > 0 && messageCount > scrollbackLimit ) {
		for( unsigned int i = 0; messageCount > scrollbackLimit && i < ( messageCount - scrollbackLimit ); i++ ) {
			[_body removeChild:[_body firstChild]];
			messageCount--;
		}
	}

	if( ! scrollNeeded && shiftAmount > 0 ) {
		unsigned long scrollTop = [[_body valueForKey:@"scrollTop"] longValue];
		[_body setValue:[NSNumber numberWithUnsignedLong:( scrollTop - shiftAmount )] forKey:@"scrollTop"];
	}

	[[self verticalMarkedScroller] setNeedsDisplay:YES];

	if( scrollNeeded ) [self scrollToBottom];
}

- (void) _prependMessages:(NSString *) messages {
	if( ! _body ) return;

	NSMutableString *result = [messages mutableCopy];
	[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];

	// check if we are near the bottom of the chat area, and if we should scroll down later
	BOOL scrollNeeded = [self scrolledNearBottom];

	// parses the message so we can get the DOM tree
	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument createElement:@"span"];
	[element setInnerHTML:result];

	[result release];
	result = nil;

	DOMNode *firstMessage = [_body firstChild];

	while( [element hasChildNodes] ) { // append all children
		if( firstMessage ) [_body insertBefore:[element firstChild] :firstMessage];
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
		[self performSelector:_cmd withObject:nil afterDelay:0.]; 
		return; 
	}

	WebFrame *contentFrame = [[self mainFrame] findFrameNamed:@"content"];
	NSScrollView *scrollView = [[[contentFrame frameView] documentView] enclosingScrollView]; 
	[scrollView setHasHorizontalScroller:NO]; 
	[scrollView setAllowsHorizontalScrolling:NO]; 

	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller]; 
	if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) { 
		NSRect scrollerFrame = [[scrollView verticalScroller] frame]; 
		NSScroller *oldScroller = scroller; 
		scroller = [[[JVMarkedScroller alloc] initWithFrame:scrollerFrame] autorelease]; 
		[scroller setFloatValue:[oldScroller floatValue] knobProportion:[oldScroller knobProportion]]; 
		[scrollView setVerticalScroller:scroller]; 
	} 
} 

#pragma mark -

- (NSString *) _contentHTMLWithBody:(NSString *) html {
	NSString *variantStyleSheetLocation = [[[self style] variantStyleSheetLocationWithName:[self styleVariant]] absoluteString];
	if( ! variantStyleSheetLocation ) variantStyleSheetLocation = @"";

	NSString *shell = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
		shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	else shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];

	return [NSString stringWithFormat:shell, @"", @"", [[[self emoticons] styleSheetLocation] absoluteString], [[[self style] mainStyleSheetLocation] absoluteString], variantStyleSheetLocation, [[[self style] baseLocation] absoluteString], [[self style] contentsOfBodyTemplateWithName:[self bodyTemplate]]];
}

- (NSURL *) _baseURL {
	return [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
}

#pragma mark -

- (long) _locationOfMessageWithIdentifier:(NSString *) identifier {
	if( ! _contentFrameReady ) return NSNotFound;
	if( ! [identifier length] ) return NSNotFound;

	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument getElementById:identifier];
	if( [element respondsToSelector:@selector( offsetTop )] )
		return [element offsetTop];
	id value = [element valueForKey:@"offsetTop"];
	if( [value respondsToSelector:@selector( longValue )] )
		return [value longValue];
	return NSNotFound;
}

- (long) _locationOfMessage:(JVChatMessage *) message {
	return [self _locationOfMessageWithIdentifier:[message messageIdentifier]];
}

- (long) _locationOfElementAtIndex:(unsigned long) index {
	if( ! _contentFrameReady || index >= [[_body childNodes] length] )
		return NSNotFound;
	DOMNode *node = [[_body childNodes] item:index];
	if( ! [node isKindOfClass:[DOMHTMLElement class]] )
		return NSNotFound;
	if( [node respondsToSelector:@selector( offsetTop )] )
		return [(DOMHTMLElement *)node offsetTop];
	id value = [node valueForKey:@"offsetTop"];
	if( [value respondsToSelector:@selector( longValue )] )
		return [value longValue];
	return NSNotFound;
}

- (unsigned long) _visibleMessageCount {
	if( ! _contentFrameReady ) return 0;
	return [[_body childNodes] length];
}
@end
