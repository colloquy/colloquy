#import "JVChatTranscript.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatScriptPlugin.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <ChatCore/NSURLAdditions.h>
#import <ChatCore/NSStringAdditions.h>

#import "MVApplicationController.h"
#import "JVChatController.h"
#import "JVStyle.h"
#import "JVChatMessage.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVMenuButton.h"
#import "NSPreferences.h"
#import "JVAppearancePreferences.h"
#import "JVMarkedScroller.h"
#import "NSBundleAdditions.h"
#import "unistd.h"

#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>
#import <libxml/xpathInternals.h>

NSMutableSet *JVChatEmoticonBundles = nil;

NSString *JVChatEmoticonsScannedNotification = @"JVChatEmoticonsScannedNotification";

static NSString *JVToolbarChooseStyleItemIdentifier = @"JVToolbarChooseStyleItem";
static NSString *JVToolbarEmoticonsItemIdentifier = @"JVToolbarEmoticonsItem";

static unsigned long xmlChildElementCount( xmlNodePtr node ) {
	xmlNodePtr current = node -> children;
	if( ! current ) return 0;

	unsigned long i = 0;
	while( current -> next ) {
		if( current -> type == XML_ELEMENT_NODE ) i++;
		current = current -> next;
	}

	return i;
}

#pragma mark -

@interface WebCoreCache
+ (void) empty;
@end

#pragma mark -

@interface WebView (WebViewPrivate) // WebKit 1.3 pending public API
- (void) setDrawsBackground:(BOOL) draws;
- (BOOL) drawsBackground;
@end

#pragma mark -

@interface NSScrollView (NSScrollViewWebKitPrivate)
- (void) setAllowsHorizontalScrolling:(BOOL) allow;
@end

#pragma mark -

@interface JVChatTranscript (JVChatTranscriptPrivate)
+ (void) _scanForEmoticons;

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;

- (void) _switchingStyleEnded:(in NSString *) html;
- (void) _changeChatStyleMenuSelection;
- (void) _updateChatStylesMenu;

- (void) _changeChatEmoticonsMenuSelection;
- (void) _updateChatEmoticonsMenu;
- (NSMenu *) _emoticonsMenu;
- (NSString *) _chatEmoticonsMappingFilePath;
- (NSString *) _chatEmoticonsCSSFileURL;

- (BOOL) _usingSpecificStyle;
- (BOOL) _usingSpecificEmoticons;
@end

#pragma mark -

@implementation JVChatTranscript
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _scanForEmoticons ) name:JVChatEmoticonSetInstalledNotification object:nil];
		tooLate = YES;
	}
}

- (id) init {
	extern NSMutableSet *JVChatEmoticonBundles;

	if( ( self = [super init] ) ) {
		display = nil;
		contents = nil;
		_isArchive = NO;
		_switchingStyles = NO;
		_styleParams = nil;
		_styleMenu = nil;
		_chatStyle = nil;
		_chatStyleVariant = nil;
		_chatEmoticons = nil;
		_emoticonMenu = nil;
		_emoticonMappings = nil;
		_windowController = nil;
		_filePath = nil;
		_messages = [[NSMutableArray arrayWithCapacity:50] retain];

		[[self class] _scanForEmoticons];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateChatStylesMenu ) name:JVStylesScannedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateChatStylesMenu ) name:JVNewStyleVariantAddedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateChatEmoticonsMenu ) name:JVChatEmoticonsScannedNotification object:nil];

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
		if( ! ( _xmlLog = xmlParseFile( [filename fileSystemRepresentation] ) ) ) return nil;

		_filePath = [filename copy];
		_isArchive = YES;

		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filename]];
	}
	return self;
}

- (void) awakeFromNib {
	[display setUIDelegate:self];
	[display setPolicyDelegate:self];

	if( [self isMemberOfClass:[JVChatTranscript class]] ) {
		if( ! _chatStyle && xmlHasProp( xmlDocGetRootElement( _xmlLog ), "style" ) ) {
			xmlChar *styleProp = xmlGetProp( xmlDocGetRootElement( _xmlLog ), "style" );
			JVStyle *style = [JVStyle styleWithIdentifier:[NSString stringWithUTF8String:styleProp]];
			if( style ) [self setChatStyle:style withVariant:nil];
			xmlFree( styleProp );
		}

		if( ! _chatEmoticons && xmlHasProp( xmlDocGetRootElement( _xmlLog ), "emoticon" ) ) {
			xmlChar *emoticonProp = xmlGetProp( xmlDocGetRootElement( _xmlLog ), "emoticon" );
			[self setChatEmoticons:[NSBundle bundleWithIdentifier:[NSString stringWithUTF8String:emoticonProp]]];
			xmlFree( emoticonProp );
		}
	}

	if( ! _chatStyle ) {
		JVStyle *style = [JVStyle defaultStyle];
		NSString *variant = [style defaultVariantName];		
		[self setChatStyle:style withVariant:variant];
	}

	if( ! _chatEmoticons && ! [self _usingSpecificEmoticons] ) {
		NSBundle *emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle identifier]]]];
		if( ! emoticon ) {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle identifier]]];
			emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle identifier]]]];
		}
		[self setChatEmoticons:emoticon];
	}

	[self _updateChatStylesMenu];
	[self _updateChatEmoticonsMenu];

	[self performSelector:@selector( _reloadCurrentStyle: ) withObject:nil afterDelay:0.];
}

