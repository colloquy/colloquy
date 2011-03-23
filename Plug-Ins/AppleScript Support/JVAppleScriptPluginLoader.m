#import "JVAppleScriptPluginLoader.h"
#import "JVAppleScriptEditorPanel.h"
#import "JVAppleScriptChatPlugin.h"
#import "JVChatWindowController.h"

#import <ChatCore/MVChatConnection.h>

@implementation JVAppleScriptPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) )
		_manager = manager;
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( ! [command caseInsensitiveCompare:@"applescript"] || ! [command caseInsensitiveCompare:@"as"] ) {
		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&subcmd];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

		NSString *path = nil;
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&path];
		if( ! [path length] ) return YES;

		path = [path stringByStandardizingPath];

		NSEnumerator *enumerator = [[_manager pluginsOfClass:[JVAppleScriptChatPlugin class] thatRespondToSelector:@selector( init )] objectEnumerator];
		JVAppleScriptChatPlugin *plugin = nil;

		while( ( plugin = [enumerator nextObject] ) )
			if( [[plugin scriptFilePath] isEqualToString:path] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
				break;

		if( ! plugin && ! [subcmd caseInsensitiveCompare:@"load"] ) {
			plugin = [[[JVAppleScriptChatPlugin alloc] initWithScriptAtPath:path withManager:_manager] autorelease];
			if( plugin ) [_manager addPlugin:plugin];
		} else if( ( ! [subcmd caseInsensitiveCompare:@"reload"] || ! [subcmd caseInsensitiveCompare:@"load"] ) && plugin ) {
			[plugin reloadFromDisk];
		} else if( ! [subcmd caseInsensitiveCompare:@"unload"] && plugin ) {
			[_manager removePlugin:plugin];
		} else if( ! [subcmd caseInsensitiveCompare:@"edit"] && plugin ) {
			[[NSWorkspace sharedWorkspace] openFile:[plugin scriptFilePath]];
		}

		return YES;
	}

	return NO;
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	for( NSString *path in [[_manager class] pluginSearchPaths] ) {
		for( NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] ) {
			if( [[file pathExtension] isEqualToString:@"scpt"] || [[file pathExtension] isEqualToString:@"scptd"] || [[file pathExtension] isEqualToString:@"applescript"] ) {
				JVAppleScriptChatPlugin *plugin = [[[JVAppleScriptChatPlugin alloc] initWithScriptAtPath:[NSString stringWithFormat:@"%@/%@", path, file] withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end
