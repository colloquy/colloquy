#import "JVFScriptPluginLoader.h"
#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"

@implementation JVFScriptPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [super init] ) {
		_manager = manager;
		_fscriptInstalled = ( NSClassFromString( @"FSInterpreter" ) ? YES : NO );
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

- (void) displayInstalationWarning {
	NSRunCriticalAlertPanel( NSLocalizedString( @"F-Script Framework Required", "F-Script required error title" ), NSLocalizedString( @"The F-Script framework was not found. The F-Script console and any F-Script plugins will not work during this session. For the latest version of F-Script visit http://www.fscript.org.", "F-Script framework required error message" ), nil, nil, nil );
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( view && ! [command caseInsensitiveCompare:@"fscript"] && ! [[arguments string] caseInsensitiveCompare:@"console"] ) {
		if( ! _fscriptInstalled ) {
			[self displayInstalationWarning];
			return YES;
		}

		JVFScriptConsolePanel *console = [[[JVFScriptConsolePanel alloc] init] autorelease];
		[[view windowController] addChatViewController:console];
		[[view windowController] showChatViewController:console];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"fscript"] ) {
		if( ! _fscriptInstalled ) {
			[self displayInstalationWarning];
			return NO;
		}

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
	if( ! _manager ) return;

	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"fscript"] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstalationWarning];
					return;
				}

				JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:[NSString stringWithFormat:@"%@/%@", path, file] withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}
@end
