#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>
#import "MVPreferencesController.h"
#import "MVPreferencesIconView.h"
#import "MVPreferencesGroupedIconView.h"
#import "NSImageAdditions.h"
#import "NSToolbarAdditions.h"

static MVPreferencesController *sharedInstance = nil;

static NSString *MVToolbarShowAllItemIdentifier = @"MVToolbarShowAllItem";
static NSString *MVPreferencesWindowNotification = @"MVPreferencesWindowNotification";

@interface NSToolbar (NSToolbarPrivate)
- (NSView *) _toolbarView;
@end

@interface MVPreferencesController (MVPreferencesControllerPrivate)
- (IBAction) _selectPreferencePane:(id) sender;
- (void) _resizeWindowForContentView:(NSView *) view;
- (NSImage *) _imageForPaneBundle:(NSBundle *) bundle;
- (NSString *) _paletteLabelForPaneBundle:(NSBundle *) bundle;
- (NSString *) _labelForPaneBundle:(NSBundle *) bundle;
@end

#pragma mark -

@implementation MVPreferencesController
+ (MVPreferencesController *) sharedInstance {
	extern MVPreferencesController *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

- (id) init {
	if( ( self = [super init] ) ) {
		NSString *path = [NSString stringWithFormat:@"%@/Contents/PreferencePanes", [[NSBundle mainBundle] bundlePath]];
		NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
		NSString *file = nil;
		NSBundle *bundle = nil;

		panes = [[NSMutableArray array] retain];
		loadedPanes = [[NSMutableDictionary dictionary] retain];
		paneInfo = [[NSMutableDictionary dictionary] retain];

		while( ( file = [enumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"prefPane"] ) {
				bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]];
				if( [bundle load] ) [panes addObject:bundle];
			}
		}

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _doUnselect: ) name:NSPreferencePaneDoUnselectNotification object:nil];
	}
	return self;
}

- (void) dealloc {
	extern MVPreferencesController *sharedInstance;

	[window close];
	window = nil;

	[multiView autorelease];
	[groupView autorelease];
	[loadingView autorelease];

	[mainView autorelease];
	[loadedPanes autorelease];
	[panes autorelease];
	[paneInfo autorelease];
	[pendingPane autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	multiView = nil;
	groupView = nil;
	loadingView = nil;

	mainView = nil;
	loadedPanes = nil;
	panes = nil;
	paneInfo = nil;
	pendingPane = nil;

	if( self == sharedInstance ) sharedInstance = nil;
	[super dealloc];
}

- (void) awakeFromNib {
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"preferences.toolbar"] autorelease];
	NSArray *groups = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MVPreferencePaneGroups" ofType:@"plist"]];

	if( groups ) {
		if( ! groupView ) groupView = [[MVPreferencesGroupedIconView alloc] initWithFrame:[[window contentView] frame]];
		[groupView setPreferencesController:self];
		[groupView setPreferencePanes:panes];
		[groupView setPreferencePaneGroups:groups];
		mainView = [groupView retain];
	} else {
		if( ! multiView ) multiView = [[MVPreferencesIconView alloc] initWithFrame:[[window contentView] frame]];
		[multiView setPreferencesController:self];
		[multiView setPreferencePanes:panes];
		mainView = [multiView retain];
	}

	[self showAll:nil];

	[window setDelegate:self];

	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDelegate:self];
	[toolbar setAlwaysCustomizableByDrag:YES];
	[toolbar setShowsContextMenu:NO];
    [window setToolbar:toolbar];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[toolbar setIndexOfFirstMovableItem:2];
}

#pragma mark -

- (NSWindow *) window {
	return [[window retain] autorelease];
}

#pragma mark -

- (IBAction) showPreferences:(id) sender {
	static BOOL loaded = NO;
	if( ! loaded ) loaded = [NSBundle loadNibNamed:@"MVPreferences" owner:self];
	[self showAll:nil];
	if( ! [window isVisible] ) [window center];
	[window makeKeyAndOrderFront:nil];
}

#pragma mark -

- (IBAction) showAll:(id) sender {
	if( [[window contentView] isEqual:mainView] ) return;

	if( currentPaneIdentifier && [[loadedPanes objectForKey:currentPaneIdentifier] shouldUnselect] != NSUnselectNow ) {
		/* more to handle later */
		return;
	}

	[window setContentView:[[[NSView alloc] initWithFrame:[mainView frame]] autorelease]];

	[window setTitle:[NSString stringWithFormat:NSLocalizedStringFromTable( @"%@ Preferences", @"MVPreferences", "preferences window title" ), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]]];
	[self _resizeWindowForContentView:mainView];

	[[loadedPanes objectForKey:currentPaneIdentifier] willUnselect];
	[window setContentView:mainView];
	[[loadedPanes objectForKey:currentPaneIdentifier] didUnselect];

	[currentPaneIdentifier autorelease];
	currentPaneIdentifier = nil;

	[window setInitialFirstResponder:mainView];
	[window makeFirstResponder:mainView];
}

