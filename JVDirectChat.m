#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import <libiconv/iconv.h>
#import <libxml/xmlmemory.h>
#import <libxml/debugXML.h>
#import <libxml/HTMLtree.h>
#import <libxml/xmlIO.h>
#import <libxml/DOCBparser.h>
#import <libxml/xinclude.h>
#import <libxml/catalog.h>
#import <libxslt/xslt.h>
#import <libxslt/xsltInternals.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import "JVChatController.h"
#import "JVDirectChat.h"
#import "MVChatConnection.h"
#import "MVChatPluginManager.h"
#import "MVTextView.h"
#import "MVMenuButton.h"
#import "NSAttributedStringAdditions.h"
#import "NSStringAdditions.h"

static NSMutableSet *JVChatStyleBundles = nil;
static NSMutableSet *JVChatEmoticonBundles = nil;

extern char *irc_html_to_irc(const char * const string);
extern char *irc_irc_to_html(const char * const string);

static NSString *JVToolbarChooseStyleItemIdentifier = @"JVToolbarChooseStyleItem";

NSComparisonResult sortChatStyles( id style1, id style2, void *context ) {
	JVDirectChat *self = context;
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

@interface JVDirectChat (JVDirectChatPrivate)
- (void) _makeHyperlinksInString:(NSMutableString *) string;
- (void) _breakLongLinesInString:(NSMutableString *) string;
- (void) _preformEmoticonSubstitutionOnString:(NSMutableString *) string;
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

@implementation JVDirectChat
- (id) init {
	extern NSMutableSet *JVChatStyleBundles;
	extern NSMutableSet *JVChatEmoticonBundles;

	if( ( self = [super init] ) ) {
		display = nil;
		contents = nil;
		send = nil;
		chooseStyle = nil;
		_messageId = 0;
		_target = nil;
		_connection = nil;
		_firstMessage = YES;
		_newMessage = NO;
		_newHighlightMessage = NO;
		_cantSendMessages = NO;
		_isActive = NO;
		_historyIndex = 0;
		_chatStyle = nil;
		_chatStyleVariant = nil;
		_chatEmoticons = nil;
		_emoticonMappings = nil;
		_chatXSLStyle = NULL;
		_windowController = nil;
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

		_encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatEncoding"];

		_sendHistory = [[NSMutableArray array] retain];
		[_sendHistory insertObject:[[[NSAttributedString alloc] initWithString:@""] autorelease] atIndex:0];

		_waitingAlerts = [[NSMutableArray array] retain];
		_waitingAlertNames = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}

- (id) initWithTarget:(NSString *) target forConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		NSString *source = nil;
		_target = [target copy];
		_connection = [connection retain];
		source = [NSString stringWithFormat:@"%@/%@", [[[self connection] url] absoluteString], _target];
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "source", [source UTF8String] );

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:connection];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didDisconnect: ) name:MVChatConnectionDidDisconnectNotification object:connection];
	}
	return self;
}