- (void) dealloc {
	extern NSMutableSet *JVChatEmoticonBundles;

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[display setUIDelegate:nil];
	[display setPolicyDelegate:nil];

	[contents release];
	[_styleMenu release];
	[_chatStyle release];
	[_chatStyleVariant release];
	[_chatEmoticons release];
	[_emoticonMenu release];
	[_emoticonMappings release];
	[_logLock release];
	[_styleParams release];
	[_filePath release];
	[_messages release];

	[JVChatEmoticonBundles autorelease];

	xmlFreeDoc( _xmlLog );
	_xmlLog = NULL;

	if( [JVChatEmoticonBundles retainCount] == 1 ) JVChatEmoticonBundles = nil;

	contents = nil;
	_styleMenu = nil;
	_chatStyle = nil;
	_chatStyleVariant = nil;
	_chatEmoticons = nil;
	_emoticonMenu = nil;
	_emoticonMappings = nil;
	_logLock = nil;
	_styleParams = nil;
	_filePath = nil;
	_windowController = nil;
	_messages = nil;

	[super dealloc];
}

- (NSString *) description {
	return [NSString stringWithFormat:@"%@ - %@", [super description], [self title]];
}

#pragma mark -
#pragma mark Window Controller and Proxy Icon Support

- (JVChatWindowController *) windowController {
	return [[_windowController retain] autorelease];
}

- (void) setWindowController:(JVChatWindowController *) controller {
	if( [[[_windowController window] representedFilename] isEqualToString:_filePath] || ! _filePath )
		[[_windowController window] setRepresentedFilename:@""];
	else if( ! [[[_windowController window] representedFilename] length] )
		[[_windowController window] setRepresentedFilename:_filePath];
	_windowController = controller;
	[display setHostWindow:[_windowController window]];
}

- (void) didUnselect {
	[[_windowController window] setRepresentedFilename:@""];
}

- (void) didSelect {
	[[_windowController window] setRepresentedFilename:( _filePath ? _filePath : @"" )];
}

#pragma mark -
#pragma mark Miscellaneous Window Info

- (NSString *) title {
	return [[NSFileManager defaultManager] displayNameAtPath:_filePath];
}

- (NSString *) windowTitle {
	xmlChar *began = xmlGetProp( xmlDocGetRootElement( _xmlLog ), "began" );
	NSCalendarDate *date = ( began ? [NSCalendarDate dateWithString:[NSString stringWithUTF8String:began]] : nil );
	xmlFree( began );
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - %@ Transcript", "chat transcript/log - window title" ), [self title], ( date ? [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]] : @"" )];
}

- (NSString *) information {
	xmlChar *began = xmlGetProp( xmlDocGetRootElement( _xmlLog ), "began" );
	NSCalendarDate *date = ( began ? [NSCalendarDate dateWithString:[NSString stringWithUTF8String:began]] : nil );
	xmlFree( began );
	return [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]];
}

- (NSString *) toolTip {
	return [NSString stringWithFormat:@"%@\n%@", [self title], [self information]];
}

- (IBAction) close:(id) sender {
	[[JVChatController defaultManager] disposeViewController:self];
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

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];
	
	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	NSImage *ret = [NSImage imageNamed:@"Generic"];
	[ret setSize:NSMakeSize( 32., 32. )];
	return [[ret retain] autorelease];
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
		[self saveTranscriptTo:[sheet filename]];
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[sheet isExtensionHidden]], NSFileExtensionHidden, nil] atPath:[sheet filename]];
	}
}

- (void) saveTranscriptTo:(NSString *) path {
	if( ! _chatEmoticons ) xmlSetProp( xmlDocGetRootElement( _xmlLog ), "emoticon", "" );
	else xmlSetProp( xmlDocGetRootElement( _xmlLog ), "emoticon", [[_chatEmoticons bundleIdentifier] UTF8String] );
	xmlSetProp( xmlDocGetRootElement( _xmlLog ), "style", [[_chatStyle identifier] UTF8String] );
	xmlSaveFormatFile( [path fileSystemRepresentation], _xmlLog, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );	
	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLong:'coTr'], NSFileHFSTypeCode, [NSNumber numberWithUnsignedLong:'coRC'], NSFileHFSCreatorCode, nil] atPath:path];
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
}

