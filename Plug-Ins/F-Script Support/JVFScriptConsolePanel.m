#import "JVFScriptConsolePanel.h"
#import "JVChatController.h"

@implementation JVFScriptConsolePanel
- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[contents release];
	[_icon release];

	contents = nil;
	_icon = nil;
	_windowController = nil;

	[super dealloc];
}

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
		_nibLoaded = [[NSBundle bundleForClass:[self class]] loadNibFile:@"F-ScriptConsole" externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] withZone:[self zone]];
	}

	return contents;
}

- (NSResponder *) firstResponder {
	return console;
}

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"F-Script Console"];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	return [toolbar autorelease];
}

- (NSString *) title {
	return NSLocalizedString( @"F-Script Console", "F-Script console panel title" );
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

#pragma mark -

- (IBAction) objectBrowser:(id) sender {
	[[console interpreter] browse];
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Object Browser", "object browser menu item title" ) action:@selector( objectBrowser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

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
		NSString *file = [[NSBundle bundleForClass:[self class]] pathForResource:@"console" ofType:@"png"];
		_icon = [[NSImage alloc] initByReferencingFile:file];
	} return _icon;
}
@end