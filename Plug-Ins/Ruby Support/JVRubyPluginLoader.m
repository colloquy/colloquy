#import "JVRubyPluginLoader.h"
#import "JVRubyChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"

@implementation JVRubyPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) ) {
		_manager = manager;
		_rubyCocoaInstalled = ( RBRubyCocoaInit != NULL ? YES : NO );
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
	[super dealloc];
}

- (void) displayInstallationWarning {
	NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"RubyCocoa Required", nil, [NSBundle bundleForClass:[self class]], "RubyCocoa required error title" ), NSLocalizedStringFromTableInBundle( @"RubyCocoa was not found. The Ruby console and any Ruby plugins will not work during this session. For the latest version of RubyCocoa visit http://rubycocoa.sourceforge.net.", nil, [NSBundle bundleForClass:[self class]], "RubyCocoa required error message" ), nil, nil, nil );
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( ! [command caseInsensitiveCompare:@"ruby"] || ! [command caseInsensitiveCompare:@"rb"] ) {
		if( ! _rubyCocoaInstalled ) {
			[self displayInstallationWarning];
			return YES;
		}

		NSArray *args = [[[arguments string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSString *subcmd = ( [args count] ? [args objectAtIndex:0] : nil );
		/* if( [args count] == 1 ) {
			if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
				JVRubyConsolePanel *console = [[[JVRubyConsolePanel alloc] init] autorelease];
				[[view windowController] addChatViewController:console];
				[[view windowController] performSelector:@selector( showChatViewController: ) withObject:console afterDelay:0];
			}
		} else */ if( [args count] > 1 ) {
			NSString *path = [[args subarrayWithRange:NSMakeRange( 1, ( [args count] - 1 ) )] componentsJoinedByString:@" "];
			path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( path ) {
				path = [path stringByStandardizingPath];

				NSEnumerator *pluginEnum = [_manager enumeratorOfPluginsOfClass:[JVRubyChatPlugin class] thatRespondToSelector:@selector( init )];
				JVRubyChatPlugin *plugin = nil;

				while( ( plugin = [pluginEnum nextObject] ) )
					if( [[[plugin scriptFilePath] stringByDeletingPathExtension] isEqualToString:[path stringByDeletingPathExtension]] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
						break;

				if( ! plugin ) {
					if( ! [subcmd caseInsensitiveCompare:@"load"] ) {
						[self loadPluginNamed:path];
					} else if( ! [subcmd caseInsensitiveCompare:@"create"] ) {
						path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"rb"];
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
						JVRubyConsolePanel *console = [[[JVRubyConsolePanel alloc] initWithRubyChatPlugin:plugin] autorelease];
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
			path = [path stringByAppendingPathComponent:[name stringByDeletingPathExtension]];
			path = [path stringByAppendingPathExtension:@"rb"];

			if( [fm fileExistsAtPath:path] ) {
				if( ! _rubyCocoaInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				JVRubyChatPlugin *plugin = [[[JVRubyChatPlugin alloc] initWithScriptAtPath:path withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
				return;
			}
		}
	}

	JVRubyChatPlugin *plugin = [[[JVRubyChatPlugin alloc] initWithScriptAtPath:name withManager:_manager] autorelease];
	if( plugin ) [_manager addPlugin:plugin];
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;
	NSFileManager *fm = [NSFileManager defaultManager];

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[fm directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"rb"] ) {
				if( ! _rubyCocoaInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				file = [path stringByAppendingPathComponent:file];

				JVRubyChatPlugin *plugin = [[[JVRubyChatPlugin alloc] initWithScriptAtPath:file withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end