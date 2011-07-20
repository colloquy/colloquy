#import "NSURLAdditions.h"
#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "JVChatWindowController.h"
#import "MVCrashCatcher.h"
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
#import "CQActivityWindowController.h"
#import "JVTranscriptPreferences.h"
#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "JVChatRoomBrowser.h"
#import "NSBundleAdditions.h"
#import "JVStyle.h"
#import "JVChatRoomPanel.h"
#import "JVDirectChatPanel.h"
#import "JVAnalyticsController.h"
//#import "JVChatTranscriptBrowserPanel.h"

#import "PFMoveApplicationController.h"

#import <Sparkle/SUUpdater.h>

@interface WebCoreCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

@interface WebCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

#if !defined(MAC_OS_X_VERSION_10_5) || (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5)
@interface NSAlert (LeopardOnly)
- (void) setAccessoryView:(NSView *) view;
@end

@interface NSDockTile : NSObject
@end

@interface NSApplication (LeopardOnly)
- (NSDockTile *) dockTile;
@end

@interface NSDockTile (LeopardOnly)
- (void) setBadgeLabel:(NSString *) string;
- (void) display;
@end
#endif

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
		_hidEntry = 0;
	}

	[_launchDate release];

	[super dealloc];
}

#pragma mark -

+ (BOOL) isTerminating {
	return applicationIsTerminating;
}

#pragma mark -

// idle stuff adapted from a post by Jonathan 'Wolf' Rentzsch on the cocoa-dev mailing list.

- (NSTimeInterval) idleTime {
	NSMutableDictionary *hidProperties = nil;
	IORegistryEntryCreateCFProperties( _hidEntry, (CFMutableDictionaryRef *) &hidProperties, kCFAllocatorDefault, 0 );

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

			// reschedule the timer, to check for idle every 10 seconds
			[_idleCheck invalidate];
			[_idleCheck release];

			_idleCheck = [[NSTimer scheduledTimerWithTimeInterval:10. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES] retain];
		}
	} else {
		if( idle > [[NSUserDefaults standardUserDefaults] integerForKey:@"JVIdleTime"] ) {
			// we're now idle

			_isIdle = YES;
			[[NSNotificationCenter defaultCenter] postNotificationName:JVMachineBecameIdleNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:idle] forKey:@"idleTime"]];

			// reschedule the timer, we will check every 2 seconds to catch the user's return quickly
			[_idleCheck invalidate];
			[_idleCheck release];

			_idleCheck = [[NSTimer scheduledTimerWithTimeInterval:2. target:self selector:@selector( checkIdle: ) userInfo:nil repeats:YES] retain];
		}
	}

	_lastIdle = idle;
}

#pragma mark -

- (IBAction) checkForUpdate:(id) sender {
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_4 ) { // test for 10.4
		NSRunInformationalAlertPanel( @"Tiger is no longer supported.", @"You are running the last version of Colloquy that is supported for Tiger (10.4.11). Please update to Leopard or Snow Leopard to receive further updates and support for Colloquy.", nil, nil, nil );
		return;
	}

	if( ! _updater ) _updater = [[SUUpdater allocWithZone:nil] init];
	[_updater checkForUpdates:sender];
}

- (IBAction) helpWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://project.colloquy.info/wiki/Documentation"]];
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

	JVPreferencesController *controller = [JVPreferencesController sharedPreferences];
	[controller addPreferenceNamed:NSLocalizedString( @"General", "general preference pane name" ) owner:[JVGeneralPreferences sharedInstance]];
	[controller addPreferenceNamed:NSLocalizedString( @"Interface", "interface preference pane name" ) owner:[JVInterfacePreferences sharedInstance]];
	[controller addPreferenceNamed:NSLocalizedString( @"Appearance", "appearance preference pane name" ) owner:[JVAppearancePreferences sharedInstance]];
	[controller addPreferenceNamed:NSLocalizedString( @"Alerts", "alerts preference pane name" ) owner:[JVNotificationPreferences sharedInstance]];
	[controller addPreferenceNamed:NSLocalizedString( @"Transfers", "file transfers preference pane name" ) owner:[JVFileTransferPreferences sharedInstance]];
	[controller addPreferenceNamed:NSLocalizedString( @"Transcripts", "chat transcript preference pane name" ) owner:[JVTranscriptPreferences sharedInstance]];
	[controller addPreferenceNamed:NSLocalizedString( @"Behavior", "behavior preference pane name" ) owner:[JVBehaviorPreferences sharedInstance]];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( setupPreferencesWithController: )];
	[invocation setArgument:&controller atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];

	setupAlready = YES;
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
	[self setupPreferences];
	[[JVPreferencesController sharedPreferences] showPreferencesPanel];
}

