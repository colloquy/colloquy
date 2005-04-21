#import <ChatCore/NSColorAdditions.h>
#import <ChatCore/NSStringAdditions.h>

#import "JVAppearancePreferences.h"
#import "JVStyle.h"
#import "JVStyleView.h"
#import "JVEmoticonSet.h"
#import "JVFontPreviewField.h"
#import "JVColorWellCell.h"
#import "JVDetailCell.h"
#import "NSBundleAdditions.h"

#import <libxml/xinclude.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

@interface WebCoreCache
+ (void) empty;
@end

#pragma mark -

@interface WebView (WebViewPrivate) // WebKit 1.3 pending public API
- (void) setDrawsBackground:(BOOL) draws;
- (BOOL) drawsBackground;
@end

#pragma mark -

@implementation JVAppearancePreferences
- (id) init {
	if( ( self = [super init] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( colorWellDidChangeColor: ) name:JVColorWellCellColorDidChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( updateChatStylesMenu ) name:JVStylesScannedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( updateEmoticonsMenu ) name:JVEmoticonSetsScannedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( reloadStyles: ) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];

		_style = nil;
		_styleOptions = nil;
		_userStyle = nil;
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_style release];
	_style = nil;

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

- (void) selectStyleWithIdentifier:(NSString *) identifier {
	[self setStyle:[JVStyle styleWithIdentifier:identifier]];
	[self changePreferences];
}

- (void) selectEmoticonsWithIdentifier:(NSString *) identifier {
	[_style setDefaultEmoticonSet:[JVEmoticonSet emoticonSetWithIdentifier:identifier]];
	[self updateEmoticonsMenu];
}

#pragma mark -

- (void) setStyle:(JVStyle *) style {
	[_style autorelease];
	_style = [style retain];

	JVChatTranscript *transcript = [JVChatTranscript chatTranscriptWithContentsOfFile:[_style previewTranscriptFilePath]];
	[preview setTranscript:transcript];

	[preview setEmoticons:[_style defaultEmoticonSet]];
	[preview setStyle:_style];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( updateVariant ) name:JVStyleVariantChangedNotification object:_style];
}

#pragma mark -

- (void) awakeFromNib {
	[(NSClipView *)[preview superview] setBackgroundColor:[NSColor clearColor]]; // allows rgba backgrounds to see through to the Desktop
	[(NSScrollView *)[(NSClipView *)[preview superview] superview] setBackgroundColor:[NSColor clearColor]];
}

- (void) initializeFromDefaults {
	[preview setPolicyDelegate:self];
	[preview setUIDelegate:self];
	[optionsTable setRefusesFirstResponder:YES];

	[useStyleFont setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputUsesStyleFont"]];

	NSTableColumn *column = [optionsTable tableColumnWithIdentifier:@"key"];
	JVDetailCell *prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont boldSystemFontOfSize:11.]];
	[prototypeCell setAlignment:NSRightTextAlignment];
	[column setDataCell:prototypeCell];

	[JVStyle scanForStyles];
	[self setStyle:[JVStyle defaultStyle]];

	[self changePreferences];
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
	JVStyle *style = [[sender representedObject] objectForKey:@"style"];
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];

	if( style == _style ) {
		[_style setDefaultVariantName:variant];

		[_styleOptions autorelease];
		_styleOptions = [[_style styleSheetOptions] mutableCopy];

		[self updateChatStylesMenu];

		if( _variantLocked ) [optionsTable deselectAll:nil];

		[self updateVariant];
		[self parseStyleOptions];
	} else {
		[self setStyle:style];

		[JVStyle setDefaultStyle:_style];
		[_style setDefaultVariantName:variant];

		[self changePreferences];
	}
}

