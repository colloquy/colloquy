#import "JVJavaScriptChatPlugin.h"

#import "JVChatController.h"
#import "JVChatEvent.h"
#import "JVChatMessage.h"
#import "JVChatRoomMember.h"
#import "JVChatRoomPanel.h"
#import "JVChatTranscript.h"
#import "JVChatTranscriptPanel.h"
#import "JVChatWindowController.h"
#import "JVNotificationController.h"
#import "JVToolbarItem.h"
#import "JVSpeechController.h"
#import "MVBuddyListController.h"
#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "NSAttributedStringAdditions.h"
#import "NSStringAdditions.h"

#import <WebKit/WebKit.h>
#import <objc/objc-runtime.h>

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

@interface WebView (WebViewPrivate) // new Tiger private method
- (void) setScriptDebugDelegate:(id) delegate;
@end

#pragma mark -

@interface WebScriptCallFrame : NSObject
- (void)setUserInfo:(id)userInfo;
- (id)userInfo;
- (WebScriptCallFrame *)caller;
- (NSArray *)scopeChain;
- (NSString *)functionName;
- (id)exception;
- (id)evaluateWebScript:(NSString *)script;
@end

#pragma mark -

static BOOL replacementIsSelectorExcludedFromWebScript( id self, SEL cmd, SEL selector ) {
	return NO;
}

#pragma mark -

@implementation NSObject (JVJavaScriptName)
+ (NSString *) webScriptNameForSelector:(SEL) selector {
	NSString *name = NSStringFromSelector( selector );
	NSRange colonRange = [name rangeOfString:@":"];
	if( colonRange.location != NSNotFound )
		return [name substringToIndex:colonRange.location];
	return name;
}
@end

#pragma mark -

NSString *JVJavaScriptErrorDomain = @"JVJavaScriptErrorDomain";

@implementation JVJavaScriptChatPlugin
+ (void) initialize {
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		Method method = class_getClassMethod( [NSObject class], @selector( isSelectorExcludedFromWebScript: ) );
		if( method ) method -> method_imp = (IMP) replacementIsSelectorExcludedFromWebScript;
		tooLate = YES;
	}
}

- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_manager = manager;
		_path = nil;
		_modDate = [[NSDate date] retain];
	}

	return self;
}

- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_path = [path copyWithZone:[self zone]];

		[self reloadFromDisk];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( checkForModifications: ) name:NSApplicationWillBecomeActiveNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[[_webview windowScriptObject] removeWebScriptKey:@"Plugin"];
	[super release];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_webview release];
	[_path release];
	[_modDate release];

	_webview = nil;
	_path = nil;
	_modDate = nil;
	_manager = nil;

	[super dealloc];
}

#pragma mark -

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];

	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"plugin" ofType:@"html"];

	if( [[url scheme] isEqualToString:@"file"] && [[url path] isEqualToString:path] ) {
		[listener use];
	} else if( [[url scheme] isEqualToString:@"about"] ) {
		if( [[[url standardizedURL] path] length] ) [listener ignore];
		else [listener use];
	} else {
		[[NSWorkspace sharedWorkspace] openURL:url];
		[listener ignore];
	}
}

- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
	if( sender == _webview ) {
		_loading = NO;

		NSString *contents = nil;
		if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
			contents = [NSString performSelector:@selector( stringWithContentsOfFile: ) withObject:[self scriptFilePath]];
		else contents = [NSString stringWithContentsOfFile:[self scriptFilePath] encoding:NSUTF8StringEncoding error:NULL];

		[[sender windowScriptObject] evaluateWebScript:contents];

		[self performSelector:@selector( load )];
	}
}

- (void) webView:(WebView *) webView windowScriptObjectAvailable:(WebScriptObject *) windowScriptObject {
	[self setupScriptGlobalsForWebView:webView];
}

- (void) webView:(WebView *) webView addMessageToConsole:(NSDictionary *) message {
	[self reportError:message inFunction:_currentFunction whileLoading:_loading];
}

