#import "JVJavaScriptPluginLoader.h"
#import "JVJavaScriptChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"

@implementation JVJavaScriptPluginLoader
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
	if( ! [command caseInsensitiveCompare:@"javascript"] || ! [command caseInsensitiveCompare:@"js"] ) {
		NSArray *args = [[[arguments string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSString *subcmd = ( [args count] ? [args objectAtIndex:0] : nil );
		/* if( [args count] == 1 ) {
			if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
				JVJavaScriptConsolePanel *console = [[[JVJavaScriptConsolePanel alloc] init] autorelease];
				[[view windowController] addChatViewController:console];
				[[view windowController] performSelector:@selector( showChatViewController: ) withObject:console afterDelay:0];
			}
		} else */ if( [args count] > 1 ) {
			NSString *path = [[args subarrayWithRange:NSMakeRange( 1, ( [args count] - 1 ) )] componentsJoinedByString:@" "];
			path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( path ) {
				path = [path stringByStandardizingPath];

				NSEnumerator *pluginEnum = [_manager enumeratorOfPluginsOfClass:[JVJavaScriptChatPlugin class] thatRespondToSelector:@selector( init )];
				JVJavaScriptChatPlugin *plugin = nil;

				while( ( plugin = [pluginEnum nextObject] ) )
					if( [[[plugin scriptFilePath] stringByDeletingPathExtension] isEqualToString:[path stringByDeletingPathExtension]] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
						break;

				if( ! plugin ) {
					if( ! [subcmd caseInsensitiveCompare:@"load"] ) {
						[self loadPluginNamed:path];
					} else if( ! [subcmd caseInsensitiveCompare:@"create"] ) {
						path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"js"];
						if( ! [path isAbsolutePath] )
							path = [[[[_manager class] pluginSearchPaths] objectAtIndex:0] stringByAppendingPathComponent:path];
						if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] ) {
							if( [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil] )
								[[NSWorkspace sharedWorkspace] openFile:path];
						}
					}
				} else if( plugin ) {
					if( ! [subcmd caseInsensitiveCompare:@"reload"] || ! [subcmd caseInsensitiveCompare:@"load"] ) {
						[plugin reloadFromDisk];
					} else if( ! [subcmd caseInsensitiveCompare:@"unload"] ) {
						[_manager removePlugin:plugin];
					/* } else if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
						JVJavaScriptConsolePanel *console = [[[JVJavaScriptConsolePanel alloc] initWithJavaScriptChatPlugin:plugin] autorelease];
						[[view windowController] addChatViewController:console];
						[[view windowController] showChatViewController:console]; */
					} else if( ! [subcmd caseInsensitiveCompare:@"edit"] ) {
						[[NSWorkspace sharedWorkspace] openFile:[plugin scriptFilePath]];
					}
				}
			}
		}

		return YES;
	}

	return NO;
}

- (void) loadPluginNamed:(NSString *) name {
	// Look through the standard plugin paths
	if( ! _manager ) return;

	if( ! [name isAbsolutePath] ) {
		NSArray *paths = [[_manager class] pluginSearchPaths];
		NSFileManager *fm = [NSFileManager defaultManager];

		NSEnumerator *enumerator = [paths objectEnumerator];
		NSString *path = nil;
		while( ( path = [enumerator nextObject] ) ) {
			NSString *pathExt = [path stringByAppendingPathComponent:name];
			if( [fm fileExistsAtPath:pathExt] ) {
				JVJavaScriptChatPlugin *plugin = [[JVJavaScriptChatPlugin alloc] initWithScriptAtPath:pathExt withManager:_manager];
				if( plugin ) [_manager addPlugin:plugin];
				[plugin release];
				return;
			}
		}
	}

	JVJavaScriptChatPlugin *plugin = [[JVJavaScriptChatPlugin alloc] initWithScriptAtPath:name withManager:_manager];
	if( plugin ) [_manager addPlugin:plugin];
	[plugin release];
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[fm directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"js"] ) {
				NSString *pathExt = [path stringByAppendingPathComponent:file];
				JVJavaScriptChatPlugin *plugin = [[JVJavaScriptChatPlugin alloc] initWithScriptAtPath:pathExt withManager:_manager];
				if( plugin ) [_manager addPlugin:plugin];
				[plugin release];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end