#import "JVFScriptPluginLoader.h"
#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import <ChatCore/MVChatConnection.h>
#import "JVChatWindowController.h"
#import "JVChatController.h"

#import <FScript/FScript.h>

@interface JVFScriptPluginLoader () <MVChatPluginCommandSupport>

@end

#if !(defined(__FScript_FSNSObject_H__) || defined(__FScript_FSNSString_H__))
#error STOP: You need F-Script installed to build Colloquy. F-Script can be found at: http://www.fscript.org
#endif

@implementation JVFScriptPluginLoader
- (instancetype) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) ) {
		_manager = manager;
		_fscriptInstalled = ( NSClassFromString( @"FSInterpreter" ) ? YES : NO );
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
}

- (void) displayInstallationWarning {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedStringFromTableInBundle( @"F-Script Framework Required", nil, [NSBundle bundleForClass:[self class]], "F-Script required error title" );
	alert.informativeText = NSLocalizedStringFromTableInBundle( @"The F-Script framework was not found. The F-Script console and any F-Script plugins will not work during this session. For the latest version of F-Script visit http://www.fscript.org.", nil, [NSBundle bundleForClass:[self class]], "F-Script framework required error message" );
	alert.alertStyle = NSAlertStyleCritical;
	[alert runModal];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( ! [command caseInsensitiveCompare:@"fscript"] || ! [command caseInsensitiveCompare:@"fs"] ) {
		if( ! _fscriptInstalled ) {
			[self displayInstallationWarning];
			return YES;
		}

		NSArray *args = [[[arguments string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
		NSString *subcmd = ( [args count] ? args[0] : nil );
		if( [args count] == 1 ) {
			if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
				JVFScriptConsolePanel *console = [[JVFScriptConsolePanel alloc] init];
				[[view windowController] addChatViewController:console];
				[[view windowController] performSelector:@selector(showChatViewController:) withObject:console afterDelay:0];
			} else if( ! [subcmd caseInsensitiveCompare:@"browse"] ) {
				FSInterpreter *interpreter = [FSInterpreter interpreter];
				if( connection) [interpreter setObject:connection forIdentifier:@"connection"];
				if( view ) [interpreter setObject:view forIdentifier:@"view"];
				[interpreter browse];
			}
		} else if( [args count] > 1 ) {
			NSString *path = [[args subarrayWithRange:NSMakeRange( 1, ( [args count] - 1 ) )] componentsJoinedByString:@" "];
			path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if( path ) {
				if( ! [subcmd caseInsensitiveCompare:@"eval"] ) {
					FSInterpreter *interpreter = [FSInterpreter interpreter];
					if( connection) [interpreter setObject:connection forIdentifier:@"connection"];
					if( view ) [interpreter setObject:view forIdentifier:@"view"];
					[interpreter execute:path];
				} else {
					path = [path stringByStandardizingPath];

					NSEnumerator *pluginEnum = [[_manager pluginsOfClass:[JVFScriptChatPlugin class] thatRespondToSelector:@selector( init )] objectEnumerator];
					JVFScriptChatPlugin *plugin = nil;

					while( ( plugin = [pluginEnum nextObject] ) )
						if( [[plugin scriptFilePath] isEqualToString:path] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
							break;

					if( ! plugin ) {
						if( ! [subcmd caseInsensitiveCompare:@"load"] ) {
							[self loadPluginNamed:path];
						} else if( ! [subcmd caseInsensitiveCompare:@"create"] ) {
							path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"fscript"];
							if( ! [path isAbsolutePath] )
								path = [[[_manager class] pluginSearchPaths][0] stringByAppendingPathComponent:path];
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
						} else if( view && ! [subcmd caseInsensitiveCompare:@"console"] ) {
							JVFScriptConsolePanel *console = [[JVFScriptConsolePanel alloc] initWithFScriptChatPlugin:plugin];
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
	
		for (__strong NSString *path in paths) {
			path = [path stringByAppendingPathComponent:[name stringByDeletingPathExtension]];
			path = [path stringByAppendingPathExtension:@"fscript"];
			if( [fm fileExistsAtPath:path] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				JVFScriptChatPlugin *plugin = [[JVFScriptChatPlugin alloc] initWithScriptAtPath:path withManager:_manager];
				if( plugin ) [_manager addPlugin:plugin];
				return;
			}
		}
	}

	JVFScriptChatPlugin *plugin = [[JVFScriptChatPlugin alloc] initWithScriptAtPath:name withManager:_manager];
	if( plugin ) [_manager addPlugin:plugin];
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	for( NSString *path in [[_manager class] pluginSearchPaths] ) {
		for( NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] ) {
			if( [[file pathExtension] isEqualToString:@"fscript"] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				JVFScriptChatPlugin *plugin = [[JVFScriptChatPlugin alloc] initWithScriptAtPath:[path stringByAppendingPathComponent:file] withManager:_manager];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end
