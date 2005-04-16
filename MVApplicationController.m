#import <ExceptionHandling/NSExceptionHandler.h>
#import <ChatCore/MVFileTransfer.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <ChatCore/NSColorAdditions.h>
#import "NSURLAdditions.h"
#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "JVChatWindowController.h"
#import "MVCrashCatcher.h"
#import "MVSoftwareUpdate.h"
#import "JVInspectorController.h"
#import "JVPreferencesController.h"
#import "JVGeneralPreferences.h"
#import "JVAppearancePreferences.h"
#import "JVNotificationPreferences.h"
#import "JVFileTransferPreferences.h"
#import "JVBehaviorPreferences.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "JVTranscriptPreferences.h"
#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "MVChatConnection.h"
#import "JVChatRoomBrowser.h"
#import "NSBundleAdditions.h"
#import "JVStyle.h"
#import "JVGetCommand.h"

#import <Foundation/NSDebug.h>

@interface WebCoreCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

NSString *JVChatStyleInstalledNotification = @"JVChatStyleInstalledNotification";
NSString *JVChatEmoticonSetInstalledNotification = @"JVChatEmoticonSetInstalledNotification";
static BOOL applicationIsTerminating = NO;

@implementation MVApplicationController
+ (BOOL) isTerminating {
	extern BOOL applicationIsTerminating;
	return applicationIsTerminating;
}

#pragma mark -

- (IBAction) checkForUpdate:(id) sender {
	[MVSoftwareUpdate checkAutomatically:NO];
}

- (IBAction) connectToSupportRoom:(id) sender {
	[[MVConnectionsController defaultManager] handleURL:[NSURL URLWithString:@"irc://irc.freenode.net/#colloquy"] andConnectIfPossible:YES];
}

- (IBAction) emailDeveloper:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:timothy@colloquy.info?subject=Colloquy%%20%%28build%%20%@%%29", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]]];
}

- (IBAction) productWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://colloquy.info"]];
}

#pragma mark -

- (IBAction) showInspector:(id) sender {
	if( [[[JVInspectorController sharedInspector] window] isKeyWindow] )
		[[[JVInspectorController sharedInspector] window] orderOut:nil];
	else [[JVInspectorController sharedInspector] show:nil];
}

- (IBAction) showPreferences:(id) sender {
	[[NSPreferences sharedPreferences] showPreferencesPanel];
}

- (IBAction) showTransferManager:(id) sender {
	if( [[[MVFileTransferController defaultManager] window] isKeyWindow] )
		[[MVFileTransferController defaultManager] hideTransferManager:nil];
	else [[MVFileTransferController defaultManager] showTransferManager:nil];
}

- (IBAction) showConnectionManager:(id) sender {
	if( [[[MVConnectionsController defaultManager] window] isKeyWindow] )
		[[MVConnectionsController defaultManager] hideConnectionManager:nil];
	else [[MVConnectionsController defaultManager] showConnectionManager:nil];
}

- (IBAction) showBuddyList:(id) sender {
	if( [[[MVBuddyListController sharedBuddyList] window] isKeyWindow] )
		[[MVBuddyListController sharedBuddyList] hideBuddyList:nil];
	else [[MVBuddyListController sharedBuddyList] showBuddyList:nil];
}

- (IBAction) openDocument:(id) sender {
	NSString *path = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];

	NSOpenPanel *openPanel = [[NSOpenPanel openPanel] retain];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"colloquyTranscript"]];
	[openPanel setResolvesAliases:YES];
	[openPanel beginSheetForDirectory:path file:nil types:nil modalForWindow:nil modalDelegate:self didEndSelector:@selector( openDocumentPanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) openDocumentPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];

	NSString *filename = [sheet filename];
	NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if( returnCode == NSOKButton && [[NSFileManager defaultManager] isReadableFileAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyTranscript"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coTr' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		[[JVChatController defaultManager] chatViewControllerForTranscript:filename];
	}
}

#pragma mark -

- (JVChatController *) chatController {
	return [JVChatController defaultManager];
}

- (MVConnectionsController *) connectionsController {
	return [MVConnectionsController defaultManager];
}

- (MVFileTransferController *) transferManager {
	return [MVFileTransferController defaultManager];
}

- (MVBuddyListController *) buddyList {
	return [MVBuddyListController sharedBuddyList];
}

#pragma mark -

- (IBAction) newConnection:(id) sender {
	[[MVConnectionsController defaultManager] newConnection:nil];
}

- (IBAction) joinRoom:(id) sender {
	[[JVChatRoomBrowser chatRoomBrowserForConnection:nil] showWindow:nil];
}

