#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <AGRegex/AGRegex.h>
#import <ChatCore/NSColorAdditions.h>
#import <ChatCore/NSStringAdditions.h>

#import "JVAppearancePreferences.h"
#import "JVChatTranscriptPrivates.h"
#import "JVFontPreviewField.h"
#import "JVColorWellCell.h"
#import "JVDetailCell.h"

#import <libxml/xinclude.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

@implementation JVAppearancePreferences
- (id) init {
	if( ( self = [super init] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( colorWellDidChangeColor: ) name:JVColorWellCellColorDidChangeNotification object:nil];

		[JVChatTranscript _scanForChatStyles];
		[JVChatTranscript _scanForEmoticons];

		_styleBundles = [[JVChatTranscript _chatStyleBundles] retain];
		_emoticonBundles = [[JVChatTranscript _emoticonBundles] retain];
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_styleBundles release];
	[_emoticonBundles release];

	_styleBundles = nil;
	_emoticonBundles = nil;

	[super dealloc];
}

- (NSString *) preferencesNibName {
	return @"JVAppearancePreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"AppearancePreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) moduleWillBeRemoved {
	[optionsDrawer close];
}

#pragma mark -

- (void) initializeFromDefaults {
	[preview setPolicyDelegate:self];
	[optionsTable setRefusesFirstResponder:YES];

	NSTableColumn *column = [optionsTable tableColumnWithIdentifier:@"key"];
	JVDetailCell *prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont boldSystemFontOfSize:11.]];
	[prototypeCell setAlignment:NSRightTextAlignment];
	[column setDataCell:prototypeCell];

	[self changePreferences:nil];
}

- (IBAction) changeBaseFontSize:(id) sender {
	int size = [sender intValue];
	[baseFontSize setIntValue:size];
	[baseFontSizeStepper setIntValue:size];
	[[preview preferences] setDefaultFontSize:size];
}

- (IBAction) changeMinimumFontSize:(id) sender {
	int size = [sender intValue];
	[minimumFontSize setIntValue:size];
	[minimumFontSizeStepper setIntValue:size];
	[[preview preferences] setMinimumFontSize:size];
}

- (IBAction) changeDefaultChatStyle:(id) sender {
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
	NSString *style = [[sender representedObject] objectForKey:@"style"];

	[[NSUserDefaults standardUserDefaults] setObject:style forKey:@"JVChatDefaultStyle"];
	if( ! variant ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", style]];
	else [[NSUserDefaults standardUserDefaults] setObject:variant forKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", style]];

	[[preview mainFrame] loadHTMLString:@"" baseURL:nil];
	// give webkit some time to load the blank before we switch preferences so we don't double refresh	
	[self performSelector:@selector( changePreferences: ) withObject:nil afterDelay:0.];
}

- (void) changePreferences:(id) sender {
	[self updateChatStylesMenu];
	[self updateEmoticonsMenu];

	NSBundle *style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];

	[_styleOptions autorelease];
	_styleOptions = [[NSMutableArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"styleOptions" ofType:@"plist"]] retain];
	if( [style objectForInfoDictionaryKey:@"JVStyleOptions"] )
		[_styleOptions addObjectsFromArray:[[[style objectForInfoDictionaryKey:@"JVStyleOptions"] mutableCopy] autorelease]];
//	_styleOptions = [[style objectForInfoDictionaryKey:@"JVStyleOptions"] mutableCopy];

	[preview setPreferencesIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	// we shouldn't have to post this notification manually, but this seems to make webkit refresh with new prefs
	[[NSNotificationCenter defaultCenter] postNotificationName:@"WebPreferencesChangedNotification" object:[preview preferences]];

	WebPreferences *prefs = [preview preferences];
	[prefs setAutosaves:YES];

	[standardFont setFont:[NSFont fontWithName:[prefs standardFontFamily] size:[prefs defaultFontSize]]];

	[minimumFontSize setIntValue:[prefs minimumFontSize]];
	[minimumFontSizeStepper setIntValue:[prefs minimumFontSize]];

	[baseFontSize setIntValue:[prefs defaultFontSize]];
	[baseFontSizeStepper setIntValue:[prefs defaultFontSize]];

	[self updatePreview];
	[self parseUserStyleOptions];
}

- (IBAction) noGraphicEmoticons:(id) sender {
	NSString *style = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"];
	[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]];
	[self updatePreview];
}

- (IBAction) changeDefaultEmoticons:(id) sender {
	NSString *style = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"];
	[[NSUserDefaults standardUserDefaults] setObject:[sender representedObject] forKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]];
	[self updatePreview];
}

#pragma mark -

