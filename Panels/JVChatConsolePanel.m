#import "JVChatConsolePanel.h"
#import "JVChatController.h"
#import "MVTextView.h"
#import "JVSplitView.h"

static NSString *JVToolbarToggleVerboseItemIdentifier = @"JVToolbarToggleVerboseItem";
static NSString *JVToolbarTogglePrivateMessagesItemIdentifier = @"JVToolbarTogglePrivateMessagesItem";
static NSString *JVToolbarClearItemIdentifier = @"JVToolbarClearItem";

@implementation JVChatConsolePanel
- (id) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_sendHistory = [[NSMutableArray array] retain];
		[_sendHistory insertObject:[[[NSAttributedString alloc] initWithString:@""] autorelease] atIndex:0];

		_sendHeight = 25.;
		_historyIndex = 0;
		_paused = NO;
		_forceSplitViewPosition = YES;

		_connection = [connection retain];
		_verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatVerboseConsoleMessages"];
		_ignorePRIVMSG = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatConsolePanelIgnoreUserChatMessages"];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _gotRawMessage: ) name:MVChatConnectionGotRawMessageNotification object:connection];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( clearConsole: ) name:MVChatConnectionWillConnectNotification object:connection];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidConnectNotification object:connection];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidDisconnectNotification object:connection];
	}
	return self;
}

- (void) awakeFromNib {
	[send setUsesSystemCompleteOnTab:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVUsePantherTextCompleteOnTab"]];
	[send setContinuousSpellCheckingEnabled:NO];
	[send setUsesFontPanel:NO];
	[send setUsesRuler:NO];
	[send setAllowsUndo:YES];
	[send setImportsGraphics:NO];
	[send setUsesFindPanel:NO];
	[send setUsesFontPanel:NO];
	[send reset:nil];

	[display setEditable:NO];
	[display setContinuousSpellCheckingEnabled:NO];
	[display setUsesFontPanel:NO];
	[display setUsesRuler:NO];
	[display setImportsGraphics:NO];

	[[display layoutManager] setDelegate:self];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		[(JVSplitView *)[[send enclosingScrollView] superview] setIsPaneSplitter:YES];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[contents release];
	[_sendHistory release];
	[_connection release];

	contents = nil;
	_connection = nil;
	_sendHistory = nil;
	_windowController = nil;

	[super dealloc];
}

- (NSString *) description {
	return [NSString stringWithFormat:@"%@: %@", NSStringFromClass( [self class] ), [[self connection] server]];
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
	[[JVChatController defaultController] disposeViewController:self];
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

- (NSResponder *) firstResponder {
	return send;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Console"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

#pragma mark -

- (BOOL) isEnabled {
	return ! ( ! [[self connection] isConnected] && [[self connection] status] != MVChatConnectionConnectingStatus );
}

- (NSString *) title {
	return [[self connection] server];
}

- (NSString *) windowTitle {
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - Console", "chat console - window title" ), [[self connection] server]];
}

- (NSString *) information {
	if( ! [[self connection] isConnected] && [[self connection] status] != MVChatConnectionConnectingStatus )
		return NSLocalizedString( @"disconnected", "disconnected status info line in drawer" );
	return nil;
}

- (NSString *) toolTip {
	if( ! [[self connection] lag] ) return [self title];
	return [NSString stringWithFormat:NSLocalizedString( @"%@\n%.3f seconds lag", "console tooltip witg lag (server delay) info in seconds" ), [self title], [[self connection] lag] / 1000.];
}

#pragma mark -

- (id <JVChatListItem>) parent {
	return nil;
}

- (NSArray *) children {
	return nil;
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""] autorelease];
	[item setTarget:_windowController];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Display", "clear console contextual menu item title" ) action:@selector( clearConsole: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	if( [[[self windowController] allChatViewControllers] count] > 1 ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
		[item setRepresentedObject:self];
		[item setTarget:[JVChatController defaultController]];
		[menu addItem:item];
	}
		
	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"console"];
}