- (void) awakeFromNib {
	NSString *prefStyle = [NSString stringWithFormat:@"chat.style.%@.%@", [[self connection] server], _target];
	NSBundle *style = nil;
	NSString *variant = nil;
	NSView *toolbarItemContainerView = nil;

	if( prefStyle ) {
		style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:prefStyle]];
		if( ! style ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:prefStyle];
	}

	if( ! style )
		style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];

	if( ! style ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
		style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	}

	variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"chat.style.%@.%@ %@ variant", [[self connection] server], _target, [style bundleIdentifier]]];
	if( ! variant ) variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@ variant", [style bundleIdentifier]]];

	[display setMaintainsBackForwardList:NO];
	[display setPolicyDelegate:self];
	[display setHostWindow:[_windowController window]];

	[self setChatEmoticons:[NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"]]];
	[self setChatStyle:style withVariant:variant];

	[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
	[[[[[display mainFrame] frameView] documentView] enclosingScrollView] setAllowsHorizontalScrolling:NO];

	toolbarItemContainerView = [chooseStyle superview];

    [chooseStyle retain];
    [chooseStyle removeFromSuperview];

	[toolbarItemContainerView autorelease];

	[self _updateChatStylesMenu];

	[send setHorizontallyResizable:YES];
	[send setVerticallyResizable:YES];
	[send setAutoresizingMask:NSViewWidthSizable];
	[send setSelectable:YES];
	[send setEditable:YES];
	[send setRichText:YES];
	[send setImportsGraphics:NO];
	[send setUsesFontPanel:NO];
	[send setUsesRuler:NO];
	[send setDelegate:self];
    [send setContinuousSpellCheckingEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSpellChecking"]];
	[send reset:nil];
}

- (void) dealloc {
	extern NSMutableSet *JVChatStyleBundles;
	extern NSMutableSet *JVChatEmoticonBundles;
	NSEnumerator *enumerator = nil;
	id alert = nil;

	[contents autorelease];
	[chooseStyle autorelease];
	[_target autorelease];
	[_connection autorelease];
	[_sendHistory autorelease];
	[_chatStyle autorelease];
	[_chatStyleVariant autorelease];
	[_chatEmoticons autorelease];
	[_emoticonMappings autorelease];
	[_waitingAlertNames autorelease];

	[JVChatStyleBundles autorelease];
	[JVChatEmoticonBundles autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	enumerator = [_waitingAlerts objectEnumerator];
	while( ( alert = [enumerator nextObject] ) )
		NSReleaseAlertPanel( alert );

	[_waitingAlerts release];

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
	_target = nil;
	_sendHistory = nil;
	_connection = nil;
	_chatStyle = nil;
	_chatStyleVariant = nil;
	_chatEmoticons = nil;
	_emoticonMappings = nil;
	_windowController = nil;
	_waitingAlerts = nil;
	_waitingAlertNames = nil;

	[super dealloc];
}

#pragma mark -

- (NSString *) target {
	return [[_target retain] autorelease];
}

- (MVChatConnection *) connection {
	return [[_connection retain] autorelease];
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
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVDirectChat" owner:self];
	return contents;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"chat.directChat"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

#pragma mark -

- (NSString *) title {
	return [[_target retain] autorelease];
}

- (NSString *) windowTitle {
	return [NSString stringWithFormat:NSLocalizedString( @"%@ - Private Message", "private message with user - window title" ), _target];
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

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:NULL keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFileToSelectedUser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Leave Chat", "leave chat contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"messageUser"];
}

- (NSImage *) statusImage {
	return ( _isActive ? nil : ( [_waitingAlerts count] ? [NSImage imageNamed:@"viewAlert"] : ( _newMessage ? ( _newHighlightMessage ? [NSImage imageNamed:@"newHighlightMessage"] : [NSImage imageNamed:@"newMessage"] ) : nil ) ) );
}

#pragma mark -

- (void) didUnselect {
	_newMessage = NO;
	_newHighlightMessage = NO;
	_isActive = NO;
}

- (void) didSelect {
	_newMessage = NO;
	_newHighlightMessage = NO;
	_isActive = YES;
	if( [_waitingAlerts count] ) {
		[[NSApplication sharedApplication] beginSheet:[_waitingAlerts objectAtIndex:0] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	}
}

#pragma mark -

- (void) setTarget:(NSString *) target {
	[_target autorelease];
	_target = [target copy];
	[_windowController reloadChatView:self];
}

#pragma mark -

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name {
	if( _isActive && ! [[_windowController window] attachedSheet] ) {
		if( alert ) [[NSApplication sharedApplication] beginSheet:alert modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	} else {
		if( name && [_waitingAlertNames objectForKey:name] ) {
			NSPanel *sheet = [[[_waitingAlertNames objectForKey:name] retain] autorelease];
			if( alert ) {
				[_waitingAlerts replaceObjectAtIndex:[_waitingAlerts indexOfObjectIdenticalTo:[_waitingAlertNames objectForKey:name]] withObject:alert];
				[_waitingAlertNames setObject:alert forKey:name];
			} else {
				[_waitingAlerts removeObjectAtIndex:[_waitingAlerts indexOfObjectIdenticalTo:[_waitingAlertNames objectForKey:name]]];
				[_waitingAlertNames removeObjectForKey:name];
			}
			NSReleaseAlertPanel( sheet );
		} else {
			if( name && alert ) [_waitingAlertNames setObject:alert forKey:name];
			if( alert ) [_waitingAlerts addObject:alert];
		}
	}
	[_windowController reloadChatView:self];
}

#pragma mark -

- (IBAction) saveDocumentTo:(id) sender {
	NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
	[savePanel setDelegate:self];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:@"colloquyTranscript"];
	[savePanel beginSheetForDirectory:NSHomeDirectory() file:_target modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( savePanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSString *source = [NSString stringWithFormat:@"%@/%@", [[[self connection] url] absoluteString], _target];
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "ended", [[[NSDate date] description] UTF8String] );
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "source", [source UTF8String] );
		xmlSaveFormatFile( [[sheet filename] fileSystemRepresentation], _xmlLog, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[sheet isExtensionHidden]], NSFileExtensionHidden, nil] atPath:[sheet filename]];
		xmlUnsetProp( xmlDocGetRootElement( _xmlLog ), "ended" );
	}
}

#pragma mark -

- (IBAction) changeChatStyle:(id) sender {
	NSBundle *style = [NSBundle bundleWithIdentifier:[sender representedObject]];
	NSString *key = [NSString stringWithFormat:@"chat.style.%@.%@", [[self connection] server], _target];
	if( style ) {
		[[NSUserDefaults standardUserDefaults] setObject:[style bundleIdentifier] forKey:key];
	} else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
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
	NSString *key = [NSString stringWithFormat:@"chat.style.%@.%@ %@ variant", [[self connection] server], _target, [style bundleIdentifier]];

	if( variant ) [[NSUserDefaults standardUserDefaults] setObject:variant forKey:key];
	else [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];

	if( style != _chatStyle ) {
		[[NSUserDefaults standardUserDefaults] setObject:[style bundleIdentifier] forKey:[NSString stringWithFormat:@"chat.style.%@.%@", [[self connection] server], _target]];
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
/*	NSBundle *style = [NSBundle bundleWithIdentifier:[sender representedObject]];
	NSString *key = [NSString stringWithFormat:@"chat.style.%@.%@", [[self connection] server], _target];
	if( style ) {
		[[NSUserDefaults standardUserDefaults] setObject:[style bundleIdentifier] forKey:key];
	} else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
		style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	}
	[self setChatStyle:style];*/
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

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes {
	NSEnumerator *enumerator = nil, *kenumerator = nil;
	NSString *key = nil, *value = nil;
	xmlDocPtr doc = NULL, msgDoc = NULL;
	xmlNodePtr root = NULL, child = NULL;
	const char *msgStr = NULL;

	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] );

	doc = xmlNewDoc( "1.0" );
	root = xmlNewNode( NULL, "event" );
	xmlSetProp( root, "name", [name UTF8String] );
	xmlSetProp( root, "occurred", [[[NSDate date] description] UTF8String] );
	xmlDocSetRootElement( doc, root );

	if( message ) {
		msgStr = [[NSString stringWithFormat:@"<message>%@</message>", message] UTF8String];
		if( msgStr ) {
			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}
	}

	kenumerator = [attributes keyEnumerator];
	enumerator = [attributes objectEnumerator];
	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) && ! [value isMemberOfClass:[NSNull class]] ) {
		msgStr = [[NSString stringWithFormat:@"<%@>%@</%@>", key, value, key] UTF8String];
		if( msgStr ) {
			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}
	}

	xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( root, _xmlLog, 1 ) );

