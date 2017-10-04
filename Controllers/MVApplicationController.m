#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "JVChatWindowController.h"
#import "MVCrashCatcher.h"
#import "JVInspectorController.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "JVChatRoomBrowser.h"
#import "NSBundleAdditions.h"
#import "JVStyle.h"
#import "JVChatRoomPanel.h"
#import "JVDirectChatPanel.h"
#import "JVAnalyticsController.h"
//#import "JVChatTranscriptBrowserPanel.h"
#import "CQKeychain.h"

#import "PFMoveApplicationController.h"

#import "CQMPreferencesWindowController.h"
#import "JVAppearancePreferencesViewController.h"

#import <Sparkle/SUUpdater.h>

@interface WebCoreCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

@interface WebCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

NSString *JVChatStyleInstalledNotification = @"JVChatStyleInstalledNotification";
NSString *JVChatEmoticonSetInstalledNotification = @"JVChatEmoticonSetInstalledNotification";
NSString *JVMachineBecameIdleNotification = @"JVMachineBecameIdleNotification";
NSString *JVMachineStoppedIdlingNotification = @"JVMachineStoppedIdlingNotification";

static BOOL applicationIsTerminating = NO;


@interface MVApplicationController (Private)
- (void) openDocumentPanelDidEnd:(NSOpenPanel *) panel returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo;
@end

@implementation MVApplicationController

@synthesize preferencesWindowController = _preferencesWindowController;

- (id) init {
	if( ( self = [super init] ) ) {
		mach_port_t masterPort = 0;
		IOMasterPort( MACH_PORT_NULL, &masterPort );

		io_iterator_t hidIter = 0;
		IOServiceGetMatchingServices( masterPort, IOServiceMatching( "IOHIDSystem" ), &hidIter );

		_hidEntry = IOIteratorNext( hidIter );
		IOObjectRelease( hidIter );

		_isIdle = NO;
		_lastIdle = 0.;
		_idleCheck = [NSTimer scheduledTimerWithTimeInterval:30. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES];
	}

	return self;
}

- (void) dealloc {
	if( _hidEntry ) {
		IOObjectRelease( _hidEntry );
		_hidEntry = 0;
	}


}

#pragma mark -

+ (BOOL) isTerminating {
	return applicationIsTerminating;
}

#pragma mark -

// idle stuff adapted from a post by Jonathan 'Wolf' Rentzsch on the cocoa-dev mailing list.

- (NSTimeInterval) idleTime {
	NSMutableDictionary *hidProperties = nil;
	CFMutableDictionaryRef hidPropertiesRef = (__bridge CFMutableDictionaryRef)hidProperties;
	IORegistryEntryCreateCFProperties( _hidEntry, &hidPropertiesRef, kCFAllocatorDefault, 0 );

	id hidIdleTimeObj = [hidProperties objectForKey:@"HIDIdleTime"];
	unsigned long long result;

	if( [hidIdleTimeObj isKindOfClass:[NSData class]] ) [hidIdleTimeObj getBytes:&result length:[hidIdleTimeObj length]];
	else result = [hidIdleTimeObj longLongValue];

	if (hidPropertiesRef)
		CFRelease(hidPropertiesRef);

	return ( result / 1000000000. );
}

- (void) checkIdle:(id) sender {
	NSTimeInterval idle = [self idleTime];

	if( _isIdle ) {
		if( idle < _lastIdle ) {
			// no longer idle

			_isIdle = NO;
			[[NSNotificationCenter chatCenter] postNotificationName:JVMachineStoppedIdlingNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:idle] forKey:@"idleTime"]];

			// reschedule the timer, to check for idle every 10 seconds
			[_idleCheck invalidate];

			_idleCheck = [NSTimer scheduledTimerWithTimeInterval:10. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES];
		}
	} else {
		if( idle > [[NSUserDefaults standardUserDefaults] integerForKey:@"JVIdleTime"] ) {
			// we're now idle

			_isIdle = YES;
			[[NSNotificationCenter chatCenter] postNotificationName:JVMachineBecameIdleNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:idle] forKey:@"idleTime"]];

			// reschedule the timer, we will check every 2 seconds to catch the user's return quickly
			[_idleCheck invalidate];

			_idleCheck = [NSTimer scheduledTimerWithTimeInterval:2. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES];
		}
	}

	_lastIdle = idle;
}

#pragma mark -