- (void) updateChatStylesMenu {
	NSEnumerator *enumerator = [[[_styleBundles allObjects] sortedArrayUsingFunction:sortBundlesByName context:self] objectEnumerator];
	NSEnumerator *denumerator = nil;
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;
	NSString *defaultStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"];
	NSString *variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", defaultStyle]];		
	NSBundle *style = [NSBundle bundleWithIdentifier:defaultStyle];
	id file = nil;

	if( ! style ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
		defaultStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"];
		variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", defaultStyle]];
	}

	menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

	while( ( style = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[JVChatTranscript _nameForBundle:style] action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:[style bundleIdentifier], @"style", nil]];
		if( [defaultStyle isEqualToString:[style bundleIdentifier]] )
			[menuItem setState:NSOnState];
		[menu addItem:menuItem];

		if( [[style pathsForResourcesOfType:@"css" inDirectory:@"Variants"] count] ) {
			denumerator = [[style pathsForResourcesOfType:@"css" inDirectory:@"Variants"] objectEnumerator];
			subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
			subMenuItem = [[[NSMenuItem alloc] initWithTitle:( [style objectForInfoDictionaryKey:@"JVBaseStyleVariantName"] ? [style objectForInfoDictionaryKey:@"JVBaseStyleVariantName"] : NSLocalizedString( @"Normal", "normal style variant menu item title" ) ) action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:[style bundleIdentifier], @"style", nil]];
			if( [defaultStyle isEqualToString:[style bundleIdentifier]] && ! variant )
				[subMenuItem setState:NSOnState];
			[subMenu addItem:subMenuItem];

			while( ( file = [denumerator nextObject] ) ) {
				file = [[file lastPathComponent] stringByDeletingPathExtension];
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:file action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:[style bundleIdentifier], @"style", file, @"variant", nil]];
				if( [defaultStyle isEqualToString:[style bundleIdentifier]] && [variant isEqualToString:file] )
					[subMenuItem setState:NSOnState];
				[subMenu addItem:subMenuItem];
			}

			[menuItem setSubmenu:subMenu];
		}

		subMenu = nil;
	}

	[styles setMenu:menu];
}

- (void) updateEmoticonsMenu {
	NSEnumerator *enumerator = [[[_emoticonBundles allObjects] sortedArrayUsingFunction:sortBundlesByName context:self] objectEnumerator];
	NSMenu *menu = nil;
	NSMenuItem *menuItem = nil;
	NSString *style = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"];
	NSString *defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]];
	NSBundle *emoticon = [NSBundle bundleWithIdentifier:defaultEmoticons];

	if( ! emoticon && [defaultEmoticons length] ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]];
		defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]];
	}

	menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Text Only", "text only emoticons menu item title" ) action:@selector( noGraphicEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	if( ! [defaultEmoticons length] ) [menuItem setState:NSOnState];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	while( ( emoticon = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[JVChatTranscript _nameForBundle:emoticon] action:@selector( changeDefaultEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[emoticon bundleIdentifier]];
		if( [defaultEmoticons isEqualToString:[emoticon bundleIdentifier]] )
			[menuItem setState:NSOnState];
		[menu addItem:menuItem];
	}

	[emoticons setMenu:menu];
}

- (void) updatePreview {
	xsltStylesheetPtr xsltStyle = NULL;
	xmlDocPtr doc = NULL;
	xmlDocPtr res = NULL;
	xmlChar *result = NULL;
	NSString *html = nil;
	int len = 0;
	const char **params = NULL;
	NSBundle *style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	NSString *variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [style bundleIdentifier]]];
	NSBundle *emoticon = nil;
	NSString *emoticonStyle = @"";
	NSString *emoticonSetting = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [style bundleIdentifier]]];
	if( [emoticonSetting length] ) {
		emoticon = [NSBundle bundleWithIdentifier:emoticonSetting];
		emoticonStyle = ( emoticon ? [[NSURL fileURLWithPath:[emoticon pathForResource:@"emoticons" ofType:@"css"]] absoluteString] : @"" );
	}

	NSString *path = [style pathForResource:@"main" ofType:@"xsl"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"xsl"];	

	params = [JVChatTranscript _xsltParamArrayWithDictionary:[NSDictionary dictionaryWithContentsOfFile:[style pathForResource:@"parameters" ofType:@"plist"]]];
	xsltStyle = xsltParseStylesheetFile( (const xmlChar *)[path fileSystemRepresentation] );

	if( [style pathForResource:@"preview" ofType:@"colloquyTranscript"] ) {
		doc = xmlParseFile( [[style pathForResource:@"preview" ofType:@"colloquyTranscript"] fileSystemRepresentation] );
	} else {
		doc = xmlParseFile( [[[NSBundle mainBundle] pathForResource:@"preview" ofType:@"colloquyTranscript"] fileSystemRepresentation] );
	}

	if( ( res = xsltApplyStylesheet( xsltStyle, doc, params ) ) ) {
		xsltSaveResultToString( &result, &len, res, xsltStyle );
		xmlFreeDoc( res );
		xmlFreeDoc( doc );
	}

	if( xsltStyle ) xsltFreeStylesheet( xsltStyle );
	if( params ) [JVChatTranscript _freeXsltParamArray:params];

	if( result ) {
		html = [NSString stringWithUTF8String:result];
		free( result );
	}

	NSString *headerPath = [style pathForResource:@"supplement" ofType:@"html"];
	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	if( variant ) path = ( [variant isAbsolutePath] ? [[NSURL fileURLWithPath:variant] absoluteString] : [[NSURL fileURLWithPath:[style pathForResource:variant ofType:@"css" inDirectory:@"Variants"]] absoluteString] );
	else path = @"";
	NSString *basePath = [style resourcePath];
	basePath = ( basePath ? [[NSURL fileURLWithPath:basePath] absoluteString] : @"" );
	html = [NSString stringWithFormat:shell, @"Preview", emoticonStyle, ( style ? [[NSURL fileURLWithPath:[style pathForResource:@"main" ofType:@"css"]] absoluteString] : @"" ), path, basePath, ( headerPath ? [NSString stringWithContentsOfFile:headerPath] : @"" ), html];

	[[preview mainFrame] loadHTMLString:html baseURL:nil];
}