#pragma mark -

- (IBAction) copyStripped:(id) sender {
	if( [[NSApplication sharedApplication] sendAction:@selector( copy: ) to:nil from:sender] ) {
		unichar chr = 0x200b;
		NSString *space = [NSString stringWithCharacters:&chr length:1];
		NSPasteboard *pb = [NSPasteboard generalPasteboard];

		if( [[pb types] containsObject:NSStringPboardType] ) {
			NSMutableString *text = [[pb stringForType:NSStringPboardType] mutableCopy];
			if( text ) {
				[text replaceOccurrencesOfString:space withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [text length] )];
				[pb setString:text forType:NSStringPboardType];
				[text release];
			}
		}

		if( [[pb types] containsObject:NSRTFPboardType] ) {
			NSData *rtfData = [pb dataForType:NSRTFPboardType];
			if( rtfData ) {
				NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithRTF:rtfData documentAttributes:NULL];
				if( string ) {
					[[string mutableString] replaceOccurrencesOfString:space withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [string length] )];
					rtfData = [string RTFFromRange:NSMakeRange( 0, [string length] ) documentAttributes:nil];
					[pb setData:rtfData forType:NSRTFPboardType];
					[string release];
				}
			}
		}
	}
}

#pragma mark -

- (void) setupPreferences {
	static BOOL setupAlready = NO;
	if( setupAlready ) return;

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSToolbar Configuration NSPreferences"];

	[NSPreferences setDefaultPreferencesClass:[JVPreferencesController class]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"General", "general preference pane name" ) owner:[JVGeneralPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Appearance", "appearance preference pane name" ) owner:[JVAppearancePreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Notification", "notification preference pane name" ) owner:[JVNotificationPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Transfers", "file transfers preference pane name" ) owner:[JVFileTransferPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Transcripts", "chat transcript preference pane name" ) owner:[JVTranscriptPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Behavior", "behavior preference pane name" ) owner:[JVBehaviorPreferences sharedInstance]];

	setupAlready = YES;
}

#pragma mark -

- (BOOL) application:(NSApplication *) sender openFile:(NSString *) filename {
	NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if( [[NSFileManager defaultManager] isReadableFileAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyTranscript"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coTr' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		[[JVChatController defaultManager] chatViewControllerForTranscript:filename];
		return YES;
	} else if( [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyStyle"] == NSOrderedSame || [[filename pathExtension] caseInsensitiveCompare:@"fireStyle"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coSt' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *newPath = [[@"~/Library/Application Support/Colloquy/Styles" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
		if( [newPath isEqualToString:filename] ) return NO;

		if( [[NSWorkspace sharedWorkspace] isFilePackageAtPath:newPath] && [[NSFileManager defaultManager] isDeletableFileAtPath:newPath] ) {
			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Already Installed", "style already installed title" ), [[filename lastPathComponent] stringByDeletingPathExtension]], [NSString stringWithFormat:NSLocalizedString( @"The %@ style is already installed. Would you like to replace it with this version?", "would you like to replace a style with a different version" ), [[filename lastPathComponent] stringByDeletingPathExtension]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[[NSFileManager defaultManager] removeFileAtPath:newPath handler:nil];
			} else return NO;
		}

		if( [[NSFileManager defaultManager] movePath:filename toPath:newPath handler:nil] ) {
			NSBundle *bundle = [NSBundle bundleWithPath:newPath];
			JVStyle *style = [JVStyle newWithBundle:bundle];

			[[NSNotificationCenter defaultCenter] postNotificationName:JVChatStyleInstalledNotification object:style]; 

			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Successfully Installed", "style installed title" ), [style displayName]], [NSString stringWithFormat:NSLocalizedString( @"%@ is ready to be used in your colloquies. Would you like to view %@ and it's options in the Appearance Preferences?", "would you like to view the style in the Appearance Preferences" ), [style displayName], [style displayName]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[self setupPreferences];
				[[JVPreferencesController sharedPreferences] showPreferencesPanelForOwner:[JVAppearancePreferences sharedInstance]];
				[[JVAppearancePreferences sharedInstance] selectStyleWithIdentifier:[style identifier]];
			}

			return YES;
		} else {
			NSRunCriticalAlertPanel( NSLocalizedString( @"Style Installation Error", "error installing style title" ), NSLocalizedString( @"The style could not be installed, please make sure you have permission to install this item.", "style install error message" ), nil, nil, nil );
		} return NO;
	} else if( [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyEmoticons"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coEm' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *newPath = [[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
		if( [newPath isEqualToString:filename] ) return NO;

		if( [[NSWorkspace sharedWorkspace] isFilePackageAtPath:newPath] && [[NSFileManager defaultManager] isDeletableFileAtPath:newPath] ) {
			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Already Installed", "emoticons already installed title" ), [[filename lastPathComponent] stringByDeletingPathExtension]], [NSString stringWithFormat:NSLocalizedString( @"The %@ emoticons are already installed. Would you like to replace them with this version?", "would you like to replace an emoticon bundle with a different version" ), [[filename lastPathComponent] stringByDeletingPathExtension]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[[NSFileManager defaultManager] removeFileAtPath:newPath handler:nil];
			} else return NO;
		}

		if( [[NSFileManager defaultManager] movePath:filename toPath:newPath handler:nil] ) {
			NSBundle *emoticon = [NSBundle bundleWithPath:newPath];
			[[NSNotificationCenter defaultCenter] postNotificationName:JVChatEmoticonSetInstalledNotification object:emoticon]; 

			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Successfully Installed", "emoticon installed title" ), [emoticon displayName]], [NSString stringWithFormat:NSLocalizedString( @"%@ is ready to be used in your colloquies. Would you like to view %@ and it's options in the Appearance Preferences?", "would you like to view the emoticons in the Appearance Preferences" ), [emoticon displayName], [emoticon displayName]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[self setupPreferences];
				[[JVPreferencesController sharedPreferences] showPreferencesPanelForOwner:[JVAppearancePreferences sharedInstance]];
				[[JVAppearancePreferences sharedInstance] selectEmoticonsWithIdentifier:[emoticon bundleIdentifier]];
			}

			return YES;
		} else {
			NSRunCriticalAlertPanel( NSLocalizedString( @"Emoticon Installation Error", "error installing emoticons title" ), NSLocalizedString( @"The emoticons could not be installed, please make sure you have permission to install this item.", "emoticons install error message" ), nil, nil, nil );
		} return NO;
	} return NO;
}