- (WebView *) webView:(WebView *) sender createWebViewWithRequest:(NSURLRequest *) request {
	NSRect frame = NSMakeRect( 200., 200., 150., 150. );

	WebView *newWebView = [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
	[newWebView setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
	[newWebView setFrameLoadDelegate:self];
	[newWebView setUIDelegate:self];
	if( request ) [[newWebView mainFrame] loadRequest:request];

	NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:( NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask ) backing:NSBackingStoreBuffered defer:NO screen:[[sender window] screen]];
	[window setOpaque:NO];
	[window setBackgroundColor:[NSColor clearColor]];
	if( [window respondsToSelector:@selector( _setContentHasShadow: )] )
		[window _setContentHasShadow:NO];
	[window setReleasedWhenClosed:YES];
	[newWebView setFrame:[[window contentView] frame]];
	[window setContentView:newWebView];
	[newWebView release];

	return newWebView;
}

- (void) webView:(WebView *) sender runJavaScriptAlertPanelWithMessage:(NSString *) message initiatedByFrame:(WebFrame *) frame {
    NSRange range = [message rangeOfString:@"\t"];
    NSString *title = NSLocalizedStringFromTableInBundle( @"Alert", nil, [NSBundle bundleForClass:[self class]], "default JavaScript alert title" );
    if( range.location != NSNotFound ) {
        title = [message substringToIndex:range.location];
        message = [message substringFromIndex:( range.location + range.length )];
    }

    NSBeginInformationalAlertSheet( title, nil, nil, nil, [sender window], nil, NULL, NULL, NULL, message );
}

- (void) webViewShow:(WebView *) sender {
	[[sender window] makeKeyAndOrderFront:sender];
}

- (void) webView:(WebView *) sender setResizable:(BOOL) resizable {
	[[sender window] setShowsResizeIndicator:resizable];
	[[[sender window] standardWindowButton:NSWindowZoomButton] setEnabled:resizable];
}

- (void) webView:(WebView *) sender failedToParseSource:(NSString *) source baseLineNumber:(unsigned) lineNumber fromURL:(NSURL *) url withError:(NSError *) error forWebFrame:(WebFrame *) webFrame {
	NSDictionary *errorInfo = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:NSLocalizedStringFromTableInBundle( @"Failed to parse script.", nil, [NSBundle bundleForClass:[self class]], "failed to parse JavaScript error message" ), @"message", ( [url isFileURL] ? [url path] : nil ), @"sourceURL", nil];
	[self reportError:errorInfo inFunction:_currentFunction whileLoading:_loading];
	[errorInfo release];
}

- (void) webView:(WebView *) sender didEnterCallFrame:(WebScriptCallFrame *) frame sourceId:(int) sid line:(int) line forWebFrame:(WebFrame *) webFrame {
	[_currentException release];
	_currentException = nil;
}

- (void) webView:(WebView *) sender willLeaveCallFrame:(WebScriptCallFrame *) frame sourceId:(int) sid line:(int) line forWebFrame:(WebFrame *) webFrame {
	if( [frame exception] ) [self reportErrorForCallFrame:frame lineNumber:line];
}

- (void) webView:(WebView *) sender exceptionWasRaised:(WebScriptCallFrame *) frame sourceId:(int) sid line:(int) line forWebFrame:(WebFrame *) webFrame {
	if( [frame exception] ) [self reportErrorForCallFrame:frame lineNumber:line];
}

#pragma mark -

- (void) setupScriptGlobalsForWebView:(WebView *) webView {
	[[webView windowScriptObject] setValue:self forKey:@"Plugin"];
	[[webView windowScriptObject] setValue:[JVChatController defaultController] forKey:@"ChatController"];
	[[webView windowScriptObject] setValue:[MVConnectionsController defaultController] forKey:@"ConnectionsController"];
	[[webView windowScriptObject] setValue:[MVFileTransferController defaultController] forKey:@"FileTransferController"];
	[[webView windowScriptObject] setValue:[MVBuddyListController sharedBuddyList] forKey:@"BuddyListController"];
	[[webView windowScriptObject] setValue:[JVSpeechController sharedSpeechController] forKey:@"SpeechController"];
	[[webView windowScriptObject] setValue:[JVNotificationController defaultController] forKey:@"NotificationController"];
	[[webView windowScriptObject] setValue:[MVChatPluginManager defaultManager] forKey:@"ChatPluginManager"];
}

#pragma mark -

- (id) allocInstance:(NSString *) class {
	return [[NSClassFromString(class) allocWithZone:nil] autorelease];
}

