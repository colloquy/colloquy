#import "JVAppleScriptEditorPanel.h"
#import "JVAppleScriptChatPlugin.h"
#import "JVChatController.h"

#include <OpenScripting/OSA.h>

static NSString *JVToolbarCompileItemIdentifier = @"JVToolbarCompileItem";

@interface NSAppleScript (NSAppleScriptPrivate)
+ (struct ComponentInstanceRecord *) _defaultScriptingComponent;
@end

#pragma mark -

@interface NSAppleScript (NSAppleScriptSaveAdditions)
- (BOOL) saveToFile:(NSString *) path;
@end

#pragma mark -

@implementation NSAppleScript (NSAppleScriptSaveAdditions)
- (BOOL) saveToFile:(NSString *) path {
	AEDesc desc = { typeNull, NULL };
	OSAError result = OSAStore( [NSAppleScript _defaultScriptingComponent], _compiledScriptID, typeOSAGenericStorage, kOSAModeNull, &desc );

	if( result == noErr ) {
		NSMutableData *data = [NSMutableData dataWithLength:(unsigned int)AEGetDescDataSize( &desc )];

		if( AEGetDescData( &desc, [data mutableBytes], [data length] ) != noErr )
			data = nil;

		AEDisposeDesc( &desc );

		return [data writeToFile:path atomically:NO];
	}

	return NO;
}
@end

#pragma mark -

@implementation JVAppleScriptEditorPanel
+ (NSDictionary *) uncompiledScriptAttributes {
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	NSFont *font = [NSFont fontWithName:@"Courier" size:12.];
	if( font ) [attributes setObject:font forKey:NSFontAttributeName];
	[attributes setObject:[NSColor purpleColor] forKey:NSForegroundColorAttributeName];
	return attributes;
}

- (id) init {
	if( ( self = [super init] ) ) {
		_script = nil;
		_plugin = nil;
		_icon = nil;
		_windowController = nil;
		_unsavedChanges = NO;
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
	if( [self plugin] ) {
		[[editor textStorage] setAttributedString:[[[self plugin] script] richTextSource]];
	} else {
		NSString *new = @"using terms from application \"Colloquy\"\n\t-- Untitled Script Plugin\nend using terms from\n";
		NSAttributedString *format = [[[NSAttributedString alloc] initWithString:new attributes:[[self class] uncompiledScriptAttributes]] autorelease];
		[[editor textStorage] setAttributedString:format];
	}
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
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

- (NSString *) title {
	if( [[[self plugin] scriptFilePath] length] )
		return [[[[self plugin] scriptFilePath] lastPathComponent] stringByDeletingPathExtension];
	return NSLocalizedString( @"Untitled", "untitled AppleScript editor panel title" );
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

- (BOOL) compile:(id) sender {
	NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:[[editor textStorage] string]] autorelease];
	if( ! script ) return;

	NSDictionary *errorInfo = nil;

	if( ! [script compileAndReturnError:&errorInfo] ) {
		NSRange range = [[errorInfo objectForKey:NSAppleScriptErrorRange] rangeValue];
		[editor setSelectedRange:range affinity:NSSelectionAffinityUpstream stillSelecting:NO];
		NSRunCriticalAlertPanel( NSLocalizedString( @"AppleScript Syntax Error", "AppleScript syntax error title" ), [errorInfo objectForKey:NSAppleScriptErrorMessage] , nil, nil, nil );
		return;
	}

	[_script autorelease];
	_script = [script retain];

	[[editor textStorage] setAttributedString:[_script richTextSource]];

	if( ! [self plugin] ) {
		JVAppleScriptChatPlugin *plugin = [[[JVAppleScriptChatPlugin alloc] initWithScript:script atPath:nil withManager:[MVChatPluginManager defaultManager]] autorelease];
		if( plugin ) {
			[[MVChatPluginManager defaultManager] addPlugin:plugin];
			_plugin = [plugin retain];
		}
	} else [[self plugin] setScript:_script];
}

- (IBAction) saveDocumentTo:(id) sender {
	NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
	[savePanel setDelegate:self];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:@"scpt"];
	[savePanel beginSheetForDirectory:[@"~/Library/Application Support/Colloquy/Plugins" stringByExpandingTildeInPath] file:[self title] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( savePanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton && [self compile:nil] ) {
		[[[self plugin] script] saveToFile:[sheet filename]];
		[[self plugin] setScriptFilePath:[sheet filename]];
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[sheet isExtensionHidden]], NSFileExtensionHidden, nil] atPath:[sheet filename]];
	}
}

#pragma mark -

- (IBAction) openScriptFile:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:[[self plugin] scriptFilePath]];
}

- (IBAction) reloadScriptFile:(id) sender {
	[[self plugin] reloadFromDisk];
	[[editor textStorage] setAttributedString:[[[self plugin] script] richTextSource]];
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
	}

	if( _unsavedChanges ) {
		NSImage *shaded = [[[NSImage alloc] initWithSize:[_icon size]] autorelease];
		[shaded lockFocus];
		[_icon compositeToPoint:NSMakePoint( 0., 0. ) operation:NSCompositeSourceOver fraction:0.5];
		[shaded unlockFocus];
		return shaded;
	}

	return _icon;
}

#pragma mark -

- (void) textViewDidChangeSelection:(NSNotification *) notification {
	[editor setTypingAttributes:[[self class] uncompiledScriptAttributes]];
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

	if( [identifier isEqualToString:JVToolbarToggleChatDrawerItemIdentifier] ) {
		toolbarItem = [_windowController toggleChatDrawerToolbarItem];
	} else if( [identifier isEqualToString:JVToolbarCompileItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Compile", "compile script toolbar item label" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Compile", "compile script toolbar item patlette label" )];
		[toolbarItem setToolTip:NSLocalizedString( @"Compile the Script", "compile script toolbar item tooltip" )];
		[toolbarItem setImage:[[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"compile" ofType:@"png"]]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( compile: )];
	} else toolbarItem = nil;

	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarCompileItemIdentifier, nil];
	return [[list retain] autorelease];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSArray *list = [NSArray arrayWithObjects:JVToolbarCompileItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];

	return [[list retain] autorelease];
}
@end