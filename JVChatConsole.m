#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import "JVChatConsole.h"
#import "JVChatController.h"
#import "MVTextView.h"

static NSString *JVToolbarToggleVerboseItemIdentifier = @"JVToolbarToggleVerboseItem";
static NSString *JVToolbarTogglePrivateMessagesItemIdentifier = @"JVToolbarTogglePrivateMessagesItem";
static NSString *JVToolbarClearItemIdentifier = @"JVToolbarClearItem";

@implementation JVChatConsole
- (id) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = [connection retain];
		_verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatVerboseConsoleMessages"];
		_ignorePRIVMSG = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatConsoleIgnoreUserChatMessages"];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _gotRawMessage: ) name:MVChatConnectionGotRawMessageNotification object:connection];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( clearConsole: ) name:MVChatConnectionWillConnectNotification object:connection];
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

- (IBAction) clearConsole:(id) sender {
	[display setString:@""];
}

- (IBAction) toggleVerbose:(id) sender {
	_verbose = ! _verbose;
}

- (IBAction) toggleMessages:(id) sender {
	_ignorePRIVMSG = ! _ignorePRIVMSG;
}

- (IBAction) close:(id) sender {
	[[JVChatController defaultManager] disposeViewController:self];
	[_windowController removeChatViewController:self];
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
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Console"];
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

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear", "clear console contextual menu item title" ) action:@selector( clearConsole: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

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

- (NSString *) identifier {
	return [NSString stringWithFormat:@"%@.console", [_connection server]];
}

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (void) addMessageToDisplay:(NSData *) message asOutboundMessage:(BOOL) outbound {
	NSAttributedString *msg = nil;
	NSMutableString *strMsg = [[[NSMutableString alloc] initWithData:message encoding:NSUTF8StringEncoding] autorelease];
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *para = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	unsigned int numeric = 0;

	if( ! strMsg ) strMsg = [NSMutableString stringWithCString:[message bytes] length:[message length]];

	if( ! [strMsg length] || ( _ignorePRIVMSG && [strMsg rangeOfString:@"PRIVMSG"].location != NSNotFound && [strMsg rangeOfString:@"\001"].location == NSNotFound ) )
		return;

	[para setParagraphSpacing:3.];
	[para setMaximumLineHeight:9.];
	if( ! outbound ) [para setMaximumLineHeight:9.];
	else [para setMaximumLineHeight:11.];

	if( outbound ) [attrs setObject:[NSFont boldSystemFontOfSize:11.] forKey:NSFontAttributeName];
	else [attrs setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Monaco" traits:0 weight:5 size:9.] forKey:NSFontAttributeName];
	[attrs setObject:para forKey:NSParagraphStyleAttributeName];

	if( ! _verbose ) {
		[strMsg replaceOccurrencesOfString:@":" withString:@"" options:NSAnchoredSearch range:NSMakeRange( 0, 1 )];
		[strMsg replaceOccurrencesOfString:@" :" withString:@" " options:NSLiteralSearch range:NSMakeRange( 0, [strMsg length] )];
	}

	if( ! outbound && ! _verbose ) {
		NSMutableArray *parts = [[[strMsg componentsSeparatedByString:@" "] mutableCopy] autorelease];
		NSString *tempStr = nil;
		unsigned i = 0, c = 0;

		if( [parts count] >= 3 && [[parts objectAtIndex:2] isEqualToString:[_connection nickname]] )
			[parts removeObjectAtIndex:2];

		if( [parts count] >= 2 && ( numeric = [[parts objectAtIndex:1] intValue] ) )
			[parts removeObjectAtIndex:1];
		else if( [parts count] >= 2 && ( [[parts objectAtIndex:1] isEqualToString:@"PRIVMSG"] && [strMsg rangeOfString:@"\001"].location != NSNotFound ) )
			[parts replaceObjectAtIndex:1 withObject:@"CTCP REQUEST"];
		else if( [parts count] >= 2 && ( [[parts objectAtIndex:1] isEqualToString:@"NOTICE"] && [strMsg rangeOfString:@"\001"].location != NSNotFound ) )
			[parts replaceObjectAtIndex:1 withObject:@"CTCP REPLY"];

		tempStr = [parts objectAtIndex:0];
		if( tempStr && [tempStr rangeOfString:@"@"].location == NSNotFound && [tempStr rangeOfString:@"."].location != NSNotFound && [NSURL URLWithString:[@"irc://" stringByAppendingString:tempStr]] ) {
			[parts removeObjectAtIndex:0];
		} else if( [tempStr hasPrefix:[NSString stringWithFormat:@"%@!", [_connection nickname]]] ) {
			[parts removeObjectAtIndex:0];
		}

		for( i = 0, c = [parts count]; i < c; i++ ) {
			tempStr = [@"irc://" stringByAppendingString:[parts objectAtIndex:i]];
			if( ( tempStr = [[NSURL URLWithString:tempStr] user] ) && [tempStr rangeOfString:@"!"].location != NSNotFound )
				[parts replaceObjectAtIndex:i withObject:[tempStr substringToIndex:[tempStr rangeOfString:@"!"].location]];
		}

		strMsg = (NSMutableString *) [parts componentsJoinedByString:@" "];
		if( numeric) strMsg = [NSString stringWithFormat:@"%03u: %@", numeric, strMsg];
	} else if( outbound && ! _verbose ) {
		if( [strMsg rangeOfString:@"NOTICE"].location != NSNotFound && [strMsg rangeOfString:@"\001"].location != NSNotFound ) {
			[strMsg replaceOccurrencesOfString:@"NOTICE" withString:@"CTCP REPLY" options:NSAnchoredSearch range:NSMakeRange( 0, 6 )];
		} else if( [strMsg rangeOfString:@"PRIVMSG"].location != NSNotFound && [strMsg rangeOfString:@"\001"].location != NSNotFound ) {
			[strMsg replaceOccurrencesOfString:@"PRIVMSG" withString:@"CTCP REQUEST" options:NSAnchoredSearch range:NSMakeRange( 0, 7 )];
		}		
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
	} else if( [identifier isEqual:JVToolbarClearItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Clear", "clear console toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Clear Console", "clear console toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Clear Console", "clear console tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"clear"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( clearConsole: )];
	} else if( [identifier isEqual:JVToolbarToggleVerboseItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Verbose", "verbose toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Toggle Verbose", "toggle verbose toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Verbose Output", "toggle verbose output tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"reveal"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( toggleVerbose: )];
	} else if( [identifier isEqual:JVToolbarTogglePrivateMessagesItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Messages", "toggle private messages toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Toggle Messages", "toggle private messages toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Private Messages Output", "toggle private messages output tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"room"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( toggleMessages: )];
	} else toolbarItem = nil;
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier, JVToolbarClearItemIdentifier, nil];
	return [[list retain] autorelease];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier, JVToolbarToggleVerboseItemIdentifier, JVToolbarTogglePrivateMessagesItemIdentifier, JVToolbarClearItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
	return [[list retain] autorelease];
}
@end

#pragma mark -

@implementation JVChatConsole (JVChatConsoleprivate)
- (void) _gotRawMessage:(NSNotification *) notification {
	[self addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] asOutboundMessage:[[[notification userInfo] objectForKey:@"outbound"] boolValue]];
}
@end