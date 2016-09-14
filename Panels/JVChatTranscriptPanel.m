#import "JVChatTranscriptPanel.h"

#import "JVTranscriptFindWindowController.h"
#import "MVApplicationController.h"
#import "JVChatController.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "JVStyleView.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVMenuButton.h"
#import "CQMPreferencesWindowController.h"
#import "JVAppearancePreferencesViewController.h"
#import "JVMarkedScroller.h"
#import "NSBundleAdditions.h"
#import <ChatCore/NSDateAdditions.h>

NS_ASSUME_NONNULL_BEGIN

NSString *JVToolbarChooseStyleItemIdentifier = @"JVToolbarChooseStyleItem";
NSString *JVToolbarEmoticonsItemIdentifier = @"JVToolbarEmoticonsItem";
NSString *JVToolbarFindItemIdentifier = @"JVToolbarFindItem";
NSString *JVToolbarQuickSearchItemIdentifier = @"JVToolbarQuickSearchItem";

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

@interface JVChatTranscriptPanel ()
- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(nullable void *) contextInfo;
@end

#pragma mark -

@implementation JVChatTranscriptPanel
@synthesize transcript = _transcript;
@synthesize searchQuery = _searchQuery;
@synthesize windowController = _windowController;

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_transcript = [[JVChatTranscript alloc] init];

		id classDescription = [NSClassDescription classDescriptionForClass:[JVChatTranscriptPanel class]];
		id specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:[self objectSpecifier] key:@"transcript"];
		[_transcript setObjectSpecifier:specifier];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _updateStylesMenu ) name:JVStylesScannedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _updateStylesMenu ) name:JVNewStyleVariantAddedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _updateEmoticonsMenu ) name:JVEmoticonSetsScannedNotification object:nil];
	}

	return self;
}

- (nullable instancetype) initWithTranscript:(NSString *) filename {
	if( ( self = [self init] ) ) {
		if( ! [[NSFileManager defaultManager] isReadableFileAtPath:filename] ) {
			return nil;
		}

		_transcript = [[JVChatTranscript alloc] initWithContentsOfFile:filename];

		if( ! _transcript ) {
			return nil;
		}

		id classDescription = [NSClassDescription classDescriptionForClass:[JVChatTranscriptPanel class]];
		id specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:[self objectSpecifier] key:@"transcript"];
		[_transcript setObjectSpecifier:specifier];

		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filename]];
	}

	return self;
}

- (void) awakeFromNib {
	[display setTranscript:[self transcript]];
	[display setScrollbackLimit:1000];
	[display setBodyTemplate:@"transcript"];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didSwitchStyles: ) name:JVStyleViewDidChangeStylesNotification object:display];

	if( ! [self style] ) {
		JVStyle *style = [JVStyle defaultStyle];
		NSString *variant = [style defaultVariantName];
		[self setStyle:style withVariant:variant];
	}

	[self _updateStylesMenu];
	[self _updateEmoticonsMenu];
}

- (void) dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter chatCenter] removeObserver:self];

	[display setUIDelegate:nil];
	[display setResourceLoadDelegate:nil];
	[display setDownloadDelegate:nil];
	[display setFrameLoadDelegate:nil];
	[display setPolicyDelegate:nil];
}

- (NSString *) description {
	return [self identifier];
}

#pragma mark -
#pragma mark Window Controller and Proxy Icon Support

- (void) setWindowController:(nullable JVChatWindowController *) controller {
	if( [[[_windowController window] representedFilename] isEqualToString:[[self transcript] filePath]] )
		[[_windowController window] setRepresentedFilename:@""];

	_windowController = controller;
	[display setHostWindow:[_windowController window]];
}

- (void) didUnselect {
	if( [[[JVTranscriptFindWindowController sharedController] window] isVisible] )
		[display clearAllMessageHighlights];
	[[_windowController window] setRepresentedFilename:@""];
}

- (void) didSelect {
	[self _refreshWindowFileProxy];
}

- (void) willDispose {
	_disposed = YES;
}

#pragma mark -
#pragma mark Miscellaneous Window Info

- (NSString *) title {
	return [[NSFileManager defaultManager] displayNameAtPath:[[self transcript] filePath]];
}

