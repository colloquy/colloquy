#import "JVChatTranscript.h"

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "JVChatController.h"
#import "MVMenuButton.h"

#import <libxml/xinclude.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

NSMutableSet *JVChatStyleBundles = nil;
NSMutableSet *JVChatEmoticonBundles = nil;

static NSString *JVToolbarChooseStyleItemIdentifier = @"JVToolbarChooseStyleItem";

NSComparisonResult sortChatStyles( id style1, id style2, void *context ) {
	JVChatTranscript *self = context;
	NSString *styleName1 = [self _chatStyleNameForBundle:style1];
	NSString *styleName2 = [self _chatStyleNameForBundle:style2];
    return [styleName1 caseInsensitiveCompare:styleName2];
}

#pragma mark -

void MVChatPlaySoundForAction( NSString *action ) {
	NSSound *sound = nil;
	NSCParameterAssert( action != nil );
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatPlayActionSounds"] ) return;
	if( ! ( sound = [NSSound soundNamed:action] ) ) {
		NSString *path = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatActionSounds"] objectForKey:action];
		if( ! [path isAbsolutePath] )
			path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];
		sound = [[NSSound alloc] initWithContentsOfFile:path byReference:NO];
		[sound setName:action];
	}
	[sound play];
}

#pragma mark -

@interface NSScrollView (NSScrollViewWebKitPrivate)
- (void) setAllowsHorizontalScrolling:(BOOL) allow;
@end

#pragma mark -

@interface JVChatTranscript (JVChatTranscriptPrivate)
- (void) _updateChatStylesMenu;
- (void) _scanForChatStyles;
- (NSString *) _applyStyleOnXMLDocument:(xmlDocPtr) doc;
- (NSString *) _chatStyleCSSFileURL;
- (NSString *) _chatStyleVariantCSSFileURL;
- (const char *) _chatStyleXSLFilePath;
- (NSString *) _chatStyleNameForBundle:(NSBundle *) style;
- (void) _scanForEmoticons;
- (NSString *) _chatEmoticonsMappingFilePath;
- (NSString *) _chatEmoticonsCSSFileURL;
- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;
@end

#pragma mark -

@implementation JVChatTranscript
- (id) init {
	extern NSMutableSet *JVChatStyleBundles;
	extern NSMutableSet *JVChatEmoticonBundles;

	if( ( self = [super init] ) ) {
		display = nil;
		contents = nil;
		chooseStyle = nil;
		_isArchive = NO;
		_chatStyle = nil;
		_chatStyleVariant = nil;
		_chatEmoticons = nil;
		_emoticonMappings = nil;
		_chatXSLStyle = NULL;
		_windowController = nil;
		_filePath = nil;
		_chatXSLStyle = NULL;

		xmlSubstituteEntitiesDefault( 1 );
		xmlLoadExtDtdDefaultValue = 1;

		if( ! JVChatStyleBundles )
			JVChatStyleBundles = [NSMutableSet set];
		[JVChatStyleBundles retain];

		if( ! JVChatEmoticonBundles )
			JVChatEmoticonBundles = [NSMutableSet set];
		[JVChatEmoticonBundles retain];

		[self _scanForChatStyles];
		[self _scanForEmoticons];

		_xmlLog = xmlNewDoc( "1.0" );
		xmlDocSetRootElement( _xmlLog, xmlNewNode( NULL, "log" ) );
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "began", [[[NSDate date] description] UTF8String] );
	}
	return self;
}

- (id) initWithTranscript:(NSString *) filename {
	if( ( self = [self init] ) ) {
		xmlFreeDoc( _xmlLog );
		_filePath = [filename copy];
		_xmlLog = xmlParseFile( [filename fileSystemRepresentation] );
		_isArchive = YES;
	}
	return self;
}