- (BOOL) application:(NSApplication *) sender printFile:(NSString *) filename {
	NSLog( @"printFile %@", filename );
	return NO;
}

- (void) handleURLEvent:(NSAppleEventDescriptor *) event withReplyEvent:(NSAppleEventDescriptor *) replyEvent {
	NSURL *url = [NSURL URLWithString:[[event descriptorAtIndex:1] stringValue]];
	if( [MVChatConnection supportsURLScheme:[url scheme]] ) [[MVConnectionsController defaultManager] handleURL:url andConnectIfPossible:YES];
	else [[NSWorkspace sharedWorkspace] openURL:url];
}

- (BOOL) exceptionHandler:(NSExceptionHandler *) sender shouldLogException:(NSException *) exception mask:(unsigned int) mask {
	return NO;
}

- (BOOL) exceptionHandler:(NSExceptionHandler *) sender shouldHandleException:(NSException *) exception mask:(unsigned int) mask {
	static BOOL _exceptionHandlerLoop = NO;
	if( _exceptionHandlerLoop ) return NO;
	_exceptionHandlerLoop = YES;

	NSTask *ls = [[NSTask alloc] init];
	NSString *pid = [[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]] stringValue];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
	NSPipe *pipe = [NSPipe pipe];

	NSString *stack = [[exception userInfo] objectForKey:NSStackTraceKey];
	NSMutableArray *stackArray = [[[stack componentsSeparatedByString:@"  "] mutableCopy] autorelease];

	if( [stackArray count] > 4 ) [stackArray removeObjectsInRange:NSMakeRange( 0, 4 )];

#ifndef DEBUG
	[stackArray removeObjectsInRange:NSMakeRange( 1, [stackArray count] - 1 )];
#endif

	[args addObject:@"-p"];
	[args addObject:pid];
	[args addObjectsFromArray:stackArray];

	[ls setStandardOutput:pipe];
	[ls setLaunchPath:@"/usr/bin/atos"];
	[ls setArguments:args];
	[ls launch];
	[ls waitUntilExit];

	NSData *result = [[pipe fileHandleForReading] readDataToEndOfFile];
	NSString *trace = [[[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding] autorelease];

#ifdef DEBUG
	NSLog( @"Exception Stack Trace:\n%@", trace );
	NSRange loc = [trace rangeOfString:@"\n"];
	if( loc.location != NSNotFound )
		trace = [trace substringWithRange:[trace lineRangeForRange:NSMakeRange( 0, loc.location )]];
#endif

	NSString *reason = [exception reason];
	if( [reason hasPrefix:@"*** "] ) reason = [reason substringFromIndex:4];

	if( NSRunCriticalAlertPanel( NSLocalizedString( @"An unresolved error has occurred.", "exception error title" ), NSLocalizedString( @"Please report this message to the Colloquy development team with a brief synopsis of your actions leading to this message. Areas of Colloquy may fail to function normally until you relaunch.\n\n%@\n\nThe error occurred in:\n%@", "exception error message" ), NSLocalizedString( @"Continue", "continue button title" ), NSLocalizedString( @"Quit", "quit button title" ), nil, reason, trace ) == NSCancelButton ) {
		[[NSApplication sharedApplication] terminate:nil];
	}

	[ls release];

	_exceptionHandlerLoop = NO;
	return YES;
}