- (NSString *) windowTitle {
	NSCalendarDate *date = [[self transcript] dateBegan];
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - %@ Transcript", "chat transcript/log - window title" ), [self title], ( date ? [NSDate formattedShortDateStringForDate:[NSDate date]] : @"" )];
}

- (nullable NSString *) information {
	return [NSDate formattedShortDateStringForDate:[NSDate date]];
}

- (NSString *) toolTip {
	return [NSString stringWithFormat:@"%@\n%@", [self title], [self information]];
}

- (IBAction) close:(nullable id) sender {
	[[JVChatController defaultController] disposeViewController:self];
}

- (IBAction) activate:(nullable id) sender {
	[[self windowController] showChatViewController:self];
	[[[self windowController] window] makeKeyAndOrderFront:nil];
}

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Transcript %@", [self title]];
}

- (nullable MVChatConnection *) connection {
	return nil;
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVChatTranscript" owner:self topLevelObjects:NULL];
	return contents;
}

- (nullable NSResponder *) firstResponder {
	return display;
}

#pragma mark -
#pragma mark Drawer/Outline View Methods

- (nullable id <JVChatListItem>) parent {
	return nil;
}

- (nullable NSArray *) children {
	return nil;
}

- (NSMenu *) menu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

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
	NSImage *ret = [NSImage imageNamed:@"Generic"];
	[ret setSize:NSMakeSize( 32., 32. )];
	return ret;
}

#pragma mark -
#pragma mark Search Support

- (IBAction) performQuickSearch:(nullable id) sender {
	if( [sender isKindOfClass:[NSTextField class]] ) {
		if( [[sender stringValue] length] >= 3 ) [self setSearchQuery:[sender stringValue]];
		else [self setSearchQuery:nil];
	} else {
		// this is for text mode users, and is what Apple does in Tiger's Mail
		if( [[[self window] toolbar] displayMode] == NSToolbarDisplayModeLabelOnly )
			[[[self window] toolbar] setDisplayMode:NSToolbarDisplayModeIconOnly];
	}
}

- (void) quickSearchMatchMessage:(nullable JVChatMessage *) message {
	if( ! message || ! _searchQueryRegex ) return;
	NSString *bodyAsPlainText = [message bodyAsPlainText];
	NSColor *markColor = [NSColor orangeColor];
	NSArray *matches = [_searchQueryRegex matchesInString:bodyAsPlainText options:0 range:NSMakeRange( 0, bodyAsPlainText.length )];
	for (NSTextCheckingResult *match in matches) {
		[display markScrollbarForMessage:message usingMarkIdentifier:@"quick find" andColor:markColor];
		[display highlightString:[bodyAsPlainText substringWithRange:match.range] inMessage:message];
	}
}

- (void) setSearchQuery:(nullable NSString *) query {
	if( query == _searchQuery || [query isEqualToString:_searchQuery] ) return;

	_searchQueryRegex = nil;
	_searchQuery = ( [query length] ? [query copy] : nil );

	if( [_searchQuery length] ) {
		// we simply convert this to a regex and not allow patterns. later we will allow user supplied patterns
		NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
		NSString *pattern = [_searchQuery stringByEscapingCharactersInSet:escapeSet];
		_searchQueryRegex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
	}

	[self _refreshSearch];
}

- (nullable NSString *) searchQuery {
	return _searchQuery;
}

#pragma mark -
#pragma mark Web Search Support

- (void) searchWeb:(id) sender {
	NSString *searchEngineFormatter = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVSearchEngineFormatter"];
	if( [searchEngineFormatter rangeOfString:@"%@"].location == NSNotFound )
		searchEngineFormatter = @"http://google.com/search?q=%@";

	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:searchEngineFormatter, [display.selectedDOMRange.text stringByEncodingIllegalURLCharacters]]]];
}

#pragma mark -
#pragma mark Scripting Support

- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedLong:(intptr_t)self];
}

- (BOOL) isEnabled {
	return YES;
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
#pragma mark File Saving

- (IBAction) saveDocumentTo:(id) sender {
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setAllowedFileTypes:@[@"colloquyTranscript"]];
	[savePanel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES]];
	[savePanel setNameFieldStringValue:[self title]];
	[savePanel beginWithCompletionHandler:^(NSInteger result) {
		[self savePanelDidEnd:savePanel returnCode:result contextInfo:NULL];
	}];
}

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(nullable void *) contextInfo {
	if( returnCode == NSOKButton ) {
		NSURL *sheetURL = [sheet URL];
		[[self transcript] writeToURL:sheetURL atomically:YES];
		[sheetURL setResourceValue:@([sheet isExtensionHidden]) forKey:NSFileExtensionHidden error:NULL];
		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:sheetURL];
	}
}