- (void) downloadLinkToDisk:(id) sender {
	NSURL *url = [[sender representedObject] objectForKey:@"WebElementLinkURL"];
	[[MVFileTransferController defaultManager] downloadFileAtURL:url toLocalFile:nil];
}

#pragma mark -
#pragma mark Styles

- (IBAction) changeChatStyle:(id) sender {
	JVStyle *style = [sender representedObject];
	if( ! style ) style = [JVStyle defaultStyle];

	[self setChatStyle:style withVariant:[style defaultVariantName]];
}

- (void) setChatStyle:(JVStyle *) style withVariant:(NSString *) variant {
	NSParameterAssert( style != nil );

	if( style == _chatStyle ) {
		if( ! [variant isEqualToString:_chatStyleVariant] )
			[self setChatStyleVariant:variant];
		return;
	}

	if( ! [_logLock tryLock] ) return;

	[display stopLoading:nil];

	_switchingStyles = YES;

	if( ! [self _usingSpecificEmoticons] ) {
		NSBundle *emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]]];
		[self setChatEmoticons:emoticon performRefresh:NO];
	}

	[_chatStyle autorelease];
	_chatStyle = [style retain];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _styleVariantChanged: ) name:JVStyleVariantChangedNotification object:_chatStyle];

	[_chatStyleVariant autorelease];
	_chatStyleVariant = [variant retain];

	[_styleParams autorelease];
	_styleParams = [[NSMutableDictionary dictionary] retain];

	// add single-quotes so that these are not interpreted as XPath expressions
	[_styleParams setObject:@"'/tmp/'" forKey:@"buddyIconDirectory"];
	[_styleParams setObject:@"'.tif'" forKey:@"buddyIconExtension"];

	NSString *timeFormatParameter = [NSString stringWithFormat:@"'%@'", [[NSUserDefaults standardUserDefaults] stringForKey:NSTimeFormatString]];
	[_styleParams setObject:timeFormatParameter forKey:@"timeFormat"];

	xmlSetProp( xmlDocGetRootElement( _xmlLog ), "style", [[_chatStyle identifier] UTF8String] );

	[self _changeChatStyleMenuSelection];

	[[display window] disableFlushWindow];

	[display setFrameLoadDelegate:self];
	[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
}

- (JVStyle *) chatStyle {
	return [[_chatStyle retain] autorelease];
}

#pragma mark -

- (IBAction) changeChatStyleVariant:(id) sender {
	JVStyle *style = [[sender representedObject] objectForKey:@"style"];
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];

	if( ! [style isEqualTo:_chatStyle] ) {
		[self setChatStyle:style withVariant:variant];
	} else {
		[self setChatStyleVariant:variant];
	}
}

- (void) setChatStyleVariant:(NSString *) variant {
	[_chatStyleVariant autorelease];
	_chatStyleVariant = [variant retain];

	[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"variantStyle\", \"%@\" );", [[_chatStyle variantStyleSheetLocationWithName:_chatStyleVariant] absoluteString]]];

	[self _changeChatStyleMenuSelection];
}

- (NSString *) chatStyleVariant {
	return [[_chatStyleVariant retain] autorelease];
}

#pragma mark -
#pragma mark Emoticons

- (IBAction) changeChatEmoticons:(id) sender {
	if( [sender representedObject] && ! [(NSString *)[sender representedObject] length] ) {
		[self setChatEmoticons:nil];
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "emoticon", "" );
		return;
	}

	NSBundle *emoticons = [NSBundle bundleWithIdentifier:[sender representedObject]];
	if( ! emoticons ) emoticons = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle identifier]]]];

	[self setChatEmoticons:emoticons];
}

- (void) setChatEmoticons:(NSBundle *) emoticons {
	[self setChatEmoticons:emoticons performRefresh:YES];
}

- (void) setChatEmoticons:(NSBundle *) emoticons performRefresh:(BOOL) refresh {
	[_chatEmoticons autorelease];
	_chatEmoticons = [emoticons retain];

	[_emoticonMappings autorelease];
	_emoticonMappings = [[NSDictionary dictionaryWithContentsOfFile:[self _chatEmoticonsMappingFilePath]] retain];

	xmlSetProp( xmlDocGetRootElement( _xmlLog ), "emoticon", [[_chatEmoticons bundleIdentifier] UTF8String] );

	if( refresh )
		[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"emoticonStyle\", \"%@\" );", [self _chatEmoticonsCSSFileURL]]];

	[self _updateChatEmoticonsMenu];
}

- (NSBundle *) chatEmoticons {
	return [[_chatEmoticons retain] autorelease];
}

#pragma mark -
#pragma mark Message Numbering