- (void) selectPreferencePaneByIdentifier:(NSString *) identifier {
	NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
	if( bundle && ! [currentPaneIdentifier isEqualToString:identifier] ) {
		NSPreferencePane *pane = nil;
		NSView *prefView = nil;
		if( currentPaneIdentifier && [[loadedPanes objectForKey:currentPaneIdentifier] shouldUnselect] != NSUnselectNow ) {
			/* more to handle later */
			closeWhenPaneIsReady = NO;
			[pendingPane autorelease];
			pendingPane = [identifier retain];
			return;
		}
		[pendingPane autorelease];
		pendingPane = nil;
		[loadingImageView setImage:[self _imageForPaneBundle:bundle]];
		[loadingTextFeld setStringValue:[NSString stringWithFormat:NSLocalizedStringFromTable( @"Loading %@...", @"MVPreferences", "loading message for the selected pane" ), [self _labelForPaneBundle:bundle]]];
		[window setTitle:[self _labelForPaneBundle:bundle]];
		[loadingView setFrameSize:NSMakeSize( NSWidth( [loadingView frame] ), [[window contentView] frame].size.height )];
		[loadingView setFrameOrigin:NSMakePoint( 0., 0. )];
		[window setContentView:loadingView];
		[window display];
		if( ! ( pane = [loadedPanes objectForKey:identifier] ) ) {
			pane = [[[[bundle principalClass] alloc] initWithBundle:bundle] autorelease];
			if( pane ) [loadedPanes setObject:pane forKey:identifier];
		}
		if( [pane loadMainView] ) {
			[pane willSelect];
			prefView = [pane mainView];

			[self _resizeWindowForContentView:prefView];

			[[loadedPanes objectForKey:currentPaneIdentifier] willUnselect];
			[window setContentView:prefView];
			[[loadedPanes objectForKey:currentPaneIdentifier] didUnselect];
			[pane didSelect];
			[[NSNotificationCenter defaultCenter] postNotificationName:MVPreferencesWindowNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self window], @"window", nil]];
			[currentPaneIdentifier autorelease];
			currentPaneIdentifier = [identifier copy];

			[window setInitialFirstResponder:[pane initialKeyView]];
			[window makeFirstResponder:[pane initialKeyView]];
		} else NSRunCriticalAlertPanel( NSLocalizedStringFromTable( @"Preferences Error", @"MVPreferences", "preferences error title" ), [NSString stringWithFormat:NSLocalizedStringFromTable( @"Could not load %@", @"MVPreferences", "error when loading the selected pane" ), [self _labelForPaneBundle:bundle]], nil, nil, nil );
	}
}

#pragma mark -

- (BOOL) windowShouldClose:(id) sender {
	if( currentPaneIdentifier && [[loadedPanes objectForKey:currentPaneIdentifier] shouldUnselect] != NSUnselectNow ) {
		closeWhenPaneIsReady = YES;
		return NO;
	}
	return YES;
}

