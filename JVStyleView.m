#import "JVStyleView.h"
#import "JVMarkedScroller.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"

#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSNotificationAdditions.h>

NSString *JVStyleViewDidChangeStylesNotification = @"JVStyleViewDidChangeStylesNotification";

@interface WebCoreCache
+ (void) empty;
@end

#pragma mark -

@interface WebView (WebViewPrivate) // WebKit 1.3 pending public API
- (void) setDrawsBackground:(BOOL) draws;
- (BOOL) drawsBackground;
@end

#pragma mark -

@interface NSScrollView (NSScrollViewWebKitPrivate)
- (void) setAllowsHorizontalScrolling:(BOOL) allow;
@end

#pragma mark -

@interface JVStyleView (JVStyleViewPrivate)
- (void) _setupMarkedScroller;
- (void) _resetDisplay;
- (void) _switchStyle;
- (void) _appendMessage:(NSString *) message;
- (void) _prependMessages:(NSString *) messages;
- (void) _styleError;
- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;
- (unsigned long) _visibleMessageCount;
- (long) _locationOfMessage:(JVChatMessage *) message;
- (long) _locationOfElementAtIndex:(unsigned long) index;
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
		_styleParameters = nil;
		_emoticons = nil;
		[self setNextTextView:nil];
	}

	return self;
}

- (void) awakeFromNib {
	_ready = YES;
	[self setFrameLoadDelegate:self];
	[self performSelector:@selector( _resetDisplay ) withObject:nil afterDelay:0.];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self setNextTextView:nil];
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
	nextTextView = textView;
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

	[[NSNotificationCenter defaultCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _styleVariantChanged: ) name:JVStyleVariantChangedNotification object:style];

	if( ! _ready ) return;

	_switchingStyles = YES;
	_requiresFullMessage = YES;
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
#ifdef WebKitVersion146
		if( [self respondsToSelector:@selector( windowScriptObject )] ) {
			NSString *styleSheetLocation = [[[self style] variantStyleSheetLocationWithName:_styleVariant] absoluteString];
			if( ! styleSheetLocation ) styleSheetLocation = @"";
			[[self windowScriptObject] callWebScriptMethod:@"setStylesheet" withArguments:[NSArray arrayWithObjects:@"variantStyle", styleSheetLocation, nil]];
		} else
#endif
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"variantStyle\", \"%@\" );", [[[self style] variantStyleSheetLocationWithName:_styleVariant] absoluteString]]];
	}
}

- (NSString *) styleVariant {
	return _styleVariant;
}

#pragma mark -

- (void) setStyleParameters:(NSDictionary *) parameters {
	[_styleParameters autorelease];
	_styleParameters = [parameters copyWithZone:[self zone]];
}

- (NSDictionary *) styleParameters {
	return _styleParameters;
}

#pragma mark -

- (void) setEmoticons:(JVEmoticonSet *) emoticons {
	[_emoticons autorelease];
	_emoticons = [emoticons retain];

	if( _webViewReady )
#ifdef WebKitVersion146
		if( [self respondsToSelector:@selector( webScriptObject )] ) {
			NSString *styleSheetLocation = [[[self emoticons] styleSheetLocation] absoluteString];
			if( ! styleSheetLocation ) styleSheetLocation = @"";
			[[self windowScriptObject] callWebScriptMethod:@"setStylesheet" withArguments:[NSArray arrayWithObjects:@"emoticonStyle", styleSheetLocation, nil]];
		} else
#endif
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"emoticonStyle\", \"%@\" );", [[[self emoticons] styleSheetLocation] absoluteString]]];
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
	[self _resetDisplay];
}

- (void) clear {
	_switchingStyles = NO;
	_requiresFullMessage = YES;
	[self _resetDisplay];
}

#pragma mark -

- (void) showTopic:(NSString *) topic {
	if( _webViewReady ) {
#ifdef WebKitVersion146
		if( [self respondsToSelector:@selector( windowScriptObject )] ) {
			[[self windowScriptObject] callWebScriptMethod:@"showTopic" withArguments:[NSArray arrayWithObject:topic]];
		} else {
#endif
			NSMutableString *mutTopic = [topic mutableCopy];
			[mutTopic replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [mutTopic length])];
			[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"showTopic( \"%@\" );", mutTopic]];
#ifdef WebKitVersion146
		}
#endif
	}
}

- (void) hideTopic {
	if( _webViewReady ) {
#ifdef WebKitVersion146
		if( [self respondsToSelector:@selector( windowScriptObject )] )
			[[self windowScriptObject] callWebScriptMethod:@"hideTopic" withArguments:[NSArray array]];
		else
#endif
			[self stringByEvaluatingJavaScriptFromString:@"hideTopic();"];
	}
}

