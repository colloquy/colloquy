#import "JVChatTranscript.h"

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatPlugin.h>

#import "JVChatController.h"
#import "MVFileTransferController.h"
#import "MVMenuButton.h"

#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

NSMutableSet *JVChatStyleBundles = nil;
NSMutableSet *JVChatEmoticonBundles = nil;

static NSString *JVToolbarChooseStyleItemIdentifier = @"JVToolbarChooseStyleItem";

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
- (void) _switchingStyleEnded:(in NSString *) html;
- (oneway void) _switchStyle:(id) sender;
+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary;
+ (void) _freeXsltParamArray:(const char **) params;
- (void) _changeChatStyleMenuSelection;
- (void) _updateChatStylesMenu;
+ (NSSet *) _chatStyleBundles;
+ (void) _scanForChatStyles;
- (NSString *) _applyStyleOnXMLDocument:(xmlDocPtr) doc;
- (NSString *) _chatStyleCSSFileURL;
- (NSString *) _chatStyleVariantCSSFileURL;
- (const char *) _chatStyleXSLFilePath;
+ (NSString *) _nameForBundle:(NSBundle *) style;
+ (NSSet *) _emoticonBundles;
+ (void) _scanForEmoticons;
- (NSString *) _chatEmoticonsMappingFilePath;
- (NSString *) _chatEmoticonsCSSFileURL;
- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;
@end

#pragma mark -

NSComparisonResult sortBundlesByName( id style1, id style2, void *context ) {
	NSString *styleName1 = [JVChatTranscript _nameForBundle:style1];
	NSString *styleName2 = [JVChatTranscript _nameForBundle:style2];
    return [styleName1 caseInsensitiveCompare:styleName2];
}

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
		_params = NULL;
		_styleParams = nil;
		_chatStyle = nil;
		_chatStyleVariant = nil;
		_chatEmoticons = nil;
		_emoticonMappings = nil;
		_chatXSLStyle = NULL;
		_windowController = nil;
		_filePath = nil;
		_chatXSLStyle = NULL;

		[[self class] _scanForChatStyles];
		[[self class] _scanForEmoticons];

		[JVChatStyleBundles retain];
		[JVChatEmoticonBundles retain];

		_logLock = [[NSLock alloc] init];

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

	if( xmlGetProp( xmlDocGetRootElement( _xmlLog ), "style" ) )
		[self setChatStyle:[NSBundle bundleWithIdentifier:[NSString stringWithUTF8String:xmlGetProp( xmlDocGetRootElement( _xmlLog ), "style" )]] withVariant:nil];

	if( ! _chatEmoticons )
		[self setChatEmoticons:[NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"]]];

	if( ! _chatStyle ) {
		NSBundle *style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
		NSString *variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [style bundleIdentifier]]];		
		if( ! style ) {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
			style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
			variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [style bundleIdentifier]]];
		}
		[self setChatStyle:style withVariant:variant];
	}

	[self _updateChatStylesMenu];

	[[[[[display mainFrame] frameView] documentView] enclosingScrollView] setAllowsHorizontalScrolling:NO];

	if( ( toolbarItemContainerView = [chooseStyle superview] ) ) {
		[chooseStyle retain];
		[chooseStyle removeFromSuperview];
		[toolbarItemContainerView autorelease];
	}
}

