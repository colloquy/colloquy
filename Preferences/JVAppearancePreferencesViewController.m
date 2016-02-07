#import "JVAppearancePreferencesViewController.h"

#import <WebKit/WebKit.h>

#import "JVStyle.h"
#import "JVStyleView.h"
#import "JVEmoticonSet.h"
#import "JVFontPreviewField.h"
#import "JVColorWellCell.h"
#import "JVDetailCell.h"
#import "NSBundleAdditions.h"
#import "NSRegularExpressionAdditions.h"

#import <objc/objc-runtime.h>

@interface WebView (WebViewPrivate) // WebKit 1.3 pending public API
@property BOOL drawsBackground;
@end

#pragma mark -

@interface JVAppearancePreferencesViewController () <WebPolicyDelegate, WebUIDelegate>

@property(nonatomic, strong) IBOutlet JVStyleView *preview;
@property(nonatomic, strong) IBOutlet NSPopUpButton *styles;
@property(nonatomic, strong) IBOutlet NSPopUpButton *emoticons;
@property(nonatomic, strong) IBOutlet JVFontPreviewField *standardFont;
@property(nonatomic, strong) IBOutlet NSTextField *minimumFontSize;
@property(nonatomic, strong) IBOutlet NSStepper *minimumFontSizeStepper;
@property(nonatomic, strong) IBOutlet NSTextField *baseFontSize;
@property(nonatomic, strong) IBOutlet NSStepper *baseFontSizeStepper;
@property(nonatomic, strong) IBOutlet NSDrawer *optionsDrawer;
@property(nonatomic, strong) IBOutlet NSTableView *optionsTable;
@property(nonatomic, strong) IBOutlet NSPanel *addVariantPanel;
@property(nonatomic, strong) IBOutlet NSTextField *variantName;

@property(nonatomic, assign) BOOL variantLocked;
@property(nonatomic, assign) BOOL alertDisplayed;
@property(nonatomic, strong) JVStyle *style;
@property(nonatomic, strong) NSMutableArray *styleOptions;
@property(nonatomic, strong) NSString *userStyle;


- (void) setStyle:(JVStyle *) style;

- (void) initializeFromDefaults;

- (void) changePreferences;

- (IBAction) changeBaseFontSize:(id) sender;
- (IBAction) changeMinimumFontSize:(id) sender;

- (IBAction) changeDefaultChatStyle:(id) sender;
- (IBAction) changeDefaultEmoticons:(id) sender;

- (IBAction) showOptions:(id) sender;

- (void) updateChatStylesMenu;
- (void) updateEmoticonsMenu;
- (void) updateVariant;

- (void) parseStyleOptions;
- (NSString *) valueOfProperty:(NSString *) property forSelector:(NSString *) selector inStyle:(NSString *) style;
- (void) setStyleProperty:(NSString *) property forSelector:(NSString *) selector toValue:(NSString *) value;
- (void) setUserStyle:(NSString *) style;
- (void) saveStyleOptions;

- (void) showNewVariantSheet;
- (IBAction) closeNewVariantSheet:(id) sender;
- (IBAction) createNewVariant:(id) sender;

@end


@implementation JVAppearancePreferencesViewController

- (id) init {
	if( ( self = [super init] ) ) {
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( colorWellDidChangeColor: ) name:JVColorWellCellColorDidChangeNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( updateChatStylesMenu ) name:JVStylesScannedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( updateEmoticonsMenu ) name:JVEmoticonSetsScannedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( reloadStyles: ) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];
	}
	return self;
}

- (void)awakeFromNib {
	[self initializeFromDefaults];
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_optionsDrawer setDelegate:nil];

	[_preview setUIDelegate:nil];
	[_preview setResourceLoadDelegate:nil];
	[_preview setDownloadDelegate:nil];
	[_preview setFrameLoadDelegate:nil];
	[_preview setPolicyDelegate:nil];
}

- (void) viewDidDisappear {
	[self.optionsDrawer close];
}


#pragma mark - MASPreferencesViewController

- (NSString *) identifier {
	return @"JVAppearancePreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"AppearancePreferences"];
}