- (void) toggleTopic:(NSString *) topic {
	if( _webViewReady ) {
		BOOL topicShowing;
#ifdef WebKitVersion146
		if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
			DOMHTMLElement *topicElement = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:@"topic-floater"];
			topicShowing = ( topicElement != nil );
		} else {
#endif
			NSString *result = [self stringByEvaluatingJavaScriptFromString:@"document.getElementById(\"topic-floater\") != null"];
			topicShowing = [result isEqualToString:@"true"];
#ifdef WebKitVersion146
		}
#endif
		if( topicShowing ) [self hideTopic];
		else [self showTopic:topic];
	}
}

#pragma mark -

- (BOOL) appendChatMessage:(JVChatMessage *) message {
	if( ! _webViewReady ) return;

	NSString *result = nil;

#ifdef WebKitVersion146
	if( _requiresFullMessage && [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:@"consecutiveInsert"];
		if( replaceElement ) _requiresFullMessage = NO; // a full message was assumed, but we can do a consecutive one
	}
#endif

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
		return;
	}

	if( [result length] ) [self _appendMessage:result];

	return ( [result length] ? YES : NO );
}

- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element {
	if( ! _webViewReady ) return;

	NSString *result = nil;

	@try {
		result = [[self style] transformChatTranscriptElement:element withParameters:[self styleParameters]];
	} @catch ( NSException *exception ) {
		result = nil;
		[self _styleError];
		return;
	}

	if( [result length] ) [self _appendMessage:result];

	return ( [result length] ? YES : NO );
}

#pragma mark -

- (void) markScrollbarForMessage:(JVChatMessage *) message {
	if( _switchingStyles || ! _webViewReady ) return;
	long loc = [self _locationOfMessage:message];
	if( loc ) [[self verticalMarkedScroller] addMarkAt:loc];
}

- (void) markScrollbarForMessages:(NSArray *) messages {
	if( _switchingStyles || ! _webViewReady ) return;

	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	NSEnumerator *enumerator = [messages objectEnumerator];
	JVChatMessage *message = nil;

	while( ( message = [enumerator nextObject] ) ) {
		long loc = [self _locationOfMessage:message];
		if( loc ) [scroller addMarkAt:loc];
	}
}

- (void) clearScrollbarMarks {
	if( ! _webViewReady ) return;

	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	[scroller removeAllMarks];
	[scroller removeAllShadedAreas];	
}

#pragma mark -

- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
	// Test for WebKit/Safari 1.3
#ifdef WebKitVersion146
	if( [self respondsToSelector:@selector( setDrawsBackground: )] ) {
		DOMCSSStyleDeclaration *style = [sender computedStyleForElement:[(DOMHTMLDocument *)[[sender mainFrame] DOMDocument] body] pseudoElement:nil];
		DOMCSSValue *value = [style getPropertyCSSValue:@"background-color"];
		DOMCSSValue *altvalue = [style getPropertyCSSValue:@"background"];
		if( ( value && [[value cssText] rangeOfString:@"rgba"].location != NSNotFound ) || ( altvalue && [[altvalue cssText] rangeOfString:@"rgba"].location != NSNotFound ) )
			[self setDrawsBackground:NO]; // allows rgba backgrounds to see through to the Desktop
		else [self setDrawsBackground:YES];
	}
#endif

	[self setPreferencesIdentifier:[[self style] identifier]];
	[[self preferences] setJavaScriptEnabled:YES];

	[[self verticalMarkedScroller] removeAllMarks];
	[[self verticalMarkedScroller] removeAllShadedAreas];

	[[self window] displayIfNeeded];
	if( [[self window] isFlushWindowDisabled] )
		[[self window] enableFlushWindow];

	_webViewReady = YES;

	if( _switchingStyles ) [NSThread detachNewThreadSelector:@selector( _switchStyle ) toTarget:self withObject:nil];
}

#pragma mark -
#pragma mark Highlight/Message Jumping

- (JVMarkedScroller *) verticalMarkedScroller {
	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		[self _setupMarkedScroller];
		scroller = (JVMarkedScroller *)[scrollView verticalScroller];
		if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] )
			return nil; // not sure, but somthing is wrong
	}

	return scroller;
}

- (IBAction) jumpToPreviousHighlight:(id) sender {
	[[self verticalMarkedScroller] jumpToPreviousMark:sender];
}