- (IBAction) checkForUpdate:(id) sender {
	if( ! _updater ) _updater = [[SUUpdater alloc] init];
	[_updater checkForUpdates:sender];
}

- (IBAction) helpWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://project.colloquy.info/wiki/Documentation"]];
}

- (IBAction) connectToSupportRoom:(id) sender {
	[[MVConnectionsController defaultController] handleURL:[NSURL URLWithString:@"irc://irc.freenode.net/#colloquy"] andConnectIfPossible:YES];
}

- (IBAction) emailDeveloper:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:support@colloquy.info?subject=Colloquy%%20%%28build%%20%@%%29", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]]];
}

- (IBAction) productWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://colloquy.info"]];
}

- (IBAction) bugReportWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://colloquy.info?bug"]];
}

#pragma mark -

- (CQMPreferencesWindowController *)preferencesWindowController {
	if (_preferencesWindowController == nil) {
		// Create preferences window controller with the built-in preferences view controllers.
		_preferencesWindowController = [[CQMPreferencesWindowController alloc] init];
		
		
		// Add plugin preferences view controllers.
		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSViewController<MASPreferencesViewController> * ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setSelector:@selector( preferencesViewController )];
		
		NSArray<NSViewController<MASPreferencesViewController> *> *pluginPreferencesVCs = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
		
		for (NSViewController<MASPreferencesViewController> *pluginPreferencesVC in pluginPreferencesVCs) {
			[_preferencesWindowController addViewController:pluginPreferencesVC];
		}
	}
	return _preferencesWindowController;
}