#pragma mark -

- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font {
	[[preview preferences] setStandardFontFamily:[font fontName]];
	[[preview preferences] setFixedFontFamily:[font fontName]];
	[[preview preferences] setSerifFontFamily:[font fontName]];
	[[preview preferences] setSansSerifFontFamily:[font fontName]];
	[self updatePreview];
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	if( [[[actionInformation objectForKey:WebActionOriginalURLKey] scheme] isEqualToString:@"about"]  ) {
		[listener use];
	} else {
		NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];
		[[NSWorkspace sharedWorkspace] openURL:url];	
		[listener ignore];
	}
}

#pragma mark -

- (void) parseUserStyleOptions {
	[_userStyle autorelease];
	_userStyle = [[NSString stringWithContentsOfFile:[[[preview preferences] userStyleSheetLocation] path]] retain];

	if( ! _userStyle ) _userStyle = [[NSString string] retain];

	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	AGRegex *regex = nil;
	AGRegexMatch *match = nil;
	NSString *style = _userStyle;
	NSString *selector = nil;
	NSString *property = nil;
	unsigned int i = 1;

	do {
		enumerator = [_styleOptions objectEnumerator];
		while( ( info = [enumerator nextObject] ) ) {
			if( [info objectForKey:@"value"] ) continue;

			selector = [[info objectForKey:@"selector"] stringByEscapingCharactersInSet:escapeSet];
			property = [[info objectForKey:@"property"] stringByEscapingCharactersInSet:escapeSet];

			regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"%@\\s*\\{[^\\}]*?\\s%@:\\s*(.*?)(?:\\s*!\\s*important\\s*)?;.*?\\}", selector, property] options:( AGRegexCaseInsensitive | AGRegexDotAll )];
			match = [regex findInString:style];
			if( [match count] > 1 && ! [info objectForKey:@"value"] )
				[info setObject:[match groupAtIndex:1] forKey:@"value"];
		}

		NSBundle *bundle = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
		NSString *variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [bundle bundleIdentifier]]];

		if( i == 1 && variant ) style = [NSString stringWithContentsOfFile:( [variant isAbsolutePath] ? variant : [bundle pathForResource:variant ofType:@"css" inDirectory:@"Variants"] )];
		else if( ( i == 1 && ! variant ) || i == 2 ) style = [NSString stringWithContentsOfFile:( bundle ? [bundle pathForResource:@"main" ofType:@"css"] : @"" )];
		else style = nil;

		i++;
	} while( style );

	[optionsTable reloadData];
}

