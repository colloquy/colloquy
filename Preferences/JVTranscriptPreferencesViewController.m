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
	NSString *path = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];

	if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] )
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

	NSMenuItem *menuItem = [self.transcriptFolder itemAtIndex:[self.transcriptFolder indexOfItemWithTag:2]];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize( 16., 16. )];

	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:icon];
	[menuItem setRepresentedObject:path];

	[self.transcriptFolder selectItem:menuItem];
}


#pragma mark -

- (IBAction) changeTranscriptFolder:(id) sender {
	if( [sender tag] == 3 ) {
		NSString *folder = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setCanChooseFiles:NO];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setResolvesAliases:NO];
		[openPanel setDirectoryURL:[NSURL fileURLWithPath:folder isDirectory:YES]];
		[openPanel beginWithCompletionHandler:^(NSInteger result) {
			[self saveDownloadsOpenPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
		}];
	}
}

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSModalResponseOK ) {
		NSMenuItem *menuItem = [self.transcriptFolder itemAtIndex:[self.transcriptFolder indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[[sheet directoryURL] path]];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[[sheet directoryURL] path]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[[sheet directoryURL] path]];

		[[NSUserDefaults standardUserDefaults] setObject:[[sheet directoryURL] path] forKey:@"JVChatTranscriptFolder"];
	}

	[self.transcriptFolder selectItemAtIndex:[self.transcriptFolder indexOfItemWithTag:2]];
}

@end