- (void) changePreferences {
	[self updateChatStylesMenu];
	[self updateEmoticonsMenu];

	[_styleOptions autorelease];
	_styleOptions = [[_style styleSheetOptions] mutableCopy];

	[[preview window] disableFlushWindow];

	[preview setPreferencesIdentifier:[_style identifier]];

	WebPreferences *prefs = [preview preferences];
	[prefs setAutosaves:YES];

	// disable the user style sheet for users of 2C4 who got this
	// turned on, we do this different now and the user style can interfere
	[prefs setUserStyleSheetEnabled:NO];

	[standardFont setFont:[NSFont fontWithName:[prefs standardFontFamily] size:[prefs defaultFontSize]]];

	[minimumFontSize setIntValue:[prefs minimumFontSize]];
	[minimumFontSizeStepper setIntValue:[prefs minimumFontSize]];

	[baseFontSize setIntValue:[prefs defaultFontSize]];
	[baseFontSizeStepper setIntValue:[prefs defaultFontSize]];

	if( _variantLocked ) [optionsTable deselectAll:nil];

	[self parseStyleOptions];

	[[preview window] enableFlushWindow];
}

- (IBAction) changeDefaultEmoticons:(id) sender {
	[self selectEmoticonsWithIdentifier:[sender representedObject]];
}

#pragma mark -

- (IBAction) changeUseStyleFont:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVChatInputUsesStyleFont"];
}

#pragma mark -