#pragma mark -

- (MVChatPluginManager *) pluginManager {
	return _manager;
}

- (NSString *) scriptFilePath {
	return _path;
}

- (void) reloadFromDisk {
	[self performSelector:@selector( unload )];

	_loading = YES;

	id old = _webview;
	_webview = [[WebView allocWithZone:nil] initWithFrame:NSZeroRect];
	[old release];

	[_webview setPolicyDelegate:self];
	[_webview setFrameLoadDelegate:self];
	[_webview setUIDelegate:self];
	if( [_webview respondsToSelector:@selector( setScriptDebugDelegate: )] )
		[_webview setScriptDebugDelegate:self];

	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"plugin" ofType:@"html"];
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5.];
	[[_webview mainFrame] loadRequest:request];
}

#pragma mark -

- (void) promptForReload {
	if( NSRunInformationalAlertPanel( NSLocalizedStringFromTableInBundle( @"JavaScript Changed", nil, [NSBundle bundleForClass:[self class]], "JavaScript file changed dialog title" ), NSLocalizedStringFromTableInBundle( @"The JavaScript \"%@\" has changed on disk. Any script variables will reset if reloaded.", nil, [NSBundle bundleForClass:[self class]], "JavaScript changed on disk message" ), NSLocalizedStringFromTableInBundle( @"Reload", nil, [NSBundle bundleForClass:[self class]], "reload button title" ), NSLocalizedStringFromTableInBundle( @"Keep Previous Version", nil, [NSBundle bundleForClass:[self class]], "keep previous version button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension] ) == NSOKButton ) {
		[self reloadFromDisk];
	}
}

- (void) checkForModifications:(NSNotification *) notification {
	if( ! [[self scriptFilePath] length] ) return;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = [self scriptFilePath];

	if( [fm fileExistsAtPath:path] ) {
		NSDictionary *info = [fm fileAttributesAtPath:path traverseLink:YES];
		NSDate *fileModDate = [info fileModificationDate];
		if( [fileModDate compare:_modDate] == NSOrderedDescending && [fileModDate compare:[NSDate date]] == NSOrderedAscending ) { // newer script file
			[_modDate autorelease];
			_modDate = [[NSDate date] retain];
			[self performSelector:@selector( promptForReload ) withObject:nil afterDelay:0.];
		}
	}
}

#pragma mark -

- (void) reportErrorForCallFrame:(WebScriptCallFrame *) frame lineNumber:(unsigned int) line {
	id handled = nil;
	id exception = [frame exception];
	@try { handled = [exception valueForKey:@"handled"]; } @catch( NSException *e ) { handled = nil; }

	if( exception && ! handled && ! [_currentException isEqual:exception] ) {
		[_currentException release];
		_currentException = [exception retain];

		NSNumber *lineNumber = ( line ? [NSNumber numberWithUnsignedInt:line] : nil );
		NSString *sourceURL = nil;
		NSString *message = exception;

		if( [exception isKindOfClass:[WebScriptObject class]] ) {
			[exception setValue:[NSNumber numberWithBool:YES] forKey:@"handled"];

			@try { lineNumber = [exception valueForKey:@"line"]; } @catch( NSException *e ) { lineNumber = nil; }
			@try { sourceURL = [exception valueForKey:@"sourceURL"]; } @catch( NSException *e ) { sourceURL = nil; }
			@try { message = [exception valueForKey:@"message"]; } @catch( NSException *e ) { message = exception; }
		}

		NSDictionary *error = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:message, @"message", lineNumber, @"lineNumber", sourceURL, @"sourceURL", nil];
		[self reportError:error inFunction:_currentFunction whileLoading:_loading];
		[error release];
	}
}

- (void) reportError:(NSDictionary *) error inFunction:(NSString *) functionName whileLoading:(BOOL) whileLoading {
	if( _errorShown ) return;

	NSMutableString *errorDesc = [[NSMutableString alloc] initWithCapacity:64];

	NSString *message = [error objectForKey:@"message"];
	NSString *sourceFile = [error objectForKey:@"sourceURL"];
	if( ! sourceFile || [sourceFile isEqualToString:[[NSBundle bundleForClass:[self class]] pathForResource:@"plugin" ofType:@"html"]] )
		sourceFile = [self scriptFilePath];
	unsigned int line = [[error objectForKey:@"lineNumber"] unsignedIntValue];

	if( [message length] ) [errorDesc appendString:message];
	else [errorDesc appendString:NSLocalizedStringFromTableInBundle( @"Unknown error.", nil, [NSBundle bundleForClass:[self class]], "unknown error message" )];

	if( line ) {
		[errorDesc appendString:@"\n"];
		[errorDesc appendFormat:NSLocalizedStringFromTableInBundle( @"Line number: %d", nil, [NSBundle bundleForClass:[self class]], "error line number" ), line];
	}

	NSString *alertTitle = NSLocalizedStringFromTableInBundle( @"JavaScript Error", nil, [NSBundle bundleForClass:[self class]], "JavaScript error title" );
	NSString *scriptTitle = [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension];
	int result = NSOKButton;

	_errorShown = YES;
	if( whileLoading ) result = NSRunCriticalAlertPanel( alertTitle, NSLocalizedStringFromTableInBundle( @"The JavaScript \"%@\" had an error while loading.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "JavaScript error message while loading" ), nil, NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" ), nil, scriptTitle, errorDesc );
	else if( functionName ) result = NSRunCriticalAlertPanel( alertTitle, NSLocalizedStringFromTableInBundle( @"The JavaScript \"%@\" had an error while calling the \"%@\" function.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "JavaScript plugin error message calling function" ), nil, NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" ), nil, scriptTitle, functionName, errorDesc );
	else result = NSRunCriticalAlertPanel( alertTitle, NSLocalizedStringFromTableInBundle( @"The JavaScript \"%@\" had an error.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "JavaScript error message" ), nil, NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" ), nil, scriptTitle, errorDesc );
	_errorShown = NO;

	if( result == NSCancelButton ) [[NSWorkspace sharedWorkspace] openFile:sourceFile];

	[errorDesc release];
}

- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector {
	if( ! [_webview windowScriptObject] ) return nil;

	_currentFunction = functionName;

	@try {
		id result = [[_webview windowScriptObject] callWebScriptMethod:functionName withArguments:arguments];
		_currentFunction = nil;
		return result;
	} @catch (NSException *exception) {
		NSDictionary *error = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:[exception reason], @"message", nil];
		[self reportError:error inFunction:functionName whileLoading:NO];
		[error release];
	}

	_currentFunction = nil;

	NSDictionary *error = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Function named \"%@\" could not be found or is not callable", functionName] forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:JVJavaScriptErrorDomain code:-1 userInfo:error];
}