- (unsigned long) numberOfMessages {
	xmlXPathContextPtr ctx = xmlXPathNewContext( _xmlLog );
	if( ! ctx ) return 0;

	xmlXPathObjectPtr result = xmlXPathEval( "/log/envelope/message", ctx );
	if( ! result || ! result -> nodesetval ) return 0;

	unsigned long ret = result -> nodesetval -> nodeNr;

	xmlXPathFreeContext( ctx );
	xmlXPathFreeObject( result );

	return ret;
}

- (NSArray *) messages {
	if( [_messages containsObject:[NSNull null]] || [_messages count] < [self numberOfMessages] )
		[self messagesInRange:NSMakeRange( 0, [self numberOfMessages] )];
	return _messages;
}

- (JVChatMessage *) messageAtIndex:(unsigned long) index {
	NSArray *msgs = [self messagesInRange:NSMakeRange( index, 1 )];
	if( [msgs count] ) return [msgs objectAtIndex:0];
	return nil;
}

- (NSArray *) messagesInRange:(NSRange) range {
	xmlXPathContextPtr ctx = xmlXPathNewContext( _xmlLog );
	if( ! ctx ) return nil;
	
 /* We need to discover all messages which are children of envelope, within the specified range. 
	We don't have a counter attribute to work with, and the Xpath position() doesn't help us - we need 
	to get a Nodeset, and then apply the range to that.
	Note that the nodeset is unsorted by default. */

	xmlXPathObjectPtr result = xmlXPathEval("/log/envelope/message", ctx );
	if( ! result || ! result -> nodesetval )
		return nil;

	xmlXPathNodeSetSort( result -> nodesetval ); // now sort the resultant nodeset in document order

	unsigned int i = 0;

	if( [_messages count] < range.location )
		for( i = [_messages count]; i < range.location; i++ )
			[_messages insertObject:[NSNull null] atIndex:i];

	xmlNodePtr node = NULL;
	unsigned int size = result -> nodesetval -> nodeNr;
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:size];
	JVChatMessage *msg = nil;

	for( i = range.location; i < ( range.location + range.length ); i++ ) {
		node = result -> nodesetval -> nodeTab[i];
		if( ! node ) continue;
		if( [_messages count] > (i) && [[_messages objectAtIndex:(i)] isKindOfClass:[NSNull class]] ) {
			msg = [JVChatMessage messageWithNode:node messageIndex:i andTranscript:self];
			[_messages replaceObjectAtIndex:(i) withObject:msg];
		} else if( [_messages count] > (i) && [[_messages objectAtIndex:(i)] isKindOfClass:[JVChatMessage class]] ) {
			msg = [_messages objectAtIndex:(i)];
		} else if( [_messages count] == (i) ) {
			msg = [JVChatMessage messageWithNode:node messageIndex:i andTranscript:self];
			[_messages insertObject:msg atIndex:(i)];
		} else continue;
		if( msg ) [ret addObject:msg];
	}

	xmlXPathFreeContext( ctx );
	xmlXPathFreeObject( result );
	return ret;
}

#pragma mark -
#pragma mark Toolbar Methods

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Chat Transcript"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

	if( [identifier isEqualToString:JVToolbarToggleChatDrawerItemIdentifier] ) {
		toolbarItem = [_windowController toggleChatDrawerToolbarItem];
	} else if( [identifier isEqualToString:JVToolbarToggleChatActivityItemIdentifier] ) {
//		toolbarItem = [_windowController chatActivityToolbarItem];
	} else if( [identifier isEqualToString:JVToolbarChooseStyleItemIdentifier] && ! willBeInserted ) {
		[toolbarItem setLabel:NSLocalizedString( @"Style", "choose style toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Style", "choose style toolbar item patlette label" )];
		[toolbarItem setImage:[NSImage imageNamed:@"chooseStyle"]];
	} else if( [identifier isEqualToString:JVToolbarChooseStyleItemIdentifier] && willBeInserted ) {
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
	} else if( [identifier isEqualToString:JVToolbarEmoticonsItemIdentifier] && ! willBeInserted ) {
		[toolbarItem setLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item patlette label" )];
		[toolbarItem setImage:[NSImage imageNamed:@"emoticon"]];
	} else if( [identifier isEqualToString:JVToolbarEmoticonsItemIdentifier] && willBeInserted ) {
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
	} else toolbarItem = nil;

	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarToggleChatDrawerItemIdentifier/*, JVToolbarToggleChatActivityItemIdentifier */, 
		JVToolbarChooseStyleItemIdentifier, 
		JVToolbarEmoticonsItemIdentifier, nil];
	return [[list retain] autorelease];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects: JVToolbarToggleChatDrawerItemIdentifier/*, JVToolbarToggleChatActivityItemIdentifier */, 
		JVToolbarChooseStyleItemIdentifier, JVToolbarEmoticonsItemIdentifier, NSToolbarShowColorsItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];

	return [[list retain] autorelease];
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqualToString:NSToolbarShowColorsItemIdentifier] ) return NO;
	else if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqualToString:NSToolbarShowColorsItemIdentifier] ) return YES;
	return YES;
}

