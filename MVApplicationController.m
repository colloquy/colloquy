#import <Cocoa/Cocoa.h>
#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "MVCrashCatcher.h"
#import "MVSoftwareUpdate.h"
#import "JVInspectorController.h"
#import "JVPreferencesController.h"
#import "JVGeneralPreferences.h"
#import "JVAppearancePreferences.h"
#import "JVFileTransferPreferences.h"
#import "JVAdvancedPreferences.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
//#import "MVBuddyListController.h"
#import "MVChatPluginManager.h"
//#import <AddressBook/AddressBook.h>
#import "JVChatController.h"

@interface WebCoreCache : NSObject {}
+ (void) setDisabled:(BOOL) disabled;
@end

#pragma mark -

@implementation MVApplicationController
- (void) dealloc {
	[[JVChatController defaultManager] autorelease];
	[[MVConnectionsController defaultManager] autorelease];
	[[MVFileTransferController defaultManager] autorelease];
//	[[MVBuddyListController sharedBuddyList] autorelease];
	[[MVChatPluginManager defaultManager] autorelease];

	[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];

	[super dealloc];
}

#pragma mark -

- (IBAction) checkForUpdate:(id) sender {
	[MVSoftwareUpdate checkAutomatically:NO];
}

- (IBAction) connectToSupportRoom:(id) sender {
	[[MVConnectionsController defaultManager] handleURL:[NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@irc.javelin.cc/#colloquy", NSUserName()]] andConnectIfPossible:YES];
}

- (IBAction) emailDeveloper:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:timothy@javelin.cc?subject=Colloquy%%20%%28build%%20%@%%29", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]]];
}

- (IBAction) productWebsite:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.javelin.cc/?colloquy"]];
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
//	[[MVBuddyListController sharedBuddyList] showBuddyList:nil];
}

#pragma mark -

- (IBAction) newConnection:(id) sender {
	[[MVConnectionsController defaultManager] newConnection:nil];
}

#pragma mark -

- (BOOL) application:(NSApplication *) sender openFile:(NSString *) filename {
	if( [[filename pathExtension] isEqualToString:@"colloquyTranscript"] ) {
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
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	[MVCrashCatcher check];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"] )
		[MVSoftwareUpdate checkAutomatically:YES];

	[MVColorPanel setPickerMode:NSColorListModeColorPanel];
	[[MVColorPanel sharedColorPanel] attachColorList:[[[NSColorList alloc] initWithName:@"Chat" fromFile:[[NSBundle mainBundle] pathForResource:@"Chat" ofType:@"clr"]] autorelease]];

/*	{
		ABPerson *buddy = [[ABAddressBook sharedAddressBook] me];
		ABMutableMultiValue *value = [[[ABMutableMultiValue alloc] init] autorelease];

		[value addValue:@"irc://pf5268@irc.freenode.net" withLabel:@"Other"];
		[value addValue:@"irc://timothy@irc.javelin.cc" withLabel:@"Other"];
		[value addValue:@"irc://nonex@irc.massinova.com" withLabel:@"Other"];

		[buddy setValue:value forProperty:@"ColloquyIRC"];
		[[ABAddressBook sharedAddressBook] save];
	} */

	[WebCoreCache setDisabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVDisableWebCoreCache"]];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSToolbar Configuration NSPreferences"];

	[NSPreferences setDefaultPreferencesClass:[JVPreferencesController class]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"General", "general preference pane name" ) owner:[JVGeneralPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Appearance", "appearance preference pane name" ) owner:[JVAppearancePreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Transfers", "file transfers preference pane name" ) owner:[JVFileTransferPreferences sharedInstance]];
	[[NSPreferences sharedPreferences] addPreferenceNamed:NSLocalizedString( @"Advanced", "advanced preference pane name" ) owner:[JVAdvancedPreferences sharedInstance]];

	[JVChatController defaultManager];
//	[MVBuddyListController sharedBuddyList];
	[MVConnectionsController defaultManager];
	[MVFileTransferController defaultManager];
}

- (void) applicationWillTerminate:(NSNotification *) notification {
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSURLCache sharedURLCache] removeAllCachedResponses];
	[self autorelease];
}
@end
