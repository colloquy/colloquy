#import <Cocoa/Cocoa.h>
#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "MVCrashCatcher.h"
#import "MVSoftwareUpdate.h"
#import "JVInspectorController.h"
#import "JVPreferencesController.h"
#import "JVGeneralPreferences.h"
#import "JVAppearancePreferences.h"
#import "JVNotificationPreferences.h"
#import "JVFileTransferPreferences.h"
#import "JVInterfacePreferences.h"
#import "JVAdvancedPreferences.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVBuddyListController.h"
#import "MVChatPluginManager.h"
#import "JVChatController.h"
#import "MVChatConnection.h"
#import "JVChatRoomBrowser.h"

#import <Foundation/NSDebug.h>

@interface WebCoreCache
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

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
	[[MVConnectionsController defaultManager] handleURL:[NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@irc.freenode.net/#colloquy", NSUserName()]] andConnectIfPossible:YES];
}

- (IBAction) emailDeveloper:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:timothy@colloquy.info?subject=Colloquy%%20%%28build%%20%@%%29", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]]];
}

- (IBAction) productWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://colloquy.info"]];
}

#pragma mark -

- (IBAction) showInspector:(id) sender {
	[[JVInspectorController sharedInspector] show:nil];
}

- (IBAction) showPreferences:(id) sender {
	[[NSPreferences sharedPreferences] showPreferencesPanel];
}

- (IBAction) showTransferManager:(id) sender {
	[[MVFileTransferController defaultManager] showTransferManager:nil];
}

- (IBAction) showConnectionManager:(id) sender {
	[[MVConnectionsController defaultManager] showConnectionManager:nil];
}

- (IBAction) showBuddyList:(id) sender {
	[[MVBuddyListController sharedBuddyList] showBuddyList:nil];
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

- (BOOL) application:(NSApplication *) sender openFile:(NSString *) filename {
	NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
	if( [[filename pathExtension] caseInsensitiveCompare:@"colloquyTranscript"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coTr' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) {
		[[JVChatController defaultManager] chatViewControllerForTranscript:filename];
		return YES;
	}
	return NO;
}

- (BOOL) application:(NSApplication *) sender printFile:(NSString *) filename {
	NSLog( @"printFile %@", filename );
	return NO;
}

- (void) handleURLEvent:(NSAppleEventDescriptor *) event withReplyEvent:(NSAppleEventDescriptor *) replyEvent {
	NSURL *url = [NSURL URLWithString:[[event descriptorAtIndex:1] stringValue]];
	[[MVConnectionsController defaultManager] handleURL:url andConnectIfPossible:YES];
}

#pragma mark -

- (void) applicationWillFinishLaunching:(NSNotification *) notification {
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[[NSBundle mainBundle] bundleIdentifier] ofType:@"plist"]]];
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector( handleURLEvent:withReplyEvent: ) forEventClass:kInternetEventClass andEventID:kAEGetURL];
//	NSZombieEnabled = YES;
//	NSDeallocateZombies = NO;
//	[NSAutoreleasePool enableFreedObjectCheck:YES];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	[MVCrashCatcher check];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"] )
		[MVSoftwareUpdate checkAutomatically:YES];

	[MVColorPanel setPickerMode:NSColorListModeColorPanel];
	[[MVColorPanel sharedColorPanel] attachColorList:[[[NSColorList alloc] initWithName:@"Chat" fromFile:[[NSBundle mainBundle] pathForResource:@"Chat" ofType:@"clr"]] autorelease]];

	[WebCoreCache setDisabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"]];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSToolbar Configuration NSPreferences"];

	[NSPreferences setDefaultPreferencesClass:[JVPreferencesController class]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"General", "general preference pane name" ) owner:[JVGeneralPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Appearance", "appearance preference pane name" ) owner:[JVAppearancePreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Interface", "interface preference pane name" ) owner:[JVInterfacePreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Notification", "notification preference pane name" ) owner:[JVNotificationPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Transfers", "file transfers preference pane name" ) owner:[JVFileTransferPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Advanced", "advanced preference pane name" ) owner:[JVAdvancedPreferences sharedInstance]];

	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/PlugIns" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Styles" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Emoticons" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Chat Rooms" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Application Support/Colloquy/Recent Acquaintances" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Scripts/Applications" stringByExpandingTildeInPath] attributes:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[@"~/Library/Scripts/Applications/Colloquy" stringByExpandingTildeInPath] attributes:nil];

	[MVChatPluginManager defaultManager];
	[MVConnectionsController defaultManager];
	[JVChatController defaultManager];
	[MVFileTransferController defaultManager];
	[MVBuddyListController sharedBuddyList];

	[[[[[[NSApplication sharedApplication] mainMenu] itemAtIndex:1] submenu] itemWithTag:20] setSubmenu:[MVConnectionsController favoritesMenu]];
}

- (void) applicationWillBecomeActive:(NSNotification *) notification {
	[MVConnectionsController refreshFavoritesMenu];
}

- (void) applicationWillTerminate:(NSNotification *) notification {
	extern BOOL applicationIsTerminating;
	applicationIsTerminating = YES;

	[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];

	[NSAutoreleasePool enableRelease:NO];

	[[MVBuddyListController sharedBuddyList] release];
	[[MVFileTransferController defaultManager] release];
	[[MVChatPluginManager defaultManager] release];
	[[JVChatController defaultManager] release];
	[[MVConnectionsController defaultManager] release];

	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (BOOL) application:(NSApplication *) sender delegateHandlesKey:(NSString *) key {
	if( [key isEqualToString:@"chatController"] || [key isEqualToString:@"connectionsController"] || [key isEqualToString:@"transferManager"] || [key isEqualToString:@"buddyList"] )
		return YES;
	return NO;
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( joinRoom: ) ) {
		if( [[[MVConnectionsController defaultManager] connections] count] ) return YES;
		else return NO;
	}
	return YES;
}
@end

#pragma mark -

@implementation NSApplication (NSApplicationScripting)
- (void) newConnection:(NSScriptCommand *) command {
	[[MVConnectionsController defaultManager] newConnection:nil];
}
@end

#pragma mark -

@implementation JVChatController (JVChatControllerObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatController"] autorelease];
}
@end

#pragma mark -

@implementation MVConnectionsController (MVConnectionsControllerObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"connectionsController"] autorelease];
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"buddyList"] autorelease];
}
@end