//	xmlDocFormatDump( stdout, doc, 1 );

	xmlFreeDoc( doc );
}

#pragma mark -

- (void) addMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action {
	BOOL highlight = NO;
	xmlDocPtr doc = NULL, msgDoc = NULL;
	xmlNodePtr root = NULL, child = NULL;
	const char *msgStr = NULL;
	NSMutableString *messageString = nil;

	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	messageString = [[[NSMutableString alloc] initWithData:message encoding:_encoding] autorelease];

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
		[self _makeHyperlinksInString:messageString];

	[self _preformEmoticonSubstitutionOnString:messageString];

	if( [messageString rangeOfString:@"\007"].length )
		[messageString replaceOccurrencesOfString:@"\007" withString:@"&#266A;" options:NSLiteralSearch range:NSMakeRange( 0, [messageString length] )];

	if( ! [user isEqualToString:[[self connection] nickname]] ) {
		NSEnumerator *enumerator = nil;
		NSMutableArray *names = nil;
		id item = nil;

//		if( _firstMessage ) MVChatPlaySoundForAction( @"MVChatFisrtMessageAction" );
//		if( ! _firstMessage ) MVChatPlaySoundForAction( @"MVChatAdditionalMessagesAction" );
//		if( [messageString rangeOfString:@"\007"].length ) MVChatPlaySoundForAction( @"MVChatInlineMessageBeepAction" );

		names = [[[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"MVChatHighlightNames"] mutableCopy] autorelease];
		[names addObject:[[self connection] nickname]];
		enumerator = [names objectEnumerator];
		while( ( item = [enumerator nextObject] ) ) {
			if( [[messageString lowercaseString] rangeOfString:item].length ) {
				MVChatPlaySoundForAction( @"MVChatMentionedAction" );
				_newHighlightMessage = YES;
				highlight = YES;
				break;
			}
		}

//		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconUntilFront"] )
//			[[NSApplication sharedApplication] requestUserAttention:NSCriticalRequest];
//		else [[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
	}

	doc = xmlNewDoc( "1.0" );
	root = xmlNewNode( NULL, "envelope" );
	xmlSetProp( root, "count", [[NSString stringWithFormat:@"%d", _messageId++] UTF8String] );
	xmlSetProp( root, "received", [[[NSDate date] description] UTF8String] );
	xmlDocSetRootElement( doc, root );

	child = xmlNewTextChild( root, NULL, "sender", [user UTF8String] );
	if( ! [user caseInsensitiveCompare:[[self connection] nickname]] ) xmlSetProp( child, "self", "yes" );

	msgStr = [[NSString stringWithFormat:@"<message>%@</message>", messageString] UTF8String];
	msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );

	child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
	if( action ) xmlSetProp( child, "action", "yes" );
	if( highlight ) xmlSetProp( child, "highlight", "yes" );
	xmlAddChild( root, child );

	xmlFreeDoc( msgDoc );

	xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( root, _xmlLog, 1 ) );

	if( _firstMessage ) {
		[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:[self _applyStyleOnXMLDocument:doc]] baseURL:nil];
	} else {
		messageString = [[[self _applyStyleOnXMLDocument:doc] mutableCopy] autorelease];
		[messageString replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange( 0, [messageString length] )];
		[messageString replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [messageString length] )];
		[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"documentAppend( \"%@\" ); scrollToBottom();", messageString]];
	}

