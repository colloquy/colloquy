#import "JVAppleScriptEditorPanel.h"
#import "JVAppleScriptChatPlugin.h"
#import "JVChatController.h"

@implementation JVAppleScriptEditorPanel
- (id) init {
	if( ( self = [super init] ) ) {
		_plugin = nil;
		_icon = nil;
		_windowController = nil;
	}

	return self;
}

- (id) initWithAppleScriptChatPlugin:(JVAppleScriptChatPlugin *) plugin {
	if( ( self = [self init] ) )
		_plugin = [plugin retain];
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
	if( [self plugin] ) [[editor textStorage] setAttributedString:[[[self plugin] script] richTextSource]];
}

#pragma mark -

- (IBAction) close:(id) sender {
	[[JVChatController defaultManager] disposeViewController:self];
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
		_nibLoaded = [[NSBundle bundleForClass:[self class]] loadNibFile:@"AppleScriptPanel" externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] withZone:[self zone]];
	}

	return contents;
}

- (NSResponder *) firstResponder {
	return editor;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"AppleScript Editor"];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	return [toolbar autorelease];
}

- (NSString *) title {
	if( [self plugin] ) return [[[[self plugin] scriptFilePath] lastPathComponent] stringByDeletingPathExtension];
	return NSLocalizedString( @"untitled", "untitled AppleScript editor panel title" );
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

- (JVAppleScriptChatPlugin *) plugin {
	return _plugin;
}

#pragma mark -

- (IBAction) openScriptFile:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:[[self plugin] scriptFilePath]];
}

- (IBAction) reloadScriptFile:(id) sender {
	NSString *filePath = [[[[self plugin] scriptFilePath] copy] autorelease];
	MVChatPluginManager *manager = [[self plugin] pluginManager];

	[[[self plugin] pluginManager] removePlugin:[self plugin]];

	[_plugin release];
	_plugin = [[[JVAppleScriptChatPlugin alloc] initWithScriptAtPath:filePath withManager:manager] autorelease];

	if( [self plugin] ) [manager addPlugin:[self plugin]];
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	if( [self plugin] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Open Script File", "open script file menu item title" ) action:@selector( openScriptFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Reload Script File", "reload script file menu item title" ) action:@selector( reloadScriptFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	if( ! _icon ) {
		NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"scriptEditor" ofType:@"png"];
		_icon = [[NSImage alloc] initByReferencingFile:file];
	} return _icon;
}
@end