- (IBAction) jumpToNextHighlight:(id) sender {
	[[self verticalMarkedScroller] jumpToNextMark:sender];
}

- (void) jumpToMessage:(JVChatMessage *) message {
	unsigned long loc = [self _locationOfMessage:message];
	if( loc ) {
		NSScroller *scroller = [self verticalMarkedScroller];
		float scale = NSHeight( [scroller rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [scroller frame] ) / [scroller knobProportion] );
		float shift = ( ( NSHeight( [scroller rectForPart:NSScrollerKnobSlot] ) * [scroller knobProportion] ) / 2. ) / scale;
		[[(NSScrollView *)[scroller superview] documentView] scrollPoint:NSMakePoint( 0., loc - shift )];
	}
}

- (void) scrollToBottom {
	if( ! _webViewReady ) return;

#ifdef WebKitVersion146
	if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
		[body setValue:[body valueForKey:@"offsetHeight"] forKey:@"scrollTop"];
	} else
#endif
	// old JavaScript method
	[self stringByEvaluatingJavaScriptFromString:@"scrollToBottom();"];
}
@end

#pragma mark -

@implementation JVStyleView (JVStyleViewPrivate)
- (void) _resetDisplay {
	_webViewReady = NO;
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];
	
	[self stopLoading:nil];
	[self clearScrollbarMarks];

	[[self window] disableFlushWindow];
	[[self mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
}

- (void) _switchStyle {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NSThread setThreadPriority:0.25];

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
			usleep( 100000 ); // give time to other threads
		}
	}

	_switchingStyles = NO;
	[self performSelectorOnMainThread:@selector( markScrollbarForMessages: ) withObject:highlightedMsgs waitUntilDone:YES];

	NSNotification *note = [NSNotification notificationWithName:JVStyleViewDidChangeStylesNotification object:self userInfo:nil];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

quickEnd:
	_switchingStyles = NO;

	[style release];
	[transcript release];
	[pool release];
}

- (void) _appendMessage:(NSString *) message {
	if( ! _webViewReady ) return;

	unsigned int messageCount = [self _visibleMessageCount];
	unsigned int scrollbackLimit = [self scrollbackLimit];
	BOOL subsequent = ( [message rangeOfString:@"<?message type=\"subsequent\"?>"].location != NSNotFound );

	if( ! subsequent && ( messageCount + 1 ) > scrollbackLimit ) {
		long loc = [self _locationOfElementAtIndex:( ( messageCount + 1 ) - scrollbackLimit )];
		if( loc > 0 ) [[self verticalMarkedScroller] shiftMarksAndShadedAreasBy:( loc * -1 )];
	}

#ifdef WebKitVersion146
	if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		DOMHTMLElement *element = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] createElement:@"span"];
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:@"consecutiveInsert"];
		if( ! replaceElement ) subsequent = NO;

		NSMutableString *transformedMessage = [message mutableCopy];
		[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];

		// parses the message so we can get the DOM tree
		[element setInnerHTML:transformedMessage];

		[transformedMessage release];
		transformedMessage = nil;

		// check if we are near the bottom of the chat area, and if we should scroll down later
		NSNumber *scrollNeeded = [[[self mainFrame] DOMDocument] evaluateWebScript:@"( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) )"];
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];

		unsigned int i = 0;
		if( ! subsequent ) { // append message normally
			[[replaceElement parentNode] removeChild:replaceElement];
			while( [[element childNodes] length] ) // append all children
				[body appendChild:[element firstChild]];
		} else if( [[element childNodes] length] >= 1 ) { // append as a subsequent message
			DOMNode *parent = [replaceElement parentNode];
			DOMNode *nextSib = [replaceElement nextSibling];
			[parent replaceChild:[element firstChild] :replaceElement]; // replaces the consecutiveInsert node
			while( [[element childNodes] length] ) { // append all remaining children (in reverse order)
				if( nextSib ) [parent insertBefore:[element firstChild] :nextSib];
				else [parent appendChild:[element firstChild]];
			}
		}

		// enforce the scrollback limit
		if( scrollbackLimit > 0 && [[body childNodes] length] > scrollbackLimit )
			for( i = 0; [[body childNodes] length] > scrollbackLimit && i < ( [[body childNodes] length] - scrollbackLimit ); i++ )
				[body removeChild:[[body childNodes] item:0]];		

		if( [scrollNeeded boolValue] ) [self scrollToBottom];
	} else
