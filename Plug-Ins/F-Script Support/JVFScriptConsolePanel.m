#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import "JVChatController.h"

#import <FScript/FScript.h>

@implementation JVFScriptConsolePanel
- (instancetype) init {
	if( ( self = [super init] ) ) {
		_plugin = nil;
		_icon = nil;
		_windowController = nil;
	}

	return self;
}

- (instancetype) initWithFScriptChatPlugin:(JVFScriptChatPlugin *) plugin {
	if( ( self = [self init] ) ) {
		_plugin = plugin;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( close: ) name:MVChatPluginManagerWillReloadPluginsNotification object:[plugin pluginManager]];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	contents = nil;
	_plugin = nil;
	_icon = nil;
	_windowController = nil;
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
	return _windowController;
}

- (void) setWindowController:(JVChatWindowController *) controller {
	_windowController = controller;
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) {
		_nibLoaded = [[NSBundle bundleForClass:[self class]] loadNibNamed:@"F-ScriptConsole" owner:self topLevelObjects:NULL];
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
	return toolbar;
}

- (NSString *) toolbarIdentifier {
	return @"F-Script Console";
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	if( [identifier isEqualToString:@"JVFScriptBrowseToolbarItem"] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
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
	return @[@"JVFScriptBrowseToolbarItem"];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return @[@"JVFScriptBrowseToolbarItem",
		NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier];
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
	return [NSString stringWithFormat:@"F-Script Console %p", self];
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
	NSString *filePath = [[[self plugin] scriptFilePath] copy];
	MVChatPluginManager *manager = [[self plugin] pluginManager];

	[[[self plugin] pluginManager] removePlugin:[self plugin]];

	_plugin = [[JVFScriptChatPlugin alloc] initWithScriptAtPath:filePath withManager:manager];

	if( [self plugin] ) {
		[manager addPlugin:[self plugin]];
		[(id)[self interpreterView] setInterpreter:[[self plugin] scriptInterpreter]];
	} else [(id)[self interpreterView] setInterpreter:[FSInterpreter interpreter]];
}

- (NSMenu *) menu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Object Browser", nil, [NSBundle bundleForClass:[self class]], "object browser menu item title" ) action:@selector( objectBrowser: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	if( [self plugin] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Open Script File", nil, [NSBundle bundleForClass:[self class]], "open script file menu item title" ) action:@selector( openScriptFile: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Reload Script File", nil, [NSBundle bundleForClass:[self class]], "reload script file menu item title" ) action:@selector( reloadScriptFile: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Detach From Window", nil, [NSBundle bundleForClass:[self class]], "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultController]];
	[menu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle( @"Close", nil, [NSBundle bundleForClass:[self class]], "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	return menu;
}

- (NSImage *) icon {
	if( ! _icon ) {
		NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"console" ofType:@"png"];
		_icon = [[NSImage alloc] initByReferencingFile:file];
	} return _icon;
}
@end