- (void) awakeFromNib {
	NSView *toolbarItemContainerView = nil;

	[display setMaintainsBackForwardList:NO];
	[display setPolicyDelegate:self];

	if( ! _chatEmoticons )
		[self setChatEmoticons:[NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"]]];

	if( ! _chatStyle ) {
		NSBundle *style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
		[self setChatStyle:style withVariant:[[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@ variant", [style bundleIdentifier]]]];
	}

	[[[[[display mainFrame] frameView] documentView] enclosingScrollView] setAllowsHorizontalScrolling:NO];

	toolbarItemContainerView = [chooseStyle superview];

	[chooseStyle retain];
	[chooseStyle removeFromSuperview];

	[toolbarItemContainerView autorelease];

	[self _updateChatStylesMenu];
}

- (void) dealloc {
	extern NSMutableSet *JVChatStyleBundles;
	extern NSMutableSet *JVChatEmoticonBundles;

	[contents autorelease];
	[chooseStyle autorelease];
	[_chatStyle autorelease];
	[_chatStyleVariant autorelease];
	[_chatEmoticons autorelease];
	[_emoticonMappings autorelease];

	[JVChatStyleBundles autorelease];
	[JVChatEmoticonBundles autorelease];

	xmlFreeDoc( _xmlLog );
	_xmlLog = NULL;

	xsltFreeStylesheet( _chatXSLStyle );
	_chatXSLStyle = NULL;

	xsltCleanupGlobals();
	xmlCleanupParser();

	if( [JVChatStyleBundles retainCount] == 1 ) JVChatStyleBundles = nil;
	if( [JVChatEmoticonBundles retainCount] == 1 ) JVChatEmoticonBundles = nil;

	contents = nil;
	chooseStyle = nil;
	_chatStyle = nil;
	_chatStyleVariant = nil;
	_chatEmoticons = nil;
	_emoticonMappings = nil;
	_windowController = nil;

	[super dealloc];
}

#pragma mark -

- (JVChatWindowController *) windowController {
	return [[_windowController retain] autorelease];
}

- (void) setWindowController:(JVChatWindowController *) controller {
	if( [[[_windowController window] representedFilename] isEqualToString:_filePath] )
		[[_windowController window] setRepresentedFilename:@""];
	_windowController = controller;
	[display setHostWindow:[_windowController window]];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatTranscript" owner:self];
	return contents;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"chat.transcript"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

#pragma mark -

- (NSString *) title {
	return [[[[_filePath lastPathComponent] stringByDeletingPathExtension] retain] autorelease];
}

- (NSString *) windowTitle {
	NSCalendarDate *date = nil;
	xmlChar *began = NULL;
	began = xmlGetProp( xmlDocGetRootElement( _xmlLog ), "began" );
	date = [NSCalendarDate dateWithString:[NSString stringWithUTF8String:began] calendarFormat:@"%Y-%m-%d %H:%M:%S %z"];
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - %@ Transcript", "chat transcript/log - window title" ), [[_filePath lastPathComponent] stringByDeletingPathExtension], [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]]];
}

- (NSString *) information {
	NSCalendarDate *date = nil;
	xmlChar *began = NULL;
	began = xmlGetProp( xmlDocGetRootElement( _xmlLog ), "began" );
	date = [NSCalendarDate dateWithString:[NSString stringWithUTF8String:began] calendarFormat:@"%Y-%m-%d %H:%M:%S %z"];
	return [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]];
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

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	NSImage *ret = [NSImage imageNamed:@"Generic"];
	[ret setSize:NSMakeSize( 32., 32. )];
	return [[ret retain] autorelease];
}

- (NSImage *) statusImage {
	return nil;
}

#pragma mark -

- (void) didUnselect {
	[[_windowController window] setRepresentedFilename:@""];
}

- (void) didSelect {
	[[_windowController window] setRepresentedFilename:_filePath];
}

#pragma mark -

- (MVChatConnection *) connection {
	return nil;
}

#pragma mark -

- (IBAction) saveDocumentTo:(id) sender {
	NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
	[savePanel setDelegate:self];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:@"colloquyTranscript"];
	[savePanel beginSheetForDirectory:NSHomeDirectory() file:@"" modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( savePanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		xmlSaveFormatFile( [[sheet filename] fileSystemRepresentation], _xmlLog, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[sheet isExtensionHidden]], NSFileExtensionHidden, nil] atPath:[sheet filename]];
	}
}

#pragma mark -

- (IBAction) changeChatStyle:(id) sender {
	NSBundle *style = [NSBundle bundleWithIdentifier:[sender representedObject]];
	if( ! style ) {
		style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatDefaultStyle"]];
	}
	[self setChatStyle:style withVariant:nil];
}

- (void) setChatStyle:(NSBundle *) style withVariant:(NSString *) variant {
	NSString *result = nil;

	[_chatStyle autorelease];
	_chatStyle = [style retain];

	[_chatStyleVariant autorelease];
	_chatStyleVariant = [variant retain];

	if( _chatXSLStyle ) xsltFreeStylesheet( _chatXSLStyle );
	_chatXSLStyle = xsltParseStylesheetFile( (const xmlChar *)[self _chatStyleXSLFilePath] );

	result = [self _applyStyleOnXMLDocument:_xmlLog];
	[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:( result ? result : @"" )] baseURL:nil];

	[self _updateChatStylesMenu];
}

- (NSBundle *) chatStyle {
	return [[_chatStyle retain] autorelease];
}

#pragma mark -

- (IBAction) changeChatStyleVariant:(id) sender {
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
	NSBundle *style = [[sender representedObject] objectForKey:@"style"];

	if( style != _chatStyle ) {
		[self setChatStyle:style withVariant:variant];
	} else {
		[self setChatStyleVariant:variant];
	}
}

- (void) setChatStyleVariant:(NSString *) variant {
	[_chatStyleVariant autorelease];
	_chatStyleVariant = [variant retain];

	[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"variantStyle\", \"%@\" );", [self _chatStyleVariantCSSFileURL]]];

	[self _updateChatStylesMenu];
}

- (NSString *) chatStyleVariant {
	return [[_chatStyleVariant retain] autorelease];
}

#pragma mark -

- (IBAction) changeChatEmoticons:(id) sender {
	NSBundle *emoticons = [NSBundle bundleWithIdentifier:[sender representedObject]];
	[self setChatEmoticons:emoticons];
}

- (void) setChatEmoticons:(NSBundle *) emoticons {
	[_chatEmoticons autorelease];
	_chatEmoticons = [emoticons retain];

	[_emoticonMappings autorelease];
	_emoticonMappings = [[[NSDictionary dictionaryWithContentsOfFile:[self _chatEmoticonsMappingFilePath]] objectForKey:@"classes"] retain];

	[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"emoticonStyle\", \"%@\" );", [self _chatEmoticonsCSSFileURL]]];
}