- (void) downloadLinkToDisk:(id) sender {
	NSURL *url = [sender representedObject][@"WebElementLinkURL"];
	[[MVFileTransferController defaultController] downloadFileAtURL:url toLocalFile:nil];
}

#pragma mark -
#pragma mark Styles

- (IBAction) changeStyle:(nullable id) sender {
	JVStyle *style = [sender representedObject];
	if( ! style ) style = [JVStyle defaultStyle];
	[self setStyle:style withVariant:[style defaultVariantName]];
}

- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant {
	if( ! [self _usingSpecificEmoticons] )
		[self setEmoticons:[style defaultEmoticonSet]];
	[display setStyle:style withVariant:variant];
	[self _changeStyleMenuSelection];
}

- (JVStyle *) style {
	return [display style];
}

#pragma mark -

- (IBAction) changeStyleVariant:(nullable id) sender {
	JVStyle *style = [sender representedObject][@"style"];
	NSString *variant = [sender representedObject][@"variant"];
	[self setStyle:style withVariant:variant];
}

- (void) setStyleVariant:(NSString *) variant {
	[display setStyleVariant:variant];
	[self _changeStyleMenuSelection];
}

- (NSString *) styleVariant {
	return [display styleVariant];
}

#pragma mark -
#pragma mark Emoticons

- (IBAction) changeEmoticons:(nullable id) sender {
	JVEmoticonSet *emoticons = [sender representedObject];
	[self setEmoticons:emoticons];
}

- (void) setEmoticons:(JVEmoticonSet *) emoticons {
	if( ! emoticons ) emoticons = [[self style] defaultEmoticonSet];
	[display setEmoticons:emoticons];
	[self _updateEmoticonsMenu];
}

- (JVEmoticonSet *) emoticons {
	return [display emoticons];
}

#pragma mark -
#pragma mark Find Support

- (IBAction) orderFrontFindPanel:(id) sender {
	[[JVTranscriptFindWindowController sharedController] showWindow:sender];
}

- (IBAction) findNext:(id) sender {
	[[JVTranscriptFindWindowController sharedController] findNext:sender];
}

- (IBAction) findPrevious:(id) sender {
	[[JVTranscriptFindWindowController sharedController] findPrevious:sender];
}

#pragma mark -
#pragma mark Toolbar Methods

- (NSString *) toolbarIdentifier {
	return @"Chat Transcript";
}

