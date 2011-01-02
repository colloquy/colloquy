#import "JVChatTranscriptPanel.h"

#import "JVTranscriptFindWindowController.h"
#import "MVApplicationController.h"
#import "JVChatController.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "JVStyleView.h"
#import "JVChatTranscript.h"
//#import "JVSQLChatTranscript.h"
#import "JVChatMessage.h"
#import "MVConnectionsController.h"
#import "CQActivityWindowController.h"
#import "MVMenuButton.h"
#import "NSPreferences.h"
#import "JVAppearancePreferences.h"
#import "JVMarkedScroller.h"
#import "NSBundleAdditions.h"
#import "NSURLAdditions.h"
#import "NSDateAdditions.h"

NSString *JVToolbarChooseStyleItemIdentifier = @"JVToolbarChooseStyleItem";
NSString *JVToolbarEmoticonsItemIdentifier = @"JVToolbarEmoticonsItem";
NSString *JVToolbarFindItemIdentifier = @"JVToolbarFindItem";
NSString *JVToolbarQuickSearchItemIdentifier = @"JVToolbarQuickSearchItem";

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

@interface JVChatTranscriptPanel (JVChatTranscriptPrivate)
- (void) _refreshWindowFileProxy;
- (void) _refreshSearch;

- (void) _changeStyleMenuSelection;
- (void) _updateStylesMenu;

- (void) _changeEmoticonsMenuSelection;
- (void) _updateEmoticonsMenu;
- (NSMenu *) _emoticonsMenu;

- (BOOL) _usingSpecificStyle;
- (BOOL) _usingSpecificEmoticons;
@end

#pragma mark -

@implementation JVChatTranscriptPanel
- (id) init {
	if( ( self = [super init] ) ) {
		_transcript = [[JVChatTranscript allocWithZone:[self zone]] init];

		id classDescription = [NSClassDescription classDescriptionForClass:[JVChatTranscriptPanel class]];
		id specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:[self objectSpecifier] key:@"transcript"];
		[_transcript setObjectSpecifier:specifier];
		[specifier release];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateStylesMenu ) name:JVStylesScannedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateStylesMenu ) name:JVNewStyleVariantAddedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateEmoticonsMenu ) name:JVEmoticonSetsScannedNotification object:nil];
	}

	return self;
}

- (id) initWithTranscript:(NSString *) filename {
	if( ( self = [self init] ) ) {
		if( ! [[NSFileManager defaultManager] isReadableFileAtPath:filename] ) {
			[self release];
			return nil;
		}

//		NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filename];
//		BOOL sqliteFormat = [[NSData dataWithBytes:"SQLite format 3" length:16] isEqualToData:[handle readDataOfLength:16]];
//		[handle closeFile];

//		if( sqliteFormat ) _transcript = [[JVSQLChatTranscript allocWithZone:[self zone]] initWithContentsOfFile:filename];
		_transcript = [[JVChatTranscript allocWithZone:[self zone]] initWithContentsOfFile:filename];

		if( ! _transcript ) {
			[self release];
			return nil;
		}

		id classDescription = [NSClassDescription classDescriptionForClass:[JVChatTranscriptPanel class]];
		id specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:[self objectSpecifier] key:@"transcript"];
		[_transcript setObjectSpecifier:specifier];
		[specifier release];

		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filename]];
	}

	return self;
}

- (void) awakeFromNib {
	[display setTranscript:[self transcript]];
	[display setScrollbackLimit:1000];
	[display setBodyTemplate:@"transcript"];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didSwitchStyles: ) name:JVStyleViewDidChangeStylesNotification object:display];

	if( ! [self style] ) {
		JVStyle *style = [JVStyle defaultStyle];
		NSString *variant = [style defaultVariantName];
		[self setStyle:style withVariant:variant];
	}

	[self _updateStylesMenu];
	[self _updateEmoticonsMenu];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[display setUIDelegate:nil];
	[display setResourceLoadDelegate:nil];
	[display setDownloadDelegate:nil];
	[display setFrameLoadDelegate:nil];
	[display setPolicyDelegate:nil];

	[contents release];
	[_styleMenu release];
	[_emoticonMenu release];
	[_transcript release];
//	[_sqlTestTranscript release];
	[_searchQuery release];
	[_searchQueryRegex release];

	contents = nil;
	_styleMenu = nil;
	_emoticonMenu = nil;
	_transcript = nil;
//	_sqlTestTranscript = nil;
	_searchQuery = nil;
	_searchQueryRegex = nil;
	_windowController = nil;

	[super dealloc];
}

