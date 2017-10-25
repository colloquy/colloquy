#import "JVChatConsolePanel.h"
#import "JVChatController.h"
#import "MVTextView.h"
#import "JVSplitView.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *JVToolbarToggleVerboseItemIdentifier = @"JVToolbarToggleVerboseItem";
static NSString *JVToolbarTogglePrivateMessagesItemIdentifier = @"JVToolbarTogglePrivateMessagesItem";
static NSString *JVToolbarClearItemIdentifier = @"JVToolbarClearItem";

@interface JVChatConsolePanel ()
- (void) textDidChange:(nullable NSNotification *) notification;
@end

@interface JVChatConsolePanel (Private)
- (void) _gotImportantMessage:(NSNotification *) notification;
- (void) _gotInformationalMessage:(NSNotification *) notification;
- (void) _gotRawMessage:(NSNotification *) notification;
- (void) _refreshIcon:(NSNotification *) notification;
@end

@implementation JVChatConsolePanel
- (instancetype) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_sendHistory = [NSMutableArray array];
		[_sendHistory insertObject:[[NSAttributedString alloc] initWithString:@""] atIndex:0];

		_sendHeight = 25.;
		_historyIndex = 0;
		_paused = NO;
		_forceSplitViewPosition = YES;

		_connection = connection;
		_verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatVerboseConsoleMessages"];
		_ignorePRIVMSG = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatConsolePanelIgnoreUserChatMessages"];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotImportantMessage: ) name:MVChatConnectionGotImportantMessageNotification object:connection];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotInformationalMessage: ) name:MVChatConnectionGotInformationalMessageNotification object:connection];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotRawMessage: ) name:MVChatConnectionGotRawMessageNotification object:connection];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( clearConsole: ) name:MVChatConnectionWillConnectNotification object:connection];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidConnectNotification object:connection];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidDisconnectNotification object:connection];
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
		[(JVSplitView *)[[send enclosingScrollView] superview] setDividerStyle:NSSplitViewDividerStylePaneSplitter];
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
}

- (NSString *) description {
	return [NSString stringWithFormat:@"%@: %@", NSStringFromClass( [self class] ), [[self connection] server]];
}

#pragma mark -

- (IBAction) clearConsole:(nullable id) sender {
	[display setString:@""];
}

- (IBAction) toggleVerbose:(nullable id) sender {
	_verbose = ! _verbose;
}

- (IBAction) toggleMessages:(nullable id) sender {
	_ignorePRIVMSG = ! _ignorePRIVMSG;
}

- (IBAction) close:(nullable id) sender {
	[[JVChatController defaultController] disposeViewController:self];
}

#pragma mark -

- (nullable JVChatWindowController *) windowController {
	return _windowController;
}

- (void) setWindowController:(nullable JVChatWindowController *) controller {
	_windowController = controller;
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVChatConsole" owner:self topLevelObjects:NULL];
	return contents;
}

- (nullable NSResponder *) firstResponder {
	return send;
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

- (nullable NSString *) information {
	if( ! [[self connection] isConnected] && [[self connection] status] != MVChatConnectionConnectingStatus )
		return NSLocalizedString( @"disconnected", "disconnected status info line in drawer" );
	return nil;
}

- (NSString *) toolTip {
	if( ! [[self connection] lag] ) return [self title];
	return [NSString stringWithFormat:NSLocalizedString( @"%@\n%.3f seconds lag", "console tooltip witg lag (server delay) info in seconds" ), [self title], [[self connection] lag] / 1000.];
}

#pragma mark -

- (nullable id <JVChatListItem>) parent {
	return nil;
}

- (nullable NSArray *) children {
	return nil;
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""];
	[item setTarget:_windowController];
	[menu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Display", "clear console contextual menu item title" ) action:@selector( clearConsole: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	if( [[[self windowController] allChatViewControllers] count] > 1 ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""];
		[item setRepresentedObject:self];
		[item setTarget:[JVChatController defaultController]];
		[menu addItem:item];
	}

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	return menu;
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"console"];
}

#pragma mark -

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Console %@", [[self connection] server]];
}

