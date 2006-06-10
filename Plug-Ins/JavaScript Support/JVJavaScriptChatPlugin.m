#import "JVJavaScriptChatPlugin.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "NSStringAdditions.h"

#import <WebKit/WebKit.h>

NSString *JVJavaScriptErrorDomain = @"JVJavaScriptErrorDomain";

@implementation JVJavaScriptChatPlugin
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
		_firstLoad = YES;

		[self reloadFromDisk];

		_firstLoad = NO;

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

	if( ! _firstLoad ) [self performSelector:@selector( load )];
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
	NSArray *args = [NSArray arrayWithObjects:command, ( arguments ? (id)arguments : (id)[NSNull null] ), ( connection ? (id)connection : (id)[NSNull null] ), ( view ? (id)view : (id)[NSNull null] ), nil];
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
	NSArray *args = [NSArray arrayWithObjects:member, room, ( reason ? (id)reason : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"memberParted" withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSArray *args = [NSArray arrayWithObjects:member, room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)reason : (id)[NSNull null] ), nil];
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
	NSArray *args = [NSArray arrayWithObjects:room, ( by ? (id)by : (id)[NSNull null] ), ( reason ? (id)reason : (id)[NSNull null] ), nil];
	[self callScriptFunctionNamed:@"kickedFromRoom" withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSArray *args = [NSArray arrayWithObjects:topic, room, ( member ? (id)member : (id)[NSNull null] ), nil];
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