- (nullable NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	if( [identifier isEqualToString:JVToolbarFindItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
		[toolbarItem setLabel:NSLocalizedString( @"Find", "find toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Find", "find toolbar item patlette label" )];
		[toolbarItem setToolTip:NSLocalizedString( @"Show Find Panel", "find toolbar item tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"reveal"]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( orderFrontFindPanel: )];
		return toolbarItem;
	} else if( [identifier isEqualToString:JVToolbarQuickSearchItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Search", "search toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Search", "search patlette label" )];

		NSSearchField *field = [[NSSearchField alloc] initWithFrame:NSMakeRect( 0., 0., 150., 22. )];
		[[field cell] setSendsWholeSearchString:NO];
		[[field cell] setSendsSearchStringImmediately:NO];
		[[field cell] setPlaceholderString:NSLocalizedString( @"Search Messages", "search field placeholder string" )];
		[[field cell] setMaximumRecents:10];
		[field setRecentsAutosaveName:@"message quick search"];
		[field setStringValue:( [self searchQuery] ? [self searchQuery] : @"" )];
		[field setAction:@selector( performQuickSearch: )];
		[field setTarget:self];

		[toolbarItem setView:field];
		[toolbarItem setMinSize:NSMakeSize( 100., 22. )];
		[toolbarItem setMaxSize:NSMakeSize( 150., 22. )];

		[toolbarItem setToolTip:NSLocalizedString( @"Search messages", "search toolbar item tooltip" )];
		[toolbarItem setTarget:self];

		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Search", "search toolbar item menu representation title" ) action:@selector( performQuickSearch: ) keyEquivalent:@""];
		[toolbarItem setMenuFormRepresentation:menuItem];

		return toolbarItem;
	} else if( [identifier isEqualToString:JVToolbarChooseStyleItemIdentifier] && ! willBeInserted ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];
		[toolbarItem setImage:[NSImage imageNamed:@"chooseStyle"]];
		return toolbarItem;
	} else if( [identifier isEqualToString:JVToolbarChooseStyleItemIdentifier] && willBeInserted ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];

		MVMenuButton *button = [[MVMenuButton alloc] initWithFrame:NSMakeRect( 0., 0., 32., 32. )];
		[button setImage:[NSImage imageNamed:@"chooseStyle"]];
		[button setDrawsArrow:YES];
		[button setMenu:_styleMenu];
		[button setRetina:(self.window.backingScaleFactor > 1.0)];

		[toolbarItem setToolTip:NSLocalizedString( @"Change chat style", "choose style toolbar item tooltip" )];
		[button setToolbarItem:toolbarItem];
		[toolbarItem setTarget:self];
		[toolbarItem setView:button];

		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar item menu representation title" ) action:NULL keyEquivalent:@""];
		NSImage *icon = [[NSImage imageNamed:@"chooseStyle"] copy];
		[icon setSize:NSMakeSize( 16., 16. )];
		[menuItem setImage:icon];
		[menuItem setSubmenu:_styleMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];

		return toolbarItem;
	} else if( [identifier isEqualToString:JVToolbarEmoticonsItemIdentifier]) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
		[toolbarItem setLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item patlette label" )];

		NSImage *image = [NSImage imageNamed:@"emoticon"];

		if ( willBeInserted ) {
			MVMenuButton *button = [[MVMenuButton alloc] initWithFrame:NSMakeRect( 0., 0., 32., 32. )];
			[button setRetina:(self.window.backingScaleFactor > 1.0)];
			[button setImage:image];
			[button setDrawsArrow:YES];
			[button setMenu:_emoticonMenu];

			[toolbarItem setToolTip:NSLocalizedString( @"Change Emoticons", "choose emoticons toolbar item tooltip" )];
			[button setToolbarItem:toolbarItem];
			[toolbarItem setTarget:self];
			[toolbarItem setView:button];

			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item menu representation title" ) action:NULL keyEquivalent:@""];
			NSImage *icon = [image copy];
			[icon setSize:NSMakeSize( 16., 16. )];
			[menuItem setImage:icon];
			[menuItem setSubmenu:_emoticonMenu];

			[toolbarItem setMenuFormRepresentation:menuItem];
		} else {
			[toolbarItem setImage:image];
		}

		return toolbarItem;
	}

	return nil;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	return @[JVToolbarChooseStyleItemIdentifier, JVToolbarEmoticonsItemIdentifier];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return @[JVToolbarChooseStyleItemIdentifier, JVToolbarEmoticonsItemIdentifier, JVToolbarFindItemIdentifier, JVToolbarQuickSearchItemIdentifier];
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqualToString:NSToolbarShowColorsItemIdentifier] ) return NO;
	else if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqualToString:NSToolbarShowColorsItemIdentifier] ) return YES;
	return YES;
}

#pragma mark -
#pragma mark Highlight/Message Jumping

- (IBAction) jumpToMark:(id) sender {
	[display jumpToMark:sender];
}

- (IBAction) jumpToPreviousHighlight:(id) sender {
	[display jumpToPreviousHighlight:sender];
}

- (IBAction) jumpToNextHighlight:(id) sender {
	[display jumpToNextHighlight:sender];
}

- (void) jumpToMessage:(JVChatMessage *) message {
	[display jumpToMessage:message];
}

#pragma mark -
#pragma mark WebView