- (NSString *) toolbarItemLabel {
	return NSLocalizedString( @"Appearance", "appearance preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark -

- (void) selectStyleWithIdentifier:(NSString *) identifier {
	self.style = [JVStyle styleWithIdentifier:identifier];
	[self changePreferences];
}

- (void) selectEmoticonsWithIdentifier:(NSString *) identifier {
	JVEmoticonSet *emoticonSet = [JVEmoticonSet emoticonSetWithIdentifier:identifier];
	[self.style setDefaultEmoticonSet:emoticonSet];
	[self.preview setEmoticons:emoticonSet];
	[self updateEmoticonsMenu];
}

#pragma mark -

- (void) setStyle:(JVStyle *) style {
	_style = style;

	JVChatTranscript *transcript = [JVChatTranscript chatTranscriptWithContentsOfURL:[_style previewTranscriptLocation]];
	[self.preview setTranscript:transcript];

	[self.preview setEmoticons:[_style defaultEmoticonSet]];
	[self.preview setStyle:_style];

	[[NSNotificationCenter chatCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( updateVariant ) name:JVStyleVariantChangedNotification object:_style];
}

#pragma mark -

- (void) initializeFromDefaults {
	[self.preview setPolicyDelegate:self];
	[self.preview setUIDelegate:self];
	[self.optionsTable setRefusesFirstResponder:YES];

	NSTableColumn *column = [self.optionsTable tableColumnWithIdentifier:@"key"];
	JVDetailCell *prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont boldSystemFontOfSize:11.]];
	[prototypeCell setAlignment:NSRightTextAlignment];
	[column setDataCell:prototypeCell];

	[JVStyle scanForStyles];
	self.style = [JVStyle defaultStyle];

	[self changePreferences];
}

- (IBAction) changeBaseFontSize:(id) sender {
	// WebPreferences is the limiting factor in keeping this variable as int.
	int size = [sender intValue];
	[self.baseFontSize setIntValue:size];
	[self.baseFontSizeStepper setIntValue:size];
	[[self.preview preferences] setDefaultFontSize:size];
}

- (IBAction) changeMinimumFontSize:(id) sender {
	// WebPreferences is the limiting factor in keeping this variable as int.
	int size = [sender intValue];
	[self.minimumFontSize setIntValue:size];
	[self.minimumFontSizeStepper setIntValue:size];
	[[self.preview preferences] setMinimumFontSize:size];
}

- (IBAction) changeDefaultChatStyle:(id) sender {
	JVStyle *style = [sender representedObject][@"style"];
	NSString *variant = [sender representedObject][@"variant"];

	if( style == self.style ) {
		[self.style setDefaultVariantName:variant];

		self.styleOptions = [[self.style styleSheetOptions] mutableCopy];

		[self updateChatStylesMenu];

		if( self.variantLocked ) [self.optionsTable deselectAll:nil];

		[self updateVariant];
		[self parseStyleOptions];
	} else {
		self.style = style;

		[JVStyle setDefaultStyle:self.style];
		[self.style setDefaultVariantName:variant];

		[self changePreferences];
	}
}

- (void) changePreferences {
	[self updateChatStylesMenu];
	[self updateEmoticonsMenu];

	self.styleOptions = [[self.style styleSheetOptions] mutableCopy];

	[self.preview setPreferencesIdentifier:[self.style identifier]];

	WebPreferences *prefs = [self.preview preferences];
	[prefs setAutosaves:YES];

	// disable the user style sheet for users of 2C4 who got this
	// turned on, we do this different now and the user style can interfere
	[prefs setUserStyleSheetEnabled:NO];

	[self.standardFont setFont:[NSFont fontWithName:[prefs standardFontFamily] size:[prefs defaultFontSize]]];

	[self.minimumFontSize setIntValue:[prefs minimumFontSize]];
	[self.minimumFontSizeStepper setIntValue:[prefs minimumFontSize]];

	[self.baseFontSize setIntValue:[prefs defaultFontSize]];
	[self.baseFontSizeStepper setIntValue:[prefs defaultFontSize]];

	if( self.variantLocked ) [self.optionsTable deselectAll:nil];

	[self parseStyleOptions];
}

- (IBAction) changeDefaultEmoticons:(id) sender {
	[self selectEmoticonsWithIdentifier:[sender representedObject]];
}

#pragma mark -

- (void) updateChatStylesMenu {
	NSString *variant = [self.style defaultVariantName];

	self.variantLocked = ! [self.style isUserVariantName:variant];

	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""], *subMenu = nil;
	NSMenuItem *menuItem = nil, *subMenuItem = nil;

	id item = nil;
	for( JVStyle *style in [[[JVStyle styles] allObjects] sortedArrayUsingSelector:@selector( compare: )] ) {
		menuItem = [[NSMenuItem alloc] initWithTitle:[style displayName] action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:@{@"style": style}];
		if( [self.style isEqualTo:style] ) [menuItem setState:NSOnState];
		[menu addItem:menuItem];

		NSArray *variants = [style variantStyleSheetNames];
		NSArray *userVariants = [style userVariantStyleSheetNames];

		if( [variants count] || [userVariants count] ) {
			subMenu = [[NSMenu alloc] initWithTitle:@""];

			subMenuItem = [[NSMenuItem alloc] initWithTitle:[style mainVariantDisplayName] action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""];
			[subMenuItem setTarget:self];
			[subMenuItem setRepresentedObject:@{@"style": style}];
			if( [self.style isEqualTo:style] && ! variant ) [subMenuItem setState:NSOnState];
			[subMenu addItem:subMenuItem];

			for( item in variants ) {
				subMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:@{@"style": style, @"variant": item}];
				if( [self.style isEqualTo:style] && [variant isEqualToString:item] )
					[subMenuItem setState:NSOnState];
				[subMenu addItem:subMenuItem];
			}

			if( [userVariants count] ) [subMenu addItem:[NSMenuItem separatorItem]];

			for( item in userVariants ) {
				subMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector( changeDefaultChatStyle: ) keyEquivalent:@""];
				[subMenuItem setTarget:self];
				[subMenuItem setRepresentedObject:@{@"style": style, @"variant": item}];
				if( [self.style isEqualTo:style] && [variant isEqualToString:item] )
					[subMenuItem setState:NSOnState];
				[subMenu addItem:subMenuItem];
			}

			[menuItem setSubmenu:subMenu];
		}

		subMenu = nil;
	}

	[self.styles setMenu:menu];
}

