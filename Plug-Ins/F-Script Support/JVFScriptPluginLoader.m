#import "JVFScriptPluginLoader.h"
#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"
#import <FScript/FSInterpreter.h>

#ifndef __FScript_FSNSObject_H__
#error STOP: You need F-Script installed to build Colloquy. F-Script can be found at: http://www.fscript.org
#endif

@implementation JVFScriptPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [super init] ) {
		_manager = manager;
		_fscriptInstalled = ( NSClassFromString( @"FSInterpreter" ) ? YES : NO );
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
	[super dealloc];
}

- (void) displayInstallationWarning {
	NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"F-Script Framework Required", nil, [NSBundle bundleForClass:[self class]], "F-Script required error title" ), NSLocalizedStringFromTableInBundle( @"The F-Script framework was not found. The F-Script console and any F-Script plugins will not work during this session. For the latest version of F-Script visit http://www.fscript.org.", nil, [NSBundle bundleForClass:[self class]], "F-Script framework required error message" ), nil, nil, nil );
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( ! [command caseInsensitiveCompare:@"fscript"] ) {
		if( ! _fscriptInstalled ) {
			[self displayInstallationWarning];
			return YES;
		}
		// ok, parse the arguments
		NSArray *args = [[[arguments string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
							componentsSeparatedByString:@" "];
		NSString *subcmd = ( [args count] ? [args objectAtIndex:0] : nil );
		if( [args count] == 1 ) {
			if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
				JVFScriptConsolePanel *console = [[[JVFScriptConsolePanel alloc] init] autorelease];
				[[view windowController] addChatViewController:console];
				// For some reason the input field wasn't clearing for me
				// This should fix that
#warning TODO: Find a better way to deal with this
				//[[view windowController] showChatViewController:console];
				[[view windowController] performSelector:@selector(showChatViewController:) withObject:console afterDelay:0];
			} else if( ! [subcmd caseInsensitiveCompare:@"browse"] ) {
				FSInterpreter *interpreter = [FSInterpreter interpreter];
				if( connection) [interpreter setObject:connection forIdentifier:@"connection"];
				if( view ) [interpreter setObject:view forIdentifier:@"view"];
				[interpreter browse];
			}
		} else if( [args count] > 1 ) {
			NSString *path = [[args subarrayWithRange:NSMakeRange(1, [args count] - 1)] componentsJoinedByString:@" "];
			path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( path ) {
				if( ! [subcmd caseInsensitiveCompare:@"eval"] ) {
					FSInterpreter *interpreter = [FSInterpreter interpreter];
					if( connection) [interpreter setObject:connection forIdentifier:@"connection"];
					if( view ) [interpreter setObject:view forIdentifier:@"view"];
					[interpreter execute:path];
				} else {
					path = [path stringByStandardizingPath];
					
					NSEnumerator *pluginEnum = [_manager enumeratorOfPluginsOfClass:[JVFScriptChatPlugin class] thatRespondToSelector:@selector( init )];
					JVFScriptChatPlugin *plugin;
					
					while( plugin = [pluginEnum nextObject] )
						if( [[plugin scriptFilePath] isEqualToString:path] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
							break;
					
					if( ! plugin ) {
						if( ! [subcmd caseInsensitiveCompare:@"load"] ) {
							[self loadPluginNamed:path];
						}
						if( ! [subcmd caseInsensitiveCompare:@"create"] ) {
							NSFileManager *fm = [NSFileManager defaultManager];
							BOOL dir;
							path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"fscript"];
							path = [[[[_manager class] pluginSearchPaths] objectAtIndex:0] stringByAppendingPathComponent:path];
							if( [fm fileExistsAtPath:[path stringByDeletingLastPathComponent] isDirectory:&dir] && dir ) {
								[fm createFileAtPath:path contents:[NSData data] attributes:nil];
								[[NSWorkspace sharedWorkspace] openFile:path];
							}
						}
					} else if( plugin ) {
						if( ! [subcmd caseInsensitiveCompare:@"reload"] || ! [subcmd caseInsensitiveCompare:@"load"] ) {
							[plugin reloadFromDisk];
						} else if( ! [subcmd caseInsensitiveCompare:@"unload"] ) {
							[_manager removePlugin:plugin];
						} else if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
							JVFScriptConsolePanel *console = [[[JVFScriptConsolePanel alloc] initWithFScriptChatPlugin:plugin] autorelease];
							[[view windowController] addChatViewController:console];
							[[view windowController] showChatViewController:console];
						} else if( ! [subcmd caseInsensitiveCompare:@"edit"] ) {
							[[NSWorkspace sharedWorkspace] openFile:[plugin scriptFilePath]];
						} else if( ! [subcmd caseInsensitiveCompare:@"browse"] ) {
							[[plugin scriptInterpreter] browse];
						}
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
		while( path = [enumerator nextObject] ) {
			path = [path stringByAppendingPathComponent:name];
			path = [path stringByAppendingPathExtension:@"fscript"];
			if( [fm fileExistsAtPath:path] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstallationWarning];
					return;
				}
				
				JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:path withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
				return;
			}
		}
	}
	
	JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:name withManager:_manager] autorelease];
	if( plugin ) [_manager addPlugin:plugin];
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( path = [enumerator nextObject] ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"fscript"] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:[NSString stringWithFormat:@"%@/%@", path, file] withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end
