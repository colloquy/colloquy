#import "JVAppleScriptPluginLoader.h"
#import "JVAppleScriptEditorPanel.h"
#import "JVAppleScriptChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"

@implementation JVAppleScriptPluginLoader
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
	if( ( ! [command caseInsensitiveCompare:@"applescript"] || ! [command caseInsensitiveCompare:@"as"] ) && ! [[arguments string] caseInsensitiveCompare:@"editor"] ) {
		JVAppleScriptEditorPanel *editor = [[[JVAppleScriptEditorPanel alloc] init] autorelease];
		[[view windowController] addChatViewController:editor];
		[[view windowController] showChatViewController:editor];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"applescript"] || ! [command caseInsensitiveCompare:@"as"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&subcmd];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

		NSString *path = nil;
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&path];
		if( ! [path length] ) return YES;

		path = [path stringByStandardizingPath];

		NSEnumerator *enumerator = [_manager enumeratorOfPluginsOfClass:[JVAppleScriptChatPlugin class] thatRespondToSelector:@selector( init )];
		JVAppleScriptChatPlugin *plugin = nil;

		while( ( plugin = [enumerator nextObject] ) )
			if( [[plugin scriptFilePath] isEqualToString:path] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
				break;

		if( ! [subcmd caseInsensitiveCompare:@"load"] || ! [subcmd caseInsensitiveCompare:@"reload"] ) {
			if( plugin ) [_manager removePlugin:plugin];
			NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:NULL] autorelease];
			if( ! [script compileAndReturnError:nil] ) return YES;
			JVAppleScriptChatPlugin *plugin = [[[JVAppleScriptChatPlugin alloc] initWithScript:script atPath:path withManager:_manager] autorelease];
			if( plugin ) [_manager addPlugin:plugin];
		} else if( ! [subcmd caseInsensitiveCompare:@"unload"] && plugin ) {
			[_manager removePlugin:plugin];
		} else if( ( ! [subcmd caseInsensitiveCompare:@"edit"] || ! [subcmd caseInsensitiveCompare:@"editor"] ) && plugin && view ) {
			JVAppleScriptEditorPanel *editor = [[[JVAppleScriptEditorPanel alloc] initWithAppleScriptChatPlugin:plugin] autorelease];
			[[view windowController] addChatViewController:editor];
			[[view windowController] showChatViewController:editor];
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
			if( [[file pathExtension] isEqualToString:@"scpt"] || [[file pathExtension] isEqualToString:@"scptd"] || [[file pathExtension] isEqualToString:@"applescript"] ) {
				NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", path, file]] error:NULL] autorelease];
				if( ! [script compileAndReturnError:nil] ) continue;
				JVAppleScriptChatPlugin *plugin = [[[JVAppleScriptChatPlugin alloc] initWithScript:script atPath:[NSString stringWithFormat:@"%@/%@", path, file] withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}
@end