- (JVStyleView *) display {
	return display;
}

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	NSMutableArray *ret = [defaultMenuItems mutableCopy];
	NSMenuItem *item = nil;
	NSUInteger i = 0;
	BOOL found = NO;

	for( i = 0; i < [ret count]; i++ ) {
		item = ret[i];

		switch( [item tag] ) {
		case WebMenuItemTagOpenLinkInNewWindow:
		case WebMenuItemTagOpenImageInNewWindow:
		case WebMenuItemTagOpenFrameInNewWindow:
		case WebMenuItemTagGoBack:
		case WebMenuItemTagGoForward:
		case WebMenuItemTagStop:
		case WebMenuItemTagReload:
			[ret removeObjectAtIndex:i];
			i--;
			break;
		case WebMenuItemTagCopy:
			found = YES;
			break;
		case WebMenuItemTagDownloadLinkToDisk:
		case WebMenuItemTagDownloadImageToDisk:
			[item setTarget:[sender UIDelegate]];
			found = YES;
			break;
		case WebMenuItemTagSearchWeb:
			[item setTarget:self];
			[item setAction:@selector(searchWeb:)];
			[item setTitle:NSLocalizedString(@"Search the Web", @"Search the Web")];
			break;
		}
	}

	if( ! found && ! [ret count] && ! [element[WebElementIsSelectedKey] boolValue] ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style", "choose style contextual menu" ) action:NULL keyEquivalent:@""];
		[item setSubmenu:_styleMenu];
		[ret addObject:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons contextual menu" ) action:NULL keyEquivalent:@""];
		NSMenu *menu = [[self _emoticonsMenu] copy];
		[item setSubmenu:menu];
		[ret addObject:item];
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	id object = [element[WebElementImageURLKey] description];
	if( ! object ) object = [element[WebElementLinkURLKey] description];
	if( ! object ) {
		WebFrame *frame = element[WebElementFrameKey];
		object = [(id <WebDocumentText>)[[frame frameView] documentView] selectedString];
	}

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	MVAddUnsafeUnretainedAddress(object, 2);
	MVAddUnsafeUnretainedAddress(self, 3);

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	if( [results count] ) {
		if( [ret count] ) [ret addObject:[NSMenuItem separatorItem]];

		for( NSArray *items in results ) {
			if( ![items conformsToProtocol:@protocol(NSFastEnumeration)] ) continue;

			for( item in items ) {
				if( [item isKindOfClass:[NSMenuItem class]] ) [ret addObject:item];
			}
		}

		if( [[ret lastObject] isSeparatorItem] )
			[ret removeObjectIdenticalTo:[ret lastObject]];
	}

	return ret;
}

- (NSUInteger) webView:(WebView *) webView dragSourceActionMaskForPoint:(NSPoint) point {
	return UINT_MAX; // WebDragSourceActionAny
}

- (void) webView:(WebView *) sender runJavaScriptAlertPanelWithMessage:(NSString *) message initiatedByFrame:(WebFrame *) frame {
    NSRange range = [message rangeOfString:@"\t"];
    NSString *title = @"Alert";
    if( range.location != NSNotFound ) {
        title = [message substringToIndex:range.location];
        message = [message substringFromIndex:( range.location + range.length )];
    }

    NSBeginInformationalAlertSheet( title, nil, nil, nil, [sender window], nil, NULL, NULL, NULL, message, nil );
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	NSURL *url = actionInformation[WebActionOriginalURLKey];

	if( [[url scheme] isEqualToString:@"about"] ) {
		if( [[[url standardizedURL] path] length] ) [listener ignore];
		else [listener use];
	} else if( [url isFileURL] && [[url path] hasPrefix:[[NSBundle mainBundle] resourcePath]] ) {
		[listener use];
	} else if( [[url scheme] isEqualToString:@"self"] ) {
		NSString *resource = [url resourceSpecifier];
		NSRange range = [resource rangeOfString:@"?"];
		NSString *command = [resource substringToIndex:( range.location != NSNotFound ? range.location : [resource length] )];

		if( [self respondsToSelector:NSSelectorFromString( [command stringByAppendingString:@":"] )] ) {
			NSString *arg = [resource substringFromIndex:( range.location != NSNotFound ? range.location : 0 )];
			[self performSelector:NSSelectorFromString( [command stringByAppendingString:@":"] ) withObject:( range.location != NSNotFound ? arg : nil )];
		}

		[listener ignore];
	} else {
		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSURL * ), @encode( id ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

		[invocation setSelector:@selector( handleClickedLink:inView: )];
		MVAddUnsafeUnretainedAddress(url, 2);
		MVAddUnsafeUnretainedAddress(self, 3);

		NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];

		if( ! [[results lastObject] boolValue] ) {
			if( [MVChatConnection supportsURLScheme:[url scheme]] ) {
				[[MVConnectionsController defaultController] handleURL:url andConnectIfPossible:YES];
			} else if( [actionInformation[WebActionModifierFlagsKey] unsignedIntValue] & NSAlternateKeyMask ) {
				[[MVFileTransferController defaultController] downloadFileAtURL:url toLocalFile:nil];
			} else {
				NSWorkspaceLaunchOptions options = ( [actionInformation[WebActionModifierFlagsKey] unsignedIntValue] & NSCommandKeyMask ? NSWorkspaceLaunchWithoutActivation : 0 );
				[[NSWorkspace sharedWorkspace] openURLs:@[url] withAppBundleIdentifier:nil options:options additionalEventParamDescriptor:nil launchIdentifiers:nil];
			}
		}

		[listener ignore];
	}
}