- (NSBundle *) chatEmoticons {
	return [[_chatEmoticons retain] autorelease];
}

#pragma mark -

- (IBAction) leaveChat:(id) sender {
	[[JVChatController defaultManager] disposeViewController:self];
	[_windowController removeChatViewController:self];
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

	if( [identifier isEqual:JVToolbarToggleChatDrawerItemIdentifier] ) {
		toolbarItem = [_windowController toggleChatDrawerToolbarItem];
	} else if( [identifier isEqual:JVToolbarChooseStyleItemIdentifier] && willBeInserted ) {
		NSImage *icon = [[[NSImage imageNamed:@"chooseStyle"] copy] autorelease];
		NSMenuItem *menuItem = nil;

		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Change chat style", "choose style toolbar item tooltip" )];
		[chooseStyle setToolbarItem:toolbarItem];
		[toolbarItem setView:chooseStyle];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar item menu representation title" ) action:NULL keyEquivalent:@""] autorelease];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];
		[menuItem setImage:icon];
		[menuItem setSubmenu:[chooseStyle menu]];

		[toolbarItem setMenuFormRepresentation:menuItem];
	} else if( [identifier isEqual:JVToolbarChooseStyleItemIdentifier] && ! willBeInserted ) {
		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];
		[toolbarItem setImage:[NSImage imageNamed:@"chooseStyle"]];
	} else toolbarItem = nil;
	return [[toolbarItem retain] autorelease];
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier, JVToolbarChooseStyleItemIdentifier, nil];
	return [[list retain] autorelease];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier, JVToolbarChooseStyleItemIdentifier, NSToolbarShowColorsItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
	return [[list retain] autorelease];
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqual:NSToolbarShowColorsItemIdentifier] ) return NO;
	else if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqual:NSToolbarShowColorsItemIdentifier] ) return YES;

	return YES;
}

