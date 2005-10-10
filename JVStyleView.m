#import "JVStyleView.h"
#import "JVMarkedScroller.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"

NSString *JVStyleViewDidChangeStylesNotification = @"JVStyleViewDidChangeStylesNotification";

@interface WebCoreCache
+ (void) empty;
+ (id)statistics;
@end

#pragma mark -

@interface WebView (WebViewPrivate) // WebKit 1.3/2.0 pending public API
- (void) setDrawsBackground:(BOOL) draws;
- (BOOL) drawsBackground;
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
- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;
- (unsigned long) _visibleMessageCount;
- (long) _locationOfMessage:(JVChatMessage *) message;
- (long) _locationOfElementAtIndex:(unsigned long) index;
- (void) _reallySetTopicMessage:(NSString *) message andAuthor:(NSString *) author;
- (void) _tickleForLayout;
@end

#pragma mark -

@implementation JVStyleView
- (id) initWithCoder:(NSCoder *) coder {
	if( ( self = [super initWithCoder:coder] ) ) {
		_switchingStyles = NO;
		_forwarding = NO;
		_ready = NO;
		_webViewReady = NO;
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
	[_domDocument release];
	[_body release];
	[_bodyTemplate release];

	nextTextView = nil;
	_transcript = nil;
	_style = nil;
	_styleVariant = nil;
	_styleParameters = nil;
	_emoticons = nil;
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

- (void) setFrame:(NSRect) frame {
	[super setFrame:frame];
	[self _tickleForLayout];
}

- (void) setFrameSize:(NSSize) size {
	[super setFrameSize:size];
	[self _tickleForLayout];
}

- (void) setBounds:(NSRect) bounds {
	[super setBounds:bounds];
	[self _tickleForLayout];
}

- (void) setBoundsSize:(NSSize) size {
	[super setBoundsSize:size];
	[self _tickleForLayout];
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
	return [[_style retain] autorelease];
}

#pragma mark -

- (void) setStyleVariant:(NSString *) variant {
	[_styleVariant autorelease];
	_styleVariant = [variant copyWithZone:[self zone]];

	if( _webViewReady ) {
		[WebCoreCache empty];

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
	[_styleParameters autorelease];
	_styleParameters = [parameters mutableCopyWithZone:[self zone]];
}

- (NSDictionary *) styleParameters {
	return _styleParameters;
}

#pragma mark -

- (void) setEmoticons:(JVEmoticonSet *) emoticons {
	[_emoticons autorelease];
	_emoticons = [emoticons retain];

	if( _webViewReady ) {
		[WebCoreCache empty];

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

- (void) setScrollbackLimit:(unsigned int) limit {
	_scrollbackLimit = limit;
}

- (unsigned int) scrollbackLimit {
	return _scrollbackLimit;
}

#pragma mark -

- (void) reloadCurrentStyle {
	_switchingStyles = YES;
	_requiresFullMessage = YES;
	_rememberScrollPosition = YES;

	[WebCoreCache empty];

	[self _resetDisplay];
}

- (void) clear {
	_switchingStyles = NO;
	_requiresFullMessage = YES;
	[self _resetDisplay];
}

- (void) mark {
	if( _webViewReady ) {
		unsigned int location = 0;

		DOMElement *elt = [_domDocument getElementById:@"mark"];
		if( elt ) [[elt parentNode] removeChild:elt];
		elt = [_domDocument createElement:@"hr"];
		[elt setAttribute:@"id" :@"mark"];
		[_body appendChild:elt];
		[self scrollToBottom];
		location = [[elt valueForKey:@"offsetTop"] longValue];

		JVMarkedScroller *scroller = [self verticalMarkedScroller];
		[scroller removeMarkWithIdentifier:@"mark"];
		[scroller addMarkAt:location withIdentifier:@"mark" withColor:[NSColor redColor]];

		_requiresFullMessage = YES;
	} else {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
	}
}

#pragma mark -

- (void) setTopicMessage:(NSAttributedString *) topic andAuthor:(NSString *) author {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];

	[_topicMessage release];
	_topicMessage = [[topic HTMLFormatWithOptions:options] retain];

	[_topicAuthor autorelease];
	_topicAuthor = [author copy];

	if( ! _webViewReady ) return;

	[self _reallySetTopicMessage:_topicMessage andAuthor:_topicAuthor];
}

#pragma mark -

- (BOOL) appendChatMessage:(JVChatMessage *) message {
	if( ! _webViewReady ) return YES; // don't schedule this to fire later since the transcript will be processed

	NSString *result = nil;

	if( _requiresFullMessage ) {
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[_domDocument getElementById:@"consecutiveInsert"];
		if( replaceElement ) _requiresFullMessage = NO; // a full message was assumed, but we can do a consecutive one
	}

	@try {
		if( _requiresFullMessage ) {
			NSArray *elements = [NSArray arrayWithObject:message];
			result = [[self style] transformChatTranscriptElements:elements withParameters:[self styleParameters]];
			_requiresFullMessage = NO;
		} else {
			result = [[self style] transformChatMessage:message withParameters:[self styleParameters]];
		}
	} @catch ( NSException *exception ) {
		result = nil;
		[self _styleError];
		return NO;
	}

	if( [result length] ) [self _appendMessage:result];

	return ( [result length] ? YES : NO );
}

- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element {
	if( ! _webViewReady ) return YES; // don't schedule this to fire later since the transcript will be processed

	NSString *result = nil;

	@try {
		result = [[self style] transformChatTranscriptElement:element withParameters:[self styleParameters]];
	} @catch ( NSException *exception ) {
		result = nil;
		[self _styleError];
		return NO;
	}

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
	if( _switchingStyles || ! _webViewReady ) {
		[self performSelector:_cmd withObject:message afterDelay:0.];
		return;
	}

	long loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) [[self verticalMarkedScroller] addMarkAt:loc];
}

- (void) markScrollbarForMessage:(JVChatMessage *) message usingMarkIdentifier:(NSString *) identifier andColor:(NSColor *) color {
	if( _switchingStyles || ! _webViewReady ) return; // can't queue, too many args. NSInvocation?

	long loc = [self _locationOfMessage:message];
	if( loc != NSNotFound ) [[self verticalMarkedScroller] addMarkAt:loc withIdentifier:identifier withColor:color];
}

- (void) markScrollbarForMessages:(NSArray *) messages {
	if( _switchingStyles || ! _webViewReady ) {
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
	[_domDocument autorelease];
	_domDocument = (DOMHTMLDocument *)[[[self mainFrame] DOMDocument] retain];

	[_body autorelease];
	_body = (DOMHTMLElement *)[[_domDocument getElementById:@"contents"] retain];
	if( ! _body ) _body = (DOMHTMLElement *)[[_domDocument body] retain];

	[self performSelector:@selector( _checkForTransparantStyle )];

	[self _reallySetTopicMessage:_topicMessage andAuthor:_topicAuthor];

	[self setPreferencesIdentifier:[[self style] identifier]];
	[[self preferences] setJavaScriptEnabled:YES];

	[self clearScrollbarMarks];

	if( [[self window] isFlushWindowDisabled] ) [[self window] enableFlushWindow];
	[[self window] displayIfNeeded];

	[self performSelector:@selector( _webkitIsReady ) withObject:nil afterDelay:0.];
}

- (void) drawRect:(NSRect) rect {
	[[NSColor clearColor] set];
	NSRectFill( rect ); // allows poking holes in the window with rgba background colors
	[super drawRect:rect];
}

#pragma mark -
#pragma mark Highlight/Message Jumping

- (JVMarkedScroller *) verticalMarkedScroller {
	NSArray *subViews = [[[[self mainFrame] frameView] documentView] subviews];
	NSEnumerator *enumerator = [subViews objectEnumerator];
	Class class = NSClassFromString( @"KWQScrollBar" );
	JVMarkedScroller *view = nil;

	while( ( view = [enumerator nextObject] ) )
		if( [view isKindOfClass:class] && NSHeight( [view frame] ) > NSWidth( [view frame] ) ) break;

	if( ! view ) {
		NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
		return (JVMarkedScroller *)[scrollView verticalScroller];		
	}

	return view;
}

- (IBAction) jumpToMark:(id) sender {
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	unsigned long long loc = [scroller locationOfMarkWithIdentifier:@"mark"];
	if( loc != NSNotFound ) {
		long shift = [scroller shiftAmountToCenterAlign];
		[_body setValue:[NSNumber numberWithUnsignedLong:( loc - shift )] forKey:@"scrollTop"];
		[scroller setLocationOfCurrentMark:loc];
	}
}

- (IBAction) jumpToPreviousHighlight:(id) sender {
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	unsigned long long loc = [scroller locationOfPreviousMark];
	if( loc != NSNotFound ) {
		long shift = [scroller shiftAmountToCenterAlign];
		[_body setValue:[NSNumber numberWithUnsignedLong:( loc - shift )] forKey:@"scrollTop"];
		[scroller setLocationOfCurrentMark:loc];
	}
}

- (IBAction) jumpToNextHighlight:(id) sender {
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	unsigned long long loc = [scroller locationOfNextMark];
	if( loc != NSNotFound ) {
		long shift = [scroller shiftAmountToCenterAlign];
		[_body setValue:[NSNumber numberWithUnsignedLong:( loc - shift )] forKey:@"scrollTop"];
		[scroller setLocationOfCurrentMark:loc];
	}
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
	if( ! _webViewReady ) {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
		return;
	}

	[_body setValue:[_body valueForKey:@"scrollHeight"] forKey:@"scrollTop"];
}
@end

#pragma mark -

@implementation JVStyleView (JVStyleViewPrivate)
- (void) _checkForTransparantStyle {
	DOMCSSStyleDeclaration *style = [self computedStyleForElement:_body pseudoElement:nil];
	DOMCSSValue *value = [style getPropertyCSSValue:@"background-color"];
	if( ( value && [[value cssText] rangeOfString:@"rgba"].location != NSNotFound ) )
		[self setDrawsBackground:NO]; // allows rgba backgrounds to see through to the Desktop
	else [self setDrawsBackground:YES];
	[self setNeedsDisplay:YES];
}

- (void) _webkitIsReady {
	_webViewReady = YES;
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

	_webViewReady = NO;
	if( _rememberScrollPosition ) {
		_lastScrollPosition = [[_body valueForKey:@"scrollTop"] longValue];
	} else _lastScrollPosition = 0;

	[[self window] disableFlushWindow];
	[[self mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
}

- (void) _switchStyle {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NSThread setThreadPriority:0.25];

	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.00025]]; // wait, WebKit might not be ready.

	JVStyle *style = [[self style] retain];
	JVChatTranscript *transcript = [[self transcript] retain];
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:[self styleParameters]];
	unsigned long elementCount = [transcript elementCount];
	unsigned long i = elementCount;
	NSEnumerator *enumerator = nil;
	NSArray *elements = nil;
	id element = nil;
	NSString *result = nil;
	NSMutableArray *highlightedMsgs = [NSMutableArray arrayWithCapacity:( [self scrollbackLimit] / 8 )];

	[parameters setObject:@"'yes'" forKey:@"bulkTransform"];

	for( i = elementCount; i > ( elementCount - MIN( [self scrollbackLimit], elementCount ) ); i -= MIN( 25, i ) ) {
		elements = [transcript elementsInRange:NSMakeRange( i - MIN( 25, i ), MIN( 25, i ) )];

		enumerator = [elements objectEnumerator];
		while( ( element = [enumerator nextObject] ) )
			if( [element isKindOfClass:[JVChatMessage class]] && [element isHighlighted] )
				[highlightedMsgs addObject:element];

		@try {
			result = [style transformChatTranscriptElements:elements withParameters:parameters];
		} @catch ( NSException *exception ) {
			result = nil;
			[self performSelectorOnMainThread:@selector( _styleError ) withObject:exception waitUntilDone:YES];
			goto quickEnd;
		}

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

	unsigned int messageCount = [self _visibleMessageCount];
	unsigned int scrollbackLimit = [self scrollbackLimit];
	BOOL subsequent = ( [message rangeOfString:@"<?message type=\"subsequent\"?>"].location != NSNotFound );

	long shiftAmount = 0;
	if( ! subsequent && ( messageCount + 1 ) > scrollbackLimit ) {
		shiftAmount = [self _locationOfElementAtIndex:( ( messageCount + 1 ) - scrollbackLimit )];
		if( shiftAmount > 0 && shiftAmount != NSNotFound )
			[[self verticalMarkedScroller] shiftMarksAndShadedAreasBy:( shiftAmount * -1 )];
	}

	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument createElement:@"span"];
	DOMHTMLElement *insertElement = (DOMHTMLElement *)[_domDocument getElementById:@"insert"];
	DOMHTMLElement *consecutiveReplaceElement = (DOMHTMLElement *)[_domDocument getElementById:@"consecutiveInsert"];
	if( ! consecutiveReplaceElement ) subsequent = NO;

	NSMutableString *transformedMessage = [message mutableCopy];
	[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
	[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];

	// parses the message so we can get the DOM tree
	[element setInnerHTML:transformedMessage];

	[transformedMessage release];
	transformedMessage = nil;

	// check if we are near the bottom of the chat area, and if we should scroll down later
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	BOOL scrollNeeded = ( ! scroller || [scroller floatValue] >= 0.985 );

	unsigned int i = 0;
	if( ! subsequent ) { // append message normally
		[[consecutiveReplaceElement parentNode] removeChild:consecutiveReplaceElement];
		while( [[element childNodes] length] ) { // append all children
			DOMNode *node = [[element firstChild] retain];
			[element removeChild:node];
			if( insertElement ) [_body insertBefore:node :insertElement];
			else [_body appendChild:node];
			[node release];
		}
	} else if( [[element childNodes] length] >= 1 ) { // append as a subsequent message
		DOMNode *parent = [consecutiveReplaceElement parentNode];
		DOMNode *nextSib = [consecutiveReplaceElement nextSibling];
		[parent replaceChild:[element firstChild] :consecutiveReplaceElement]; // replaces the consecutiveInsert node
		while( [[element childNodes] length] ) { // append all remaining children (in reverse order)
			DOMNode *node = [[element firstChild] retain];
			[element removeChild:node];
			if( nextSib ) [parent insertBefore:node :nextSib];
			else [parent appendChild:node];
			[node release];
		}
	}

	// enforce the scrollback limit
	if( scrollbackLimit > 0 && [[_body childNodes] length] > scrollbackLimit )
		for( i = 0; [[_body childNodes] length] > scrollbackLimit && i < ( [[_body childNodes] length] - scrollbackLimit ); i++ )
			[_body removeChild:[[_body childNodes] item:0]];

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
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	BOOL scrollNeeded = ( ! scroller || [scroller floatValue] >= 0.985 );

	// parses the message so we can get the DOM tree
	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument createElement:@"span"];
	[element setInnerHTML:result];

	[result release];
	result = nil;

	DOMNode *firstMessage = [_body firstChild];

	while( [[element childNodes] length] ) { // append all children
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

- (void) _tickleForLayout {
	// nasty hack to make overflow areas resize/reposition their scrollbars
	// simply calling [[[[self mainFrame] frameView] documentView] layout] wont trigger this
	DOMElement *node = [_domDocument createElement:@"span"];
	[_body appendChild:node];
	[_body removeChild:node];
}

#pragma mark -

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html {
	NSURL *resources = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
	NSString *variantStyleSheetLocation = [[[self style] variantStyleSheetLocationWithName:[self styleVariant]] absoluteString];
	if( ! variantStyleSheetLocation ) variantStyleSheetLocation = @"";

	NSString *shell = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
		shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	else shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];

	return [NSString stringWithFormat:shell, @"", [resources absoluteString], [[[self emoticons] styleSheetLocation] absoluteString], [[[self style] mainStyleSheetLocation] absoluteString], variantStyleSheetLocation, [[[self style] baseLocation] absoluteString], [[self style] contentsOfBodyTemplateWithName:[self bodyTemplate]]];
}

#pragma mark -

- (long) _locationOfMessageWithIdentifier:(NSString *) identifier {
	if( ! _webViewReady ) return 0;
	if( ! [identifier length] ) return 0;

	DOMElement *element = [_domDocument getElementById:identifier];
	id value = [element valueForKey:@"offsetTop"];
	if( [value respondsToSelector:@selector( longValue )] )
		return [value longValue];
	return NSNotFound;
}

- (long) _locationOfMessage:(JVChatMessage *) message {
	return [self _locationOfMessageWithIdentifier:[message messageIdentifier]];
}

- (long) _locationOfElementAtIndex:(unsigned long) index {
	if( ! _webViewReady ) return NSNotFound;
	id value = [[[_body childNodes] item:index] valueForKey:@"offsetTop"];
	if( index < [[_body childNodes] length] && [value respondsToSelector:@selector( longValue )] )
		return [value longValue];
	return NSNotFound;
}

- (unsigned long) _visibleMessageCount {
	if( ! _webViewReady ) return 0;
	return [[_body childNodes] length];
}

- (void) _reallySetTopicMessage:(NSString *) message andAuthor:(NSString *) author {
	DOMHTMLElement *element = (DOMHTMLElement *)[_domDocument getElementById:@"topicMessage"];
	[element setInnerHTML:( message ? message : @"" )];
	[element setTitle:( message ? message : @"" )];
	element = (DOMHTMLElement *)[_domDocument getElementById:@"topicAuthor"];
	[element setInnerText:( author ? author : @"" )];
	[element setTitle:( author ? author : @"" )];
}
@end