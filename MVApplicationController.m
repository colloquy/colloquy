#import <Cocoa/Cocoa.h>
#import "MVColorPanel.h"
#import "MVApplicationController.h"
#import "MVCrashCatcher.h"
#import "MVSoftwareUpdate.h"
#import "MVPreferencesController.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVBuddyListController.h"
//#import <AddressBook/AddressBook.h>

@implementation MVApplicationController
- (void) dealloc {
	[[MVPreferencesController sharedInstance] autorelease];
	[[MVConnectionsController defaultManager] autorelease];
	[[MVFileTransferController defaultManager] autorelease];
	[[MVBuddyListController sharedBuddyList] autorelease];

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

- (IBAction) showPreferences:(id) sender {
	[[MVPreferencesController sharedInstance] showPreferences:nil];
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

- (IBAction) newConnection:(id) sender {
	[[MVConnectionsController defaultManager] newConnection:nil];
}

#pragma mark -

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	[MVCrashCatcher check];
	[MVSoftwareUpdate checkAutomatically:YES];

	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[[NSBundle mainBundle] bundleIdentifier] ofType:@"plist"]]];

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
	}*/

	[MVBuddyListController sharedBuddyList];
	[MVConnectionsController defaultManager];
	[MVFileTransferController defaultManager];
}

- (void) applicationWillTerminate:(NSNotification *) notification {
	[self autorelease];
}
@end