- (void) windowWillClose:(NSNotification *) notification {
	[[loadedPanes objectForKey:currentPaneIdentifier] willUnselect];
	[[loadedPanes objectForKey:currentPaneIdentifier] didUnselect];
	[currentPaneIdentifier autorelease];
	currentPaneIdentifier = nil;
	[loadedPanes removeAllObjects];
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) itemIdentifier willBeInsertedIntoToolbar:(BOOL) flag {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	if( [itemIdentifier isEqualToString:MVToolbarShowAllItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedStringFromTable( @"Show All", @"MVPreferences", "show all toolbar item name" )];
		[toolbarItem setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( showAll: )];
	} else {
		NSBundle *bundle = [NSBundle bundleWithIdentifier:itemIdentifier];
		if( bundle ) {
			[toolbarItem setLabel:[self _labelForPaneBundle:bundle]];
			[toolbarItem setPaletteLabel:[self _paletteLabelForPaneBundle:bundle]];
			[toolbarItem setImage:[self _imageForPaneBundle:bundle]];
			[toolbarItem setTarget:self];
			[toolbarItem setAction:@selector( _selectPreferencePane: )];
		} else toolbarItem = nil;
	}
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *fixed = [NSMutableArray arrayWithObjects:MVToolbarShowAllItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
	NSArray *defaults = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MVPreferencePaneDefaults" ofType:@"plist"]];
	[fixed addObjectsFromArray:defaults];
	return fixed;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *items = [NSMutableArray array];
	NSEnumerator *enumerator = [panes objectEnumerator];
	id item = nil;
	while( ( item = [enumerator nextObject] ) )
		[items addObject:[item bundleIdentifier]];
	[items addObject:MVToolbarShowAllItemIdentifier];
	[items addObject:NSToolbarSeparatorItemIdentifier];
	return items;
}
@end

#pragma mark -

@implementation MVPreferencesController (MVPreferencesControllerPrivate)
- (IBAction) _selectPreferencePane:(id) sender {
	[self selectPreferencePaneByIdentifier:[sender itemIdentifier]];
}

- (void) _doUnselect:(NSNotification *) notification {
	if( closeWhenPaneIsReady ) [window close];
	[self selectPreferencePaneByIdentifier:pendingPane];
}

- (void) _resizeWindowForContentView:(NSView *) view {
	NSRect windowFrame, newWindowFrame;
	unsigned int newWindowHeight;

	windowFrame = [NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
	newWindowHeight = NSHeight( [view frame] );
	if( [[window toolbar] isVisible] )
		newWindowHeight += NSHeight( [[[window toolbar] _toolbarView] frame] );
	newWindowFrame = [NSWindow frameRectForContentRect:NSMakeRect( NSMinX( windowFrame ), NSMaxY( windowFrame ) - newWindowHeight, NSWidth( windowFrame ), newWindowHeight ) styleMask:[window styleMask]];

	[window setFrame:newWindowFrame display:YES animate:[window isVisible]];
}

- (NSImage *) _imageForPaneBundle:(NSBundle *) bundle {
	NSImage *image = nil;
	NSMutableDictionary *cache = [paneInfo objectForKey:[bundle bundleIdentifier]];
	image = [[[cache objectForKey:@"MVPreferencePaneImage"] retain] autorelease];
	if( ! image ) {
		NSDictionary *info = [bundle infoDictionary];
		image = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:[info objectForKey:@"NSPrefPaneIconFile"]]] autorelease];
		if( ! image ) image = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:[info objectForKey:@"CFBundleIconFile"]]] autorelease];
		if( ! cache ) [paneInfo setObject:[NSMutableDictionary dictionary] forKey:[bundle bundleIdentifier]];
		cache = [paneInfo objectForKey:[bundle bundleIdentifier]];
		if( image ) [cache setObject:image forKey:@"MVPreferencePaneImage"];
	}
	return image;
}

- (NSString *) _paletteLabelForPaneBundle:(NSBundle *) bundle {
	NSString *label = nil;
	NSMutableDictionary *cache = [paneInfo objectForKey:[bundle bundleIdentifier]];
	label = [[[cache objectForKey:@"MVPreferencePanePaletteLabel"] retain] autorelease];
	if( ! label ) {
		NSDictionary *info = [bundle localizedInfoDictionary];
		label = [info objectForKey:@"NSPrefPaneIconLabel"];
		if( ! label ) label = [info objectForKey:@"CFBundleName"];
		if( ! label ) label = [bundle bundleIdentifier];
		if( ! cache ) [paneInfo setObject:[NSMutableDictionary dictionary] forKey:[bundle bundleIdentifier]];
		cache = [paneInfo objectForKey:[bundle bundleIdentifier]];
		if( label ) [cache setObject:label forKey:@"MVPreferencePanePaletteLabel"];
	}
	return label;
}

- (NSString *) _labelForPaneBundle:(NSBundle *) bundle {
	NSString *label = nil;
	NSMutableDictionary *cache = [paneInfo objectForKey:[bundle bundleIdentifier]];
	label = [[[cache objectForKey:@"MVPreferencePaneLabel"] retain] autorelease];
	if( ! label ) {
		NSDictionary *info = [bundle localizedInfoDictionary];
		label = [info objectForKey:@"CFBundleName"];
		if( ! label ) label = [bundle bundleIdentifier];
		if( ! cache ) [paneInfo setObject:[NSMutableDictionary dictionary] forKey:[bundle bundleIdentifier]];
		cache = [paneInfo objectForKey:[bundle bundleIdentifier]];
		if( label ) [cache setObject:label forKey:@"MVPreferencePaneLabel"];
	}
	return label;
}
@end