- (WebView *) webView:(WebView *) sender createWebViewWithRequest:(NSURLRequest *) request {
	NSRect frame = NSMakeRect( NSMinX( [[sender window] frame] ) + 15., NSMaxY( [[sender window] frame] ) - 190., 150., 150. );

	WebView *newWebView = [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
	[newWebView setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
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

	return newWebView;
}

- (void) webViewShow:(WebView *) sender {
	[[sender window] makeKeyAndOrderFront:sender];
}

- (void) webView:(WebView *) sender setResizable:(BOOL) resizable {
	[[sender window] setShowsResizeIndicator:resizable];
	[[[sender window] standardWindowButton:NSWindowZoomButton] setEnabled:resizable];
}
@end

#pragma mark -

@implementation JVChatTranscriptPanel (Private)
#pragma mark Style Support
- (void) _refreshWindowFileProxy {
	if(	[[self windowController] activeChatViewController] != self ) return;
	if( ! [[NSFileManager defaultManager] fileExistsAtPath:[[self transcript] filePath]] ) {
		[[_windowController window] setRepresentedFilename:@""];
	} else {
		[[_windowController window] setRepresentedFilename:[[self transcript] filePath]];
	}
}

- (void) _refreshSearch {
	[display clearScrollbarMarksWithIdentifier:@"quick find"];
	[display clearAllStringHighlights];

	if( ! [_searchQuery length] ) return;

	for( JVChatMessage *message in [[self transcript] messages] )
		[self quickSearchMatchMessage:message];
}

- (void) _didSwitchStyles:(NSNotification *) notification {
	[self _refreshSearch];
}

#pragma mark -

- (void) _reloadCurrentStyle:(nullable id) sender {
	[display reloadCurrentStyle];
}

- (NSMenu *) _stylesMenu {
	return _styleMenu;
}

- (void) _changeStyleMenuSelection {
	BOOL hasPerRoomStyle = [self _usingSpecificStyle];

	for( NSMenuItem *menuItem in [_styleMenu itemArray] ) {
		if( [menuItem tag] != 5 ) continue;

		if( [[self style] isEqualTo:[menuItem representedObject]] && hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( ! [menuItem representedObject] && ! hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( [[self style] isEqualTo:[menuItem representedObject]] && ! hasPerRoomStyle ) [menuItem setState:NSMixedState];
		else [menuItem setState:NSOffState];

		for( NSMenuItem *subMenuItem in [[menuItem submenu] itemArray] ) {
			JVStyle *style = [subMenuItem representedObject][@"style"];
			NSString *variant = [subMenuItem representedObject][@"variant"];
			if( [subMenuItem action] == @selector( changeStyleVariant: ) && [[self style] isEqualTo:style] && ( [[self styleVariant] isEqualToString:variant] || ( ! [self styleVariant] && ! variant ) ) )
				[subMenuItem setState:NSOnState];
			else [subMenuItem setState:NSOffState];
		}
	}
}

- (void) _updateStylesMenu {
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;

	if( ! ( menu = _styleMenu ) ) {
		menu = [[NSMenu alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar menu title" )];
		_styleMenu = menu;
	} else {
		for( menuItem in [[menu itemArray] copy] )
			if( [menuItem tag] || [menuItem isSeparatorItem] )
				[menu removeItem:menuItem];
	}

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Default", "default style menu item title" ) action:@selector( changeStyle: ) keyEquivalent:@""];
	[menuItem setTag:5];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:nil];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	for( JVStyle *style in [[[JVStyle styles] allObjects] sortedArrayUsingSelector:@selector( compare: )] ) {
		if( !style.displayName.length ) continue;

		menuItem = [[NSMenuItem alloc] initWithTitle:[style displayName] action:@selector( changeStyle: ) keyEquivalent:@""];
		[menuItem setTag:5];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:style];
		[menu addItem:menuItem];

		NSArray *variants = [style variantStyleSheetNames];
		NSArray *userVariants = [style userVariantStyleSheetNames];

		if( [variants count] || [userVariants count] ) {
			subMenu = [[NSMenu alloc] initWithTitle:@""];

			subMenuItem = [[NSMenuItem alloc] initWithTitle:[style mainVariantDisplayName] action:@selector( changeStyleVariant: ) keyEquivalent:@""];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:@{@"style": style}];
			[subMenu addItem:subMenuItem];

			for( id item in variants ) {
				subMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector( changeStyleVariant: ) keyEquivalent:@""];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:@{@"style": style, @"variant": item}];
				[subMenu addItem:subMenuItem];
			}

			if( [userVariants count] ) [subMenu addItem:[NSMenuItem separatorItem]];

			for( id item in userVariants ) {
				subMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector( changeStyleVariant: ) keyEquivalent:@""];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:@{@"style": style, @"variant": item}];
				[subMenu addItem:subMenuItem];
			}

			[menuItem setSubmenu:subMenu];
		}

		subMenu = nil;
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItem setTag:10];
	[menu addItem:menuItem];

	[self _changeStyleMenuSelection];
}