//	xmlDocFormatDump( stdout, doc, 1 );
//	NSLog( [self _applyStyleOnXMLDocument:doc] );
//	NSLog( @"%@", [self _fullDisplayHTMLWithBody:@""] );

	xmlFreeDoc( doc );

	_newMessage = YES;
	_firstMessage = NO;

	[_windowController reloadChatView:self];

//	if( NSMinY( [[[display mainFrame] frameView] visibleRect] ) >= ( NSHeight( [[[display mainFrame] frameView] bounds] ) - ( NSHeight( [[[display mainFrame] frameView] visibleRect] ) * 1.1 ) ) )
//	[[[[display mainFrame] frameView] documentView] scrollPoint:NSMakePoint( 0., NSHeight( [[[[display mainFrame] frameView] documentView] bounds] ) )];
}

#pragma mark -

- (IBAction) send:(id) sender {
	NSMutableAttributedString *subMsg = nil;
	BOOL action = NO;
	NSRange range;

	if( ! [[self connection] isConnected] || _cantSendMessages ) return;

	_historyIndex = 0;
	if( ! [[send textStorage] length] ) return;
	if( [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[NSAttributedString alloc] initWithString:@""] autorelease]];
	[_sendHistory insertObject:[[[send textStorage] copy] autorelease] atIndex:1];
	if( [_sendHistory count] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatMaximumHistory"] unsignedIntValue] )
		[_sendHistory removeObjectAtIndex:[_sendHistory count] - 1];

	if( [sender isKindOfClass:[NSNumber class]] && [sender boolValue] ) action = YES;

	[[[send textStorage] mutableString] replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange( 0, [[send textStorage] length] )];
	[[[send textStorage] mutableString] replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange( 0, [[send textStorage] length] )];
	[[[send textStorage] mutableString] replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange( 0, [[send textStorage] length] )];
	[[[send textStorage] mutableString] replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange( 0, [[send textStorage] length] )];

	while( [[send textStorage] length] ) {
		range = [[[send textStorage] string] rangeOfString:@"\n"];
		if( ! range.length ) range.location = [[send textStorage] length];
		subMsg = [[[[send textStorage] attributedSubstringFromRange:NSMakeRange( 0, range.location )] mutableCopy] autorelease];

		if( ( [subMsg length] >= 1 && range.length ) || ( [subMsg length] && ! range.length ) ) {
			if( [[subMsg string] hasPrefix:@"/"] ) {
				BOOL handled = NO;
				NSScanner *scanner = [NSScanner scannerWithString:[subMsg string]];
				NSString *command = nil;
				NSAttributedString *arguments = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [[subMsg string] length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [subMsg attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], range.location - [scanner scanLocation] )];

				handled = [self processUserCommand:command withArguments:arguments];

				if( ! handled ) {
					NSRunInformationalAlertPanel( NSLocalizedString( @"Command not recognised", "IRC command not recognised dialog title" ), NSLocalizedString( @"The command you specified is not recognised by Colloquy or it's plugins. No action can be performed.", "IRC command not recognised dialog message" ), nil, nil, nil );
					return;
				}
			} else {
				char *msg = NULL;
				NSMutableData *msgData = nil;
				NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"]], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"]], @"NSHTMLIgnoreFontTraits", nil];

