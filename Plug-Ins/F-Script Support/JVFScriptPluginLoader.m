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
	} else if( ! [command caseInsensitiveCompare:@"fscript"] ) {
		BOOL load = NO;
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&subcmd];
		if( ! [subcmd caseInsensitiveCompare:@"load"] || ! [subcmd caseInsensitiveCompare:@"reload"] ) load = YES;
		else if( ! [subcmd caseInsensitiveCompare:@"unload"] ) load = NO;
		else return NO;

		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

		NSString *path = nil;
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&path];
		if( ! [path length] ) return YES;
		if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] ) return YES;

		path = [path stringByStandardizingPath];

		NSEnumerator *enumerator = [_manager enumeratorOfPluginsOfClass:[JVFScriptChatPlugin class] thatRespondToSelector:@selector( init )];
		JVFScriptChatPlugin *plugin = nil;

		while( ( plugin = [enumerator nextObject] ) )
			if( [[plugin scriptFilePath] isEqualToString:path] )
				break;

		if( plugin ) [_manager removePlugin:plugin];
		if( load ) {
			plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:path withManager:_manager] autorelease];
			if( plugin ) [_manager addPlugin:plugin];
		}

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