#endif
	{ // old JavaScript method
		NSMutableString *transformedMessage = [message mutableCopy];
		[transformedMessage escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[transformedMessage replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		if( subsequent ) [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollBackLimit = %d; appendConsecutiveMessage( \"%@\" );", scrollbackLimit, transformedMessage]];
		else [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollBackLimit = %d; appendMessage( \"%@\" );", scrollbackLimit, transformedMessage]];
		[transformedMessage release];
	}
}

- (void) _prependMessages:(NSString *) messages {
	if( ! _webViewReady ) return;

#ifdef WebKitVersion146
	if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		NSMutableString *result = [messages mutableCopy];
		[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];

		// check if we are near the bottom of the chat area, and if we should scroll down later
		NSNumber *scrollNeeded = [[[self mainFrame] DOMDocument] evaluateWebScript:@"( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) )"];

		// parses the message so we can get the DOM tree
		DOMHTMLElement *element = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] createElement:@"span"];
		[element setInnerHTML:result];

		[result release];
		result = nil;

		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
		DOMNode *firstMessage = [body firstChild];

		while( [[element childNodes] length] ) { // append all children
			if( firstMessage ) [body insertBefore:[element firstChild] :firstMessage];
			else [body appendChild:[element firstChild]];
		}

		if( [scrollNeeded boolValue] ) [self scrollToBottom];
	} else
#endif
	{ // old JavaScript method
		NSMutableString *result = [messages mutableCopy];
		[result escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[result replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];
		[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"prependMessages( \"%@\" );", result]];
		[result release];
	}
}

- (void) _styleError {
	NSRunCriticalAlertPanel( NSLocalizedString( @"An internal Style error occurred.", "the stylesheet parse failed" ), NSLocalizedString( @"The %@ Style has been damaged or has an internal error preventing new messages from displaying. Please contact the %@ author about this.", "the style contains and error" ), @"OK", nil, nil, [[self style] displayName], [[self style] displayName] );
}

- (void) _styleVariantChanged:(NSNotification *) notification {
	NSString *variant = [[notification userInfo] objectForKey:@"variant"];
	if( [variant isEqualToString:[self styleVariant]] )
		[self setStyleVariant:variant];
}

#pragma mark -

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html {
	NSURL *resources = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
	NSURL *defaultStyleSheetLocation = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"default" ofType:@"css"]];
	NSString *variantStyleSheetLocation = [[[self style] variantStyleSheetLocationWithName:[self styleVariant]] absoluteString];
	if( ! variantStyleSheetLocation ) variantStyleSheetLocation = @"";
	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	return [NSString stringWithFormat:shell, @"", [resources absoluteString], [defaultStyleSheetLocation absoluteString], [[[self emoticons] styleSheetLocation] absoluteString], [[[self style] mainStyleSheetLocation] absoluteString], variantStyleSheetLocation, [[[self style] baseLocation] absoluteString], [[self style] contentsOfHeaderFile], html];
}

#pragma mark -

- (long) _locationOfMessageWithIdentifier:(NSString *) identifier {
	if( ! _webViewReady ) return 0;
	if( ! [identifier length] ) return 0;
#ifdef WebKitVersion146
	if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		DOMElement *element = [[[self mainFrame] DOMDocument] getElementById:identifier];
		id value = [element valueForKey:@"offsetTop"];
		if( [value respondsToSelector:@selector( intValue )] )
			return [value intValue];
		return 0;
	} else
#endif
	// old JavaScript method
	return [[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"locationOfMessage( \"%@\" );", identifier]] intValue];
}

- (long) _locationOfMessage:(JVChatMessage *) message {
	return [self _locationOfMessageWithIdentifier:[message messageIdentifier]];
}

- (long) _locationOfElementAtIndex:(unsigned long) index {
	if( ! _webViewReady ) return 0;
#ifdef WebKitVersion146
	if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
		id value = [[[body childNodes] item:index] valueForKey:@"offsetTop"];
		if( index < [[body childNodes] length] && [value respondsToSelector:@selector( intValue )] )
			return [value intValue];
		return 0;
	} else
#endif
	// old JavaScript method
	return [[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"locationOfElementAtIndex( %d );", index]] intValue];
}

- (unsigned long) _visibleMessageCount {
	if( ! _webViewReady ) return 0;
#ifdef WebKitVersion146
	if( [[self mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		return [[[(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body] childNodes] length];
	} else
#endif
	// old JavaScript method
	return [[self stringByEvaluatingJavaScriptFromString:@"scrollBackMessageCount();"] intValue];
}

#pragma mark -

- (void) _setupMarkedScroller {
	if( ! _webViewReady ) return;

	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
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
@end