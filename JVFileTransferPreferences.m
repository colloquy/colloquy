#import <Cocoa/Cocoa.h>
#import <ChatCore/MVFileTransfer.h>
#import "JVFileTransferPreferences.h"
#import "MVFileTransferController.h"

@implementation JVFileTransferPreferences
- (NSString *) preferencesNibName {
	return @"JVFileTransferPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"FileTransferPreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	NSRange range = [MVFileTransfer fileTransferPortRange];
	[minRate setIntValue:range.location];
	[maxRate setIntValue:( range.location + range.length )];

	NSString *path = [MVFileTransferController userPreferredDownloadFolder];
	NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize( 16., 16. )];

	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:icon];
	[menuItem setRepresentedObject:path];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:1]];
	} else {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:2]];
	}
	
	[autoAccept selectItemAtIndex:[autoAccept indexOfItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"]]];
	[removeTransfers selectItemAtIndex:[removeTransfers indexOfItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"]]];
	[openSafe setState:(int)[[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"]];
}

- (IBAction) changePortRange:(id) sender {
	NSRange range = NSMakeRange( [minRate intValue], ( [maxRate intValue] - [minRate intValue] ) );
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRange( range ) forKey:@"JVFileTransferPortRange"];
	[MVFileTransfer setFileTransferPortRange:range];
}

- (IBAction) changeAutoAccept:(id) sender {
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"JVAutoAcceptFilesFrom"];
}

- (IBAction) changeSaveDownloads:(id) sender {
	if( [sender tag] == 3 ) {
		NSOpenPanel *openPanel = [[NSOpenPanel openPanel] retain];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setCanChooseFiles:NO];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setResolvesAliases:NO];
		[openPanel beginSheetForDirectory:[MVFileTransferController userPreferredDownloadFolder] file:nil types:nil modalForWindow:[[self viewForPreferenceNamed:nil] window] modalDelegate:self didEndSelector:@selector( saveDownloadsOpenPanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	} else if( [sender tag] == 2 ) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVAskForTransferSaveLocation"];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskForTransferSaveLocation"];
	}
}

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[sheet directory]];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[sheet directory]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[sheet directory]];
		[saveDownloads selectItem:menuItem];

		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVAskForTransferSaveLocation"];
		[MVFileTransferController setUserPreferredDownloadFolder:[sheet directory]];
	} else {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:1]];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskForTransferSaveLocation"];
	}
}

- (IBAction) changeRemoveTransfers:(id) sender {
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"JVRemoveTransferedItems"];
}

- (IBAction) toggleOpenSafeFiles:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVOpenSafeFiles"];
}
@end
