#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import "JVChatController.h"

#import <FScript/FScript.h>

@implementation JVFScriptConsolePanel
- (id) init {
	if( ( self = [super init] ) ) {
		_plugin = nil;
		_icon = nil;
		_windowController = nil;
	}

	return self;
}

- (id) initWithFScriptChatPlugin:(JVFScriptChatPlugin *) plugin {
	if( ( self = [self init] ) ) {
		_plugin = [plugin retain];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( close: ) name:MVChatPluginManagerWillReloadPluginsNotification object:[plugin pluginManager]];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[contents release];
	[_plugin release];
	[_icon release];

	contents = nil;
	_plugin = nil;
	_icon = nil;
	_windowController = nil;

	[super dealloc];
}

- (void) awakeFromNib {
	if( [self plugin] ) [(id)[self interpreterView] setInterpreter:[[self plugin] scriptInterpreter]];
}

#pragma mark -

- (IBAction) close:(id) sender {
	[[JVChatController defaultController] disposeViewController:self];
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
	if( ! _nibLoaded ) {
		_nibLoaded = [[NSBundle bundleForClass:[self class]] loadNibFile:@"F-ScriptConsole" externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] withZone:[self zone]];
	}

	return contents;
}

- (NSResponder *) firstResponder {
	return console;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"F-Script Console"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	if( [identifier isEqualToString:@"JVFScriptBrowseToolbarItem"] ) {
		NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
		[toolbarItem setLabel:NSLocalizedStringFromTableInBundle( @"Browse", nil, [NSBundle bundleForClass:[self class]], "browse fscript toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTableInBundle( @"Object Browser", nil, [NSBundle bundleForClass:[self class]], "browse fscript toolbar customize palette name" )];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( objectBrowser: )];
		[toolbarItem setImage:[NSImage imageNamed:@"reveal"]];
		return toolbarItem;
	}

	return nil;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObject:@"JVFScriptBrowseToolbarItem"];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:@"JVFScriptBrowseToolbarItem",
		NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

- (NSString *) title {
	if( [self plugin] ) return [NSString stringWithFormat:NSLocalizedStringFromTableInBundle( @"%@ Console", nil, [NSBundle bundleForClass:[self class]], "plugin named console panel title" ), [[[[self plugin] scriptFilePath] lastPathComponent] stringByDeletingPathExtension]];
	return NSLocalizedStringFromTableInBundle( @"F-Script Console", nil, [NSBundle bundleForClass:[self class]], "F-Script console panel title" );
}

- (NSString *) windowTitle {
	return [self title];
}

- (NSString *) information {
	return nil;
}

- (NSString *) toolTip {
	return [self title];
}

#pragma mark -

- (id <JVChatListItem>) parent {
	return nil;
}

#pragma mark -

- (NSString *) identifier {
	return [NSString stringWithFormat:@"F-Script Console %x", self];
}

- (MVChatConnection *) connection {
	return nil;
}

- (JVFScriptChatPlugin *) plugin {
	return _plugin;
}

- (FSInterpreterView *) interpreterView {
	return console;
}

#pragma mark -

- (IBAction) objectBrowser:(id) sender {
	[[console interpreter] browse];
}

- (IBAction) openScriptFile:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:[[self plugin] scriptFilePath]];
}

- (IBAction) reloadScriptFile:(id) sender {
	NSString *filePath = [[[[self plugin] scriptFilePath] copy] autorelease];
	MVChatPluginManager *manager = [[self plugin] pluginManager];

	[[[self plugin] pluginManager] removePlugin:[self plugin]];

	[_plugin release];
	_plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:filePath withManager:manager] autorelease];

	if( [self plugin] ) {
		[manager addPlugin:[self plugin]];
		[(id)[self interpreterView] setInterpreter:[[self plugin] scriptInterpreter]];
	} else [(id)[self interpreterView] setInterpreter:[FSInterpreter interpreter]];
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Object Browser", nil, [NSBundle bundleForClass:[self class]], "object browser menu item title" ) action:@selector( objectBrowser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	if( [self plugin] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Open Script File", nil, [NSBundle bundleForClass:[self class]], "open script file menu item title" ) action:@selector( openScriptFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Reload Script File", nil, [NSBundle bundleForClass:[self class]], "reload script file menu item title" ) action:@selector( reloadScriptFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Detach From Window", nil, [NSBundle bundleForClass:[self class]], "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultController]];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Close", nil, [NSBundle bundleForClass:[self class]], "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	if( ! _icon ) {
		NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"console" ofType:@"png"];
		_icon = [[NSImage alloc] initByReferencingFile:file];
	} return _icon;
}
@end