- (NSArray *) arrayFromJavaScriptArray:(WebScriptObject *) javaScriptArray {
	@try {
		id lengthObj = [javaScriptArray valueForKey:@"length"];
		if( ! [lengthObj respondsToSelector:@selector( unsignedIntValue )] )
			return nil;

		unsigned length = [lengthObj unsignedIntValue];
		NSMutableArray *result = [NSMutableArray arrayWithCapacity:length];
		for( unsigned i = 0; i < length; ++i ) {
			id item = [javaScriptArray webScriptValueAtIndex:i];
			if( item ) [result addObject:item];
		}

		return result;
	} @catch( NSException *e ) {
		// do nothing
	}

	return nil;
}

#pragma mark -

- (void) load {
	NSArray *args = [NSArray arrayWithObjects:[self scriptFilePath], nil];
	[self callScriptFunctionNamed:@"load" withArguments:args forSelector:_cmd];
}

- (void) unload {
	[self callScriptFunctionNamed:@"unload" withArguments:nil forSelector:_cmd];
}

- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:( object ? (id)object : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] ), nil];
	id result = [self callScriptFunctionNamed:@"contextualMenuItems" withArguments:args forSelector:_cmd];
	if( [result isKindOfClass:[WebScriptObject class]] )
		return [self arrayFromJavaScriptArray:result];
	return nil;
}

- (NSArray *) toolbarItemIdentifiersForView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:view, nil];
	id result = [self callScriptFunctionNamed:@"toolbarItemIdentifiers" withArguments:args forSelector:_cmd];
	if( [result isKindOfClass:[WebScriptObject class]] )
		return [self arrayFromJavaScriptArray:result];
	return nil;
}

