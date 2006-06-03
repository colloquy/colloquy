#import "NSURLAdditions.h"
#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "JVChatWindowController.h"
#import "MVCrashCatcher.h"
#import "MVSoftwareUpdate.h"
#import "JVInspectorController.h"
#import "JVPreferencesController.h"
#import "JVGeneralPreferences.h"
#import "JVInterfacePreferences.h"
#import "JVAppearancePreferences.h"
#import "JVNotificationPreferences.h"
#import "JVFileTransferPreferences.h"
#import "JVBehaviorPreferences.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "JVTranscriptPreferences.h"
#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "JVChatRoomBrowser.h"
#import "NSBundleAdditions.h"
#import "JVStyle.h"
#import "JVDirectChatPanel.h"
#import "JVChatTranscriptBrowserPanel.h"

#import <Foundation/NSDebug.h>

@interface WebCoreCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

NSString *JVChatStyleInstalledNotification = @"JVChatStyleInstalledNotification";
NSString *JVChatEmoticonSetInstalledNotification = @"JVChatEmoticonSetInstalledNotification";
NSString *JVMachineBecameIdleNotification = @"JVMachineBecameIdleNotification";
NSString *JVMachineStoppedIdlingNotification = @"JVMachineStoppedIdlingNotification";

static BOOL applicationIsTerminating = NO;

@implementation MVApplicationController
- (id) init {
	if( ( self = [super init] ) ) {
		mach_port_t masterPort = 0;
		kern_return_t err = IOMasterPort( MACH_PORT_NULL, &masterPort );

		io_iterator_t hidIter = 0;
		err = IOServiceGetMatchingServices( masterPort, IOServiceMatching( "IOHIDSystem" ), &hidIter );

		_hidEntry = IOIteratorNext( hidIter );
		IOObjectRelease( hidIter );

		_isIdle = NO;
		_lastIdle = 0.;
		_idleCheck = [[NSTimer scheduledTimerWithTimeInterval:30. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES] retain];
	}

	return self;
}

- (void) dealloc {
	if( _hidEntry ) {
		IOObjectRelease( _hidEntry );
		_hidEntry = nil;
	}

	[super dealloc];
}

#pragma mark -

+ (BOOL) isTerminating {
	extern BOOL applicationIsTerminating;
	return applicationIsTerminating;
}

#pragma mark -

// idle stuff adapted from a post by Jonathan 'Wolf' Rentzsch on the cocoa-dev mailing list.

- (NSTimeInterval) idleTime {
	NSMutableDictionary *hidProperties = nil;
	kern_return_t err = IORegistryEntryCreateCFProperties( _hidEntry, (CFMutableDictionaryRef *) &hidProperties, kCFAllocatorDefault, 0 );

	id hidIdleTimeObj = [hidProperties objectForKey:@"HIDIdleTime"];
	unsigned long long result;

	if( [hidIdleTimeObj isKindOfClass:[NSData class]] ) [hidIdleTimeObj getBytes:&result];
	else result = [hidIdleTimeObj longLongValue];

	[hidProperties release];

	return ( result / 1000000000. );
}

- (void) checkIdle:(id) sender {
	NSTimeInterval idle = [self idleTime];

	if( _isIdle ) {
		if( idle < _lastIdle ) {
			// no longer idle

			_isIdle = NO;
			[[NSNotificationCenter defaultCenter] postNotificationName:JVMachineStoppedIdlingNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:idle] forKey:@"idleTime"]];

			// reschedule the timer, to check for idle every 30 seconds
			[_idleCheck invalidate];
			[_idleCheck autorelease];

			_idleCheck = [[NSTimer scheduledTimerWithTimeInterval:30. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES] retain];
		}
	} else {
		if( idle > [[NSUserDefaults standardUserDefaults] integerForKey:@"JVIdleTime"] ) {
			// we're now idle

			_isIdle = YES;
			[[NSNotificationCenter defaultCenter] postNotificationName:JVMachineBecameIdleNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:idle] forKey:@"idleTime"]];

			// reschedule the timer, we will check every second to catch the user's return quickly
			[_idleCheck invalidate];
			[_idleCheck autorelease];

			_idleCheck = [[NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES] retain];
		}
	}

	_lastIdle = idle;
}

#pragma mark -

- (IBAction) checkForUpdate:(id) sender {
	[MVSoftwareUpdate checkAutomatically:NO];
}

- (IBAction) connectToSupportRoom:(id) sender {
	[[MVConnectionsController defaultController] handleURL:[NSURL URLWithString:@"irc://irc.freenode.net/#colloquy"] andConnectIfPossible:YES];
}

- (IBAction) emailDeveloper:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:timothy@colloquy.info?subject=Colloquy%%20%%28build%%20%@%%29", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]]];
}

- (IBAction) productWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://colloquy.info"]];
}

- (IBAction) bugReportWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://colloquy.info?bug"]];
}

#pragma mark -