- (void) setupFolders {
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/PlugIns" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles/Variants" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Sounds" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
//	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Chat Rooms" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
//	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Acquaintances" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc/Client Keys" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc/Server Keys" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Scripts/Applications" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
	[fm createDirectoryAtPath:[@"~/Library/Scripts/Applications/Colloquy" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
}

#pragma mark -

- (IBAction) showInspector:(id) sender {
	if( [[[JVInspectorController sharedInspector] window] isKeyWindow] )
		[[[JVInspectorController sharedInspector] window] orderOut:nil];
	else [[JVInspectorController sharedInspector] show:nil];
}

- (IBAction) showPreferences:(id) sender {
	[self.preferencesWindowController showWindow:sender];
}

- (IBAction) showTransferManager:(id) sender {
	if( [[[MVFileTransferController defaultController] window] isKeyWindow] )
		[[MVFileTransferController defaultController] hideTransferManager:nil];
	else [[MVFileTransferController defaultController] showTransferManager:nil];
}

- (IBAction) showConnectionManager:(id) sender {
	if( [[[MVConnectionsController defaultController] window] isKeyWindow] )
		[[MVConnectionsController defaultController] hideConnectionManager:nil];
	else [[MVConnectionsController defaultController] showConnectionManager:nil];
}

- (IBAction) showTranscriptBrowser:(id) sender {
//	[[JVChatTranscriptBrowserPanel sharedBrowser] showBrowser:self];
}

- (IBAction) showBuddyList:(id) sender {
	if( [[[MVBuddyListController sharedBuddyList] window] isKeyWindow] )
		[[MVBuddyListController sharedBuddyList] hideBuddyList:nil];
	else [[MVBuddyListController sharedBuddyList] showBuddyList:nil];
}

- (IBAction) openDocument:(id) sender {
	NSString *path = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];

	NSArray *fileTypes = [NSArray arrayWithObject:@"colloquyTranscript"];
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setResolvesAliases:YES];
	[openPanel setDirectoryURL:[NSURL fileURLWithPath:path isDirectory:YES]];
	[openPanel setAllowedFileTypes:fileTypes];
	[openPanel beginWithCompletionHandler:^(NSInteger result) {
		[self openDocumentPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
	}];
}

- (void) openDocumentPanelDidEnd:(NSOpenPanel *) panel returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	NSString *filename = [[panel URL] path];
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
	if( returnCode == NSModalResponseOK && [[NSFileManager defaultManager] isReadableFileAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyTranscript"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coTr' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		[[JVChatController defaultController] chatViewControllerForTranscript:filename];
	}
}

#pragma mark -

- (JVChatController *) chatController {
	return [JVChatController defaultController];
}

- (MVConnectionsController *) connectionsController {
	return [MVConnectionsController defaultController];
}

- (MVFileTransferController *) transferManager {
	return [MVFileTransferController defaultController];
}

- (MVBuddyListController *) buddyList {
	return [MVBuddyListController sharedBuddyList];
}

#pragma mark -

- (IBAction) newConnection:(id) sender {
	[[MVConnectionsController defaultController] newConnection:nil];
}

- (IBAction) joinRoom:(id) sender {
	if( ! [[[MVConnectionsController defaultController] connections] count] )
		return;
	NSArray *connections = [[MVConnectionsController defaultController] connectedConnections];
	MVChatConnection *connection = ( [connections count] ? [connections objectAtIndex:0] : nil );
	[[JVChatRoomBrowser chatRoomBrowserForConnection:connection] showWindow:nil];
}

#pragma mark -

- (IBAction) markAllDisplays:(id) sender {
	JVChatController *chatController = [JVChatController defaultController];
	Class controllerClass = [JVDirectChatPanel class];
	NSSet *viewControllers = [chatController chatViewControllersKindOfClass:controllerClass];
	[viewControllers makeObjectsPerformSelector:@selector( markDisplay: ) withObject:sender];
}

#pragma mark -

- (BOOL) application:(NSApplication *) sender openFile:(NSString *) filename {
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];

	if( [[NSFileManager defaultManager] isReadableFileAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyTranscript"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coTr' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *searchString = nil;

		NSAppleEventManager *sam = [NSAppleEventManager sharedAppleEventManager];
		NSAppleEventDescriptor *lastEvent = [sam currentAppleEvent];
		searchString = [[lastEvent descriptorForKeyword:keyAESearchText] stringValue];

		JVChatTranscriptPanel *transcript = [[JVChatController defaultController] chatViewControllerForTranscript:filename];
		if( searchString ) [transcript setSearchQuery:searchString];

		return YES;
	} else if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename] && */ ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyStyle"] == NSOrderedSame || [[filename pathExtension] caseInsensitiveCompare:@"fireStyle"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coSt' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *newPath = [[@"~/Library/Application Support/Colloquy/Styles" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
		if( [newPath isEqualToString:filename] ) return NO;

		if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:newPath] && */ [[NSFileManager defaultManager] isDeletableFileAtPath:newPath] ) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = [NSString stringWithFormat:NSLocalizedString( @"%@ Already Installed", "style already installed title" ), [[filename lastPathComponent] stringByDeletingPathExtension]];
			alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"The %@ style is already installed. Would you like to replace it with this version?", "would you like to replace a style with a different version" ), [[filename lastPathComponent] stringByDeletingPathExtension]];
			alert.alertStyle = NSAlertStyleInformational;
			[alert addButtonWithTitle:NSLocalizedString( @"Yes", "yes button" )];
			[alert addButtonWithTitle:NSLocalizedString( @"No", "no button" )];
			NSModalResponse response = [alert runModal];
			
			if( response == NSAlertFirstButtonReturn ) {
				[[NSFileManager defaultManager] removeItemAtPath:newPath error:nil];
			} else {
				return NO;
			}
		}

		if( [[NSFileManager defaultManager] moveItemAtPath:filename toPath:newPath error:nil] ) {
			NSBundle *bundle = [NSBundle bundleWithPath:newPath];
			JVStyle *style = [JVStyle newWithBundle:bundle];

			[[NSNotificationCenter chatCenter] postNotificationName:JVChatStyleInstalledNotification object:style];

			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = [NSString stringWithFormat:NSLocalizedString( @"%@ Successfully Installed", "style installed title" ), [style displayName]];
			alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"%@ is ready to be used in your colloquies. Would you like to view %@ and it's options in the Appearance Preferences?", "would you like to view the style in the Appearance Preferences" ), [style displayName], [style displayName]];
			alert.alertStyle = NSAlertStyleInformational;
			[alert addButtonWithTitle:NSLocalizedString( @"Yes", "yes button" )];
			[alert addButtonWithTitle:NSLocalizedString( @"No", "no button" )];
			NSModalResponse response = [alert runModal];

			if( response == NSAlertFirstButtonReturn ) {
				[self showPreferences:nil];
				[self.preferencesWindowController selectControllerWithIdentifier:self.preferencesWindowController.appearancePreferences.identifier];
				[self.preferencesWindowController.appearancePreferences selectStyleWithIdentifier:[style identifier]];
			}

			return YES;
		} else {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedString( @"Style Installation Error", "error installing style title" );
			alert.informativeText = NSLocalizedString( @"The style could not be installed, please make sure you have permission to install this item.", "style install error message" );
			alert.alertStyle = NSAlertStyleCritical;
			[alert runModal];
			
		} return NO;
	} else if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename] && */ ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyEmoticons"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coEm' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *newPath = [[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
		if( [newPath isEqualToString:filename] ) return NO;

		if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:newPath] && */ [[NSFileManager defaultManager] isDeletableFileAtPath:newPath] ) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = [NSString stringWithFormat:NSLocalizedString( @"%@ Already Installed", "emoticons already installed title" ), [[filename lastPathComponent] stringByDeletingPathExtension]];
			alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"The %@ emoticons are already installed. Would you like to replace them with this version?", "would you like to replace an emoticon bundle with a different version" ), [[filename lastPathComponent] stringByDeletingPathExtension]];
			alert.alertStyle = NSAlertStyleInformational;
			[alert addButtonWithTitle:NSLocalizedString( @"Yes", "yes button" )];
			[alert addButtonWithTitle:NSLocalizedString( @"No", "no button" )];
			NSModalResponse response = [alert runModal];

			if( response == NSAlertFirstButtonReturn ) {
				[[NSFileManager defaultManager] removeItemAtPath:newPath error:nil];
			} else return NO;
		}

		if( [[NSFileManager defaultManager] moveItemAtPath:filename toPath:newPath error:nil] ) {
			NSBundle *emoticon = [NSBundle bundleWithPath:newPath];
			[[NSNotificationCenter chatCenter] postNotificationName:JVChatEmoticonSetInstalledNotification object:emoticon];

			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = [NSString stringWithFormat:NSLocalizedString( @"%@ Successfully Installed", "emoticon installed title" ), [emoticon displayName]];
			alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"%@ is ready to be used in your colloquies. Would you like to view %@ and it's options in the Appearance Preferences?", "would you like to view the emoticons in the Appearance Preferences" ), [emoticon displayName], [emoticon displayName]];
			alert.alertStyle = NSAlertStyleInformational;
			[alert addButtonWithTitle:NSLocalizedString( @"Yes", "yes button" )];
			[alert addButtonWithTitle:NSLocalizedString( @"No", "no button" )];
			NSModalResponse response = [alert runModal];

			if( response == NSAlertFirstButtonReturn ) {
				[self showPreferences:nil];
				[self.preferencesWindowController selectControllerWithIdentifier:self.preferencesWindowController.appearancePreferences.identifier];
				[self.preferencesWindowController.appearancePreferences selectEmoticonsWithIdentifier:[emoticon bundleIdentifier]];
			}

			return YES;
		} else {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedString( @"Emoticon Installation Error", "error installing emoticons title" );
			alert.informativeText = NSLocalizedString( @"The emoticons could not be installed, please make sure you have permission to install this item.", "emoticons install error message" );
			alert.alertStyle = NSAlertStyleCritical;
			[alert runModal];
			
		} return NO;
	} return NO;
}