/*				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"] && ! action ) {
					extern NSArray *chatActionVerbs;
					NSString *tempString = [[subMsg string] stringByAppendingString:@" "];
					enumerator = [chatActionVerbs objectEnumerator];
					while( ( item = [enumerator nextObject] ) ) {
						if( [tempString hasPrefix:[item stringByAppendingString:@" "]] ) {
							action = YES;
							break;
						}
					}
				}*/

				subMsg = [self sendAttributedMessage:subMsg asAction:action];

				msgData = [[[subMsg HTMLWithOptions:options usingEncoding:_encoding allowLossyConversion:YES] mutableCopy] autorelease];
				[msgData appendBytes:"\0" length:1];

				msg = irc_html_to_irc( (const char * const) [msgData bytes] );
				msg = irc_irc_to_html( msg );

				[self addMessageToDisplay:[[[NSData dataWithBytes:msg length:strlen( msg )] retain] autorelease] fromUser:[[self connection] nickname] asAction:action];
			}
		}
		if( range.length ) range.location++;
		[[send textStorage] deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}

	[send reset:nil];
	[display stringByEvaluatingJavaScriptFromString:@"document.body.scrollTop = document.body.offsetHeight;"];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments {
	BOOL handled = NO;
	id item = nil;
	NSEnumerator *enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processUserCommand:withArguments:toUser:forConnection: )] objectEnumerator];

	while( ( item = [enumerator nextObject] ) ) {
		handled = [item processUserCommand:command withArguments:arguments toUser:[self target] forConnection:[self connection]];
		if( handled ) break;
	}

	return handled;
}