- (void) dealloc {
	extern NSMutableSet *JVChatStyleBundles;
	extern NSMutableSet *JVChatEmoticonBundles;

	[contents release];
	[chooseStyle release];
	[_chatStyle release];
	[_chatStyleVariant release];
	[_chatEmoticons release];
	[_emoticonMappings release];
	[_logLock release];
	[_styleParams release];
	[_filePath release];

	[JVChatStyleBundles autorelease];
	[JVChatEmoticonBundles autorelease];

	xmlFreeDoc( _xmlLog );
	_xmlLog = NULL;

	xmlFreeDoc( _xmlQueue );
	_xmlQueue = NULL;

	xsltFreeStylesheet( _chatXSLStyle );
	_chatXSLStyle = NULL;

	[[self class] _freeXsltParamArray:_params];
	_params = NULL;

	if( [JVChatStyleBundles retainCount] == 1 ) JVChatStyleBundles = nil;
	if( [JVChatEmoticonBundles retainCount] == 1 ) JVChatEmoticonBundles = nil;

	contents = nil;
	chooseStyle = nil;
	_chatStyle = nil;
	_chatStyleVariant = nil;
	_chatEmoticons = nil;
	_emoticonMappings = nil;
	_logLock = nil;
	_styleParams = nil;
	_filePath = nil;
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
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Chat Transcript"];
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

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Transcript %@", [[_filePath lastPathComponent] stringByDeletingPathExtension]];
}

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
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "style", [[_chatStyle bundleIdentifier] UTF8String] );
		xmlSaveFormatFile( [[sheet filename] fileSystemRepresentation], _xmlLog, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[sheet isExtensionHidden]], NSFileExtensionHidden, nil] atPath:[sheet filename]];
		xmlUnsetProp( xmlDocGetRootElement( _xmlLog ), "style" );
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
	int result = NSOKButton;
	BOOL manyMessages = NO;

	NSParameterAssert( style != nil );

	manyMessages = ( xmlLsCountNode( xmlDocGetRootElement( _xmlLog ) ) > 2000 ? YES : NO );

	if( _isArchive && _previousStyleSwitch && manyMessages ) result = NSRunInformationalAlertPanel( NSLocalizedString( @"Time Consuming Style Switch", "time consuming style switch alert title" ), NSLocalizedString( @"This transcript is large and will take a considerable amount of time to switch the style. Would you like to continue anyway?", "large transcript style switch alert message" ), NSLocalizedString( @"Continue", "continue button name" ), @"Cancel", nil );
	else if( ! _isArchive && manyMessages ) result = NSRunInformationalAlertPanel( NSLocalizedString( @"Time Consuming Style Switch", "time consuming style switch alert title" ), NSLocalizedString( @"This converstaion is large and will take a considerable amount of time to switch the style. Would you like to do a full switch and wait until the switch is complete or a quick switch by hiding previous messages and return to the conversation?", "large transcript style switch alert message" ), NSLocalizedString( @"Full Switch", "full switch button name" ), @"Cancel", NSLocalizedString( @"Quick Switch", "clear button name" ) );

	if( result == NSCancelButton ) return;

	if( ! [_logLock tryLock] ) return;	

	_previousStyleSwitch = YES;

	[_chatStyle autorelease];
	_chatStyle = [style retain];

	[_chatStyleVariant autorelease];
	_chatStyleVariant = [variant retain];

	[_styleParams autorelease];
	_styleParams = [[NSDictionary dictionaryWithContentsOfFile:[_chatStyle pathForResource:@"parameters" ofType:@"plist"]] retain];

	if( _params ) [[self class] _freeXsltParamArray:_params];
	_params = [[self class] _xsltParamArrayWithDictionary:_styleParams];

	if( _chatXSLStyle ) xsltFreeStylesheet( _chatXSLStyle );
	_chatXSLStyle = xsltParseStylesheetFile( (const xmlChar *)[self _chatStyleXSLFilePath] );

	[self _changeChatStyleMenuSelection];

	if( result == NSAlertOtherReturn ) {
		[self _switchingStyleEnded:@""];
	} else [NSThread detachNewThreadSelector:@selector( _switchStyle: ) toTarget:self withObject:nil];
}

- (NSBundle *) chatStyle {
	return [[_chatStyle retain] autorelease];
}

#pragma mark -

- (IBAction) changeChatStyleVariant:(id) sender {
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
	NSString *style = [[sender representedObject] objectForKey:@"style"];

	if( ! [style isEqualToString:[_chatStyle bundleIdentifier]] ) {
		[self setChatStyle:[NSBundle bundleWithIdentifier:style] withVariant:variant];
	} else {
		[self setChatStyleVariant:variant];
	}
}

- (void) setChatStyleVariant:(NSString *) variant {
	[_chatStyleVariant autorelease];
	_chatStyleVariant = [variant retain];

	[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"variantStyle\", \"%@\" );", [self _chatStyleVariantCSSFileURL]]];

	[self _changeChatStyleMenuSelection];
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
}