- (BOOL) application:(NSApplication *) sender printFile:(NSString *) filename {
	NSLog( @"printFile %@", filename );
	return NO;
}

- (void) handleURLEvent:(NSAppleEventDescriptor *) event withReplyEvent:(NSAppleEventDescriptor *) replyEvent {
	NSURL *url = [NSURL URLWithString:[[event descriptorAtIndex:1] stringValue]];
	if( [MVChatConnection supportsURLScheme:[url scheme]] ) [[MVConnectionsController defaultController] handleURL:url andConnectIfPossible:YES];
	else [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark -

- (void) receiveSleepNotification:(NSNotification *) notification {
	_previouslyConnectedConnections = [[NSMutableArray alloc] init];

	NSString *quitString = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVSleepMessage"];
	NSAttributedString *quitAttributedString = ( quitString ? [[NSAttributedString alloc] initWithString:quitString] : nil );
	NSArray *openedConnections = [[MVConnectionsController defaultController] connectedConnections];
	MVChatConnection *connection = nil;

	for ( connection in openedConnections ) {
		NSMutableDictionary *connectionInformation = [[NSMutableDictionary alloc] init];

		[connection disconnectWithReason:quitAttributedString];
		[connectionInformation setObject:connection forKey:@"connection"];

		if ( [[connection awayStatusMessage] length] )
			[connectionInformation setObject:[connection awayStatusMessage] forKey:@"away"];
		else [connectionInformation setObject:@"" forKey:@"away"];

		[_previouslyConnectedConnections addObject:connectionInformation];

	}

}

- (void) receiveWakeNotification:(NSNotification *) notification {
	[self performSelector:@selector( _receiveWakeNotification: ) withObject:notification afterDelay:5.];
}

- (void) _receiveWakeNotification:(NSNotification *) notification {
	NSDictionary *connectionInformation = nil;

	for ( connectionInformation in _previouslyConnectedConnections ) {
		MVChatConnection *connection = [connectionInformation objectForKey:@"connection"];
		[connection connect];

		if ([(MVChatString *) [connectionInformation objectForKey:@"away"] length])
			[connection setAwayStatusMessage:[connectionInformation objectForKey:@"away"]];
	}

	_previouslyConnectedConnections = nil;
}

- (IBAction) terminateWithoutConfirm:(id) sender {
	_terminateWithoutConfirm = YES;
	[[NSApplication sharedApplication] terminate:sender];
}

- (void) applicationWillFinishLaunching:(NSNotification *) notification {
	PFMoveToApplicationsFolderIfNecessary();

	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[[NSBundle mainBundle] bundleIdentifier] ofType:@"plist"]]];
	if ([[[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys] indexOfObject:@"JVRemoveTransferedItems"] != NSNotFound) {
		[[NSUserDefaults standardUserDefaults] setInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"] forKey:@"JVRemoveTransferredItems"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVRemoveTransferedItems"];
	}
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector( handleURLEvent:withReplyEvent: ) forEventClass:kInternetEventClass andEventID:kAEGetURL];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MVAskOnInvalidCertificates"] || [[[CQKeychain standardKeychain] passwordForServer:@"MVAskOnInvalidCertificates" area:@"MVSecurePrefs"] boolValue])
		[[CQKeychain standardKeychain] setPassword:@"1" forServer:@"MVAskOnInvalidCertificates" area:@"MVSecurePrefs"];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	_launchDate = [[NSDate alloc] init];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"] && NSAppKitVersionNumber >= NSAppKitVersionNumber10_4 ) {
		_updater = [[SUUpdater alloc] init];
		[_updater checkForUpdatesInBackground];
		[_updater setUpdateCheckInterval:60. * 60. * 12.]; // check every 12 hours
	}

	[[MVColorPanel sharedColorPanel] attachColorList:[[NSColorList alloc] initWithName:@"Chat" fromFile:[[NSBundle mainBundle] pathForResource:@"Chat" ofType:@"clr"]]];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"] ) {
		Class webCacheClass = NSClassFromString( @"WebCache" );
		if( ! webCacheClass ) webCacheClass = NSClassFromString( @"WebCoreCache" );

		[webCacheClass setDisabled:YES];
	}

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( invalidPluginsFound: ) name:MVChatPluginManagerDidFindInvalidPluginsNotification object:nil];

	[MVConnectionsController defaultController];
	[JVChatController defaultController];
	[MVChatPluginManager defaultManager];

	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:20] setSubmenu:[MVConnectionsController favoritesMenu]];
	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:30] setSubmenu:[JVChatController smartTranscriptMenu]];

	NSMenu *viewMenu = [[[[NSApplication sharedApplication] mainMenu] itemAtIndex:3] submenu];
	NSMenuItem *fullscreenItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Enter Full Screen", @"Enter Full Screen menu item") action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
	[fullscreenItem setKeyEquivalentModifierMask:(NSControlKeyMask | NSCommandKeyMask)];
	[fullscreenItem setTarget:nil];

	[viewMenu insertItem:fullscreenItem atIndex:6];
	[viewMenu insertItem:[NSMenuItem separatorItem] atIndex:7];


	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( terminateWithoutConfirm: ) name:NSWorkspaceWillPowerOffNotification object:[NSWorkspace sharedWorkspace]];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( receiveSleepNotification: ) name:NSWorkspaceWillSleepNotification object:[NSWorkspace sharedWorkspace]];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( receiveWakeNotification: ) name:NSWorkspaceDidWakeNotification object:[NSWorkspace sharedWorkspace]];

	[self performSelector:@selector( setupFolders ) withObject:nil afterDelay:5.]; // do this later to speed up launch

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskedToAllowAnalytics"]) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Allow analytics to be sent?", @"Allow analytics to be sent? message text.") defaultButton:NSLocalizedString(@"Send", @"Send button title") alternateButton:NSLocalizedString(@"Don't send", @"Don't send button title") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"To help us know what to improve on, Colloquy can send back information about your current configuration. The data sent back will not contain any identifiable information. ", @"To help us know what to improve on, Colloquy can send back information about your current configuration. The data sent back will not contain any identifiable information message text"), nil];
		[alert setAlertStyle:NSInformationalAlertStyle];

		if ([alert runModal])
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAllowAnalytics"];

		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskedToAllowAnalytics"];
	}

	[self performSelector:@selector(_deferredLaunchingBehavior) withObject:nil afterDelay:0.];

	[[NSProcessInfo processInfo] setAutomaticTerminationSupportEnabled:YES];
}

