#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import "JVFileTransferPreferences.h"

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
	NSRange range = [MVChatConnection fileTransferPortRange];
	NSLog( @"%@", NSStringFromRange( range ) );
	[minRate setIntValue:range.location];
	[maxRate setIntValue:( range.location + range.length )];

	if( [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVTransferSaveLocation"] isEqualToString:@"ask"] ) {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:1]];

		NSString *path = [@"~/Desktop" stringByExpandingTildeInPath];
		NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[path lastPathComponent]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:path];
	} else {
		NSString *path = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVTransferSaveLocation"] stringByExpandingTildeInPath];
		NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[path lastPathComponent]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:path];
		[saveDownloads selectItem:menuItem];
	}

	[autoAccept selectItemAtIndex:[autoAccept indexOfItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"]]];
	[removeTransfers selectItemAtIndex:[removeTransfers indexOfItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"]]];
	[openSafe setState:(int)[[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"]];
}

- (void) saveChanges {
	NSRange range = NSMakeRange( [minRate intValue], ( [maxRate intValue] - [minRate intValue] ) );
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRange( range ) forKey:@"JVFileTransferPortRange"];
	[MVChatConnection setFileTransferPortRange:range];
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
		[openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[[self viewForPreferenceNamed:nil] window] modalDelegate:self didEndSelector:@selector( saveDownloadsOpenPanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	} else if( [sender tag] == 2 ) {
		[[NSUserDefaults standardUserDefaults] setObject:[sender representedObject] forKey:@"JVTransferSaveLocation"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:@"ask" forKey:@"JVTransferSaveLocation"];
	}
}

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[sheet directory]];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[sheet directory] lastPathComponent]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[sheet directory]];
		[saveDownloads selectItem:menuItem];

		[[NSUserDefaults standardUserDefaults] setObject:[sheet directory] forKey:@"JVTransferSaveLocation"];
	} else {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:1]];
		[[NSUserDefaults standardUserDefaults] setObject:@"ask" forKey:@"JVTransferSaveLocation"];
	}
}

- (IBAction) changeRemoveTransfers:(id) sender {
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"JVRemoveTransferedItems"];
}

- (IBAction) toggleOpenSafeFiles:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVOpenSafeFiles"];
}
@end
