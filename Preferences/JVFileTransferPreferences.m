#import "JVFileTransferPreferences.h"
#import "MVFileTransferController.h"

@interface JVFileTransferPreferences (Private)
- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo;
@end

@implementation JVFileTransferPreferences
- (NSString *) preferencesNibName {
	return @"JVFileTransferPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [NSImage imageNamed:@"FileTransferPreferences"];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	NSRange range = [MVFileTransfer fileTransferPortRange];
	[minRate setIntegerValue:range.location];
	[maxRate setIntegerValue: NSMaxRange(range)];

	BOOL autoOpen = [MVFileTransfer isAutoPortMappingEnabled];
	[autoOpenPorts setState:( autoOpen ? NSOnState: NSOffState )];

	NSString *path = [MVFileTransferController userPreferredDownloadFolder];
	NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize( 16., 16. )];

	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:icon];
	[menuItem setRepresentedObject:path];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:1]];
	} else {
		[saveDownloads selectItem:menuItem];
	}
}

- (IBAction) changePortRange:(id) sender {
	NSRange range = NSMakeRange( [minRate intValue], ( [maxRate intValue] - [minRate intValue] ) );
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRange( range ) forKey:@"JVFileTransferPortRange"];
	[MVFileTransfer setFileTransferPortRange:range];
}

- (IBAction) changeAutoOpenPorts:(id) sender {
	BOOL autoOpen = ( [sender state] == NSOnState );
	[[NSUserDefaults standardUserDefaults] setBool:autoOpen forKey:@"JVAutoOpenTransferPorts"];
	[MVFileTransfer setAutoPortMappingEnabled:autoOpen];
}

- (IBAction) changeSaveDownloads:(id) sender {
	if( [sender tag] == 3 ) {
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setCanChooseFiles:NO];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setResolvesAliases:NO];
		[openPanel setDirectoryURL:[NSURL fileURLWithPath:[MVFileTransferController userPreferredDownloadFolder] isDirectory:YES]];
		[openPanel beginWithCompletionHandler:^(NSInteger result) {
			[self saveDownloadsOpenPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
		}];
	} else if( [sender tag] == 2 ) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVAskForTransferSaveLocation"];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskForTransferSaveLocation"];
	}
}

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [saveDownloads itemAtIndex:[saveDownloads indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[[sheet directoryURL] path]];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[[sheet directoryURL] path]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[[sheet directoryURL] path]];
		[saveDownloads selectItem:menuItem];

		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVAskForTransferSaveLocation"];
		[MVFileTransferController setUserPreferredDownloadFolder:[[sheet directoryURL] path]];
	} else {
		[saveDownloads selectItemAtIndex:[saveDownloads indexOfItemWithTag:1]];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskForTransferSaveLocation"];
	}
}
@end