- (IBAction) showActivityManager:(id) sender {
	if ( [[CQActivityWindowController sharedController].window isKeyWindow] )
		[[CQActivityWindowController sharedController] hideActivityWindow:nil];
	else [[CQActivityWindowController sharedController] showActivityWindow:nil];
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
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
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
			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Already Installed", "style already installed title" ), [[filename lastPathComponent] stringByDeletingPathExtension]], [NSString stringWithFormat:NSLocalizedString( @"The %@ style is already installed. Would you like to replace it with this version?", "would you like to replace a style with a different version" ), [[filename lastPathComponent] stringByDeletingPathExtension]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[[NSFileManager defaultManager] removeItemAtPath:newPath error:nil];
			} else return NO;
		}

		if( [[NSFileManager defaultManager] moveItemAtPath:filename toPath:newPath error:nil] ) {
			NSBundle *bundle = [NSBundle bundleWithPath:newPath];
			JVStyle *style = [JVStyle newWithBundle:bundle];

			[[NSNotificationCenter defaultCenter] postNotificationName:JVChatStyleInstalledNotification object:style];

			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Successfully Installed", "style installed title" ), [style displayName]], [NSString stringWithFormat:NSLocalizedString( @"%@ is ready to be used in your colloquies. Would you like to view %@ and it's options in the Appearance Preferences?", "would you like to view the style in the Appearance Preferences" ), [style displayName], [style displayName]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[self setupPreferences];
				[[JVPreferencesController sharedPreferences] showPreferencesPanelForOwner:[JVAppearancePreferences sharedInstance]];
				[[JVAppearancePreferences sharedInstance] selectStyleWithIdentifier:[style identifier]];
			}

			[style release];

			return YES;
		} else {
			NSRunCriticalAlertPanel( NSLocalizedString( @"Style Installation Error", "error installing style title" ), NSLocalizedString( @"The style could not be installed, please make sure you have permission to install this item.", "style install error message" ), nil, nil, nil );
		} return NO;
	} else if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename] && */ ( [[filename pathExtension] caseInsensitiveCompare:@"colloquyEmoticons"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coEm' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
		NSString *newPath = [[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] stringByAppendingPathComponent:[filename lastPathComponent]];
		if( [newPath isEqualToString:filename] ) return NO;

		if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:newPath] && */ [[NSFileManager defaultManager] isDeletableFileAtPath:newPath] ) {
			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"%@ Already Installed", "emoticons already installed title" ), [[filename lastPathComponent] stringByDeletingPathExtension]], [NSString stringWithFormat:NSLocalizedString( @"The %@ emoticons are already installed. Would you like to replace them with this version?", "would you like to replace an emoticon bundle with a different version" ), [[filename lastPathComponent] stringByDeletingPathExtension]], NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
				[[NSFileManager defaultManager] removeItemAtPath:newPath error:nil];
			} else return NO;
		}

		if( [[NSFileManager defaultManager] moveItemAtPath:filename toPath:newPath error:nil] ) {
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

		[connectionInformation release];
	}
	
	[quitAttributedString release];
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

	[_previouslyConnectedConnections release];
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
#ifdef DEBUG
	NSDebugEnabled = YES;