- (NSMutableAttributedString *) sendAttributedMessage:(NSMutableAttributedString *) message asAction:(BOOL) action {
	id item = nil;
	NSEnumerator *enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processPrivateMessage:toUser:asAction:forConnection: )] objectEnumerator];

	while( ( item = [enumerator nextObject] ) )
		message = [item processPrivateMessage:message toUser:[self target] asAction:action forConnection:[self connection]];

	[[self connection] sendMessageToUser:[self target] attributedMessage:message withEncoding:_encoding asAction:action];

	return message;
}

#pragma mark -

- (IBAction) clear:(id) sender {
	[send reset:nil];
}

- (IBAction) clearDisplay:(id) sender {
//	[_html setString:@""];
//	[[display mainFrame] loadHTMLString:[self _fullDisplayHTML] baseURL:nil];
}

#pragma mark -

- (BOOL) textView:(NSTextView *) textView enterHit:(NSEvent *) event {
	BOOL ret = NO;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnEnter"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnEnter"] ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	}
	return ret;
}

- (BOOL) textView:(NSTextView *) textView returnHit:(NSEvent *) event {
	BOOL ret = NO;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	}
	return ret;
}

- (BOOL) textView:(NSTextView *) textView upArrowHit:(NSEvent *) event {
	if( ! _historyIndex && [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[send textStorage] copy] autorelease]];
	_historyIndex++;
	if( _historyIndex >= [_sendHistory count] ) {
		_historyIndex = [_sendHistory count] - 1;
		if( (signed) _historyIndex < 0 ) _historyIndex = 0;
		return YES;
	}
	[send reset:nil];
	[[send textStorage] insertAttributedString:[_sendHistory objectAtIndex:_historyIndex] atIndex:0];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView downArrowHit:(NSEvent *) event {
	if( ! _historyIndex && [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[send textStorage] copy] autorelease]];
	if( [[send textStorage] length] ) _historyIndex--;
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

- (void) textDidChange:(NSNotification *) notification {
	_historyIndex = 0;
}

#pragma mark -

- (BOOL) splitView:(NSSplitView *) sender canCollapseSubview:(NSView *) subview {
	return NO;
}