- (BOOL) _usingSpecificStyle {
	return NO;
}

#pragma mark -
#pragma mark Emoticons Support

- (NSMenu *) _emoticonsMenu {
	if( [_emoticonMenu itemWithTag:20] )
		return [[_emoticonMenu itemWithTag:20] submenu];
	return _emoticonMenu;
}

- (void) _changeEmoticonsMenuSelection {
	BOOL hasPerRoomEmoticons = [self _usingSpecificEmoticons];

	NSArray *array = [[[_emoticonMenu itemWithTag:20] submenu] itemArray];
	if (!array.count) array = [_emoticonMenu itemArray];

	for( NSMenuItem *menuItem in array ) {
		if( [menuItem tag] ) continue;
		if( [[self emoticons] isEqualTo:[menuItem representedObject]] && hasPerRoomEmoticons ) [menuItem setState:NSOnState];
		else if( ! [menuItem representedObject] && ! hasPerRoomEmoticons ) [menuItem setState:NSOnState];
		else if( [[self emoticons] isEqualTo:[menuItem representedObject]] && ! hasPerRoomEmoticons ) [menuItem setState:NSMixedState];
		else [menuItem setState:NSOffState];
	}
}

- (void) _updateEmoticonsMenu {
	NSMenu *menu = nil;
	NSMenuItem *menuItem = nil;

	if( ! ( menu = _emoticonMenu ) ) {
		menu = [[NSMenu alloc] initWithTitle:@""];
		_emoticonMenu = menu;
	} else {
		[menu removeAllItems];
	}

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeEmoticons: ) keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:nil];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[NSMenuItem alloc] initWithTitle:[[JVEmoticonSet textOnlyEmoticonSet] displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:[JVEmoticonSet textOnlyEmoticonSet]];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	for( JVEmoticonSet *emoticon in [[[JVEmoticonSet emoticonSets] allObjects] sortedArrayUsingSelector:@selector( compare: )] ) {
		if( ! [[emoticon displayName] length] ) continue;
		menuItem = [[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:emoticon];
		[menu addItem:menuItem];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItem setTag:10];
	[menu addItem:menuItem];

	[self _changeEmoticonsMenuSelection];
}

- (BOOL) _usingSpecificEmoticons {
	return NO;
}

#pragma mark -

- (void) _openAppearancePreferences:(nullable id) sender {
	MVApplicationController *applicationController = (MVApplicationController *)NSApp.delegate;
	[applicationController showPreferences:sender];
	CQMPreferencesWindowController *preferencesWindowController = [applicationController preferencesWindowController];
	[preferencesWindowController selectControllerWithIdentifier:preferencesWindowController.appearancePreferences.identifier];
}

@end

NS_ASSUME_NONNULL_END