- (void) setupPreferences {
	static BOOL setupAlready = NO;
	if( setupAlready ) return;

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSToolbar Configuration NSPreferences"];

	[JVPreferencesController setDefaultPreferencesClass:[JVPreferencesController class]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"General", "general preference pane name" ) owner:[JVGeneralPreferences sharedInstance]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Interface", "interface preference pane name" ) owner:[JVInterfacePreferences sharedInstance]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Appearance", "appearance preference pane name" ) owner:[JVAppearancePreferences sharedInstance]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Alerts", "alerts preference pane name" ) owner:[JVNotificationPreferences sharedInstance]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Transfers", "file transfers preference pane name" ) owner:[JVFileTransferPreferences sharedInstance]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Transcripts", "chat transcript preference pane name" ) owner:[JVTranscriptPreferences sharedInstance]];
	[[JVPreferencesController sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Behavior", "behavior preference pane name" ) owner:[JVBehaviorPreferences sharedInstance]];

	setupAlready = YES;
}

- (void) setupFolders {
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Plugins" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles/Variants" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Sounds" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath] attributes:nil];
//	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Chat Rooms" stringByExpandingTildeInPath] attributes:nil];
//	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Acquaintances" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc/Client Keys" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Silc/Server Keys" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Scripts/Applications" stringByExpandingTildeInPath] attributes:nil];
	[fm createDirectoryAtPath:[@"~/Library/Scripts/Applications/Colloquy" stringByExpandingTildeInPath] attributes:nil];
}

#pragma mark -

- (IBAction) showInspector:(id) sender {
	if( [[[JVInspectorController sharedInspector] window] isKeyWindow] )
		[[[JVInspectorController sharedInspector] window] orderOut:nil];
	else [[JVInspectorController sharedInspector] show:nil];
}

- (IBAction) showPreferences:(id) sender {
	[self setupPreferences];
	[[JVPreferencesController sharedPreferences] showPreferencesPanel];
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
	[[JVChatTranscriptBrowserPanel sharedBrowser] showBrowser:self];
}

- (IBAction) showBuddyList:(id) sender {
	if( [[[MVBuddyListController sharedBuddyList] window] isKeyWindow] )
		[[MVBuddyListController sharedBuddyList] hideBuddyList:nil];
	else [[MVBuddyListController sharedBuddyList] showBuddyList:nil];
}

- (IBAction) openDocument:(id) sender {
	NSString *path = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];

	NSArray *fileTypes = [NSArray arrayWithObject:@"colloquyTranscript"];
	NSOpenPanel *openPanel = [[NSOpenPanel openPanel] retain];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setResolvesAliases:YES];
	[openPanel beginForDirectory:path file:nil types:fileTypes modelessDelegate:self didEndSelector:@selector( openDocumentPanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) openDocumentPanelDidEnd:(NSOpenPanel *) panel returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[panel autorelease];
	NSString *filename = [panel filename];
	NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if( returnCode == NSOKButton && [[NSFileManager defaultManager] isReadableFileAtPath:filename] && ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyTranscript"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coTr' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
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
	NSArray *connections = [[MVConnectionsController defaultController] connections];
	MVChatConnection *connection = ( [connections count] ? [connections objectAtIndex:1] : nil );
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
	NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];

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
	} else if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename] && */ ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyEmoticons"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coEm' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *newPath = [[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
		if( [newPath isEqualToString:filename] ) return NO;

		if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:newPath] && */ [[NSFileManager defaultManager] isDeletableFileAtPath:newPath] ) {
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
	if( [MVChatConnection supportsURLScheme:[url scheme]] ) [[MVConnectionsController defaultController] handleURL:url andConnectIfPossible:YES];
	else [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark -

- (IBAction) terminateWithoutConfirm:(id) sender {
	_terminateWithoutConfirm = YES;
	[[NSApplication sharedApplication] terminate:sender];
}

- (void) applicationWillFinishLaunching:(NSNotification *) notification {
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
	[MVCrashCatcher check];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"] )
		[MVSoftwareUpdate checkAutomatically:YES];

	[[MVColorPanel sharedColorPanel] attachColorList:[[[NSColorList alloc] initWithName:@"Chat" fromFile:[[NSBundle mainBundle] pathForResource:@"Chat" ofType:@"clr"]] autorelease]];

	[WebCoreCache setDisabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"]];

	[MVChatPluginManager defaultManager];
	[MVConnectionsController defaultController];
	[JVChatController defaultController];
	[MVFileTransferController defaultController];
	[MVBuddyListController sharedBuddyList];

	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:20] setSubmenu:[MVConnectionsController favoritesMenu]];
	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:30] setSubmenu:[JVChatController smartTranscriptMenu]];

	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( terminateWithoutConfirm: ) name:NSWorkspaceWillPowerOffNotification object:[NSWorkspace sharedWorkspace]];

	[self performSelector:@selector( setupFolders ) withObject:nil afterDelay:5.]; // do this later to speed up launch
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

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender {
	if( _terminateWithoutConfirm ) return NSTerminateNow; // special command key used, quit asap
	if( ! [[[MVConnectionsController defaultController] connectedConnections] count] )
		return NSTerminateNow; // no active connections, we can just quit now
	if( ! [[[JVChatController defaultController] chatViewControllersKindOfClass:[JVDirectChatPanel class]] count] )
		return NSTerminateNow; // no active chats, we can just quit now
	if( NSRunCriticalAlertPanel( NSLocalizedString( @"Are you sure you want to quit?", "are you sure you want to quit title" ), NSLocalizedString( @"Are you sure you want to quit Colloquy and disconnect from all active connections?", "are you sure you want to quit message" ), @"Quit", @"Cancel", nil ) == NSCancelButton )
		return NSTerminateCancel;
	return NSTerminateNow;
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
	} else if( [menuItem action] == @selector( addToFavorites: ) ) {
		[menuItem setTitle:NSLocalizedString( @"Add to Favorites", "add to favorites menu item")];
		return NO;
	}
	return YES;
}
@end