- (float) splitView:(NSSplitView *) splitView constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) index {
//	float position = ( NSHeight( [splitView frame] ) - proposedPosition - [splitView dividerThickness] );
//	int lines = (int) floorf( position / 15. );
//	NSLog( @"%.2f %.2f / 15. = %.2f (%d)", proposedPosition, position, position / 15., lines );
	return ( roundf( proposedPosition / 15. ) * 15. ) + [splitView dividerThickness] + 2.;
	return proposedPosition;
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

@implementation JVDirectChat (JVDirectChatPrivate)
- (void) _makeHyperlinksInString:(NSMutableString *) string {
	NSScanner *urlScanner = [NSScanner scannerWithString:string];
	NSCharacterSet *urlStopSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r\0<>\"'![]{}()|*^!"];
	NSString *link = nil, *urlHandle = nil;
	NSMutableString *mutableLink = nil;
	unsigned int lastLoc = 0;

	while( ! [urlScanner isAtEnd] ) {
		while( ! [urlScanner isAtEnd] ) {
			lastLoc = [urlScanner scanLocation];
			if( [urlScanner scanUpToString:@"://" intoString:&urlHandle] ) {
				NSRange range = [urlHandle rangeOfCharacterFromSet:urlStopSet options:NSBackwardsSearch];
				[urlScanner setScanLocation:lastLoc];
				if( ! range.length ) {
					if( lastLoc ) lastLoc += 1;
					break;
				} else if( ! [urlHandle rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].length ) {
					lastLoc += range.location + range.length + ( lastLoc ? 1 : 0 );
					if( lastLoc < [string length] ) [urlScanner setScanLocation:lastLoc];
					else [urlScanner setScanLocation:[string length]];
					break;
				}
			}
			[urlScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		}
		if( [urlScanner scanUpToString:@"://" intoString:&urlHandle] && [urlScanner scanUpToCharactersFromSet:urlStopSet intoString:&link] ) {
			if( [link length] >= 7 ) {
				if( [link characterAtIndex:([link length] - 1)] == '.' || [link characterAtIndex:([link length] - 1)] == '?' )
					link = [link substringToIndex:([link length] - 1)];
				link = [urlHandle stringByAppendingString:link];
				mutableLink = [[link mutableCopy] autorelease];
				[mutableLink replaceOccurrencesOfString:@"/" withString:@"/&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"+" withString:@"+&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"%" withString:@"&#8203;%" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"&amp;" withString:@"&#8203;&amp;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[string replaceCharactersInRange:NSMakeRange( lastLoc, [link length] ) withString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", link, mutableLink]];
			}
		}
	}

	urlHandle = link = nil;
	lastLoc = 0;

	[urlScanner setScanLocation:0];
	while( ! [urlScanner isAtEnd] ) {
		while( ! [urlScanner isAtEnd] ) {
			lastLoc = [urlScanner scanLocation];
			if( [urlScanner scanUpToString:@"@" intoString:&urlHandle] ) {
				NSRange range = [urlHandle rangeOfCharacterFromSet:urlStopSet options:NSBackwardsSearch];
				[urlScanner setScanLocation:lastLoc];
				if( ! range.length ) {
					if( lastLoc ) lastLoc += 1;
					break;
				} else if( ! [urlHandle rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].length ) {
					lastLoc += range.location + range.length + ( lastLoc ? 1 : 0 );
					if( lastLoc < [string length] ) [urlScanner setScanLocation:lastLoc];
					else [urlScanner setScanLocation:[string length]];
					break;
				}
			}
			[urlScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		}
		if( [urlScanner scanUpToString:@"@" intoString:&urlHandle] && [urlScanner scanUpToCharactersFromSet:urlStopSet intoString:&link] ) {
			NSRange hasPeriod = [link rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
			NSRange limitRange = NSMakeRange( lastLoc, [[urlHandle stringByAppendingString:link] length] );
			if( [urlHandle length] && [link length] && hasPeriod.location < ([link length] - 1) && hasPeriod.location != NSNotFound /*&& ! [attrs objectForKey:NSLinkAttributeName]*/ ) {
				[string replaceCharactersInRange:limitRange withString:[NSString stringWithFormat:@"<a href=\"mailto:%@%@\">%@%@</a>", urlHandle, link, urlHandle, link]];
			}
		}
	}

	urlHandle = link = nil;
	lastLoc = 0;

	[urlScanner setScanLocation:0];
	while( [urlScanner isAtEnd] == NO ) {
		lastLoc = [urlScanner scanLocation];
		if( [urlScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&urlHandle] ) {
			if( ( [urlHandle rangeOfString:@"#"].location == 0 || [urlHandle rangeOfString:@"&"].location == 0 || [urlHandle rangeOfString:@"+"].location == 0 ) && [urlHandle length] > 2 && [urlHandle rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != 1 && ! [[urlHandle substringFromIndex:1] rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].length ) {
				id irc = [NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], urlHandle];
				if( lastLoc ) lastLoc += 1;
				[string replaceCharactersInRange:NSMakeRange( lastLoc, [urlHandle length] ) withString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", irc, urlHandle]];
			}
		}
	}	
}

- (void) _breakLongLinesInString:(NSMutableString *) string { // Not good on strings that have prior HTML or HTML entities
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSCharacterSet *stopSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	unsigned int lastLoc = 0;

	while( ! [scanner isAtEnd] ) {
		lastLoc = [scanner scanLocation];
		[scanner scanUpToCharactersFromSet:stopSet intoString:nil];
		if( ( [scanner scanLocation] - lastLoc ) > 34 ) { // Who says "supercalifragilisticexpialidocious" anyway?
			unsigned int times = (unsigned int) ( ( [scanner scanLocation] - lastLoc ) / 34 );
			while( times > 0 ) {
				[string insertString:@"&#8203;" atIndex:( lastLoc + ( times * 34 ) )];
				times--;
			}
		}
	}
}

- (void) _preformEmoticonSubstitutionOnString:(NSMutableString *) string {
	NSMutableString *str = nil;
	NSEnumerator *keyEnumerator = [_emoticonMappings keyEnumerator];
	NSEnumerator *objEnumerator = [_emoticonMappings objectEnumerator];
	NSEnumerator *srcEnumerator = nil;
	id key = nil, obj = nil;
	BOOL moreReplacements = YES;

	while( ( key = [keyEnumerator nextObject] ) && ( obj = [objEnumerator nextObject] ) ) {
		srcEnumerator = [obj objectEnumerator];
		while( ( str = [srcEnumerator nextObject] ) ) {
			str = [[str mutableCopy] autorelease];
			[str replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange( 0, [str length] )];
			[str replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange( 0, [str length] )];
			[str replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange( 0, [str length] )];
			moreReplacements = YES;
			while( moreReplacements ) {
				NSRange range = [string rangeOfString:str];
				if( range.length ) {
					if( (signed)( range.location - 1 ) >= 0 && [string characterAtIndex:( range.location - 1 )] != ' ' )
						break;
					if( (signed)( range.location + [str length] ) < [string length] && [string characterAtIndex:( range.location + [str length] )] != ' ' )
						break;
					[string replaceCharactersInRange:range withString:[NSString stringWithFormat:@"<span class=\"emoticon %@\"><samp>%@</samp></span>", key, str]];
				} else moreReplacements = NO;
			}
		}
	}
}

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

	if( [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"chat.style.%@.%@", [[self connection] server], _target]] )
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

	if( ! _chatXSLStyle ) return nil;

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
	return [[[NSString stringWithFormat:shell, _target, [self _chatEmoticonsCSSFileURL], [self _chatStyleCSSFileURL], [self _chatStyleVariantCSSFileURL], html] retain] autorelease];
}

- (void) _alertSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	NSEnumerator *kenumerator = nil, *enumerator = nil;
	id key = nil, value = nil;

	[[NSApplication sharedApplication] endSheet:sheet];
	[sheet orderOut:nil];

	[_waitingAlerts removeObjectIdenticalTo:sheet];

	kenumerator = [_waitingAlertNames keyEnumerator];
	enumerator = [_waitingAlertNames objectEnumerator];
	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) )
		if( value == sheet ) break;

	if( key ) [_waitingAlertNames removeObjectForKey:key];

	NSReleaseAlertPanel( sheet );

	if( [_waitingAlerts count] )
		[[NSApplication sharedApplication] beginSheet:[_waitingAlerts objectAtIndex:0] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) _didConnect:(NSNotification *) notification {
	[self showAlert:nil withName:@"disconnected"]; // cancel the disconnected alert
	_cantSendMessages = NO;
}

- (void) _didDisconnect:(NSNotification *) notification {
	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You're now offline", "title of the you're offline message sheet" ), NSLocalizedString( @"You are no longer connected to the server where you were chatting. No messages can be sent at this time. Reconnecting might be in progress.", "chat window error description for loosing connection" ), @"OK", nil, nil ) withName:@"disconnected"];
	_cantSendMessages = YES;
}
@end