- (NSString *) description {
	return [self identifier];
}

#pragma mark -
#pragma mark Window Controller and Proxy Icon Support

- (JVChatWindowController *) windowController {
	return _windowController;
}

- (void) setWindowController:(JVChatWindowController *) controller {
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

- (NSString *) information {
	return [NSDate formattedShortDateStringForDate:[NSDate date]];
}

- (NSString *) toolTip {
	return [NSString stringWithFormat:@"%@\n%@", [self title], [self information]];
}

- (IBAction) close:(id) sender {
	[[JVChatController defaultController] disposeViewController:self];
}

- (IBAction) activate:(id) sender {
	[[self windowController] showChatViewController:self];
	[[[self windowController] window] makeKeyAndOrderFront:nil];
}

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Transcript %@", [self title]];
}

- (MVChatConnection *) connection {
	return nil;
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatTranscript" owner:self];
	return contents;
}

- (NSResponder *) firstResponder {
	return display;
}

#pragma mark -
#pragma mark Drawer/Outline View Methods

- (id <JVChatListItem>) parent {
	return nil;
}

- (NSArray *) children {
	return nil;
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	if( [[[self windowController] allChatViewControllers] count] > 1 ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
		[item setRepresentedObject:self];
		[item setTarget:[JVChatController defaultController]];
		[menu addItem:item];
	}

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
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

- (IBAction) performQuickSearch:(id) sender {
	if( [sender isKindOfClass:[NSTextField class]] ) {
		if( [[sender stringValue] length] >= 3 ) [self setSearchQuery:[sender stringValue]];
		else [self setSearchQuery:nil];
	} else {
		// this is for text mode users, and is what Apple does in Tiger's Mail
		if( [[[self window] toolbar] displayMode] == NSToolbarDisplayModeLabelOnly )
			[[[self window] toolbar] setDisplayMode:NSToolbarDisplayModeIconOnly];
	}
}

- (void) quickSearchMatchMessage:(JVChatMessage *) message {
	if( ! message || ! _searchQueryRegex ) return;
	NSColor *markColor = [NSColor orangeColor];
	AGRegexMatch *match = [_searchQueryRegex findInString:[message bodyAsPlainText]];
	if( match ) {
		[display markScrollbarForMessage:message usingMarkIdentifier:@"quick find" andColor:markColor];
		[display highlightString:[match group] inMessage:message];
	}
}

- (void) setSearchQuery:(NSString *) query {
	if( query == _searchQuery || [query isEqualToString:_searchQuery] ) return;

	[_searchQueryRegex autorelease];
	_searchQueryRegex = nil;

	[_searchQuery autorelease];
	_searchQuery = ( [query length] ? [query copyWithZone:[self zone]] : nil );

	if( [_searchQuery length] ) {
		// we simply convert this to a regex and not allow patterns. later we will allow user supplied patterns
		NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
		NSString *pattern = [_searchQuery stringByEscapingCharactersInSet:escapeSet];
		_searchQueryRegex = [[AGRegex allocWithZone:[self zone]] initWithPattern:pattern options:AGRegexCaseInsensitive];
	}

	[self _refreshSearch];
}

- (NSString *) searchQuery {
	return _searchQuery;
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
#pragma mark File Saving

- (IBAction) saveDocumentTo:(id) sender {
	NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
	[savePanel setDelegate:self];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:@"colloquyTranscript"];
	[savePanel beginSheetForDirectory:NSHomeDirectory() file:[self title] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( savePanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		[[self transcript] writeToFile:[sheet filename] atomically:YES];
		[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[sheet isExtensionHidden]], NSFileExtensionHidden, nil] ofItemAtPath:[sheet filename] error:nil];
		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:[sheet filename]]];
	}
}

- (void) downloadLinkToDisk:(id) sender {
	NSURL *url = [[sender representedObject] objectForKey:@"WebElementLinkURL"];
	[[CQActivityWindowController sharedController] downloadFileAtURL:url toLocalFile:nil];
}

#pragma mark -
#pragma mark Styles

