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
#import "JVSpeechController.h"
#import "MVBuddyListController.h"
#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "NSStringAdditions.h"

#import <WebKit/WebKit.h>

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

static BOOL replacementIsSelectorExcludedFromWebScript( id self, SEL cmd, SEL selector ) {
	return NO;
}

static BOOL replacementIsKeyExcludedFromWebScript( id self, SEL cmd, const char *name ) {
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

		method = class_getClassMethod( [NSObject class], @selector( isKeyExcludedFromWebScript: ) );
		if( method ) method -> method_imp = (IMP) replacementIsKeyExcludedFromWebScript;

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

	if( sender == _webview && [url isFileURL] && [[url path] isEqualToString:[[NSBundle bundleForClass:[self class]] pathForResource:@"plugin" ofType:@"html"]] ) {
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
		NSString *contents = nil;
		if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
			contents = [NSString stringWithContentsOfFile:[self scriptFilePath]];
		else contents = [NSString stringWithContentsOfFile:[self scriptFilePath] encoding:NSUTF8StringEncoding error:NULL];

		@try {
			[[_webview windowScriptObject] evaluateWebScript:contents];
		} @catch (NSException *exception) {
			NSString *errorDesc = [exception reason];
			int result = NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"JavaScript Error", nil, [NSBundle bundleForClass:[self class]], "JavaScript error title" ), NSLocalizedStringFromTableInBundle( @"The JavaScript \"%@\" had an error while loading.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "JavaScript error message" ), nil, NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension], errorDesc );
			if( result == NSCancelButton ) [[NSWorkspace sharedWorkspace] openFile:[self scriptFilePath]];
			return;
		}

		[self performSelector:@selector( load )];
	}
}

- (void) webView:(WebView *) webView windowScriptObjectAvailable:(WebScriptObject *) windowScriptObject {
	[self setupScriptGlobalsForWebView:webView];
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
    NSString *title = @"Alert";
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

#pragma mark -

- (void) setupScriptGlobalsForWebView:(WebView *) webView {
	[[webView windowScriptObject] setValue:[JVChatController defaultController] forKey:@"ChatController"];
	[[webView windowScriptObject] setValue:[MVConnectionsController defaultController] forKey:@"ConnectionsController"];
	[[webView windowScriptObject] setValue:[MVFileTransferController defaultController] forKey:@"FileTransferController"];
	[[webView windowScriptObject] setValue:[MVBuddyListController sharedBuddyList] forKey:@"BuddyListController"];
	[[webView windowScriptObject] setValue:[JVSpeechController sharedSpeechController] forKey:@"SpeechController"];
	[[webView windowScriptObject] setValue:[JVNotificationController defaultController] forKey:@"NotificationController"];
	[[webView windowScriptObject] setValue:[MVChatPluginManager defaultManager] forKey:@"ChatPluginManager"];
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

	id old = _webview;
	_webview = [[WebView allocWithZone:nil] initWithFrame:NSZeroRect];
	[old release];

	[_webview setPolicyDelegate:self];
	[_webview setFrameLoadDelegate:self];
	[_webview setUIDelegate:self];

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

- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector {
	if( ! [_webview windowScriptObject] ) return nil;

	@try {
		return [[_webview windowScriptObject] callWebScriptMethod:functionName withArguments:arguments];
	} @catch (NSException *exception) {
		int result = NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"JavaScript Error", nil, [NSBundle bundleForClass:[self class]], "JavaScript error title" ), NSLocalizedStringFromTableInBundle( @"The JavaScript \"%@\" had an error while calling the \"%@\" function.\n\n%@", nil, [NSBundle bundleForClass:[self class]], "JavaScript plugin error message" ), nil, NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension], functionName, [exception reason] );
		if( result == NSCancelButton ) [[NSWorkspace sharedWorkspace] openFile:[self scriptFilePath]];
	}

	NSDictionary *error = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Function named \"%@\" could not be found or is not callable", functionName] forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:JVJavaScriptErrorDomain code:-1 userInfo:error];
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
	return ( [result isKindOfClass:[NSArray class]] ? result : nil );
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSArray *args = [NSArray arrayWithObjects:identifier, ( context ? (id)context : (id)[NSNull null] ), ( preferences ? (id)preferences : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"performNotification" withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSArray *args = [NSArray arrayWithObjects:command, ( arguments ? (id)[arguments string] : (id)[NSNull null] ), ( connection ? (id)connection : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] ), nil];
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
	NSArray *args = [NSArray arrayWithObjects:member, room, ( reason ? (id)[reason string] : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:member, room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)[reason string] : (id)[NSNull null] ), nil];
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
	NSArray *args = [NSArray arrayWithObjects:room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)[reason string] : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSArray *args = [NSArray arrayWithObjects:[topic string], room, ( member ? (id)member : (id)[NSNull null] ), nil];
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