#pragma mark -

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Console %@", [[self connection] server]];
}

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (void) didSelect {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] ) {
		[(JVSplitView *)[[send enclosingScrollView] superview] setPositionUsingName:@"JVChatSplitViewPosition"];
	} else [self textDidChange:nil];
}

#pragma mark -

- (void) pause {
	if( [[self connection] type] == MVChatConnectionIRCType )
		_paused = YES;
}

- (void) resume {
	_paused = NO;
}

- (BOOL) isPaused {
	return _paused;
}

- (void) addMessageToDisplay:(NSString *) message asOutboundMessage:(BOOL) outbound {
	NSAttributedString *msg = nil;
	NSMutableString *strMsg = [[message mutableCopy] autorelease];
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *para = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	unsigned int numeric = 0;

	if( [[self connection] type] == MVChatConnectionIRCType ) {
		if( ! [strMsg length] || ( _ignorePRIVMSG && [strMsg rangeOfString:@"PRIVMSG"].location != NSNotFound && [strMsg rangeOfString:@"\001"].location == NSNotFound ) )
			return;

		if( ! _verbose ) {
			[strMsg replaceOccurrencesOfString:@":" withString:@"" options:NSAnchoredSearch range:NSMakeRange( 0, 1 )];
			[strMsg replaceOccurrencesOfString:@" :" withString:@" " options:NSLiteralSearch range:NSMakeRange( 0, [strMsg length] )];
		}

		[strMsg replaceOccurrencesOfString:@"\n" withString:@"" options:NSAnchoredSearch | NSBackwardsSearch range:NSMakeRange( [strMsg length] - 2, 2 )];
		[strMsg replaceOccurrencesOfString:@"\r" withString:@"" options:NSAnchoredSearch | NSBackwardsSearch range:NSMakeRange( [strMsg length] - 1, 1 )];

		if( ! outbound && ! _verbose ) {
			NSMutableArray *parts = [[[strMsg componentsSeparatedByString:@" "] mutableCopy] autorelease];
			NSString *tempStr = nil;
			unsigned i = 0, c = 0;

			if( [parts count] >= 3 && [[parts objectAtIndex:2] isEqualToString:[[self connection] nickname]] )
				[parts removeObjectAtIndex:2];

			if( [parts count] >= 2 && ( numeric = [[parts objectAtIndex:1] intValue] ) )
				[parts removeObjectAtIndex:1];
			else if( [parts count] >= 2 && ( [[parts objectAtIndex:1] isEqualToString:@"PRIVMSG"] && [strMsg rangeOfString:@"\001"].location != NSNotFound && [strMsg rangeOfString:@" ACTION"].location == NSNotFound ) )
				[parts replaceObjectAtIndex:1 withObject:@"CTCP REQUEST"];
			else if( [parts count] >= 2 && ( [[parts objectAtIndex:1] isEqualToString:@"NOTICE"] && [strMsg rangeOfString:@"\001"].location != NSNotFound ) )
				[parts replaceObjectAtIndex:1 withObject:@"CTCP REPLY"];

			tempStr = [parts objectAtIndex:0];
			if( tempStr && [tempStr rangeOfString:@"@"].location == NSNotFound && [tempStr rangeOfString:@"."].location != NSNotFound && [NSURL URLWithString:[@"irc://" stringByAppendingString:tempStr]] ) {
				[parts removeObjectAtIndex:0];
			} else if( [tempStr hasPrefix:[NSString stringWithFormat:@"%@!", [[self connection] nickname]]] ) {
				[parts removeObjectAtIndex:0];
			}

			for( i = 0, c = [parts count]; i < c; i++ ) {
				tempStr = [@"irc://" stringByAppendingString:[parts objectAtIndex:i]];
				if( ( tempStr = [[NSURL URLWithString:tempStr] user] ) && [tempStr rangeOfString:@"!"].location != NSNotFound )
					[parts replaceObjectAtIndex:i withObject:[tempStr substringToIndex:[tempStr rangeOfString:@"!"].location]];
			}

			strMsg = (NSMutableString *) [parts componentsJoinedByString:@" "];
			if( numeric ) strMsg = [NSString stringWithFormat:@"%03u: %@", numeric, strMsg];
		} else if( outbound && ! _verbose ) {
			if( [strMsg rangeOfString:@"NOTICE"].location != NSNotFound && [strMsg rangeOfString:@"\001"].location != NSNotFound ) {
				[strMsg replaceOccurrencesOfString:@"NOTICE" withString:@"CTCP REPLY" options:NSAnchoredSearch range:NSMakeRange( 0, 6 )];
			} else if( [strMsg rangeOfString:@"PRIVMSG"].location != NSNotFound && [strMsg rangeOfString:@"\001"].location != NSNotFound && [strMsg rangeOfString:@" ACTION"].location == NSNotFound ) {
				[strMsg replaceOccurrencesOfString:@"PRIVMSG" withString:@"CTCP REQUEST" options:NSAnchoredSearch range:NSMakeRange( 0, 7 )];
			}
		}
	}

	[para setParagraphSpacing:3.];
	[para setMaximumLineHeight:9.];
	if( ! outbound ) [para setMaximumLineHeight:9.];
	else [para setMaximumLineHeight:11.];

	if( outbound ) [attrs setObject:[NSFont boldSystemFontOfSize:11.] forKey:NSFontAttributeName];
	else [attrs setObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Monaco" traits:0 weight:5 size:9.] forKey:NSFontAttributeName];
	[attrs setObject:para forKey:NSParagraphStyleAttributeName];

	NSScrollView *scrollView = [display enclosingScrollView];
	NSScroller *scroller = [scrollView verticalScroller];
	if( ! [scrollView hasVerticalScroller] || [scroller floatValue] >= 0.995 ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;

	msg = [[[NSAttributedString alloc] initWithString:strMsg attributes:attrs] autorelease];
	[[display textStorage] beginEditing];
	if( [[display string] length] )
		[display replaceCharactersInRange:NSMakeRange( [[display string] length], 0 ) withString:@"\n"];
	[[display textStorage] appendAttributedString:msg];
	[[display textStorage] endEditing];
}

- (void) performScrollToBottom {
	NSScrollView *scrollView = [display enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];
	[scrollView scrollClipView:clipView toPoint:[clipView constrainScrollPoint:NSMakePoint( 0, [[scrollView documentView] bounds].size.height )]];
	[scrollView reflectScrolledClipView:clipView];
}

- (void) layoutManager:(NSLayoutManager *) layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *) textContainer atEnd:(BOOL) atEnd {
	unsigned int length = [[display string] length];
	if( _scrollerIsAtBottom && atEnd && length != _lastDisplayTextLength )
		[self performScrollToBottom];
	_lastDisplayTextLength = length;
}

#pragma mark -

- (void) send:(id) sender {
	NSMutableAttributedString *subMsg = nil;
	NSRange range;

	if( ! [[self connection] isConnected] ) return;

	[self resume];

	_historyIndex = 0;
	if( ! [[send string] length] ) return;
	if( [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[NSAttributedString alloc] initWithString:@""] autorelease]];
	[_sendHistory insertObject:[[[send textStorage] copy] autorelease] atIndex:1];
	if( [_sendHistory count] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatMaximumHistory"] unsignedIntValue] )
		[_sendHistory removeObjectAtIndex:[_sendHistory count] - 1];

	while( [[send string] length] ) {
		range = [[[send textStorage] string] rangeOfString:@"\n"];
		if( ! range.length ) range.location = [[send string] length];
		subMsg = [[[[send textStorage] attributedSubstringFromRange:NSMakeRange( 0, range.location )] mutableCopy] autorelease];

		if( ( [subMsg length] >= 1 && range.length ) || ( [subMsg length] && ! range.length ) ) {
			if( [[subMsg string] hasPrefix:@"/"] ) {
				NSScanner *scanner = [NSScanner scannerWithString:[subMsg string]];
				NSString *command = nil;
				NSAttributedString *arguments = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [[subMsg string] length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [subMsg attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], range.location - [scanner scanLocation] )];

				NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( MVChatConnection * ), @encode( id ), nil];
				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

				[invocation setSelector:@selector( processUserCommand:withArguments:toConnection:inView: )];
				[invocation setArgument:&command atIndex:2];
				[invocation setArgument:&arguments atIndex:3];
				[invocation setArgument:&_connection atIndex:4];
				[invocation setArgument:&self atIndex:5];

				NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];

				if( ! [[results lastObject] boolValue] )
					[[self connection] sendRawMessage:[command stringByAppendingFormat:@" %@", [arguments string]]];
			} else {
				[[self connection] sendRawMessage:[subMsg string]];
			}
		}
		if( range.length ) range.location++;
		[[send textStorage] deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}

	[send reset:nil];
	[self textDidChange:nil];
	[self performScrollToBottom];
}

- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event {
	[self send:nil];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event {
	[self send:nil];
	return YES;
}

- (BOOL) upArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[send textStorage] copy] autorelease]];

	_historyIndex++;

	if( _historyIndex >= (int) [_sendHistory count] ) {
		if( [_sendHistory count] >= 1 )
			_historyIndex = [_sendHistory count] - 1;
		else _historyIndex = 0;
		return YES;
	}

	[send reset:nil];
	[[send textStorage] insertAttributedString:[_sendHistory objectAtIndex:_historyIndex] atIndex:0];

	return YES;
}

- (BOOL) downArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[send textStorage] copy] autorelease]];
	if( [[send string] length] ) _historyIndex--;
	if( _historyIndex < 0 ) {
		[send reset:nil];
		_historyIndex = -1;
		return YES;
	} else if( ! [_sendHistory count] ) {
		_historyIndex = 0;
		return YES;
	}
	[send reset:nil];
	[[send textStorage] insertAttributedString:[_sendHistory objectAtIndex:_historyIndex] atIndex:0];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event {
	unichar chr = 0;

	if( [[event charactersIgnoringModifiers] length] ) {
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];
	} else return NO;

	// exclude device-dependent flags, caps-lock and fn key (necessary for pg up/pg dn/home/end on portables)
	if( [event modifierFlags] & ~( NSFunctionKeyMask | NSNumericPadKeyMask | NSAlphaShiftKeyMask | 0xffff ) ) return NO;

	BOOL usesOnlyArrows = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendHistoryUsesOnlyArrows"];

	if( chr == NSUpArrowFunctionKey && ( usesOnlyArrows || [event modifierFlags] & NSAlternateKeyMask ) ) {
		return [self upArrowKeyPressed];
	} else if( chr == NSDownArrowFunctionKey && ( usesOnlyArrows || [event modifierFlags] & NSAlternateKeyMask ) ) {
		return [self downArrowKeyPressed];
	}

	return NO;
}