- (void) downloadLinkToDisk:(id) sender {
	NSURL *url = [[sender representedObject] objectForKey:@"WebElementLinkURL"];
	[[MVFileTransferController defaultManager] downloadFileAtURL:url toLocalFile:nil];
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

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	NSMutableArray *ret = [[defaultMenuItems mutableCopy] autorelease];
	NSMenuItem *item = nil;
	unsigned i = 0;

	for( i = 0; i < [ret count]; i++ ) {
		item = [ret objectAtIndex:i];
		switch( [item tag] ) {
		case WebMenuItemTagOpenLinkInNewWindow:
		case WebMenuItemTagOpenImageInNewWindow:
		case WebMenuItemTagOpenFrameInNewWindow:
			[ret removeObjectAtIndex:i];
			i--;
			break;
		case WebMenuItemTagDownloadLinkToDisk:
		case WebMenuItemTagDownloadImageToDisk:
			[item setTarget:[sender UIDelegate]];
			break;
		}
	}
	return ret;
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	if( [[[actionInformation objectForKey:WebActionOriginalURLKey] scheme] isEqualToString:@"about"]  ) {
		[listener use];
	} else if( [[[actionInformation objectForKey:WebActionOriginalURLKey] scheme] isEqualToString:@"self"]  ) {
		NSString *command = [[actionInformation objectForKey:WebActionOriginalURLKey] resourceSpecifier];
		[self performSelector:NSSelectorFromString( [command stringByAppendingString:@":"] ) withObject:nil];
		[listener ignore];
	} else {
		if( [[actionInformation objectForKey:WebActionModifierFlagsKey] unsignedIntValue] & NSAlternateKeyMask ) {
			[[MVFileTransferController defaultManager] downloadFileAtURL:[actionInformation objectForKey:WebActionOriginalURLKey] toLocalFile:nil];
		} else {
			[[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];	
		}
		[listener ignore];
	}
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptPrivate)
- (void) _finishStyleSwitch:(id) sender {
	[display setPreferencesIdentifier:[_chatStyle bundleIdentifier]];
	// we shouldn't have to post this notification manually, but this seems to make webkit refresh with new prefs
	[[NSNotificationCenter defaultCenter] postNotificationName:@"WebPreferencesChangedNotification" object:[display preferences]];
	[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:sender] baseURL:nil];
	[_logLock unlock];
}