- (nullable MVChatConnection *) connection {
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
	id strMsg = [message mutableCopy];
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *para = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSUInteger numeric = 0;

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
			NSMutableArray *parts = [[strMsg componentsSeparatedByString:@" "] mutableCopy];
			NSString *tempStr = nil;
			NSUInteger i = 0, c = 0;

			if( [parts count] >= 3 && [parts[2] isEqualToString:[[self connection] nickname]] )
				[parts removeObjectAtIndex:2];

			if( [parts count] >= 2 && ( numeric = [parts[1] intValue] ) )
				[parts removeObjectAtIndex:1];
			else if( [parts count] >= 2 && ( [parts[1] isEqualToString:@"PRIVMSG"] && [strMsg rangeOfString:@"\001"].location != NSNotFound && [strMsg rangeOfString:@" ACTION"].location == NSNotFound ) )
				parts[1] = @"CTCP REQUEST";
			else if( [parts count] >= 2 && ( [parts[1] isEqualToString:@"NOTICE"] && [strMsg rangeOfString:@"\001"].location != NSNotFound ) )
				parts[1] = @"CTCP REPLY";

			tempStr = parts[0];
			if( tempStr && [tempStr rangeOfString:@"@"].location == NSNotFound && [tempStr rangeOfString:@"."].location != NSNotFound && [NSURL URLWithString:[@"irc://" stringByAppendingString:tempStr]] ) {
				[parts removeObjectAtIndex:0];
			} else if( [tempStr hasPrefix:[NSString stringWithFormat:@"%@!", [[self connection] nickname]]] ) {
				[parts removeObjectAtIndex:0];
			}

			for( i = 0, c = [parts count]; i < c; i++ ) {
				tempStr = [@"irc://" stringByAppendingString:parts[i]];
				if( ( tempStr = [[NSURL URLWithString:tempStr] user] ) && [tempStr rangeOfString:@"!"].location != NSNotFound )
					parts[i] = [tempStr substringToIndex:[tempStr rangeOfString:@"!"].location];
			}

			strMsg = (NSMutableString *) [parts componentsJoinedByString:@" "];
			if( numeric ) strMsg = [NSString stringWithFormat:@"%03ld: %@", numeric, strMsg];
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

	if( outbound ) attrs[NSFontAttributeName] = [NSFont boldSystemFontOfSize:11.];
	else attrs[NSFontAttributeName] = [[NSFontManager sharedFontManager] fontWithFamily:@"Monaco" traits:0 weight:5 size:9.];
	attrs[NSParagraphStyleAttributeName] = para;

	NSScrollView *scrollView = [display enclosingScrollView];
	NSScroller *scroller = [scrollView verticalScroller];
	if( ! [scrollView hasVerticalScroller] || [scroller floatValue] >= 0.995 ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;

	msg = [[NSAttributedString alloc] initWithString:strMsg attributes:attrs];
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

- (void) layoutManager:(NSLayoutManager *) layoutManager didCompleteLayoutForTextContainer:(nullable NSTextContainer *) textContainer atEnd:(BOOL) atEnd {
	NSUInteger length = [[display string] length];
	if( _scrollerIsAtBottom && atEnd && length != _lastDisplayTextLength )
		[self performScrollToBottom];
	_lastDisplayTextLength = length;
}

#pragma mark -

- (void) send:(nullable id) sender {
	NSMutableAttributedString *subMsg = nil;
	NSRange range;

	if( [[self connection] status] != MVChatConnectionConnectingStatus && [[self connection] status] != MVChatConnectionConnectedStatus )
		return;

	[self resume];

	_historyIndex = 0;
	if( ! [[send string] length] ) return;
	if( [_sendHistory count] )
		_sendHistory[0] = [[NSAttributedString alloc] initWithString:@""];
	[_sendHistory insertObject:[[send textStorage] copy] atIndex:1];
	if( [_sendHistory count] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatMaximumHistory"] unsignedIntValue] )
		[_sendHistory removeObjectAtIndex:[_sendHistory count] - 1];

	while( [[send string] length] ) {
		range = [[[send textStorage] string] rangeOfString:@"\n"];
		if( ! range.length ) range.location = [[send string] length];
		subMsg = [[[send textStorage] attributedSubstringFromRange:NSMakeRange( 0, range.location )] mutableCopy];

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
				MVAddUnsafeUnretainedAddress(command, 2)
				MVAddUnsafeUnretainedAddress(arguments, 3)
				MVAddUnsafeUnretainedAddress(_connection, 4)
				MVAddUnsafeUnretainedAddress(self, 5)

				NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];

				if( ! [[results lastObject] boolValue] )
					[[self connection] sendCommand:command withArguments:arguments];
			} else {
				[[self connection] sendCommand:[subMsg string] withArguments:nil];
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
		_sendHistory[0] = [[send textStorage] copy];

	_historyIndex++;

	if( _historyIndex >= (NSInteger) [_sendHistory count] ) {
		if( [_sendHistory count] >= 1 )
			_historyIndex = [_sendHistory count] - 1;
		else _historyIndex = 0;
		return YES;
	}

	[send reset:nil];
	[[send textStorage] insertAttributedString:_sendHistory[_historyIndex] atIndex:0];

	return YES;
}

- (BOOL) downArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		_sendHistory[0] = [[send textStorage] copy];
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
	[[send textStorage] insertAttributedString:_sendHistory[_historyIndex] atIndex:0];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event {
	unichar chr = 0;

	if( [[event charactersIgnoringModifiers] length] ) {
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];
	} else return NO;

	// exclude device-dependent flags, caps-lock and fn key (necessary for pg up/pg dn/home/end on portables)
	if( [event modifierFlags] & ~( NSFunctionKeyMask | NSNumericPadKeyMask | NSAlphaShiftKeyMask | NSAlternateKeyMask | 0xffff ) ) return NO;

	BOOL usesOnlyArrows = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendHistoryUsesOnlyArrows"];

	if( chr == NSUpArrowFunctionKey && ( usesOnlyArrows || [event modifierFlags] & NSAlternateKeyMask ) ) {
		return [self upArrowKeyPressed];
	} else if( chr == NSDownArrowFunctionKey && ( usesOnlyArrows || [event modifierFlags] & NSAlternateKeyMask ) ) {
		return [self downArrowKeyPressed];
	}

	return NO;
}

- (nullable NSArray *) textView:(NSTextView *) textView stringCompletionsForPrefix:(NSString *) prefix {
	return nil;
}

- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event {
	[send reset:nil];
	return YES;
}

- (void) textDidChange:(nullable NSNotification *) notification {
	_historyIndex = 0;

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return;

	// We need to resize the textview to fit the content.
	// The scroll views are two superviews up: NSTextView -> NSClipView -> NSScrollView
	NSSplitView *splitView = (NSSplitView *)[[send enclosingScrollView] superview];
	NSRect splitViewFrame = [splitView frame];
	NSSize contentSize = [send minimumSizeForContent];
	NSRect sendFrame = [[send enclosingScrollView] frame];
	CGFloat dividerThickness = [splitView dividerThickness];
	CGFloat maxContentHeight = ( NSHeight( splitViewFrame ) - dividerThickness - 75. );
	CGFloat newContentHeight =  MIN( maxContentHeight, MAX( 22., contentSize.height + 8. ) );

	if( newContentHeight == NSHeight( sendFrame ) ) return;

	NSRect displayFrame = [[display enclosingScrollView] frame];

	// Set size of the web view to the maximum size possible
	displayFrame.size.height = NSHeight( splitViewFrame ) - dividerThickness - newContentHeight;
	displayFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = newContentHeight;
	sendFrame.origin.y = NSHeight( displayFrame ) + dividerThickness;

	NSScrollView *scrollView = [display enclosingScrollView];
	NSScroller *scroller = [scrollView verticalScroller];
	if( ! [scrollView hasVerticalScroller] || [scroller floatValue] >= 0.995 ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;

	// Commit the changes
	[[send enclosingScrollView] setFrame:sendFrame];
	[[display enclosingScrollView] setFrame:displayFrame];

	[splitView adjustSubviews];

	if( _scrollerIsAtBottom )
		[self performScrollToBottom];
}

#pragma mark -
#pragma mark Scripting Support

- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedLong:(intptr_t)self];
}

- (NSWindow *) window {
	return [[self windowController] window];
}

- (nullable id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The panel id %@ doesn't have the \"%@\" property.", [self uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(nullable id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of panel id %@ is read only.", key, [self uniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}

#pragma mark -
#pragma mark Toolbar Support

- (NSString *) toolbarIdentifier {
	return @"Console";
}

- (nullable NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	if( [identifier isEqual:JVToolbarClearItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Clear", "clear console toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Clear Console", "clear console toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Clear Console", "clear console tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"clear"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( clearConsole: )];

		return toolbarItem;
	} else if( [identifier isEqual:JVToolbarToggleVerboseItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Verbose", "verbose toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Toggle Verbose", "toggle verbose toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Verbose Output", "toggle verbose output tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"reveal"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( toggleVerbose: )];

		return toolbarItem;
	} else if( [identifier isEqual:JVToolbarTogglePrivateMessagesItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Messages", "toggle private messages toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Toggle Messages", "toggle private messages toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Private Messages Output", "toggle private messages output tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"roomIcon"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( toggleMessages: )];

		return toolbarItem;
	}

	return nil;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	return @[JVToolbarClearItemIdentifier];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return @[JVToolbarToggleVerboseItemIdentifier, JVToolbarTogglePrivateMessagesItemIdentifier, JVToolbarClearItemIdentifier];
}

#pragma mark -
#pragma mark SplitView Support

- (CGFloat) splitView:(NSSplitView *) splitView constrainSplitPosition:(CGFloat) proposedPosition ofSubviewAt:(NSInteger) index {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return ( NSHeight( [[splitView subviews][index] frame] ) ); // prevents manual resize
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
	CGFloat dividerThickness = [sender dividerThickness];
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

@implementation JVChatConsolePanel (Private)
- (void) _gotImportantMessage:(NSNotification *) notification {
	if( _paused ) return;
	[self addMessageToDisplay:[notification userInfo][@"message"] asOutboundMessage:NO];
}

- (void) _gotInformationalMessage:(NSNotification *) notification {
	if( _paused ) return;
	[self addMessageToDisplay:[notification userInfo][@"message"] asOutboundMessage:NO];
}

- (void) _gotRawMessage:(NSNotification *) notification {
	if( _paused ) return;
	[self addMessageToDisplay:[notification userInfo][@"message"] asOutboundMessage:[[notification userInfo][@"outbound"] boolValue]];
}

- (void) _refreshIcon:(NSNotification *) notification {
	[_windowController reloadListItem:self andChildren:NO];
}
@end

NS_ASSUME_NONNULL_END