#pragma mark -
#pragma mark WebView

// Allows some simple code to work when not built with WebKit/Safari 1.3
#ifndef _WEB_SCRIPT_OBJECT_H_
#define WebMenuItemTagGoBack 9
#define WebMenuItemTagGoForward 10
#define WebMenuItemTagStop 11
#define WebMenuItemTagReload 12
#endif

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	NSMutableArray *ret = [[defaultMenuItems mutableCopy] autorelease];
	NSMenuItem *item = nil;
	unsigned i = 0;
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
	if( ! object ) object = [(id <WebDocumentText>)[[[display mainFrame] frameView] documentView] selectedString];

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	[invocation setArgument:&object atIndex:2];
	[invocation setArgument:&self atIndex:3];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	if( [results count] ) {
		if( [ret count] ) [ret addObject:[NSMenuItem separatorItem]];

		NSArray *items = nil;
		NSEnumerator *enumerator = [results objectEnumerator];
		while( ( items = [enumerator nextObject] ) ) {
			if( ! [items respondsToSelector:@selector( objectEnumerator )] ) continue;
			NSEnumerator *ienumerator = [items objectEnumerator];
			while( ( item = [ienumerator nextObject] ) )
				if( [item isKindOfClass:[NSMenuItem class]] ) [ret addObject:item];
		}

		if( [[ret lastObject] isSeparatorItem] )
			[ret removeObjectIdenticalTo:[ret lastObject]];
	}

	return ret;
}

- (unsigned) webView:(WebView *) webView dragSourceActionMaskForPoint:(NSPoint) point {
	return UINT_MAX; // WebDragSourceActionAny
}

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_2
#define NSWorkspaceLaunchWithoutActivation 0x00000200
#endif

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];

	if( [[url scheme] isEqualToString:@"about"] ) {
		if( [[[url standardizedURL] path] length] ) [listener ignore];
		else [listener use];
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
			if( [url isChatURL] ) {
				[[MVConnectionsController defaultManager] handleURL:url andConnectIfPossible:YES];
			} else if( [[actionInformation objectForKey:WebActionModifierFlagsKey] unsignedIntValue] & NSAlternateKeyMask ) {
				[[MVFileTransferController defaultManager] downloadFileAtURL:url toLocalFile:nil];
			} else {
				if( ( [[actionInformation objectForKey:WebActionModifierFlagsKey] unsignedIntValue] & NSCommandKeyMask ) && [[NSWorkspace sharedWorkspace] respondsToSelector:@selector( openURLs:withAppBundleIdentifier:options:additionalEventParamDescriptor:launchIdentifiers: )] ) {
					[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url] withAppBundleIdentifier:nil options:NSWorkspaceLaunchWithoutActivation additionalEventParamDescriptor:nil launchIdentifiers:nil];
				} else {
					[[NSWorkspace sharedWorkspace] openURL:url];
				}
			}
		}

		[listener ignore];
	}
}

- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
// Test for WebKit/Safari 1.3
#ifdef _WEB_SCRIPT_OBJECT_H_
	if( [display respondsToSelector:@selector( setDrawsBackground: )] ) {
		DOMCSSStyleDeclaration *style = [sender computedStyleForElement:[(DOMHTMLDocument *)[[sender mainFrame] DOMDocument] body] pseudoElement:nil];
		DOMCSSValue *value = [style getPropertyCSSValue:@"background-color"];
		DOMCSSValue *altvalue = [style getPropertyCSSValue:@"background"];
		if( ( value && [[value cssText] rangeOfString:@"rgba"].location != NSNotFound ) || ( altvalue && [[altvalue cssText] rangeOfString:@"rgba"].location != NSNotFound ) )
			[display setDrawsBackground:NO]; // allows rgba backgrounds to see through to the Desktop
		else [display setDrawsBackground:YES];
	}
#endif

	[display setPreferencesIdentifier:[_chatStyle identifier]];
	[[display preferences] setJavaScriptEnabled:YES];

	if( [[display window] isFlushWindowDisabled] )
		[[display window] enableFlushWindow];

	[display setFrameLoadDelegate:nil];

	NSScrollView *scrollView = [[[[display mainFrame] frameView] documentView] enclosingScrollView];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setAllowsHorizontalScrolling:NO];

	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		NSRect scrollerFrame = [[scrollView verticalScroller] frame];
		NSScroller *oldScroller = scroller;
		scroller = [[[JVMarkedScroller alloc] initWithFrame:scrollerFrame] autorelease];
		[scroller setFloatValue:[oldScroller floatValue] knobProportion:[oldScroller knobProportion]];
		[scrollView setVerticalScroller:scroller];
	}

	if( _switchingStyles )
		[NSThread detachNewThreadSelector:@selector( _switchStyle: ) toTarget:self withObject:nil];
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptPrivate)
#pragma mark Style Support