- (void) _switchingStyleEnded:(in NSString *) html {
	NSString *queueResult = @"";
	if( _xmlQueue ) {
		queueResult = [self _applyStyleOnXMLDocument:_xmlQueue];
		xmlAddChildList( xmlDocGetRootElement( _xmlLog ), xmlCopyNodeList( xmlDocGetRootElement( _xmlQueue ) -> children ) );
		xmlFreeDoc( _xmlQueue );
		_xmlQueue = NULL;
	}

	[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
	// give webkit some time to load the blank before we switch preferences so we don't double refresh
	[self performSelector:@selector( _finishStyleSwitch: ) withObject:[( html ? html : @"" ) stringByAppendingString:queueResult] afterDelay:0.];
}

- (oneway void) _switchStyle:(id) sender {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *result = [self _applyStyleOnXMLDocument:_xmlLog];
	[self performSelectorOnMainThread:@selector( _switchingStyleEnded: ) withObject:result waitUntilDone:YES];
	[pool release];
}

+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary {
	NSEnumerator *keyEnumerator = [dictionary keyEnumerator];
	NSEnumerator *enumerator = [dictionary objectEnumerator];
	NSString *key = nil;
	NSString *value = nil;
	const char **temp = NULL, **ret = NULL;

	if( ! [dictionary count] ) return NULL;

	ret = temp = malloc( ( ( [dictionary count] * 2 ) + 1 ) * sizeof( char * ) );

	while( ( key = [keyEnumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		*(temp++) = (char *) strdup( [key UTF8String] );
		*(temp++) = (char *) strdup( [value UTF8String] );
	}

	*(temp) = NULL;

	return ret;
}

+ (void) _freeXsltParamArray:(const char **) params {
	const char **temp = params;

	if( ! params ) return;

	while( *(temp) ) {
		free( (void *)*(temp++) );
		free( (void *)*(temp++) );
	}

	free( params );
}

- (NSMenu *) _stylesMenu {
	if( ! _nibLoaded ) [self view];
	return [[[chooseStyle menu] retain] autorelease];
}

- (void) _changeChatStyleMenuSelection {
	NSEnumerator *enumerator = [[[chooseStyle menu] itemArray] objectEnumerator];
	NSEnumerator *senumerator = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;
	BOOL hasPerRoomStyle = NO;
	NSString *style = nil;

//	if( [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"chat.style.%@", [self identifier]]] )
//		hasPerRoomStyle = YES;

	style = [_chatStyle bundleIdentifier];

	while( ( menuItem = [enumerator nextObject] ) ) {
		if( [style isEqualToString:[menuItem representedObject]] && hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( ! [menuItem representedObject] && ! hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( [style isEqualToString:[menuItem representedObject]] && ! hasPerRoomStyle ) [menuItem setState:NSMixedState];
		else [menuItem setState:NSOffState];

		senumerator = [[[menuItem submenu] itemArray] objectEnumerator];
		while( ( subMenuItem = [senumerator nextObject] ) ) {
			if( [subMenuItem action] == @selector( changeChatStyle: ) && [style isEqualToString:[subMenuItem representedObject]] && ! [_chatStyleVariant length] )
				[subMenuItem setState:NSOnState];
			else if( [subMenuItem action] == @selector( changeChatStyleVariant: ) && [style isEqualToString:[[subMenuItem representedObject] objectForKey:@"style"]] && [_chatStyleVariant isEqualToString:[[subMenuItem representedObject] objectForKey:@"variant"]] ) 
				[subMenuItem setState:NSOnState];
			else [subMenuItem setState:NSOffState];
		}
	}
}

- (void) _updateChatStylesMenu {
	extern NSMutableSet *JVChatStyleBundles;
	NSEnumerator *enumerator = [[[JVChatStyleBundles allObjects] sortedArrayUsingFunction:sortBundlesByName context:self] objectEnumerator];
	NSEnumerator *denumerator = nil;
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;
	NSBundle *style = nil;
	id file = nil;

	if( ! ( menu = [chooseStyle menu] ) ) {
		menu = [[[NSMenu alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar menu title" )] autorelease];
		[chooseStyle setMenu:menu];
	} else {
		NSEnumerator *enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];

		if( [menu numberOfItems] > ( [JVChatStyleBundles count] + 2 ) )
			[enumerator nextObject];

		while( ( menuItem = [enumerator nextObject] ) )
			[menu removeItem:menuItem];
	}

	style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Default", "default style menu item title" ) action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	while( ( style = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[[self class] _nameForBundle:style] action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[style bundleIdentifier]];
		[menu addItem:menuItem];

		if( [[style pathsForResourcesOfType:@"css" inDirectory:@"Variants"] count] ) {
			denumerator = [[style pathsForResourcesOfType:@"css" inDirectory:@"Variants"] objectEnumerator];
			subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
			subMenuItem = [[[NSMenuItem alloc] initWithTitle:( [style objectForInfoDictionaryKey:@"JVBaseStyleVariantName"] ? [style objectForInfoDictionaryKey:@"JVBaseStyleVariantName"] : NSLocalizedString( @"Normal", "normal style variant menu item title" ) ) action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:[style bundleIdentifier]];
			[subMenu addItem:subMenuItem];

			while( ( file = [denumerator nextObject] ) ) {
				file = [[file lastPathComponent] stringByDeletingPathExtension];
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:file action:@selector( changeChatStyleVariant: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:[style bundleIdentifier], @"style", file, @"variant", nil]];
				[subMenu addItem:subMenuItem];
			}

			[menuItem setSubmenu:subMenu];
		}

		subMenu = nil;
	}

	[self _changeChatStyleMenuSelection];
}

+ (NSSet *) _chatStyleBundles {
	extern NSMutableSet *JVChatStyleBundles;
	return [[JVChatStyleBundles retain] autorelease];
}

+ (void) _scanForChatStyles {
	extern NSMutableSet *JVChatStyleBundles;
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	if( ! JVChatStyleBundles )
		JVChatStyleBundles = [NSMutableSet set];

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
}

- (NSString *) _applyStyleOnXMLDocument:(xmlDocPtr) doc {
	xmlDocPtr res = NULL;
	xmlChar *result = NULL;
	NSString *ret = nil;
	int len = 0;

	NSParameterAssert( doc != NULL );
	NSAssert( _chatXSLStyle, @"XSL not allocated." );

	if( ( res = xsltApplyStylesheet( _chatXSLStyle, doc, _params ) ) ) {
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
	NSString *path = [_chatStyle pathForResource:@"main" ofType:@"css"];
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
	NSString *path = [_chatStyle pathForResource:@"main" ofType:@"xsl"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"xsl"];
	return [path fileSystemRepresentation];
}

+ (NSString *) _nameForBundle:(NSBundle *) bundle {
	NSDictionary *info = [bundle localizedInfoDictionary];
	NSString *label = [info objectForKey:@"CFBundleName"];
	if( ! label ) label = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
	if( ! label ) label = [bundle bundleIdentifier];
	return [[label retain] autorelease];
}

+ (NSSet *) _emoticonBundles {
	extern NSMutableSet *JVChatEmoticonBundles;
	return [[JVChatEmoticonBundles retain] autorelease];
}

+ (void) _scanForEmoticons {
	extern NSMutableSet *JVChatEmoticonBundles;
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	if( ! JVChatEmoticonBundles )
		JVChatEmoticonBundles = [NSMutableSet set];

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
	if( path ) return [[[[NSURL fileURLWithPath:path] absoluteString] retain] autorelease];
	else return @"";
}

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html {
	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	return [[[NSString stringWithFormat:shell, [self title], [self _chatEmoticonsCSSFileURL], [self _chatStyleCSSFileURL], [self _chatStyleVariantCSSFileURL], html] retain] autorelease];
}
@end