- (void) updateEmoticonsMenu {
	NSMenu *menu = nil;
	NSMenuItem *menuItem = nil;
	JVEmoticonSet *defaultEmoticon = [self.style defaultEmoticonSet];

	menu = [[NSMenu alloc] initWithTitle:@""];

	JVEmoticonSet *emoticon = [JVEmoticonSet textOnlyEmoticonSet];
	menuItem = [[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeDefaultEmoticons: ) keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItem setRepresentedObject:[emoticon identifier]];
	if( [defaultEmoticon isEqual:emoticon] ) [menuItem setState:NSOnState];
	[menu addItem:menuItem];

	[menu addItem:[NSMenuItem separatorItem]];

	for( JVEmoticonSet *emoticon in [[[JVEmoticonSet emoticonSets] allObjects] sortedArrayUsingSelector:@selector( compare: )] ) {
		if( ! [[emoticon displayName] length] ) continue;
		menuItem = [[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeDefaultEmoticons: ) keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[emoticon identifier]];
		if( [defaultEmoticon isEqual:emoticon] ) [menuItem setState:NSOnState];
		[menu addItem:menuItem];
	}

	[self.emoticons setMenu:menu];
}

- (void) updateVariant {
	[self.preview setStyleVariant:[self.style defaultVariantName]];
	[self.preview reloadCurrentStyle];
}

#pragma mark -

- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font {
	[[self.preview preferences] setStandardFontFamily:[font familyName]];
	[[self.preview preferences] setFixedFontFamily:[font familyName]];
	[[self.preview preferences] setSerifFontFamily:[font familyName]];
	[[self.preview preferences] setSansSerifFontFamily:[font familyName]];
}

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	return nil;
}