- (void) _reloadCurrentStyle:(id) sender {
	JVStyle *style = [[_chatStyle retain] autorelease];

	[WebCoreCache empty];

	[style reload];

	[_chatStyle autorelease];
	_chatStyle = nil;

	[self setChatStyle:style withVariant:_chatStyleVariant];

	if( ! _chatStyle ) _chatStyle = [style retain];
}

- (void) _switchingStyleEnded:(id) sender {
	_switchingStyles = NO;
	[_logLock unlock];
	return;

	NSScrollView *scrollView = [[[[display mainFrame] frameView] documentView] enclosingScrollView];
	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		[scroller removeAllMarks];

		xmlXPathContextPtr ctx = xmlXPathNewContext( _xmlLog );
		if( ! ctx ) return;

		xmlXPathObjectPtr result = xmlXPathEval( "/log/envelope/message[@highlight = 'yes']/..", ctx );
		if( ! result ) {
			xmlXPathFreeContext( ctx );
			return;
		}

		xmlNodePtr cur = NULL;
		unsigned int c = ( result -> nodesetval ? result -> nodesetval -> nodeNr : 0 );
		unsigned int i = 0;
		for( i = 0; i < c; i++ ) {
			cur = result -> nodesetval -> nodeTab[i];
			xmlChar *idProp = xmlGetProp( cur, "id" );
			unsigned int loc = [[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"locationOfMessage( \"%s\" );", idProp]] intValue];
			if( loc ) [(JVMarkedScroller *)[[[[[display mainFrame] frameView] documentView] enclosingScrollView] verticalScroller] addMarkAt:loc];
			xmlFree( idProp );
		}

		xmlXPathFreeContext( ctx );
		xmlXPathFreeObject( result );
	}
}

- (oneway void) _switchStyle:(id) sender {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	unsigned long elements = xmlChildElementCount( xmlDocGetRootElement( _xmlLog ) );
	unsigned long i = elements;
	xmlNodePtr startNode = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
	NSString *result = nil;

	usleep( 5000 ); // wait a little bit for WebKit since it just loaded

	for( i = elements; i > ( elements - MIN( 600, elements ) ) && startNode; i -= MIN( 25, i ) ) {
		unsigned int j = 25;
		xmlNodePtr node = startNode;
		xmlNodePtr nextNode = startNode -> next;
		xmlNodePtr nodeList = NULL;

		startNode -> next = NULL;

		while( j > 0 && node -> prev ) {
			if( node -> type == XML_ELEMENT_NODE ) j--;
			node = node -> prev;
		}

		xmlNodePtr root = xmlNewNode( NULL, "log" );
		xmlDocPtr doc = xmlNewDoc( "1.0" );
		xmlDocSetRootElement( doc, root );

		nodeList = xmlCopyNodeList( node );
		xmlAddChildList( root, nodeList );

		@try {
			result = [_chatStyle transformXMLDocument:doc withParameters:_styleParams];
		} @catch ( NSException *exception ) {
			result = nil;
			[self performSelectorOnMainThread:@selector( _styleError: ) withObject:exception waitUntilDone:YES];
		}

		xmlFreeDoc( doc );

		startNode -> next = nextNode;
		startNode = node -> prev;

		if( result ) {
			[self performSelectorOnMainThread:@selector( _prependMessages: ) withObject:result waitUntilDone:YES];
			usleep( 100000 ); // wait for WebKit to render the chunk
		} else goto finish;
	}

finish:
	[self performSelectorOnMainThread:@selector( _switchingStyleEnded: ) withObject:nil waitUntilDone:YES];
	[pool release];
}