- (NSToolbarItem *) toolbarItemForIdentifier:(NSString *) identifier inView:(id <JVChatViewController>) view willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSArray *args = [NSArray arrayWithObjects:identifier, view, [NSNumber numberWithBool:willBeInserted], nil];
	JVToolbarItem *result = [self callScriptFunctionNamed:@"toolbarItem" withArguments:args forSelector:_cmd];
	if( [result isKindOfClass:[JVToolbarItem class]] ) {
		[result setTarget:self];
		[result setAction:@selector( handleClickedToolbarItem: )];
		[result setRepresentedObject:view];
		return result;
	}

	return nil;
}

- (void) handleClickedToolbarItem:(JVToolbarItem *) sender {
	NSArray *args = [NSArray arrayWithObjects:sender, [sender representedObject], nil];
	[self callScriptFunctionNamed:@"handleClickedToolbarItem" withArguments:args forSelector:_cmd];
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSArray *args = [NSArray arrayWithObjects:identifier, ( context ? (id)context : (id)[NSNull null] ), ( preferences ? (id)preferences : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"performNotification" withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	NSString *argumentsHTML = [arguments HTMLFormatWithOptions:options];
	argumentsHTML = [argumentsHTML stringByStrippingIllegalXMLCharacters];

	NSArray *args = [NSArray arrayWithObjects:command, ( argumentsHTML ? (id)argumentsHTML : (id)[NSNull null] ), ( connection ? (id)connection : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] ), nil];
	id result = [self callScriptFunctionNamed:@"processUserCommand" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:url, ( view ? (id)view : (id)[NSNull null] ), nil];
	id result = [self callScriptFunctionNamed:@"handleClickedLink" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:message, view, nil];
	[self callScriptFunctionNamed:@"processIncomingMessage" withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:message, view, nil];
	[self callScriptFunctionNamed:@"processOutgoingMessage" withArguments:args forSelector:_cmd];
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObjects:member, room, nil];
	[self callScriptFunctionNamed:@"memberJoined" withArguments:args forSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	NSString *reasonHTML = [reason HTMLFormatWithOptions:options];
	reasonHTML = [reasonHTML stringByStrippingIllegalXMLCharacters];

	NSArray *args = [NSArray arrayWithObjects:member, room, ( reasonHTML ? (id)reasonHTML : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	NSString *reasonHTML = [reason HTMLFormatWithOptions:options];
	reasonHTML = [reasonHTML stringByStrippingIllegalXMLCharacters];

	NSArray *args = [NSArray arrayWithObjects:member, room, ( by ? (id)by : (id)[NSNull null] ), ( reasonHTML ? (id)reasonHTML : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"memberKicked" withArguments:args forSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObject:room];
	[self callScriptFunctionNamed:@"joinedRoom" withArguments:args forSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	NSArray *args = [NSArray arrayWithObject:room];
	[self callScriptFunctionNamed:@"partingFromRoom" withArguments:args forSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	NSString *reasonHTML = [reason HTMLFormatWithOptions:options];
	reasonHTML = [reasonHTML stringByStrippingIllegalXMLCharacters];

	NSArray *args = [NSArray arrayWithObjects:room, ( by ? (id)by : (id)[NSNull null] ), ( reasonHTML ? (id)reasonHTML : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	NSString *topicHTML = [topic HTMLFormatWithOptions:options];
	topicHTML = [topicHTML stringByStrippingIllegalXMLCharacters];

	NSArray *args = [NSArray arrayWithObjects:topicHTML, room, ( member ? (id)member : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"topicChanged" withArguments:args forSelector:_cmd];
}

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = [NSArray arrayWithObjects:command, ( arguments ? (id)arguments : (id)[NSNull null] ), user, nil];
	id result = [self callScriptFunctionNamed:@"processSubcodeRequest" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSArray *args = [NSArray arrayWithObjects:command, ( arguments ? (id)arguments : (id)[NSNull null] ), user, nil];
	id result = [self callScriptFunctionNamed:@"processSubcodeReply" withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSArray *args = [NSArray arrayWithObject:connection];
	[self callScriptFunctionNamed:@"connected" withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSArray *args = [NSArray arrayWithObject:connection];
	[self callScriptFunctionNamed:@"disconnecting" withArguments:args forSelector:_cmd];
}
@end
