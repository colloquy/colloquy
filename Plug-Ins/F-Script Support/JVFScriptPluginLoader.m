#import "JVFScriptPluginLoader.h"
#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"

@implementation JVFScriptPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [super init] ) {
		_manager = manager;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( detachNotifications ) name:MVChatPluginManagerWillReloadPluginsNotification object:manager];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( findAndLoadPlugins ) name:MVChatPluginManagerDidReloadPluginsNotification object:manager];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( ! NSClassFromString( @"FSInterpreter" ) ) return NO;

	if( view && ! [command caseInsensitiveCompare:@"fscript"] && ! [[arguments string] caseInsensitiveCompare:@"console"] ) {
		JVFScriptConsolePanel *console = [[[JVFScriptConsolePanel alloc] init] autorelease];
		[[view windowController] addChatViewController:console];
		[[view windowController] showChatViewController:console];
		return YES;
	}

	return NO;
}

- (void) detachNotifications {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) findAndLoadPlugins {
	if( ! _manager || ! NSClassFromString( @"FSInterpreter" ) ) return;

	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"fscript"] ) {
				JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:[NSString stringWithFormat:@"%@/%@", path, file] withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}
@end