#pragma mark -

- (void) applicationWillFinishLaunching:(NSNotification *) notification {
	[JVGetCommand poseAsClass:[NSGetCommand class]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[[NSBundle mainBundle] bundleIdentifier] ofType:@"plist"]]];
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector( handleURLEvent:withReplyEvent: ) forEventClass:kInternetEventClass andEventID:kAEGetURL];
#ifdef DEBUG
	NSDebugEnabled = YES;
//	NSZombieEnabled = YES;
//	NSDeallocateZombies = NO;
//	[NSAutoreleasePool enableFreedObjectCheck:YES];
#endif
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableExceptionOccurredDialog"] ) {
		NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
		[handler setExceptionHandlingMask:( NSLogUncaughtExceptionMask | NSLogUncaughtSystemExceptionMask | NSLogUncaughtRuntimeErrorMask | NSHandleUncaughtExceptionMask|NSHandleUncaughtSystemExceptionMask | NSHandleUncaughtRuntimeErrorMask )];
		[handler setDelegate:self];
	}

	[MVCrashCatcher check];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"] )
		[MVSoftwareUpdate checkAutomatically:YES];

	[[MVColorPanel sharedColorPanel] attachColorList:[[[NSColorList alloc] initWithName:@"Chat" fromFile:[[NSBundle mainBundle] pathForResource:@"Chat" ofType:@"clr"]] autorelease]];

	[WebCoreCache setDisabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"]];

	[self setupPreferences];

	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Plugins" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles/Variants" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Chat Rooms" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Acquaintances" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc/Client Keys" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc/Server Keys" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Scripts/Applications" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Scripts/Applications/Colloquy" stringByExpandingTildeInPath] attributes:nil];
	
	[MVChatPluginManager defaultManager];
	[MVConnectionsController defaultManager];
	[JVChatController defaultManager];
	[MVFileTransferController defaultManager];
//	[MVBuddyListController sharedBuddyList];

	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:20] setSubmenu:[MVConnectionsController favoritesMenu]];
	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:30] setSubmenu:[JVChatController smartTranscriptMenu]];

	NSRange range = NSRangeFromString( [[NSUserDefaults standardUserDefaults] stringForKey:@"JVFileTransferPortRange"] );
	[MVFileTransfer setFileTransferPortRange:range];
}

- (void) applicationWillBecomeActive:(NSNotification *) notification {
	[MVConnectionsController refreshFavoritesMenu];
}

- (void) applicationWillTerminate:(NSNotification *) notification {
	extern BOOL applicationIsTerminating;
	applicationIsTerminating = YES;

	[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];

	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (NSMenu *) applicationDockMenu:(NSApplication *) sender {
	NSMenu *menu = [[[NSMenu allocWithZone:[self zone]] initWithTitle:@""] autorelease];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	id view = nil;

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	[invocation setArgument:&sender atIndex:2];
	[invocation setArgument:&view atIndex:3];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	if( [results count] ) {
		NSArray *items = nil;
		NSMenuItem *item = nil;
		NSEnumerator *enumerator = [results objectEnumerator];
		while( ( items = [enumerator nextObject] ) ) {
			if( ! [items respondsToSelector:@selector( objectEnumerator )] ) continue;
			NSEnumerator *ienumerator = [items objectEnumerator];
			while( ( item = [ienumerator nextObject] ) )
				if( [item isKindOfClass:[NSMenuItem class]] ) [menu addItem:item];
		}

		if( [[[menu itemArray] lastObject] isSeparatorItem] )
			[menu removeItem:[[menu itemArray] lastObject]];
	}

	return menu;
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( joinRoom: ) ) {
		if( [[[MVConnectionsController defaultManager] connections] count] ) return YES;
		else return NO;
	}
	return YES;
}
@end