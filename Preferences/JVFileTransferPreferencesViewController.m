#import "JVFileTransferPreferencesViewController.h"

#import "MVFileTransferController.h"


@interface JVFileTransferPreferencesViewController ()

@property(nonatomic, strong) IBOutlet NSPopUpButton *saveDownloads;
@property(nonatomic, strong) IBOutlet NSTextField *minRate;
@property(nonatomic, strong) IBOutlet NSTextField *maxRate;
@property(nonatomic, strong) IBOutlet NSButton *autoOpenPorts;

- (IBAction) changePortRange:(id) sender;
- (IBAction) changeAutoOpenPorts:(id) sender;
- (IBAction) changeSaveDownloads:(id) sender;

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet
						   returnCode:(int) returnCode
						  contextInfo:(void *) contextInfo;

@end


@implementation JVFileTransferPreferencesViewController

- (void)awakeFromNib {
	[self initializeFromDefaults];
}


#pragma mark - MASPreferencesViewController

- (NSString *) identifier {
	return @"JVFileTransferPreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"FileTransferPreferences"];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString( @"Transfers", "file transfers preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark - Private

- (void) initializeFromDefaults {
	NSRange range = [MVFileTransfer fileTransferPortRange];
	[self.minRate setIntValue:range.location];
	[self.maxRate setIntValue:( range.location + range.length )];

	BOOL autoOpen = [MVFileTransfer isAutoPortMappingEnabled];
	[self.autoOpenPorts setState:( autoOpen ? NSOnState: NSOffState )];

	NSString *path = [MVFileTransferController userPreferredDownloadFolder];
	NSMenuItem *menuItem = [self.saveDownloads itemAtIndex:[self.saveDownloads indexOfItemWithTag:2]];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize( 16., 16. )];

	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:icon];
	[menuItem setRepresentedObject:path];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
		[self.saveDownloads selectItemAtIndex:[self.saveDownloads indexOfItemWithTag:1]];
	} else {
		[self.saveDownloads selectItem:menuItem];
	}
}

- (IBAction) changePortRange:(id) sender {
	NSRange range = NSMakeRange( [self.minRate intValue], ( [self.maxRate intValue] - [self.minRate intValue] ) );
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

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [self.saveDownloads itemAtIndex:[self.saveDownloads indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[[sheet directoryURL] path]];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[[sheet directoryURL] path]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[[sheet directoryURL] path]];
		[self.saveDownloads selectItem:menuItem];

		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVAskForTransferSaveLocation"];
		[MVFileTransferController setUserPreferredDownloadFolder:[[sheet directoryURL] path]];
	} else {
		[self.saveDownloads selectItemAtIndex:[self.saveDownloads indexOfItemWithTag:1]];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVAskForTransferSaveLocation"];
	}
}
@end
