#import "JVTranscriptPreferencesViewController.h"


@interface JVTranscriptPreferencesViewController ()

@property(nonatomic, strong) IBOutlet NSPopUpButton *transcriptFolder;

- (void) initializeFromDefaults;

- (IBAction) changeTranscriptFolder:(id) sender;

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet
						   returnCode:(NSInteger) returnCode
						  contextInfo:(void *) contextInfo;

@end


@implementation JVTranscriptPreferencesViewController

- (void)awakeFromNib {
	[self initializeFromDefaults];
}


#pragma mark - MASPreferencesViewController

- (NSString *) identifier {
	return @"JVTranscriptPreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"TranscriptPreferences"];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString( @"Transcripts", "chat transcript preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark - Private

- (void) initializeFromDefaults {
	NSURL *url = [[NSUserDefaults standardUserDefaults] URLForKey:@"JVChatTranscriptFolder"];
	//TODO: get properties via -resourceValuesForKeys:error:
	NSString *path = [url path];

	if( ! [url checkResourceIsReachableAndReturnError:NULL] )
		[[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil];

	NSMenuItem *menuItem = [self.transcriptFolder itemAtIndex:[self.transcriptFolder indexOfItemWithTag:2]];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize( 16., 16. )];

	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:icon];
	[menuItem setRepresentedObject:url];

	[self.transcriptFolder selectItem:menuItem];
}


#pragma mark -

- (IBAction) changeTranscriptFolder:(id) sender {
	if( [sender tag] == 3 ) {
		NSURL *folder = [[NSUserDefaults standardUserDefaults] URLForKey:@"JVChatTranscriptFolder"];
		if (!folder) {
			folder = [NSURL fileURLWithPath:[[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath] isDirectory:YES];
		}
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setCanChooseFiles:NO];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setResolvesAliases:NO];
		[openPanel setDirectoryURL:folder];
		[openPanel beginWithCompletionHandler:^(NSInteger result) {
			[self saveDownloadsOpenPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
		}];
	}
}

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [self.transcriptFolder itemAtIndex:[self.transcriptFolder indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[[sheet directoryURL] path]];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[[sheet directoryURL] path]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[sheet directoryURL]];

		[[NSUserDefaults standardUserDefaults] setURL:[sheet directoryURL] forKey:@"JVChatTranscriptFolder"];
	}

	[self.transcriptFolder selectItemAtIndex:[self.transcriptFolder indexOfItemWithTag:2]];
}

@end