- (void) applicationWillBecomeActive:(NSNotification *) notification {
	[MVConnectionsController refreshFavoritesMenu];
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *) application hasVisibleWindows:(BOOL) hasVisibleWindows {
	if( ! hasVisibleWindows )
		[[MVConnectionsController defaultController] showConnectionManager:nil];
	return YES;
}

- (void) applicationWillTerminate:(NSNotification *) notification {
	applicationIsTerminating = YES;

	[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];

	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSURLCache sharedURLCache] removeAllCachedResponses];

	NSTimeInterval runTime = ABS([_launchDate timeIntervalSinceNow]);
	[[JVAnalyticsController defaultController] setObject:[NSNumber numberWithDouble:runTime] forKey:@"run-time"];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender {
	if( _terminateWithoutConfirm ) return NSTerminateNow; // special command key used, quit asap
	if( ! [[[MVConnectionsController defaultController] connectedConnections] count] )
		return NSTerminateNow; // no active connections, we can just quit now
	if( ! [[[JVChatController defaultController] chatViewControllersKindOfClass:[JVDirectChatPanel class]] count] )
		return NSTerminateNow; // no active chats, we can just quit now
	NSAlert *confirmQuitAlert = [[NSAlert alloc] init];
	[confirmQuitAlert setMessageText:NSLocalizedString( @"Are you sure you want to quit?", "are you sure you want to quit title" )];
	[confirmQuitAlert setInformativeText:NSLocalizedString( @"Are you sure you want to quit Colloquy and disconnect from all active connections?", "are you sure you want to quit message" )];
	[confirmQuitAlert addButtonWithTitle:NSLocalizedString( @"Quit", "quit button" )];
	[confirmQuitAlert addButtonWithTitle:NSLocalizedString( @"Cancel", "cancel button" )];
	[confirmQuitAlert setAlertStyle:NSCriticalAlertStyle];
	/* no quit message field in the quit dialog until someone makes it prettier (for example label it). Ticket #1557.
	// quit message. leopard only for now, because NSAlert's setAccessoryView is 10.5+ only, 10.4 would need a new NIB for this feature:
	if ( floor( NSAppKitVersionNumber ) > NSAppKitVersionNumber10_4) {
		NSTextField *quitMessageAccessory = [[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,220,22)] autorelease];
		[quitMessageAccessory bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.JVQuitMessage" options:nil];
		[confirmQuitAlert setAccessoryView:quitMessageAccessory];
		// the roomKeyAccessory should be in the tab chain and probably also the initial first responder, this code is not ready yet though
		// [confirmQuitAlert layout];
		// [[confirmQuitAlert window] setInitialFirstResponder:quitMessageAccessory];
	}
	*/
	if ( [confirmQuitAlert runModal] == NSAlertSecondButtonReturn ) {
		return NSTerminateCancel;
	}
	return NSTerminateNow;
}

