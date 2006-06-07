#import "JVPythonPluginLoader.h"
#import "JVPythonChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"
#import "pyobjc-api.h"

@implementation JVPythonPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) ) {
		_manager = manager;
		_pyobjcInstalled = ( PyObjC_ImportAPI != NULL ? YES : NO );
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
	[super dealloc];
}

- (void) displayInstallationWarning {
	NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"PyObjC Required", nil, [NSBundle bundleForClass:[self class]], "PyObjC required error title" ), NSLocalizedStringFromTableInBundle( @"PyObjC was not found. The Python console and any Python plugins will not work during this session. For the latest version of PyObjC visit http://pyobjc.sourceforge.net.", nil, [NSBundle bundleForClass:[self class]], "PyObjC required error message" ), nil, nil, nil );
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( ! [command caseInsensitiveCompare:@"python"] || ! [command caseInsensitiveCompare:@"py"] ) {
		if( ! _pyobjcInstalled ) {
			[self displayInstallationWarning];
			return YES;
		}

		NSArray *args = [[[arguments string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSString *subcmd = ( [args count] ? [args objectAtIndex:0] : nil );
		/* if( [args count] == 1 ) {
			if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
				JVPythonConsolePanel *console = [[[JVPythonConsolePanel alloc] init] autorelease];
				[[view windowController] addChatViewController:console];
				[[view windowController] performSelector:@selector( showChatViewController: ) withObject:console afterDelay:0];
			}
		} else */ if( [args count] > 1 ) {
			NSString *path = [[args subarrayWithRange:NSMakeRange( 1, ( [args count] - 1 ) )] componentsJoinedByString:@" "];
			path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( path ) {
				path = [path stringByStandardizingPath];

				NSEnumerator *pluginEnum = [_manager enumeratorOfPluginsOfClass:[JVPythonChatPlugin class] thatRespondToSelector:@selector( init )];
				JVPythonChatPlugin *plugin = nil;

				while( ( plugin = [pluginEnum nextObject] ) )
					if( [[[plugin scriptFilePath] stringByDeletingPathExtension] isEqualToString:[path stringByDeletingPathExtension]] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
						break;

				if( ! plugin ) {
					if( ! [subcmd caseInsensitiveCompare:@"load"] ) {
						[self loadPluginNamed:path];
					} else if( ! [subcmd caseInsensitiveCompare:@"create"] ) {
						path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"py"];
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
						JVPythonConsolePanel *console = [[[JVPythonConsolePanel alloc] initWithPythonChatPlugin:plugin] autorelease];
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
			NSString *pathExt = [path stringByAppendingPathExtension:@"py"];
			if( ! [fm fileExistsAtPath:pathExt] ) pathExt = [path stringByAppendingPathExtension:@"pyo"];
			if( ! [fm fileExistsAtPath:pathExt] ) pathExt = [path stringByAppendingPathExtension:@"pyc"];

			if( [fm fileExistsAtPath:pathExt] ) {
				if( ! _pyobjcInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				JVPythonChatPlugin *plugin = [[[JVPythonChatPlugin alloc] initWithScriptAtPath:pathExt withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
				return;
			}
		}
	}

	JVPythonChatPlugin *plugin = [[[JVPythonChatPlugin alloc] initWithScriptAtPath:name withManager:_manager] autorelease];
	if( plugin ) [_manager addPlugin:plugin];
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;

	NSMutableSet *foundModules = [NSMutableSet set];
	NSFileManager *fm = [NSFileManager defaultManager];

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[fm directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"pyc"] || [[file pathExtension] isEqualToString:@"py"] || [[file pathExtension] isEqualToString:@"pyo"] ) {
				if( ! _pyobjcInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				NSString *moduleName = [[file lastPathComponent] stringByDeletingPathExtension];
				if( [foundModules containsObject:moduleName] ) continue;
				[foundModules addObject:moduleName];

				// try to find the human editable version and use it's path
				file = [[path stringByAppendingPathComponent:file] stringByDeletingPathExtension];
				NSString *pathExt = [file stringByAppendingPathExtension:@"py"];
				if( ! [fm fileExistsAtPath:pathExt] ) pathExt = [file stringByAppendingPathExtension:@"pyo"];
				if( ! [fm fileExistsAtPath:pathExt] ) pathExt = [file stringByAppendingPathExtension:@"pyc"];

				JVPythonChatPlugin *plugin = [[[JVPythonChatPlugin alloc] initWithScriptAtPath:pathExt withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end