- (void) webView:(WebView *) sender decidePolicyForNavigationAction:(NSDictionary *) actionInformation request:(NSURLRequest *) request frame:(WebFrame *) frame decisionListener:(id <WebPolicyDecisionListener>) listener {
	NSURL *url = actionInformation[WebActionOriginalURLKey];

	if( [[url scheme] isEqualToString:@"about"] ) {
		if( [[[url standardizedURL] path] length] ) [listener ignore];
		else [listener use];
	} else if( [url isFileURL] && [[url path] hasPrefix:[[NSBundle mainBundle] resourcePath]] ) {
		[listener use];
	} else {
		[[NSWorkspace sharedWorkspace] openURL:url];
		[listener ignore];
	}
}

#pragma mark -

- (void) buildFileMenuForCell:(NSPopUpButtonCell *) cell andOptions:(NSMutableDictionary *) options {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"None", "no background image label" ) action:NULL keyEquivalent:@""];
	[menuItem setRepresentedObject:@"none"];
	[menu addItem:menuItem];

	NSArray *files = [[self.style bundle] pathsForResourcesOfType:nil inDirectory:options[@"folder"]];
	NSString *resourcePath = [[self.style bundle] resourcePath];
	BOOL matched = NO;

	if( [files count] ) [menu addItem:[NSMenuItem separatorItem]];

	for( NSString *path in files ) {
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		NSRect rect = NSMakeRect( 0., 0., 12., 12. );
		NSImageRep *sourceImageRep = [icon bestRepresentationForRect:rect context:[NSGraphicsContext currentContext] hints:nil];
		NSImage *smallImage = [[NSImage alloc] initWithSize:NSMakeSize( 12., 12. )];
		[smallImage lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationLow];
		[sourceImageRep drawInRect:rect];
		[smallImage unlockFocus];

		menuItem = [[NSMenuItem alloc] initWithTitle:[[[NSFileManager defaultManager] displayNameAtPath:path] stringByDeletingPathExtension] action:NULL keyEquivalent:@""];
		[menuItem setImage:smallImage];
		[menuItem setRepresentedObject:path];
		[menuItem setTag:5];
		[menu addItem:menuItem];

		NSString *fullPath = ( [options[@"path"] isAbsolutePath] ? options[@"path"] : [resourcePath stringByAppendingPathComponent:options[@"path"]] );
		if( [path isEqualToString:fullPath] ) {
			NSInteger index = [menu indexOfItemWithRepresentedObject:path];
			options[@"value"] = @(index);
			matched = YES;
		}
	}

	NSString *path = options[@"path"];
	if( ! matched && [path length] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		NSString *fullPath = ( [path isAbsolutePath] ? path : [resourcePath stringByAppendingPathComponent:path] );
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:fullPath];
		NSRect rect = NSMakeRect( 0., 0., 12., 12. );
		NSImageRep *sourceImageRep = [icon bestRepresentationForRect:rect context:[NSGraphicsContext currentContext] hints:nil];
		NSImage *smallImage = [[NSImage alloc] initWithSize:NSMakeSize( 12., 12. )];
		[smallImage lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationLow];
		[sourceImageRep drawInRect:rect];
		[smallImage unlockFocus];

		menuItem = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path] action:NULL keyEquivalent:@""];
		[menuItem setImage:smallImage];
		[menuItem setRepresentedObject:path];
		[menuItem setTag:10];
		[menu addItem:menuItem];

		NSInteger index = [menu indexOfItemWithRepresentedObject:path];
		options[@"value"] = @(index);
	}

	[menu addItem:[NSMenuItem separatorItem]];

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Other...", "other image label" ) action:@selector( selectImageFile: ) keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItem setTag:10];
	[menu addItem:menuItem];

	[cell setMenu:menu];
	[cell synchronizeTitleAndSelectedItem];
	[self.optionsTable performSelector:@selector( reloadData ) withObject:nil afterDelay:0.];
}

#pragma mark -

// Called when Colloquy reactivates.
- (void) reloadStyles:(NSNotification *) notification {
	if( ! [[self.preview window] isVisible] ) return;
	[JVStyle scanForStyles];

	if( ! [self.userStyle length] ) return;
	[self parseStyleOptions];
	[self updateVariant];
}