- (void) webView:(WebView *) webView decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	if( [[[actionInformation objectForKey:WebActionOriginalURLKey] scheme] isEqualToString:@"about"]  ) {
		[listener use];
	} else {
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];
	}
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptPrivate)
- (void) _updateChatStylesMenu {
	extern NSMutableSet *JVChatStyleBundles;
	NSEnumerator *enumerator = [[[JVChatStyleBundles allObjects] sortedArrayUsingFunction:sortChatStyles context:self] objectEnumerator];
	NSEnumerator *denumerator = nil;
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;
	NSBundle *style = nil;
	BOOL hasPerRoomStyle = NO;
	id file = nil;

	if( ! ( menu = [chooseStyle menu] ) ) {
		menu = [[[NSMenu alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar menu title" )] autorelease];
	} else {
		NSEnumerator *enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];

		if( [menu numberOfItems] > ( [JVChatStyleBundles count] + 2 ) )
			[enumerator nextObject];

		while( ( menuItem = [enumerator nextObject] ) )
			[menu removeItem:menuItem];
	}

	if( [self connection] && [self target] && [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"chat.style.%@.%@", [[self connection] server], [self target]]] )
		hasPerRoomStyle = YES;

	style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Default", "default style menu item title" ) action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	if( style == _chatStyle && ! hasPerRoomStyle ) [menuItem setState:NSOnState];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	while( ( style = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[self _chatStyleNameForBundle:style] action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		if( style == _chatStyle && hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( style == _chatStyle && ! hasPerRoomStyle ) [menuItem setState:NSMixedState];
		[menuItem setRepresentedObject:[style bundleIdentifier]];
		[menu addItem:menuItem];

		if( [[style pathsForResourcesOfType:@"css" inDirectory:@"Variants"] count] ) {
			denumerator = [[style pathsForResourcesOfType:@"css" inDirectory:@"Variants"] objectEnumerator];
			subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

			subMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Normal", "normal style variant menu item title" ) action:@selector( changeChatStyleVariant: ) keyEquivalent:@""] autorelease];
			[subMenuItem setTarget:self];
			if( style == _chatStyle && ! [_chatStyleVariant length] ) [subMenuItem setState:NSOnState];
			[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", nil]];
			[subMenu addItem:subMenuItem];

			while( ( file = [denumerator nextObject] ) ) {
				file = [[file lastPathComponent] stringByDeletingPathExtension];
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:file action:@selector( changeChatStyleVariant: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				if( style == _chatStyle && [_chatStyleVariant isEqualToString:file] ) [subMenuItem setState:NSOnState];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", file, @"variant", nil]];
				[subMenu addItem:subMenuItem];
			}

			[menuItem setSubmenu:subMenu];
		}

		subMenu = nil;
	}

	[chooseStyle setMenu:menu];
}

- (void) _scanForChatStyles {
	extern NSMutableSet *JVChatStyleBundles;
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	[paths addObject:[NSString stringWithFormat:@"%@/Styles", [[NSBundle mainBundle] resourcePath]]];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/Styles", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/Styles", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];

	enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"colloquyStyle"] ) {
				if( ( bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]] ) ) {
					[bundle load];
					[JVChatStyleBundles addObject:bundle];
				}
			}
		}
	}

	[self _updateChatStylesMenu];
}