- (void) changeUserStyleProperty:(NSString *) property ofSelector:(NSString *) selector toValue:(NSString *) value isImportant:(BOOL) important {
	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	NSString *rselector = [selector stringByEscapingCharactersInSet:escapeSet];
	NSString *rproperty = [property stringByEscapingCharactersInSet:escapeSet];

	AGRegex *regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"(%@\\s*\\{[^\\}]*?\\s%@:\\s*)(?:.*?)((?:\\s*!\\s*important\\s*)?;.*?\\})", rselector, rproperty] options:( AGRegexCaseInsensitive | AGRegexDotAll )];
	if( [[regex findInString:_userStyle] count] ) { // Change existing property in selector block
		[_userStyle autorelease];
		_userStyle = [[regex replaceWithString:[NSString stringWithFormat:@"$1%@$2", value] inString:_userStyle] retain];
	} else {
		regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"(\\s%@\\s*\\{)(\\s*)", rselector] options:AGRegexCaseInsensitive];
		if( [[regex findInString:_userStyle] count] ) { // Append to existing selector block
			[_userStyle autorelease];
			_userStyle = [[regex replaceWithString:[NSString stringWithFormat:@"$1$2%@: %@%@;$2", rproperty, value, ( important ? @" !important" : @"" )] inString:_userStyle] retain];
		} else { // Create new selector block
			[_userStyle autorelease];
			_userStyle = [[_userStyle stringByAppendingFormat:@"%@%@ {\n\t%@: %@%@;\n}", ( [_userStyle length] ? @"\n\n": @"" ), selector, property, value, ( important ? @" !important" : @"" )] retain];
		}
	}
}

- (void) saveUserStyleOptions {
	NSString *path = [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Styles/Overrides/%@.css", [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]] stringByExpandingTildeInPath];
	[_userStyle writeToFile:path atomically:NO];

	[[preview preferences] setUserStyleSheetLocation:[NSURL fileURLWithPath:path]];
	[[preview preferences] setUserStyleSheetEnabled:YES];
}

- (IBAction) showOptions:(id) sender {
	[optionsDrawer setParentWindow:[sender window]];
	[optionsDrawer setPreferredEdge:NSMaxXEdge];
	if( [optionsDrawer contentSize].width < [optionsDrawer minContentSize].width )
		[optionsDrawer setContentSize:[optionsDrawer minContentSize]];
	[optionsDrawer toggle:sender];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_styleOptions count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqualToString:@"key"] ) {
		return [[_styleOptions objectAtIndex:row] objectForKey:@"description"];
	} else if( [[column identifier] isEqualToString:@"value"] ) {
		NSDictionary *info = [_styleOptions objectAtIndex:row];
		id value = [info objectForKey:@"value"];
		if( value && [[info objectForKey:@"type"] isEqualToString:@"list"] ) {
			int index = [[info objectForKey:@"values"] indexOfObject:value];
			return [NSNumber numberWithInt:( index != NSNotFound ? index : -1 )];
		} else if( value ) return value;
		return [info objectForKey:@"default"];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqualToString:@"value"] ) {
		NSMutableDictionary *info = [_styleOptions objectAtIndex:row];
		NSString *value = object;

		if( [[info objectForKey:@"type"] isEqualToString:@"list"] )
			value = [[info objectForKey:@"values"] objectAtIndex:[object intValue]];

		if( value ) {
			[info setObject:value forKey:@"value"];
			[self changeUserStyleProperty:[info objectForKey:@"property"] ofSelector:[info objectForKey:@"selector"] toValue:value isImportant:[[info objectForKey:@"important"] boolValue]];
			[self saveUserStyleOptions];
			[self updatePreview];
		}
	}
}

- (void) colorWellDidChangeColor:(NSNotification *) notification {
	JVColorWellCell *cell = [notification object];
	if( ! [[cell representedObject] isKindOfClass:[NSNumber class]] ) return;
	int row = [[cell representedObject] intValue];

	NSMutableDictionary *info = [_styleOptions objectAtIndex:row];
	[info setObject:[cell color] forKey:@"value"];

	[self changeUserStyleProperty:[info objectForKey:@"property"] ofSelector:[info objectForKey:@"selector"] toValue:[[cell color] CSSAttributeValue] isImportant:[[info objectForKey:@"important"] boolValue]];
	[self saveUserStyleOptions];
	[self updatePreview];
}

- (id) tableView:(NSTableView *) view dataCellForRow:(int) row tableColumn:(NSTableColumn *) column {
	if( [[column identifier] isEqualToString:@"value"] ) {
		NSMutableDictionary *options = [_styleOptions objectAtIndex:row];
		if( [options objectForKey:@"cell"] ) {
			return [[[options objectForKey:@"cell"] retain] autorelease];
		} else if( [[options objectForKey:@"type"] isEqualToString:@"color"] ) {
			id cell = [[JVColorWellCell new] autorelease];
			[cell setRepresentedObject:[NSNumber numberWithInt:row]];
			[options setObject:cell forKey:@"cell"];
			return cell;
		} else if( [[options objectForKey:@"type"] isEqualToString:@"list"] ) {
			id cell = [[NSPopUpButtonCell new] autorelease];
			[cell setControlSize:NSSmallControlSize];
			[cell setFont:[NSFont menuFontOfSize:[NSFont smallSystemFontSize]]];
			[cell addItemsWithTitles:[options objectForKey:@"options"]];
			[options setObject:cell forKey:@"cell"];
			return cell;
		}
	}

	return nil;
}
@end