- (NSMenu *) applicationDockMenu:(NSApplication *) sender {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	id view = nil;

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	MVAddUnsafeUnretainedAddress(sender, 2);
	MVAddUnsafeUnretainedAddress(view, 2);

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	if( [results count] ) {
		for( NSArray *items in results ) {
			if( ![items conformsToProtocol:@protocol(NSFastEnumeration)] ) continue;
			for( NSMenuItem *item in items )
				if( [item isKindOfClass:[NSMenuItem class]] ) [menu addItem:item];
		}

		if( [[[menu itemArray] lastObject] isSeparatorItem] )
			[menu removeItem:[[menu itemArray] lastObject]];
	}

	return menu;
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( joinRoom: ) ) {
		if( [[[MVConnectionsController defaultController] connections] count] ) {
			return YES;
		} else {
			return NO;
		}
	} else if( [menuItem action] == @selector( markAllDisplays: ) ) {
		JVChatController *chatController = [JVChatController defaultController];
		Class controllerClass = [JVDirectChatPanel class];
		NSSet *viewControllers = [chatController chatViewControllersKindOfClass:controllerClass];
		return ( [viewControllers count] > 0 );
	} else if( [menuItem action] == @selector( toggleFavorites: ) ) {
		[menuItem setTitle:NSLocalizedString( @"Add to Favorites", "add to favorites menu item")];
		return NO;
	}
	return YES;
}

