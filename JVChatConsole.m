#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import "JVChatConsole.h"
#import "JVChatController.h"
#import "MVTextView.h"

@implementation JVChatConsole
- (id) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = [connection retain];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _gotRawMessage: ) name:MVChatConnectionGotRawMessageNotification object:connection];
	}
	return self;
}

- (void) awakeFromNib {
	[send setContinuousSpellCheckingEnabled:NO];
	[send setUsesFontPanel:NO];
	[send setUsesRuler:NO];
	[send setImportsGraphics:NO];
	[send reset:nil];

	[display setContinuousSpellCheckingEnabled:NO];
	[display setUsesFontPanel:NO];
	[display setUsesRuler:NO];
	[display setImportsGraphics:NO];
}

- (void) dealloc {
	[contents autorelease];
	[_connection autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	contents = nil;
	_connection = nil;
	_windowController = nil;

	[super dealloc];
}

#pragma mark -

- (JVChatWindowController *) windowController {
	return [[_windowController retain] autorelease];
}

- (void) setWindowController:(JVChatWindowController *) controller {
	_windowController = controller;
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatConsole" owner:self];
	return contents;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"chat.console"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

#pragma mark -

- (NSString *) title {
	return [_connection server];
}

- (NSString *) windowTitle {
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - Console", "chat console - window title" ), [_connection server]];
}

- (NSString *) information {
	return nil;
}

#pragma mark -

- (id <JVChatListItem>) parent {
	return nil;
}

- (int) numberOfChildren {
	return 0;
}

- (id) childAtIndex:(int) index {
	return nil;
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

/*	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];*/

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"console"];
}

- (NSImage *) statusImage {
	return nil;
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (void) addMessageToDisplay:(NSString *) message asOutboundMessage:(BOOL) outbound {
	NSAttributedString *msg = nil;
	NSMutableString *strMsg = [[message mutableCopy] autorelease];
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatVerboseConsoleMessages"];

	[attrs setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Monaco" traits:0 weight:5 size:9.] forKey:NSFontAttributeName];
	[attrs setObject:( outbound ? [NSColor blueColor] : [NSColor blackColor] ) forKey:NSForegroundColorAttributeName];

	if( ! verbose ) [strMsg replaceOccurrencesOfString:@" :" withString:@" " options:NSLiteralSearch range:NSMakeRange( 0, [strMsg length] )];

	if( ! outbound && ! verbose ) {
		NSMutableArray *parts = [[[strMsg componentsSeparatedByString:@" "] mutableCopy] autorelease];
		if( [[parts objectAtIndex:2] isEqualToString:[_connection nickname]] )
			[parts removeObjectAtIndex:2];
		if( [[parts objectAtIndex:1] intValue] )
			[parts removeObjectAtIndex:1];
		if( [[parts objectAtIndex:0] isEqualToString:[@":" stringByAppendingString:[_connection server]]] )
			[parts removeObjectAtIndex:0];
		else if( [[parts objectAtIndex:0] hasPrefix:[@":" stringByAppendingString:[_connection nickname]]] )
			[parts removeObjectAtIndex:0];
		strMsg = (NSMutableString *) [parts componentsJoinedByString:@" "];
	}

	msg = [[[NSAttributedString alloc] initWithString:strMsg attributes:attrs] autorelease];
	if( [[display textStorage] length] )
		[display replaceCharactersInRange:NSMakeRange( [[display textStorage] length], 0 ) withString:@"\n"];
	[[display textStorage] appendAttributedString:msg];
	if( NSMinY( [display visibleRect] ) >= ( NSHeight( [display bounds] ) - ( NSHeight( [display visibleRect] ) * 1.1 ) ) )
		[display scrollRangeToVisible:NSMakeRange( [[display textStorage] length], 0 )];
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
	if( [identifier isEqual:JVToolbarToggleChatDrawerItemIdentifier] ) {
		toolbarItem = [_windowController toggleChatDrawerToolbarItem];
	} else toolbarItem = nil;
	return nil;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier, nil];
	return [[list retain] autorelease];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
	return [[list retain] autorelease];
}
@end

#pragma mark -

@implementation JVChatConsole (JVChatConsoleprivate)
- (void) _gotRawMessage:(NSNotification *) notification {
	[self addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] asOutboundMessage:[[[notification userInfo] objectForKey:@"outbound"] boolValue]];
}
@end