- (void) updateChatStylesMenu {
	NSString *variant = [_style defaultVariantName];

	_variantLocked = ! [_style isUserVariantName:variant];

	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease], *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;

	NSEnumerator *enumerator = [[[[JVStyle styles] allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
	NSEnumerator *venumerator = nil;
	JVStyle *style = nil;
	id item = nil;

	while( ( style = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[style displayName] action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", nil]];
		if( [_style isEqualTo:style] ) [menuItem setState:NSOnState];
		[menu addItem:menuItem];

		NSArray *variants = [style variantStyleSheetNames];
		NSArray *userVariants = [style userVariantStyleSheetNames];

		if( [variants count] || [userVariants count] ) {
			subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

			subMenuItem = [[[NSMenuItem alloc] initWithTitle:[style mainVariantDisplayName] action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", nil]];
			if( [_style isEqualTo:style] && ! variant ) [subMenuItem setState:NSOnState];
			[subMenu addItem:subMenuItem];

			venumerator = [variants objectEnumerator];
			while( ( item = [venumerator nextObject] ) ) {
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", item, @"variant", nil]];
				if( [_style isEqualTo:style] && [variant isEqualToString:item] )
					[subMenuItem setState:NSOnState];
				[subMenu addItem:subMenuItem];
			}

			if( [userVariants count] ) [subMenu addItem:[NSMenuItem separatorItem]];

			venumerator = [userVariants objectEnumerator];
			while( ( item = [venumerator nextObject] ) ) {
				subMenuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""] autorelease];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:style, @"style", item, @"variant", nil]];
				if( [_style isEqualTo:style] && [variant isEqualToString:item] )
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
	NSEnumerator *enumerator = [[[[JVEmoticonSet emoticonSets] allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
	NSMenu *menu = nil;
	NSMenuItem *menuItem = nil;
	JVEmoticonSet *defaultEmoticon = [_style defaultEmoticonSet];
	JVEmoticonSet *emoticon = nil;

	menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];

	emoticon = [JVEmoticonSet textOnlyEmoticonSet];
	menuItem = [[[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeDefaultEmoticons: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:[emoticon identifier]];
	if( [defaultEmoticon isEqual:emoticon] ) [menuItem setState:NSOnState];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	while( ( emoticon = [enumerator nextObject] ) ) {
		if( ! [[emoticon displayName] length] ) continue;
		menuItem = [[[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeDefaultEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[emoticon identifier]];
		if( [defaultEmoticon isEqual:emoticon] ) [menuItem setState:NSOnState];
		[menu addItem:menuItem];
	}

	[emoticons setMenu:menu];
}

- (void) updateVariant {
	[preview setStyleVariant:[_style defaultVariantName]];
}

#pragma mark -

- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font {
	[[preview preferences] setStandardFontFamily:[font fontName]];
	[[preview preferences] setFixedFontFamily:[font fontName]];
	[[preview preferences] setSerifFontFamily:[font fontName]];
	[[preview preferences] setSansSerifFontFamily:[font fontName]];
}

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	return nil;
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

- (void) buildFileMenuForCell:(NSPopUpButtonCell *) cell andOptions:(NSMutableDictionary *) options {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"None", "no background image label" ) action:NULL keyEquivalent:@""] autorelease];
	[menuItem setRepresentedObject:@"none"];
	[menu addItem:menuItem];

	NSArray *files = [[_style bundle] pathsForResourcesOfType:nil inDirectory:[options objectForKey:@"folder"]];
	NSEnumerator *enumerator = [files objectEnumerator];
	NSString *resourcePath = [[[_style bundle] resourcePath] stringByAppendingPathComponent:[options objectForKey:@"folder"]];
	NSString *path = nil;
	BOOL matched = NO;

	if( [files count] ) [menu addItem:[NSMenuItem separatorItem]];

	while( ( path = [enumerator nextObject] ) ) {
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		NSImageRep *sourceImageRep = [icon bestRepresentationForDevice:nil];
		NSImage *smallImage = [[[NSImage alloc] initWithSize:NSMakeSize( 12., 12. )] autorelease];
		[smallImage lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationLow];
		[sourceImageRep drawInRect:NSMakeRect( 0., 0., 12., 12. )];
		[smallImage unlockFocus];

		menuItem = [[[NSMenuItem alloc] initWithTitle:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
		[menuItem setImage:smallImage];
		[menuItem setRepresentedObject:path];
		[menuItem setTag:5];
		[menu addItem:menuItem];

		NSString *fullPath = ( [[options objectForKey:@"path"] isAbsolutePath] ? [options objectForKey:@"path"] : [resourcePath stringByAppendingPathComponent:[options objectForKey:@"path"]] );
		if( [path isEqualToString:fullPath] ) {
			int index = [menu indexOfItemWithRepresentedObject:path];
			[options setObject:[NSNumber numberWithInt:index] forKey:@"value"];
			matched = YES;
		}
	}

	path = [options objectForKey:@"path"];
	if( ! matched && [path length] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		NSImageRep *sourceImageRep = [icon bestRepresentationForDevice:nil];
		NSImage *smallImage = [[[NSImage alloc] initWithSize:NSMakeSize( 12., 12. )] autorelease];
		[smallImage lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationLow];
		[sourceImageRep drawInRect:NSMakeRect( 0., 0., 12., 12. )];
		[smallImage unlockFocus];

		menuItem = [[[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path] action:NULL keyEquivalent:@""] autorelease];
		[menuItem setImage:smallImage];
		[menuItem setRepresentedObject:path];
		[menuItem setTag:10];
		[menu addItem:menuItem];

		int index = [menu indexOfItemWithRepresentedObject:path];
		[options setObject:[NSNumber numberWithInt:index] forKey:@"value"];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Other...", "other image label" ) action:@selector( selectImageFile: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[menuItem setTag:10];
	[menu addItem:menuItem];

	[cell setMenu:menu];
	[cell synchronizeTitleAndSelectedItem];
	[optionsTable performSelector:@selector( reloadData ) withObject:nil afterDelay:0.];
}

#pragma mark -

// Called when Colloquy reactivates.
- (void) reloadStyles:(NSNotification *) notification {
	if( ! [[preview window] isVisible] ) return;
	[JVStyle scanForStyles];

	if( ! [_userStyle length] ) return;
	[self parseStyleOptions];
	[self updateVariant];
}

// Parses the style options plist and reads the CSS files to figure out the current selected values.
- (void) parseStyleOptions {
	[self setUserStyle:[_style contentsOfVariantStyleSheetWithName:[_style defaultVariantName]]];

	NSString *css = _userStyle;
	css = [css stringByAppendingString:[_style contentsOfMainStyleSheet]];

	NSEnumerator *enumerator = [_styleOptions objectEnumerator];
	NSMutableDictionary *info = nil;

	// Step through each options.
	while( ( info = [enumerator nextObject] ) ) {
		NSMutableArray *styleLayouts = [NSMutableArray array];
		NSArray *sarray = nil;
		NSEnumerator *senumerator = nil;
		if( ! [info objectForKey:@"style"] ) continue;
		if( [[info objectForKey:@"style"] isKindOfClass:[NSArray class]] && [[info objectForKey:@"type"] isEqualToString:@"list"] )
			sarray = [info objectForKey:@"style"];
		else sarray = [NSArray arrayWithObject:[info objectForKey:@"style"]];
		senumerator = [sarray objectEnumerator];

		[info removeObjectForKey:@"value"]; // Clear any old values, we will get the new value later on.

		// Step through each style choice per option, colors have only one; lists have one style per list item.
		int count = 0;
		NSString *style = nil;
		while( ( style = [senumerator nextObject] ) ) {
			// Parse all the selectors in the style.
			AGRegex *regex = [AGRegex regexWithPattern:@"(\\S.*?)\\s*\{([^\\}]*?)\\}" options:( AGRegexCaseInsensitive | AGRegexDotAll )];
			NSEnumerator *selectors = [regex findEnumeratorInString:style];
			AGRegexMatch *selector = nil;

			NSMutableArray *styleLayout = [NSMutableArray array];
			[styleLayouts addObject:styleLayout];

			// Step through the selectors.
			while( ( selector = [selectors nextObject] ) ) {
				// Parse all the properties for the selector.
				regex = [AGRegex regexWithPattern:@"(\\S*?):\\s*(.*?);" options:( AGRegexCaseInsensitive | AGRegexDotAll )];
				NSEnumerator *properties = [regex findEnumeratorInString:[selector groupAtIndex:2]];
				AGRegexMatch *property = nil;

				// Step through all the properties and build a dictionary on this selector/property/value combo.
				while( ( property = [properties nextObject] ) ) {
					NSMutableDictionary *propertyInfo = [NSMutableDictionary dictionary];
					NSString *p = [property groupAtIndex:1];
					NSString *s = [selector groupAtIndex:1];
					NSString *v = [property groupAtIndex:2];

					[propertyInfo setObject:s forKey:@"selector"];
					[propertyInfo setObject:p forKey:@"property"];
					[propertyInfo setObject:v forKey:@"value"];
					[styleLayout addObject:propertyInfo];

					// Get the current value of this selector/property from the Variant CSS and the Main CSS to compare.
					NSString *value = [self valueOfProperty:p forSelector:s inStyle:css];
					if( [[info objectForKey:@"type"] isEqualToString:@"list"] ) {
						// Strip the "!important" flag to compare correctly.
						regex = [AGRegex regexWithPattern:@"\\s*!\\s*important\\s*$" options:AGRegexCaseInsensitive];
						NSString *compare = [regex replaceWithString:@"" inString:v];

						// Try to pick which option the list needs to select.
						if( ! [value isEqualToString:compare] ) { // Didn't match.
							NSNumber *value = [info objectForKey:@"value"];
							if( [value intValue] == count ) [info removeObjectForKey:@"value"];
						} else [info setObject:[NSNumber numberWithInt:count] forKey:@"value"]; // Matched for now.
					} else if( [[info objectForKey:@"type"] isEqualToString:@"color"] ) {
						if( value && [v rangeOfString:@"%@"].location != NSNotFound ) {
							// Strip the "!important" flag to compare correctly.
							regex = [AGRegex regexWithPattern:@"\\s*!\\s*important\\s*$" options:AGRegexCaseInsensitive];

							// Replace %@ with (.*) so we can pull the color value out.
							NSString *expression = [regex replaceWithString:@"" inString:v];
							expression = [expression stringByEscapingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"]];
							expression = [NSString stringWithFormat:expression, @"(.*)"];

							// Store the color value if we found one.
							regex = [AGRegex regexWithPattern:expression options:AGRegexCaseInsensitive];
							AGRegexMatch *vmatch = [regex findInString:value];
							if( [vmatch count] ) [info setObject:[vmatch groupAtIndex:1] forKey:@"value"];
						}
					} else if( [[info objectForKey:@"type"] isEqualToString:@"file"] ) {
						if( value && [v rangeOfString:@"%@"].location != NSNotFound ) {
							// Strip the "!important" flag to compare correctly.
							regex = [AGRegex regexWithPattern:@"\\s*!\\s*important\\s*$" options:AGRegexCaseInsensitive];

							[info setObject:[NSNumber numberWithInt:0] forKey:@"value"];
							[info setObject:[NSNumber numberWithInt:0] forKey:@"default"];

							// Replace %@ with (.*) so we can pull the color value out.
							NSString *expression = [regex replaceWithString:@"" inString:v];
							expression = [expression stringByEscapingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"]];
							expression = [NSString stringWithFormat:expression, @"(.*)"];

							// Store the color value if we found one.
							regex = [AGRegex regexWithPattern:expression options:AGRegexCaseInsensitive];
							AGRegexMatch *vmatch = [regex findInString:value];
							if( [vmatch count] ) {
								if( ! [[vmatch groupAtIndex:1] isEqualToString:@"none"] )
									[info setObject:[vmatch groupAtIndex:1] forKey:@"path"];
								else [info removeObjectForKey:@"path"];
								if( [info objectForKey:@"cell"] )
									[self buildFileMenuForCell:[info objectForKey:@"cell"] andOptions:info];
							}
						}
					}
				}
			}

			count++;
		}

		[info setObject:styleLayouts forKey:@"layouts"];
	}

	[optionsTable reloadData];
}

// reads a value form a CSS file for the property and selector provided.
- (NSString *) valueOfProperty:(NSString *) property forSelector:(NSString *) selector inStyle:(NSString *) style {
	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	selector = [selector stringByEscapingCharactersInSet:escapeSet];
	property = [property stringByEscapingCharactersInSet:escapeSet];

	AGRegex *regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"%@\\s*\\{[^\\}]*?\\s%@:\\s*(.*?)(?:\\s*!\\s*important\\s*)?;.*?\\}", selector, property] options:( AGRegexCaseInsensitive | AGRegexDotAll )];
	AGRegexMatch *match = [regex findInString:style];
	if( [match count] > 1 ) return [match groupAtIndex:1];

	return nil;
}

// Saves a CSS value to the specified property and selector, creating it if one isn't already in the file.
- (void) setStyleProperty:(NSString *) property forSelector:(NSString *) selector toValue:(NSString *) value {
	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	NSString *rselector = [selector stringByEscapingCharactersInSet:escapeSet];
	NSString *rproperty = [property stringByEscapingCharactersInSet:escapeSet];

	AGRegex *regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"(%@\\s*\\{[^\\}]*?\\s%@:\\s*)(?:.*?)(;.*?\\})", rselector, rproperty] options:( AGRegexCaseInsensitive | AGRegexDotAll )];
	if( [[regex findInString:_userStyle] count] ) { // Change existing property in selector block
		[self setUserStyle:[regex replaceWithString:[NSString stringWithFormat:@"$1%@$2", value] inString:_userStyle]];
	} else {
		regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"(\\s%@\\s*\\{)(\\s*)", rselector] options:AGRegexCaseInsensitive];
		if( [[regex findInString:_userStyle] count] ) { // Append to existing selector block
			[self setUserStyle:[regex replaceWithString:[NSString stringWithFormat:@"$1$2%@: %@;$2", rproperty, value] inString:_userStyle]];
		} else { // Create new selector block
			[self setUserStyle:[_userStyle stringByAppendingFormat:@"%@%@ {\n\t%@: %@;\n}", ( [_userStyle length] ? @"\n\n": @"" ), selector, property, value]];
		}
	}
}

- (void) setUserStyle:(NSString *) style {
	[_userStyle autorelease];
	if( ! style ) _userStyle = [[NSString string] retain];
	else _userStyle = [style retain];
}

// Saves the custom variant to the user's area.
- (void) saveStyleOptions {
	if( _variantLocked ) return;
	[_userStyle writeToURL:[_style variantStyleSheetLocationWithName:[_style defaultVariantName]] atomically:YES];

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[_style defaultVariantName], @"variant", nil];
	NSNotification *notification = [NSNotification notificationWithName:JVStyleVariantChangedNotification object:_style userInfo:info];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

// Shows the drawer, option clicking the button will open the custom variant CSS file.
- (IBAction) showOptions:(id) sender {
	if( ! _variantLocked && [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask ) {
		[[NSWorkspace sharedWorkspace] openURL:[_style variantStyleSheetLocationWithName:[_style defaultVariantName]]];
		return;
	}

	if( _variantLocked && [optionsDrawer state] == NSDrawerClosedState )
		[self showNewVariantSheet];

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
		if( value ) return value;
		return [info objectForKey:@"default"];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( _variantLocked ) return;

	if( [[column identifier] isEqualToString:@"value"] ) {
		NSMutableDictionary *info = [_styleOptions objectAtIndex:row];
		if( [[info objectForKey:@"type"] isEqualToString:@"list"] ) {
			[info setObject:object forKey:@"value"];

			NSEnumerator *enumerator = [[[info objectForKey:@"layouts"] objectAtIndex:[object intValue]] objectEnumerator];
			NSDictionary *styleInfo = nil;
			while( ( styleInfo = [enumerator nextObject] ) ) {
				[self setStyleProperty:[styleInfo objectForKey:@"property"] forSelector:[styleInfo objectForKey:@"selector"] toValue:[styleInfo objectForKey:@"value"]];
			}

			[self saveStyleOptions];
		} else if( [[info objectForKey:@"type"] isEqualToString:@"file"] ) {
			if( [object intValue] == -1 ) return;

			NSString *path = [[[info objectForKey:@"cell"] itemAtIndex:[object intValue]] representedObject];
			if( ! path ) return;

			[info setObject:object forKey:@"value"];

			NSEnumerator *enumerator = [[[info objectForKey:@"layouts"] objectAtIndex:0] objectEnumerator];
			NSDictionary *styleInfo = nil;
			while( ( styleInfo = [enumerator nextObject] ) ) {
				NSString *setting = [NSString stringWithFormat:[styleInfo objectForKey:@"value"], path];
				[self setStyleProperty:[styleInfo objectForKey:@"property"] forSelector:[styleInfo objectForKey:@"selector"] toValue:setting];
			}

			[self saveStyleOptions];
		} else return;
	}
}

// Called when JVColorWell's color changes.
- (void) colorWellDidChangeColor:(NSNotification *) notification {
	if( _variantLocked ) return;

	JVColorWellCell *cell = [notification object];
	if( ! [[cell representedObject] isKindOfClass:[NSNumber class]] ) return;
	int row = [[cell representedObject] intValue];

	NSMutableDictionary *info = [_styleOptions objectAtIndex:row];
	[info setObject:[cell color] forKey:@"value"];

	NSArray *style = [[info objectForKey:@"layouts"] objectAtIndex:0];
	NSString *value = [[cell color] CSSAttributeValue];
	NSEnumerator *enumerator = [style objectEnumerator];
	NSDictionary *styleInfo = nil;
	NSString *setting = nil;

	while( ( styleInfo = [enumerator nextObject] ) ) {
		setting = [NSString stringWithFormat:[styleInfo objectForKey:@"value"], value];
		[self setStyleProperty:[styleInfo objectForKey:@"property"] forSelector:[styleInfo objectForKey:@"selector"] toValue:setting];
	}

	[self saveStyleOptions];
}

- (IBAction) selectImageFile:(id) sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int index = [optionsTable selectedRow];
	NSMutableDictionary *info = [_styleOptions objectAtIndex:index];

	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTreatsFilePackagesAsDirectories:NO];
	[openPanel setCanChooseDirectories:NO];

	NSArray *types = [NSArray arrayWithObjects:@"jpg",@"tif",@"tiff",@"jpeg",@"gif",@"png",@"pdf",nil];
	NSString *value = [sender representedObject];
	if( [openPanel runModalForDirectory:[value stringByDeletingLastPathComponent] file:[value lastPathComponent] types:types] != NSOKButton )
		return;

	value = [openPanel filename];
	[info setObject:value forKey:@"path"];

	NSArray *style = [[info objectForKey:@"layouts"] objectAtIndex:0];
	NSEnumerator *enumerator = [style objectEnumerator];
	NSDictionary *styleInfo = nil;

	while( ( styleInfo = [enumerator nextObject] ) ) {
		NSString *setting = [NSString stringWithFormat:[styleInfo objectForKey:@"value"], value];
		[self setStyleProperty:[styleInfo objectForKey:@"property"] forSelector:[styleInfo objectForKey:@"selector"] toValue:setting];
	}

	[self saveStyleOptions];

	NSMutableDictionary *options = [_styleOptions objectAtIndex:index];
	[self buildFileMenuForCell:[options objectForKey:@"cell"] andOptions:options];
}

- (BOOL) tableView:(NSTableView *) view shouldSelectRow:(int) row {
	static NSTimeInterval lastTime = 0;
	if( _variantLocked && ( [NSDate timeIntervalSinceReferenceDate] - lastTime ) > 1. ) {
		[self showNewVariantSheet];
	}

	lastTime = [NSDate timeIntervalSinceReferenceDate];
	return ( ! _variantLocked );
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
			NSPopUpButtonCell *cell = [[NSPopUpButtonCell new] autorelease];
			[cell setControlSize:NSSmallControlSize];
			[cell setFont:[NSFont menuFontOfSize:[NSFont smallSystemFontSize]]];
			[cell addItemsWithTitles:[options objectForKey:@"options"]];
			[options setObject:cell forKey:@"cell"];
			return cell;
        } else if( [[options objectForKey:@"type"] isEqualToString:@"file"] ) {
			NSPopUpButtonCell *cell = [[NSPopUpButtonCell new] autorelease];
			[cell setControlSize:NSSmallControlSize];
			[cell setFont:[NSFont menuFontOfSize:[NSFont smallSystemFontSize]]];
			[self buildFileMenuForCell:cell andOptions:options];
			[options setObject:cell forKey:@"cell"];
			return cell;
		}
	}

	return nil;
}

#pragma mark -

// Shows the new variant sheet asking for a name.
- (void) showNewVariantSheet {
	[newVariantName setStringValue:NSLocalizedString( @"Untitled Variant", "new variant name" )];
	[[NSApplication sharedApplication] beginSheet:newVariantPanel modalForWindow:[preview window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) closeNewVariantSheet:(id) sender {
	[newVariantPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:newVariantPanel];
}

// Creates the new variant, making the proper folder and copying the current CSS settings.
- (IBAction) createNewVariant:(id) sender {
	[self closeNewVariantSheet:sender];

	NSMutableString *name = [[[newVariantName stringValue] mutableCopy] autorelease];
	[name replaceOccurrencesOfString:@"/" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [name length] )];
	[name replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [name length] )];

	[[NSFileManager defaultManager] createDirectoryAtPath:[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Styles/Variants/%@/", [_style identifier]] stringByExpandingTildeInPath] attributes:nil];

	NSString *path = [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Styles/Variants/%@/%@.css", [_style identifier], name] stringByExpandingTildeInPath];
	[_userStyle writeToFile:path atomically:YES];

	[_style setDefaultVariantName:name];

	[[NSNotificationCenter defaultCenter] postNotificationName:JVNewStyleVariantAddedNotification object:_style];

	[self updateChatStylesMenu];
	[self updateVariant];
}
@end