//	NSZombieEnabled = YES;
//	NSDeallocateZombies = NO;
//	[NSAutoreleasePool enableFreedObjectCheck:YES];
#endif
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	_launchDate = [[NSDate alloc] init];

	[MVCrashCatcher check];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"] && NSAppKitVersionNumber >= NSAppKitVersionNumber10_4 ) {
		_updater = [[SUUpdater allocWithZone:nil] init];
		[_updater checkForUpdatesInBackground];
		[_updater setUpdateCheckInterval:60. * 60. * 12.]; // check every 12 hours
	}

	[[MVColorPanel sharedColorPanel] attachColorList:[[[NSColorList alloc] initWithName:@"Chat" fromFile:[[NSBundle mainBundle] pathForResource:@"Chat" ofType:@"clr"]] autorelease]];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"] ) {
		Class webCacheClass = NSClassFromString( @"WebCache" );
		if( ! webCacheClass ) webCacheClass = NSClassFromString( @"WebCoreCache" );

		[webCacheClass setDisabled:YES];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( invalidPluginsFound: ) name:MVChatPluginManagerDidFindInvalidPluginsNotification object:nil];

	[MVChatPluginManager defaultManager];
	[MVConnectionsController defaultController];
	[JVChatController defaultController];
	[MVFileTransferController defaultController];
	[MVBuddyListController sharedBuddyList];
	[CQActivityWindowController sharedController];

	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:20] setSubmenu:[MVConnectionsController favoritesMenu]];
	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:30] setSubmenu:[JVChatController smartTranscriptMenu]];

	NSMenu *viewMenu = [[[[NSApplication sharedApplication] mainMenu] itemAtIndex:3] submenu];
	NSMenuItem *fullscreenItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Enter Full Screen", @"Enter Full Screen menu item") action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
	[fullscreenItem setKeyEquivalentModifierMask:(NSControlKeyMask | NSCommandKeyMask)];
	[fullscreenItem setTarget:nil];

	[viewMenu insertItem:fullscreenItem atIndex:6];
	[viewMenu insertItem:[NSMenuItem separatorItem] atIndex:7];

	[fullscreenItem release];

	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( terminateWithoutConfirm: ) name:NSWorkspaceWillPowerOffNotification object:[NSWorkspace sharedWorkspace]];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( receiveSleepNotification: ) name:NSWorkspaceWillSleepNotification object:[NSWorkspace sharedWorkspace]];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector( receiveWakeNotification: ) name:NSWorkspaceDidWakeNotification object:[NSWorkspace sharedWorkspace]];

	[self performSelector:@selector( setupFolders ) withObject:nil afterDelay:5.]; // do this later to speed up launch

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskedToAllowAnalytics"]) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Allow analytics to be sent?", @"Allow analytics to be sent? message text.") defaultButton:NSLocalizedString(@"Send", @"Send button title") alternateButton:NSLocalizedString(@"Don't send", @"Don't send button title") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"To help us know what to improve on, Colloquy can send back information about your current configuration. The data sent back will not contain will not contain any identifiable information. ", @"To help us know what to improve on, Colloquy can send back information about your current configuration. The data sent back will not contain will not contain any identifiable information message text")];
		[alert setAlertStyle:NSInformationalAlertStyle];

		if ([alert runModal])
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAllowAnalytics"];

		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskedToAllowAnalytics"];
	}

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
	NSAlert *confirmQuitAlert = [[[NSAlert alloc] init] autorelease];
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
	NSMenu *menu = [[[NSMenu allocWithZone:[self zone]] initWithTitle:@""] autorelease];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	id view = nil;

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	[invocation setArgument:&sender atIndex:2];
	[invocation setArgument:&view atIndex:3];

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
	} else if( [menuItem action] == @selector( addToFavorites: ) ) {
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

	[alert release];
}

#pragma mark -

- (void) updateDockTile {
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowDockBadge"] ) {
		unsigned int totalHighlightCount = 0;

		for( JVChatRoomPanel *room in [[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] )
			totalHighlightCount += [room newHighlightMessagesWaiting];

		for( JVChatRoomPanel *directChat in [[JVChatController defaultController] chatViewControllersOfClass:[JVDirectChatPanel class]] )
			totalHighlightCount += [directChat newMessagesWaiting];

		[[NSApp dockTile] setBadgeLabel:( totalHighlightCount == 0 ? nil : [NSString stringWithFormat:@"%u", totalHighlightCount] )];
		[[NSApp dockTile] display];
	} else {
		[[NSApp dockTile] setBadgeLabel:nil];
		[[NSApp dockTile] display];
	}
}
@end