// Parses the style options plist and reads the CSS files to figure out the current selected values.
- (void) parseStyleOptions {
	self.userStyle = [self.style contentsOfVariantStyleSheetWithName:[self.style defaultVariantName]];

	NSString *css = self.userStyle;
	css = [css stringByAppendingString:[self.style contentsOfMainStyleSheet]];

	// Step through each options.
	for( NSMutableDictionary *info in self.styleOptions ) {
		NSMutableArray *styleLayouts = [NSMutableArray array];
		NSArray *sarray = nil;
		if( ! info[@"style"] ) continue;
		if( [info[@"style"] isKindOfClass:[NSArray class]] && [info[@"type"] isEqualToString:@"list"] )
			sarray = info[@"style"];
		else sarray = @[info[@"style"]];

		[info removeObjectForKey:@"value"]; // Clear any old values, we will get the new value later on.

		// Step through each style choice per option, colors have only one; lists have one style per list item.
		NSUInteger count = 0;
		for( NSString *style in sarray ) {
			// Parse all the selectors in the style.
			NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(\\S.*?)\\s*\\{([^\\}]*?)\\}" options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators) error:nil];

			NSMutableArray *styleLayout = [NSMutableArray array];
			[styleLayouts addObject:styleLayout];

			// Step through the selectors.
			for( NSTextCheckingResult *selector in [regex matchesInString:style options:0 range:NSMakeRange( 0, style.length )] ) {
				// Parse all the properties for the selector.
				regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(\\S*?):\\s*(.*?);" options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators) error:nil];

				// Step through all the properties and build a dictionary on this selector/property/value combo.
				NSString *matchedText = [style substringWithRange:[selector rangeAtIndex:2]];
				for( NSTextCheckingResult *property in [regex matchesInString:matchedText options:0 range:NSMakeRange( 0, matchedText.length )] ) {
					NSMutableDictionary *propertyInfo = [NSMutableDictionary dictionary];
					NSString *p = [matchedText substringWithRange:[property rangeAtIndex:1]];
					NSString *s = [style substringWithRange:[selector rangeAtIndex:1]];
					NSString *v = [matchedText substringWithRange:[property rangeAtIndex:2]];

					propertyInfo[@"selector"] = s;
					propertyInfo[@"property"] = p;
					propertyInfo[@"value"] = v;
					[styleLayout addObject:propertyInfo];

					// Get the current value of this selector/property from the Variant CSS and the Main CSS to compare.
					NSString *value = [self valueOfProperty:p forSelector:s inStyle:css];
					if( [info[@"type"] isEqualToString:@"list"] ) {
						// Strip the "!important" flag to compare correctly.
						NSString *compare = [v stringByReplacingOccurrencesOfRegex:@"\\s*!\\s*important\\s*$" withString:@"" options:NSRegularExpressionCaseInsensitive range:NSMakeRange( 0, v.length ) error:nil];

						// Try to pick which option the list needs to select.
						if( ! [value isEqualToString:compare] ) { // Didn't match.
							NSNumber *value = info[@"value"];
							if( [value unsignedLongValue] == count ) [info removeObjectForKey:@"value"];
						} else info[@"value"] = @(count); // Matched for now.
					} else if( [info[@"type"] isEqualToString:@"color"] ) {
						if( value && [v rangeOfString:@"%@"].location != NSNotFound ) {
							// Replace %@ with (.*) so we can pull the color value out.
							NSString *expression = [v stringByReplacingOccurrencesOfRegex:@"\\s*!\\s*important\\s*$" withString:@"" options:NSRegularExpressionCaseInsensitive range:NSMakeRange( 0, v.length ) error:nil];
							expression = [expression stringByEscapingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"]];
							expression = [NSString stringWithFormat:expression, @"(.*)"];

							// Store the color value if we found one.
							regex = [NSRegularExpression cachedRegularExpressionWithPattern:expression options:NSRegularExpressionCaseInsensitive error:nil];
							NSTextCheckingResult *vmatch = [regex firstMatchInString:value options:0 range:NSMakeRange( 0, value.length )];
							if( [vmatch numberOfRanges] ) [info setObject:[value substringWithRange:[vmatch rangeAtIndex:1]] forKey:@"value"];
						}
					} else if( [info[@"type"] isEqualToString:@"file"] ) {
						if( value && [v rangeOfString:@"%@"].location != NSNotFound ) {
							info[@"value"] = @0UL;
							info[@"default"] = @0UL;

							// Replace %@ with (.*) so we can pull the path value out.
							NSString *expression = [v stringByReplacingOccurrencesOfRegex:@"\\s*!\\s*important\\s*$" withString:@"" options:NSRegularExpressionCaseInsensitive range:NSMakeRange( 0, v.length ) error:nil];
							expression = [expression stringByEscapingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"]];
							expression = [NSString stringWithFormat:expression, @"(.*)"];

							// Store the path value if we found one.
							regex = [NSRegularExpression cachedRegularExpressionWithPattern:expression options:NSRegularExpressionCaseInsensitive error:nil];
							NSTextCheckingResult *vmatch = [regex firstMatchInString:value options:0 range:NSMakeRange( 0, value.length )];
							if( [vmatch numberOfRanges] ) {
								if( ! [[value substringWithRange:[vmatch rangeAtIndex:1]] isEqualToString:@"none"] )
									[info setObject:[value substringWithRange:[vmatch rangeAtIndex:1]] forKey:@"path"];
								else [info removeObjectForKey:@"path"];
								if( info[@"cell"] )
									[self buildFileMenuForCell:info[@"cell"] andOptions:info];
							}
						}
					}
				}
			}

			count++;
		}

		info[@"layouts"] = styleLayouts;
	}

	[self.optionsTable reloadData];
}

// reads a value form a CSS file for the property and selector provided.
- (NSString *) valueOfProperty:(NSString *) property forSelector:(NSString *) selector inStyle:(NSString *) style {
	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	selector = [selector stringByEscapingCharactersInSet:escapeSet];
	property = [property stringByEscapingCharactersInSet:escapeSet];

	NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:[NSString stringWithFormat:@"%@\\s*\\{[^\\}]*?\\s%@:\\s*(.*?)(?:\\s*!\\s*important\\s*)?;.*?\\}", selector, property] options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators error:nil];
	NSTextCheckingResult *match = [regex firstMatchInString:style options:0 range:NSMakeRange( 0, style.length ) ];
	if( [match numberOfRanges] > 1 ) return [style substringWithRange:[match rangeAtIndex:1]];

	return nil;
}