#pragma mark -

- (void) invalidPluginsFound:(NSNotification *) notification {
	if( [NSDate timeIntervalSinceReferenceDate] - [_launchDate timeIntervalSinceReferenceDate] < 5. ) {
		[self performSelector:@selector(invalidPluginsFound:) withObject:notification afterDelay:5.];

		return;
	}

	NSArray *invalidPlugins = notification.object;

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = (invalidPlugins.count > 1) ? NSLocalizedString( @"Unable to load plugins", @"Unable to load plugins message text" ) : NSLocalizedString( @"Unable to load a plugin", @"Unable to load a plugin message text" );

	NSString *informativeText = nil;
	if( invalidPlugins.count > 1 ) {
		informativeText = NSLocalizedString( @"Colloquy is unable to load the following plugins:\n", @"Colloquy is unable to load the following plugins:\n. informative text");
		for( NSString *pluginName in invalidPlugins )
			informativeText = [informativeText stringByAppendingFormat:@"%@\n", [pluginName fileName]];
	} else {
		NSString *pluginName = [[invalidPlugins lastObject] fileName];
		informativeText = [NSString stringWithFormat:NSLocalizedString( @"Colloquy is unable to load the plugin named \"%@\".", @"Colloquy is unable to load the plugin named \"%@\". informative text"), pluginName];
	}

	alert.informativeText = informativeText;
	alert.alertStyle = NSWarningAlertStyle;

	[alert addButtonWithTitle:NSLocalizedString( @"OK", @"OK button title" )];

	[alert runModal];

}

#pragma mark -

- (void) updateDockTile {
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowDockBadge"] ) {
		NSUInteger totalHighlightCount = 0;

		for( JVChatRoomPanel *room in [[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] )
			totalHighlightCount += [room newHighlightMessagesWaiting];

		for( JVChatRoomPanel *directChat in [[JVChatController defaultController] chatViewControllersOfClass:[JVDirectChatPanel class]] )
			totalHighlightCount += [directChat newMessagesWaiting];

		[[NSApp dockTile] setBadgeLabel:( totalHighlightCount == 0 ? nil : [[NSNumber numberWithUnsignedInteger:totalHighlightCount] stringValue] )];
		[[NSApp dockTile] display];
	} else {
		[[NSApp dockTile] setBadgeLabel:nil];
		[[NSApp dockTile] display];
	}
}

#pragma mark -

- (void) _deferredLaunchingBehavior {
	[MVCrashCatcher check];
	[MVFileTransferController defaultController];
	[MVBuddyListController sharedBuddyList];

	JVAnalyticsController *analyticsController = [JVAnalyticsController defaultController];
	if (analyticsController) {
		NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];

		NSString *information = [infoDictionary objectForKey:@"CFBundleName"];
		[[JVAnalyticsController defaultController] setObject:information forKey:@"application-name"];

		information = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
		[[JVAnalyticsController defaultController] setObject:information forKey:@"application-version"];

		information = [infoDictionary objectForKey:@"CFBundleVersion"];
		[[JVAnalyticsController defaultController] setObject:information forKey:@"application-build-version"];

		[[JVAnalyticsController defaultController] setObject:[[NSLocale currentLocale] localeIdentifier] forKey:@"locale"];

		NSInteger showNotices = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatAlwaysShowNotices"];
		information = (!showNotices ? @"none" : (showNotices == 1 ? @"all" : @"auto"));
		[[JVAnalyticsController defaultController] setObject:information forKey:@"notices-behavior"];

		information = ([[[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"] hasCaseInsensitiveSubstring:@"Get Colloquy"] ? @"default" : @"custom");
		[[JVAnalyticsController defaultController] setObject:information forKey:@"quit-message"];
	}
}
@end