- (NSArray *) textView:(NSTextView *) textView stringCompletionsForPrefix:(NSString *) prefix {
	return nil;
}

- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event {
	[send reset:nil];
	return YES;
}

- (void) textDidChange:(NSNotification *) notification {
	_historyIndex = 0;

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return;

	// We need to resize the textview to fit the content.
	// The scroll views are two superviews up: NSTextView -> NSClipView -> NSScrollView
	NSSplitView *splitView = (NSSplitView *)[[send enclosingScrollView] superview];
	NSRect splitViewFrame = [splitView frame];
	NSSize contentSize = [send minimumSizeForContent];
	NSRect sendFrame = [[send enclosingScrollView] frame];
	float dividerThickness = [splitView dividerThickness];
	float maxContentHeight = ( NSHeight( splitViewFrame ) - dividerThickness - 75. );
	float newContentHeight =  MIN( maxContentHeight, MAX( 25., contentSize.height + 8. ) );

	if( newContentHeight == NSHeight( sendFrame ) ) return;

	NSRect displayFrame = [[display enclosingScrollView] frame];

	// Set size of the web view to the maximum size possible
	displayFrame.size.height = NSHeight( splitViewFrame ) - dividerThickness - newContentHeight;
	displayFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = newContentHeight;
	sendFrame.origin.y = NSHeight( displayFrame ) + dividerThickness;

	[[display window] disableFlushWindow]; // prevent any draw (white) flashing that might occur

	NSScrollView *scrollView = [display enclosingScrollView];
	NSScroller *scroller = [scrollView verticalScroller];
	if( ! [scrollView hasVerticalScroller] || [scroller floatValue] >= 0.995 ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;

	// Commit the changes
	[[send enclosingScrollView] setFrame:sendFrame];
	[[display enclosingScrollView] setFrame:displayFrame];

	if( _scrollerIsAtBottom )
		[self performScrollToBottom];

	[splitView setNeedsDisplay:YES]; // makes the divider redraw correctly later
	[[display window] enableFlushWindow]; // flush everything we have drawn
	[[display window] displayIfNeeded];
}

#pragma mark -
#pragma mark Scripting Support

- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (NSWindow *) window {
	return [[self windowController] window];
}

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The panel id %@ doesn't have the \"%@\" property.", [self uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of panel id %@ is read only.", key, [self uniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}

#pragma mark -
#pragma mark Toolbar Support

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

#pragma mark -
#pragma mark SplitView Support

- (float) splitView:(NSSplitView *) splitView constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) index {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return ( NSHeight( [[[splitView subviews] objectAtIndex:index] frame] ) ); // prevents manual resize
	return proposedPosition;
}