// Saves a CSS value to the specified property and selector, creating it if one isn't already in the file.
- (void) setStyleProperty:(NSString *) property forSelector:(NSString *) selector toValue:(NSString *) value {
//	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
//	NSString *rselector = [selector stringByEscapingCharactersInSet:escapeSet];
//	NSString *rproperty = [property stringByEscapingCharactersInSet:escapeSet];
//
//	NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:[NSString stringWithFormat:@"(%@\\s*\\{[^\\}]*?\\s%@:\\s*)(?:.*?)(;.*?\\})", rselector, rproperty] options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators error:nil];
//	AGRegex *regex = [AGRegex regexWithPattern: options:( AGRegexCaseInsensitive | AGRegexDotAll )];
//	if( [[regex findInString:self.userStyle] count] ) { // Change existing property in selector block
//		[self setUserStyle:[regex replaceWithString:[NSString stringWithFormat:@"$1%@$2", value] inString:self.userStyle]];
//	} else {
//		regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"(\\s%@\\s*\\{)(\\s*)", rselector] options:AGRegexCaseInsensitive];
//		if( [[regex findInString:self.userStyle] count] ) { // Append to existing selector block
//			[self setUserStyle:[regex replaceWithString:[NSString stringWithFormat:@"$1$2%@: %@;$2", rproperty, value] inString:self.userStyle]];
//		} else { // Create new selector block
//			[self setUserStyle:[self.userStyle stringByAppendingFormat:@"%@%@ {\n\t%@: %@;\n}", ( [self.userStyle length] ? @"\n\n": @"" ), selector, property, value]];
//		}
//	}
}

- (void) setUserStyle:(NSString *) style {
	if( ! style ) _userStyle = [NSString string];
	else _userStyle = style;
}