- (NSString *) _applyStyleOnXMLDocument:(xmlDocPtr) doc {
	xmlDocPtr res = NULL;
	xmlChar *result = NULL;
	NSString *ret = nil;
	int len = 0;

	NSParameterAssert( doc != NULL );
	NSAssert( _chatXSLStyle, @"XSL not allocated." );

	if( ( res = xsltApplyStylesheet( _chatXSLStyle, doc, NULL ) ) ) {
		xsltSaveResultToString( &result, &len, res, _chatXSLStyle );
		xmlFreeDoc( res );
	}

	if( result ) {
		ret = [NSString stringWithUTF8String:result];
		free( result );
	}

	return [[ret retain] autorelease];
}

- (NSString *) _chatStyleCSSFileURL {
	NSString *path = [_chatStyle pathForResource:[_chatStyle objectForInfoDictionaryKey:@"JVStyleName"] ofType:@"css"];
	if( path ) return [[[[NSURL fileURLWithPath:path] absoluteString] retain] autorelease];
	else return @"";
}

- (NSString *) _chatStyleVariantCSSFileURL {
	NSString *path = nil;
	if( _chatStyleVariant ) {
		if( [_chatStyleVariant isAbsolutePath] ) path = [[NSURL fileURLWithPath:_chatStyleVariant] absoluteString];
		else path = [[NSURL fileURLWithPath:[_chatStyle pathForResource:_chatStyleVariant ofType:@"css" inDirectory:@"Variants"]] absoluteString];
	}
	if( ! path ) path = @"";
	return [[path retain] autorelease];
}

- (const char *) _chatStyleXSLFilePath {
	NSString *path = [_chatStyle pathForResource:[_chatStyle objectForInfoDictionaryKey:@"JVStyleName"] ofType:@"xsl"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"xsl"];
	return [path fileSystemRepresentation];
}

- (NSString *) _chatStyleNameForBundle:(NSBundle *) style {
	NSDictionary *info = [style localizedInfoDictionary];
	NSString *label = [info objectForKey:@"CFBundleName"];
	if( ! label ) label = [style objectForInfoDictionaryKey:@"CFBundleName"];
	if( ! label ) label = [style objectForInfoDictionaryKey:@"JVStyleName"];
	if( ! label ) label = [NSString stringWithFormat:@"Style %x", style];
	return [[label retain] autorelease];
}

- (void) _scanForEmoticons {
	extern NSMutableSet *JVChatEmoticonBundles;
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	[paths addObject:[NSString stringWithFormat:@"%@/Emoticons", [[NSBundle mainBundle] resourcePath]]];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Emoticons", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/Emoticons", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/Emoticons", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];

	enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"colloquyEmoticons"] ) {
				if( ( bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]] ) ) {
					[bundle load];
					[JVChatEmoticonBundles addObject:bundle];
				}
			}
		}
	}
}

- (NSString *) _chatEmoticonsMappingFilePath {
	NSString *path = [_chatEmoticons pathForResource:@"emoticons" ofType:@"plist"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"emoticons" ofType:@"plist"];
	return [[path retain] autorelease];
}

- (NSString *) _chatEmoticonsCSSFileURL {
	NSString *path = [_chatEmoticons pathForResource:@"emoticons" ofType:@"css"];
	if( path ) return [[[[NSURL fileURLWithPath: path] absoluteString] retain] autorelease];
	else return @"";
}

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html {
	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	return [[[NSString stringWithFormat:shell, [self title], [self _chatEmoticonsCSSFileURL], [self _chatStyleCSSFileURL], [self _chatStyleVariantCSSFileURL], html] retain] autorelease];
}
@end