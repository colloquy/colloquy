#import "JVAppearancePreferences.h"
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "JVFontPreviewField.h"

#import <libxml/xinclude.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

NSComparisonResult sortBundlesByName( id style1, id style2, void *context );

#pragma mark -

@interface JVChatTranscript
+ (void) _scanForChatStyles;
+ (NSSet *) _chatStyleBundles;
+ (NSString *) _nameForBundle:(NSBundle *) style;
+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary;
+ (void) _freeXsltParamArray:(const char **) params;
+ (NSSet *) _emoticonBundles;
+ (void) _scanForEmoticons;
@end

#pragma mark -

@implementation JVAppearancePreferences
- (id) init {
	self = [super init];
	[JVChatTranscript _scanForChatStyles];
	[JVChatTranscript _scanForEmoticons];
	_styleBundles = [[JVChatTranscript _chatStyleBundles] retain];
	_emoticonBundles = [[JVChatTranscript _emoticonBundles] retain];
	return self;
}

- (void) dealloc {
	[_styleBundles autorelease];
	[_emoticonBundles autorelease];
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

#pragma mark -

- (void) initializeFromDefaults {
	[preview setPolicyDelegate:self];
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
}

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

	doc = xmlParseFile( [[[NSBundle mainBundle] pathForResource:@"preview" ofType:@"colloquyTranscript"] fileSystemRepresentation] );

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

	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	if( variant ) path = ( [variant isAbsolutePath] ? [[NSURL fileURLWithPath:variant] absoluteString] : [[NSURL fileURLWithPath:[style pathForResource:variant ofType:@"css" inDirectory:@"Variants"]] absoluteString] );
	else path = @"";
	html = [NSString stringWithFormat:shell, @"Preview", emoticonStyle, ( style ? [[NSURL fileURLWithPath:[style pathForResource:@"main" ofType:@"css"]] absoluteString] : @"" ), path, html];

	[[preview mainFrame] loadHTMLString:html baseURL:nil];
}

- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font {
	[[preview preferences] setStandardFontFamily:[font familyName]];
	[[preview preferences] setFixedFontFamily:[font familyName]];
	[[preview preferences] setSerifFontFamily:[font familyName]];
	[[preview preferences] setSansSerifFontFamily:[font familyName]];
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
@end