- (void) _prependMessages:(NSString *) messages {
	if( [[display mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
#ifdef _WEB_SCRIPT_OBJECT_H_
		NSMutableString *result = [messages mutableCopy];
		[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];

		// check if we are near the bottom of the chat area, and if we should scroll down later
		NSNumber *scrollNeeded = [[[display mainFrame] DOMDocument] evaluateWebScript:@"( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) )"];

		// parses the message so we can get the DOM tree
		DOMHTMLElement *element = (DOMHTMLElement *)[[[display mainFrame] DOMDocument] createElement:@"span"];
		[element setInnerHTML:result];

		[result release];
		result = nil;

		DOMHTMLElement *body = [(DOMHTMLDocument *)[[display mainFrame] DOMDocument] body];
		DOMNode *firstMessage = [body firstChild];

		while( [[element children] length] ) { // append all children
			if( firstMessage ) [body insertBefore:[element firstChild] :firstMessage];
			else [body appendChild:[element firstChild]];
		}

		// scroll down if we need to
		if( [scrollNeeded boolValue] ) [body setValue:[body valueForKey:@"offsetHeight"] forKey:@"scrollTop"];
#endif
	} else {
		NSMutableString *result = [messages mutableCopy];
		[result escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[result replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];
		[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];
		[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"prependMessages( \"%@\" );", result]];
		[result release];
	}
}

- (void) _styleError:(NSException *) exception {
	NSRunCriticalAlertPanel( NSLocalizedString( @"An internal Style error occurred.", "the stylesheet parse failed" ), NSLocalizedString( @"The %@ Style has been damaged or has an internal error preventing new messages from displaying. Please contact the %@ author about this.", "the style contains and error" ), @"OK", nil, nil, [_chatStyle displayName], [_chatStyle displayName] );
}

- (NSMenu *) _stylesMenu {
	return [[_styleMenu retain] autorelease];
}

- (void) _changeChatStyleMenuSelection {
	NSEnumerator *enumerator = [[_styleMenu itemArray] objectEnumerator];
	NSMenuItem *menuItem = nil;
	BOOL hasPerRoomStyle = [self _usingSpecificStyle];

	while( ( menuItem = [enumerator nextObject] ) ) {
		if( [menuItem tag] != 5 ) continue;

		if( [_chatStyle isEqualTo:[menuItem representedObject]] && hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( ! [menuItem representedObject] && ! hasPerRoomStyle ) [menuItem setState:NSOnState];
		else if( [_chatStyle isEqualTo:[menuItem representedObject]] && ! hasPerRoomStyle ) [menuItem setState:NSMixedState];
		else [menuItem setState:NSOffState];

		NSEnumerator *senumerator = [[[menuItem submenu] itemArray] objectEnumerator];
		NSMenuItem *subMenuItem = nil;
		while( ( subMenuItem = [senumerator nextObject] ) ) {
			JVStyle *style = [[subMenuItem representedObject] objectForKey:@"style"];
			NSString *variant = [[subMenuItem representedObject] objectForKey:@"variant"];
			if( [subMenuItem action] == @selector( changeChatStyleVariant: ) && [_chatStyle isEqualTo:style] && ( [_chatStyleVariant isEqualToString:variant] || ( ! _chatStyleVariant && ! variant ) ) ) 
				[subMenuItem setState:NSOnState];
			else [subMenuItem setState:NSOffState];
		}
	}
}

- (void) _updateChatStylesMenu {
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;

	if( ! ( menu = _styleMenu ) ) {
		menu = [[NSMenu alloc] initWithTitle:NSLocalizedString( @"Style", "choose style toolbar menu title" )];
		_styleMenu = menu;
	} else {
		NSEnumerator *enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];
		while( ( menuItem = [enumerator nextObject] ) )
			if( [menuItem tag] || [menuItem isSeparatorItem] )
				[menu removeItem:menuItem];
	}

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Default", "default style menu item title" ) action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
	[menuItem setTag:5];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:nil];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	NSEnumerator *enumerator = [[[[JVStyle styles] allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
	NSEnumerator *venumerator = nil;
	JVStyle *style = nil;
	id item = nil;

	while( ( style = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[style displayName] action:@selector( changeChatStyle: ) keyEquivalent:@""] autorelease];
		[menuItem setTag:5];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:style];
		[menu addItem:menuItem];

		NSArray *variants = [style variantStyleSheetNames];
		NSArray *userVariants = [style userVariantStyleSheetNames];

		if( [variants count] || [userVariants count] ) {
			subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

			subMenuItem = [[[NSMenuItem alloc] initWithTitle:[style mainVariantDisplayName] action:@selector( changeChatStyleVariant: ) keyEquivalent:@""] autorelease];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", nil]];
			[subMenu addItem:subMenuItem];

			venumerator = [variants objectEnumerator];
			while( ( item = [venumerator nextObject] ) ) {
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( changeChatStyleVariant: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", item, @"variant", nil]];
				[subMenu addItem:subMenuItem];
			}

			if( [userVariants count] ) [subMenu addItem:[NSMenuItem separatorItem]];

			venumerator = [userVariants objectEnumerator];
			while( ( item = [venumerator nextObject] ) ) {
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( changeChatStyleVariant: ) keyEquivalent:@""] autorelease];
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

	[self _changeChatStyleMenuSelection];
}

- (BOOL) _usingSpecificStyle {
	return ( xmlHasProp( xmlDocGetRootElement( _xmlLog ), "style" ) ? YES : NO );
}

- (void) _styleVariantChanged:(NSNotification *) notification {
	if( [[[notification userInfo] objectForKey:@"variant"] isEqualToString:_chatStyleVariant] )
		[self setChatStyleVariant:[[notification userInfo] objectForKey:@"variant"]];
}

#pragma mark -
#pragma mark Emoticons Support

+ (void) _scanForEmoticons {
	extern NSMutableSet *JVChatEmoticonBundles;
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	[JVChatEmoticonBundles removeAllObjects];

	if( ! JVChatEmoticonBundles )
		JVChatEmoticonBundles = [[NSMutableSet set] retain];

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

	[[NSNotificationCenter defaultCenter] postNotificationName:JVChatEmoticonsScannedNotification object:JVChatEmoticonBundles]; 
}

- (NSMenu *) _emoticonsMenu {
	if( [_emoticonMenu itemWithTag:20] )
		return [[_emoticonMenu itemWithTag:20] submenu];
	return [[_emoticonMenu retain] autorelease];
}

- (void) _changeChatEmoticonsMenuSelection {
	NSEnumerator *enumerator = nil;
	NSMenuItem *menuItem = nil;
	BOOL hasPerRoomEmoticons = [self _usingSpecificEmoticons];
	NSString *emoticons = [_chatEmoticons bundleIdentifier];

	enumerator = [[[[_emoticonMenu itemWithTag:20] submenu] itemArray] objectEnumerator];
	if( ! enumerator ) enumerator = [[_emoticonMenu itemArray] objectEnumerator];
	while( ( menuItem = [enumerator nextObject] ) ) {
		if( [menuItem tag] ) continue;
		if( [menuItem representedObject] && ! [(NSString *)[menuItem representedObject] length] && ! _chatEmoticons && hasPerRoomEmoticons ) [menuItem setState:NSOnState];
		else if( [emoticons isEqualToString:[menuItem representedObject]] && hasPerRoomEmoticons ) [menuItem setState:NSOnState];
		else if( ! [menuItem representedObject] && ! hasPerRoomEmoticons ) [menuItem setState:NSOnState];
		else if( [menuItem representedObject] && ! [(NSString *)[menuItem representedObject] length] && ! _chatEmoticons && ! hasPerRoomEmoticons ) [menuItem setState:NSMixedState];
		else if( [emoticons isEqualToString:[menuItem representedObject]] && ! hasPerRoomEmoticons ) [menuItem setState:NSMixedState];
		else [menuItem setState:NSOffState];
	}
}

- (void) _updateChatEmoticonsMenu {
	extern NSMutableSet *JVChatEmoticonBundles;
	NSEnumerator *enumerator = nil;
	NSMenu *menu = nil;
	NSMenuItem *menuItem = nil;
	BOOL new = YES;
	NSBundle *emoticon = nil;

	if( ! ( menu = _emoticonMenu ) ) {
		menu = [[NSMenu alloc] initWithTitle:@""];
		_emoticonMenu = menu;
	} else {
		NSEnumerator *enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];
		new = NO;
		while( ( menuItem = [enumerator nextObject] ) )
			[menu removeItem:menuItem];
	}

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Text Only", "text only emoticons menu item title" ) action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:@""];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	enumerator = [[[JVChatEmoticonBundles allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
	while( ( emoticon = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[emoticon bundleIdentifier]];
		[menu addItem:menuItem];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setTag:10];
	[menu addItem:menuItem];

	[self _changeChatEmoticonsMenuSelection];
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

- (IBAction) _openAppearancePreferences:(id) sender {
	[[NSPreferences sharedPreferences] showPreferencesPanelForOwner:[JVAppearancePreferences sharedInstance]];
}

- (BOOL) _usingSpecificEmoticons {
	return ( xmlHasProp( xmlDocGetRootElement( _xmlLog ), "emoticon" ) ? YES : NO );
}

#pragma mark -
#pragma mark Web View Template

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html {
	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	return [NSString stringWithFormat:shell, [self title], [self _chatEmoticonsCSSFileURL], [[_chatStyle mainStyleSheetLocation] absoluteString], [[_chatStyle variantStyleSheetLocationWithName:_chatStyleVariant] absoluteString], [[_chatStyle baseLocation] absoluteString], [_chatStyle contentsOfHeaderFile], html];
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptScripting)
- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (JVChatMessage *) valueInMessagesAtIndex:(unsigned) index {
	return [self messageAtIndex:index];
}

#pragma mark -

- (void) saveScriptCommand:(NSScriptCommand *) command {
	NSString *path = [[command evaluatedArguments] objectForKey:@"File"];

	if( ! [[path pathComponents] count] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid path."];
		return;
	}

	[self saveTranscriptTo:path];
}
@end

#pragma mark -

@implementation MVChatScriptPlugin (MVChatScriptPluginLinkClickSupport)
- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:[url absoluteString], @"----", view, @"hCl1", nil];
	id result = [self callScriptHandler:'hClX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}
@end