- (void) splitViewDidResizeSubviews:(NSNotification *) notification {
	// Cache the height of the send box so we can keep it constant during window resizes.
	NSRect sendFrame = [[send enclosingScrollView] frame];
	_sendHeight = sendFrame.size.height;

	if( _scrollerIsAtBottom )
		[self performScrollToBottom];

	if( ! _forceSplitViewPosition && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		[(JVSplitView *)[notification object] savePositionUsingName:@"JVChatSplitViewPosition"];

	_forceSplitViewPosition = NO;
}

- (void) splitViewWillResizeSubviews:(NSNotification *) notification {
	NSScrollView *scrollView = [display enclosingScrollView];
	NSScroller *scroller = [scrollView verticalScroller];
	if( ! [scrollView hasVerticalScroller] || [scroller floatValue] >= 0.995 ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;
}

- (void) splitView:(NSSplitView *) sender resizeSubviewsWithOldSize:(NSSize) oldSize {
	float dividerThickness = [sender dividerThickness];
	NSRect newFrame = [sender frame];

	// Keep the size of the send box constant during window resizes

	// We need to resize the scroll view frames of the webview and the textview.
	// The scroll views are two superviews up: NSTextView(WebView) -> NSClipView -> NSScrollView
	NSRect sendFrame = [[send enclosingScrollView] frame];
	NSRect displayFrame = [[display enclosingScrollView] frame];

	// Set size of the web view to the maximum size possible
	displayFrame.size.height = NSHeight( newFrame ) - dividerThickness - _sendHeight;
	displayFrame.size.width = NSWidth( newFrame );
	displayFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = _sendHeight;
	sendFrame.size.width = NSWidth( newFrame );
	sendFrame.origin.y = NSHeight( displayFrame ) + dividerThickness;

	// Commit the changes
	[[send enclosingScrollView] setFrame:sendFrame];
	[[display enclosingScrollView] setFrame:displayFrame];
}
@end

#pragma mark -

@implementation JVChatConsolePanel (JVChatConsolePanelPrivate)
- (void) _gotRawMessage:(NSNotification *) notification {
	if( _paused ) return;
	[self addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] asOutboundMessage:[[[notification userInfo] objectForKey:@"outbound"] boolValue]];
}

- (void) _refreshIcon:(NSNotification *) notification {
	[_windowController reloadListItem:self andChildren:NO];
}
@end