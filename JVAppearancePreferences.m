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
	[standardFont setShowPointSize:YES];
	[fixedWidthFont setShowPointSize:YES];
	[self changePreferences];
	[self updateChatStylesMenu];
	[self updateEmoticonsMenu];
	[self updatePreview];
}

- (void) saveChanges {
	[[preview preferences] setMinimumFontSize:[minimumFontSize intValue]];
}

- (IBAction) changeDefaultChatStyle:(id) sender {
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
	NSString *style = [[sender representedObject] objectForKey:@"style"];

	[[NSUserDefaults standardUserDefaults] setObject:style forKey:@"JVChatDefaultStyle"];
	if( ! variant ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", style]];
	else [[NSUserDefaults standardUserDefaults] setObject:variant forKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", style]];

	[self changePreferences];
	[self updateChatStylesMenu];
	[self updatePreview];
}

- (void) changePreferences {
	WebPreferences *prefs = [[[preview preferences] retain] autorelease];
	[preview setPreferencesIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	[prefs setMinimumFontSize:[minimumFontSize intValue]];
	[[preview preferences] setAutosaves:YES];
	[standardFont setFont:[NSFont fontWithName:[[preview preferences] standardFontFamily] size:[[preview preferences] defaultFontSize]]];
	[fixedWidthFont setFont:[NSFont fontWithName:[[preview preferences] fixedFontFamily] size:[[preview preferences] defaultFixedFontSize]]];
	[serifFont setFont:[NSFont fontWithName:[[preview preferences] serifFontFamily] size:[[preview preferences] defaultFontSize]]];
	[sansSerifFont setFont:[NSFont fontWithName:[[preview preferences] sansSerifFontFamily] size:[[preview preferences] defaultFontSize]]];
	[minimumFontSize setIntValue:[[preview preferences] minimumFontSize]];
	[minimumFontSizeStepper setIntValue:[[preview preferences] minimumFontSize]];
}

- (void) updateChatStylesMenu {
	NSEnumerator *enumerator = [[[_styleBundles allObjects] sortedArrayUsingFunction:sortBundlesByName context:self] objectEnumerator];
	NSEnumerator *denumerator = nil;
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;
	NSString *defaultStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"];
	NSString *variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", defaultStyle]];		
	NSBundle *style = nil;
	id file = nil;

	if( ! defaultStyle ) {
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
	[[NSUserDefaults standardUserDefaults] setObject:@"none" forKey:@"JVChatDefaultEmoticons"];
	[self updatePreview];
}

- (IBAction) hideEmoticons:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:@"hidden" forKey:@"JVChatDefaultEmoticons"];
	[self updatePreview];
}

- (IBAction) changeDefaultEmoticons:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[sender representedObject] forKey:@"JVChatDefaultEmoticons"];
	[self updatePreview];
}

- (void) updateEmoticonsMenu {
	NSEnumerator *enumerator = [[[_emoticonBundles allObjects] sortedArrayUsingFunction:sortBundlesByName context:self] objectEnumerator];
	NSMenu *menu = nil;
	NSMenuItem *menuItem = nil;
	NSString *defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"];
	NSBundle *emoticon = nil;

	if( ! defaultEmoticons ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultEmoticons"];
		defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"];
	}

	menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Graphics", "no graphic emoticons menu item title" ) action:@selector( noGraphicEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menu addItem:menuItem];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Hidden", "hide emoticons menu item title" ) action:@selector( hideEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
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

	if( [(NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"] length] ) {
		if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"] isEqualToString:@"hidden"] ) {
			emoticonStyle = [[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"emoticonsHidden" ofType:@"css"]] absoluteString];
		} else {
			emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultEmoticons"]];
			emoticonStyle = ( emoticon ? [[NSURL fileURLWithPath:[emoticon pathForResource:@"emoticons" ofType:@"css"]] absoluteString] : @"" );
		}
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

- (BOOL) fontPreviewField:(JVFontPreviewField *) field shouldChangeToFont:(NSFont *) font {
	if( field == serifFont || field == sansSerifFont ) {
		NSFont *newFont = [NSFont fontWithName:( [font familyName] ? [font familyName] : [font fontName] ) size:11.];
		[field setFont:newFont];
		[self fontPreviewField:field didChangeToFont:newFont];
		return NO;
	}
	return YES;
}

- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font {
	if( field == standardFont ) {
		[[preview preferences] setStandardFontFamily:[font familyName]];
		[[preview preferences] setDefaultFontSize:[font pointSize]];
	} else if( field == fixedWidthFont ) {
		[[preview preferences] setFixedFontFamily:[font familyName]];
		[[preview preferences] setDefaultFixedFontSize:[font pointSize]];
	} else if( field == serifFont ) {
		[[preview preferences] setSerifFontFamily:[font familyName]];
		[standardFont setFont:[NSFont fontWithName:[[preview preferences] standardFontFamily] size:[[preview preferences] defaultFontSize]]];
	} else if( field == sansSerifFont ) {
		[[preview preferences] setSansSerifFontFamily:[font familyName]];
		[standardFont setFont:[NSFont fontWithName:[[preview preferences] standardFontFamily] size:[[preview preferences] defaultFontSize]]];
	}
	[self updatePreview];
}
@end