- (IBAction) changeStyle:(id) sender {
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

- (IBAction) changeStyleVariant:(id) sender {
	JVStyle *style = [[sender representedObject] objectForKey:@"style"];
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
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

- (IBAction) changeEmoticons:(id) sender {
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
#pragma mark Transcript Access

- (JVChatTranscript *) transcript {
	return _transcript;
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

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	if( [identifier isEqualToString:JVToolbarFindItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
		[toolbarItem setLabel:NSLocalizedString( @"Find", "find toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Find", "find toolbar item patlette label" )];
		[toolbarItem setToolTip:NSLocalizedString( @"Show Find Panel", "find toolbar item tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"reveal"]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( orderFrontFindPanel: )];
		return [toolbarItem autorelease];
	} else if( [identifier isEqualToString:JVToolbarQuickSearchItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Search", "search toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Search", "search patlette label" )];

		NSSearchField *field = [[[NSSearchField alloc] initWithFrame:NSMakeRect( 0., 0., 150., 22. )] autorelease];
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

		NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Search", "search toolbar item menu representation title" ) action:@selector( performQuickSearch: ) keyEquivalent:@""] autorelease];
		[toolbarItem setMenuFormRepresentation:menuItem];

		return [toolbarItem autorelease];
	} else if( [identifier isEqualToString:JVToolbarChooseStyleItemIdentifier] && ! willBeInserted ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];
		[toolbarItem setImage:[NSImage imageNamed:@"chooseStyle"]];
		return [toolbarItem autorelease];
	} else if( [identifier isEqualToString:JVToolbarChooseStyleItemIdentifier] && willBeInserted ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];

		MVMenuButton *button = [[[MVMenuButton alloc] initWithFrame:NSMakeRect( 0., 0., 32., 32. )] autorelease];
		[button setImage:[NSImage imageNamed:@"chooseStyle"]];
		[button setDrawsArrow:YES];
		[button setMenu:_styleMenu];

		[toolbarItem setToolTip:NSLocalizedString( @"Change chat style", "choose style toolbar item tooltip" )];
		[button setToolbarItem:toolbarItem];
		[toolbarItem setTarget:self];
		[toolbarItem setView:button];

		NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar item menu representation title" ) action:NULL keyEquivalent:@""] autorelease];
		NSImage *icon = [[[NSImage imageNamed:@"chooseStyle"] copy] autorelease];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];
		[menuItem setImage:icon];
		[menuItem setSubmenu:_styleMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];

		return [toolbarItem autorelease];
	} else if( [identifier isEqualToString:JVToolbarEmoticonsItemIdentifier] && ! willBeInserted ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
		[toolbarItem setLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item patlette label" )];
		[toolbarItem setImage:[NSImage imageNamed:@"emoticon"]];
		return [toolbarItem autorelease];
	} else if( [identifier isEqualToString:JVToolbarEmoticonsItemIdentifier] && willBeInserted ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item patlette label" )];

		MVMenuButton *button = [[[MVMenuButton alloc] initWithFrame:NSMakeRect( 0., 0., 32., 32. )] autorelease];
		[button setImage:[NSImage imageNamed:@"emoticon"]];
		[button setDrawsArrow:YES];
		[button setMenu:_emoticonMenu];

		[toolbarItem setToolTip:NSLocalizedString( @"Change Emoticons", "choose emoticons toolbar item tooltip" )];
		[button setToolbarItem:toolbarItem];
		[toolbarItem setTarget:self];
		[toolbarItem setView:button];

		NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item menu representation title" ) action:NULL keyEquivalent:@""] autorelease];
		NSImage *icon = [[[NSImage imageNamed:@"emoticon"] copy] autorelease];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];
		[menuItem setImage:icon];
		[menuItem setSubmenu:_emoticonMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];

		return [toolbarItem autorelease];
	}

	return nil;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:JVToolbarChooseStyleItemIdentifier, JVToolbarEmoticonsItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:JVToolbarChooseStyleItemIdentifier, JVToolbarEmoticonsItemIdentifier, JVToolbarFindItemIdentifier, JVToolbarQuickSearchItemIdentifier, nil];
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
	NSMutableArray *ret = [[defaultMenuItems mutableCopy] autorelease];
	NSMenuItem *item = nil;
	NSUInteger i = 0;
	BOOL found = NO;

	for( i = 0; i < [ret count]; i++ ) {
		item = [ret objectAtIndex:i];

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
		}
	}

	if( ! found && ! [ret count] && ! [[element objectForKey:WebElementIsSelectedKey] boolValue] ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style", "choose style contextual menu" ) action:NULL keyEquivalent:@""] autorelease];
		[item setSubmenu:_styleMenu];
		[ret addObject:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons contextual menu" ) action:NULL keyEquivalent:@""] autorelease];
		NSMenu *menu = [[[self _emoticonsMenu] copy] autorelease];
		[item setSubmenu:menu];
		[ret addObject:item];
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	id object = [[element objectForKey:WebElementImageURLKey] description];
	if( ! object ) object = [[element objectForKey:WebElementLinkURLKey] description];
	if( ! object ) {
		WebFrame *frame = [element objectForKey:WebElementFrameKey];
		object = [(id <WebDocumentText>)[[frame frameView] documentView] selectedString];
	}

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	[invocation setArgument:&object atIndex:2];
	[invocation setArgument:&self atIndex:3];

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

    NSBeginInformationalAlertSheet( title, nil, nil, nil, [sender window], nil, NULL, NULL, NULL, message );
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];

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
		[invocation setArgument:&url atIndex:2];
		[invocation setArgument:&self atIndex:3];

		NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];

		if( ! [[results lastObject] boolValue] ) {
			if( [MVChatConnection supportsURLScheme:[url scheme]] ) {
				[[MVConnectionsController defaultController] handleURL:url andConnectIfPossible:YES];
			} else if( [[actionInformation objectForKey:WebActionModifierFlagsKey] unsignedIntValue] & NSAlternateKeyMask ) {
				[[CQActivityWindowController sharedController] downloadFileAtURL:url toLocalFile:nil];
			} else {
				NSWorkspaceLaunchOptions options = ( [[actionInformation objectForKey:WebActionModifierFlagsKey] unsignedIntValue] & NSCommandKeyMask ? NSWorkspaceLaunchWithoutActivation : 0 );
				[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url] withAppBundleIdentifier:nil options:options additionalEventParamDescriptor:nil launchIdentifiers:nil];
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
	[newWebView release];

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
#pragma mark Style Support

@implementation JVChatTranscriptPanel (JVChatTranscriptPrivate)
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

- (void) _reloadCurrentStyle:(id) sender {
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
			JVStyle *style = [[subMenuItem representedObject] objectForKey:@"style"];
			NSString *variant = [[subMenuItem representedObject] objectForKey:@"variant"];
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
		for( menuItem in [[[menu itemArray] copy] autorelease] )
			if( [menuItem tag] || [menuItem isSeparatorItem] )
				[menu removeItem:menuItem];
	}

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Default", "default style menu item title" ) action:@selector( changeStyle: ) keyEquivalent:@""] autorelease];
	[menuItem setTag:5];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:nil];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	for( JVStyle *style in [[[JVStyle styles] allObjects] sortedArrayUsingSelector:@selector( compare: )] ) {
		if( !style.displayName.length ) continue;

		menuItem = [[[NSMenuItem alloc] initWithTitle:[style displayName] action:@selector( changeStyle: ) keyEquivalent:@""] autorelease];
		[menuItem setTag:5];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:style];
		[menu addItem:menuItem];

		NSArray *variants = [style variantStyleSheetNames];
		NSArray *userVariants = [style userVariantStyleSheetNames];

		if( [variants count] || [userVariants count] ) {
			subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

			subMenuItem = [[[NSMenuItem alloc] initWithTitle:[style mainVariantDisplayName] action:@selector( changeStyleVariant: ) keyEquivalent:@""] autorelease];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", nil]];
			[subMenu addItem:subMenuItem];

			for( id item in variants ) {
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( changeStyleVariant: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", item, @"variant", nil]];
				[subMenu addItem:subMenuItem];
			}

			if( [userVariants count] ) [subMenu addItem:[NSMenuItem separatorItem]];

			for( id item in userVariants ) {
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( changeStyleVariant: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", item, @"variant", nil]];
				[subMenu addItem:subMenuItem];
			}

			[menuItem setSubmenu:subMenu];
		}

		subMenu = nil;
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""] autorelease];
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
		for( menuItem in [[[menu itemArray] copy] autorelease] )
			[menu removeItem:menuItem];
	}

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:nil];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:[[JVEmoticonSet textOnlyEmoticonSet] displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:[JVEmoticonSet textOnlyEmoticonSet]];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	for( JVEmoticonSet *emoticon in [[[JVEmoticonSet emoticonSets] allObjects] sortedArrayUsingSelector:@selector( compare: )] ) {
		if( ! [[emoticon displayName] length] ) continue;
		menuItem = [[[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:emoticon];
		[menu addItem:menuItem];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setTag:10];
	[menu addItem:menuItem];

	[self _changeEmoticonsMenuSelection];
}

- (IBAction) _openAppearancePreferences:(id) sender {
	[[NSPreferences sharedPreferences] showPreferencesPanelForOwner:[JVAppearancePreferences sharedInstance]];
}

- (BOOL) _usingSpecificEmoticons {
	return NO;
}
@end