// Saves the custom variant to the user's area.
- (void) saveStyleOptions {
	if( self.variantLocked ) return;

	[self.userStyle writeToURL:[self.style variantStyleSheetLocationWithName:[self.style defaultVariantName]] atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	NSDictionary *info = @{@"variant": [self.style defaultVariantName]};
	NSNotification *notification = [NSNotification notificationWithName:JVStyleVariantChangedNotification object:self.style userInfo:info];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

// Shows the drawer, option clicking the button will open the custom variant CSS file.
- (IBAction) showOptions:(id) sender {
	if( ! self.variantLocked && [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask ) {
		[[NSWorkspace sharedWorkspace] openURL:[self.style variantStyleSheetLocationWithName:[self.style defaultVariantName]]];
		return;
	}

	if( self.variantLocked && [self.optionsDrawer state] == NSDrawerClosedState )
		[self showNewVariantSheet];

	[self.optionsDrawer setParentWindow:[sender window]];
	[self.optionsDrawer setPreferredEdge:NSMaxXEdge];
	if( [self.optionsDrawer contentSize].width < [self.optionsDrawer minContentSize].width )
		[self.optionsDrawer setContentSize:[self.optionsDrawer minContentSize]];
	[self.optionsDrawer toggle:sender];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	return [self.styleOptions count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( [[column identifier] isEqualToString:@"key"] ) {
		return NSLocalizedString( self.styleOptions[row][@"description"], "description of style options, appearance preferences" );
	} else if( [[column identifier] isEqualToString:@"value"] ) {
		NSDictionary *info = self.styleOptions[row];
		id value = info[@"value"];
		if( value ) return value;
		return info[@"default"];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( self.variantLocked ) return;

	if( [[column identifier] isEqualToString:@"value"] ) {
		NSMutableDictionary *info = self.styleOptions[row];
		if( [info[@"type"] isEqualToString:@"list"] ) {
			info[@"value"] = object;

			for( NSDictionary *styleInfo in info[@"layouts"][[object intValue]] )
				[self setStyleProperty:styleInfo[@"property"] forSelector:styleInfo[@"selector"] toValue:styleInfo[@"value"]];

			[self saveStyleOptions];
		} else if( [info[@"type"] isEqualToString:@"file"] ) {
			if( [object intValue] == -1 ) return;

			NSString *path = [[(NSPopUpButtonCell *)info[@"cell"] itemAtIndex:[object intValue]] representedObject];
			if( ! path ) return;

			info[@"value"] = object;

			for( NSDictionary *styleInfo in info[@"layouts"][0] ) {
				NSString *setting = [[NSString alloc] initWithFormat:styleInfo[@"value"], path];
				[self setStyleProperty:styleInfo[@"property"] forSelector:styleInfo[@"selector"] toValue:setting];
			}

			[self saveStyleOptions];
		} else return;
	}
}

// Called when JVColorWell's color changes.
- (void) colorWellDidChangeColor:(NSNotification *) notification {
	if( self.variantLocked ) return;

	JVColorWellCell *cell = [notification object];
	if( ! [[cell representedObject] isKindOfClass:[NSNumber class]] ) return;
	NSInteger row = [[cell representedObject] intValue];

	NSMutableDictionary *info = self.styleOptions[row];
	info[@"value"] = [cell color];

	NSArray *style = info[@"layouts"][0];
	NSString *value = [[cell color] CSSAttributeValue];
	NSString *setting = nil;

	for( NSDictionary *styleInfo in style ) {
		setting = [[NSString alloc] initWithFormat:styleInfo[@"value"], value];
		[self setStyleProperty:styleInfo[@"property"] forSelector:styleInfo[@"selector"] toValue:setting];
	}

	[self saveStyleOptions];
}

- (IBAction) selectImageFile:(id) sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	NSInteger index = [self.optionsTable selectedRow];
	NSMutableDictionary *info = self.styleOptions[index];

	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTreatsFilePackagesAsDirectories:NO];
	[openPanel setCanChooseDirectories:NO];

	NSArray *types = @[@"jpg", @"tif", @"tiff", @"jpeg", @"gif", @"png", @"pdf"];
	NSString *value = [sender representedObject];

	[openPanel setDirectoryURL:[NSURL fileURLWithPath:value isDirectory:NO]];
	[openPanel setAllowedFileTypes:types];

	if( [openPanel runModal] != NSOKButton )
		return;

	value = [[openPanel URL] path];
	info[@"path"] = value;

	NSArray *style = info[@"layouts"][0];

	for( NSDictionary *styleInfo in style ) {
		NSString *setting = [NSString stringWithFormat:styleInfo[@"value"], value];
		[self setStyleProperty:styleInfo[@"property"] forSelector:styleInfo[@"selector"] toValue:setting];
	}

	[self saveStyleOptions];

	NSMutableDictionary *options = self.styleOptions[index];
	[self buildFileMenuForCell:options[@"cell"] andOptions:options];
}

- (BOOL) tableView:(NSTableView *) view shouldSelectRow:(NSInteger) row {
	static NSTimeInterval lastTime = 0;
	if( self.variantLocked && ( [NSDate timeIntervalSinceReferenceDate] - lastTime ) > 1. ) {
		[self showNewVariantSheet];
	}

	lastTime = [NSDate timeIntervalSinceReferenceDate];
	return ( ! self.variantLocked );
}

- (id) tableView:(NSTableView *) view dataCellForRow:(NSInteger) row tableColumn:(NSTableColumn *) column {
	if( [[column identifier] isEqualToString:@"value"] ) {
		NSMutableDictionary *options = [self.styleOptions objectAtIndex:row];
		if( [options objectForKey:@"cell"] ) {
			return options[@"cell"];
		} else if( [[options objectForKey:@"type"] isEqualToString:@"color"] ) {
			id cell = [JVColorWellCell new];
			[cell setRepresentedObject:@(row)];
			options[@"cell"] = cell;
			return cell;
		} else if( [options[@"type"] isEqualToString:@"list"] ) {
			NSPopUpButtonCell *cell = [NSPopUpButtonCell new];
			NSMutableArray *localizedOptions = [NSMutableArray array];

			for( NSString *optionTitle in options[@"options"] )
				[localizedOptions addObject:NSLocalizedString( optionTitle, "title of style option value" )];
			[cell setControlSize:NSSmallControlSize];
			[cell setFont:[NSFont menuFontOfSize:[NSFont smallSystemFontSize]]];
			[cell addItemsWithTitles:localizedOptions];
			options[@"cell"] = cell;
			return cell;
        } else if( [options[@"type"] isEqualToString:@"file"] ) {
			NSPopUpButtonCell *cell = [NSPopUpButtonCell new];
			[cell setControlSize:NSSmallControlSize];
			[cell setFont:[NSFont menuFontOfSize:[NSFont smallSystemFontSize]]];
			[self buildFileMenuForCell:cell andOptions:options];
			options[@"cell"] = cell;
			return cell;
		}
	}

	return nil;
}

#pragma mark -

// Shows the new variant sheet asking for a name.
- (void) showNewVariantSheet {
	[self.variantName setStringValue:NSLocalizedString( @"Untitled Variant", "new variant name" )];
	[[NSApplication sharedApplication] beginSheet:self.addVariantPanel modalForWindow:[self.preview window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) closeNewVariantSheet:(id) sender {
	[self.addVariantPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:self.addVariantPanel];
}

// Creates the new variant, making the proper folder and copying the current CSS settings.
- (IBAction) createNewVariant:(id) sender {
	[self closeNewVariantSheet:sender];

	NSMutableString *name = [[self.variantName stringValue] mutableCopy];
	[name replaceOccurrencesOfString:@"/" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [name length] )];
	[name replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [name length] )];

	NSString *varDir = [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Styles/Variants/%@/", [self.style identifier]] stringByExpandingTildeInPath];
	[[NSFileManager defaultManager] createDirectoryAtPath:varDir withIntermediateDirectories:YES attributes:nil error:nil];

	NSString *path = [[varDir stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"css"];

	[self.userStyle writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	[self.style setDefaultVariantName:name];

	[[NSNotificationCenter chatCenter] postNotificationName:JVNewStyleVariantAddedNotification object:self.style];

	[self updateChatStylesMenu];
	[self updateVariant];
}
@end
