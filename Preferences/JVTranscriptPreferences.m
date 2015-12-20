#import "JVTranscriptPreferences.h"

@interface JVTranscriptPreferences (Private)
- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
@end

@implementation JVTranscriptPreferences
- (NSString *) preferencesNibName {
	return @"JVTranscriptPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [NSImage imageNamed:@"TranscriptPreferences"];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	NSString *path = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];

	if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] )
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

	NSMenuItem *menuItem = [transcriptFolder itemAtIndex:[transcriptFolder indexOfItemWithTag:2]];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize( 16., 16. )];

	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:icon];
	[menuItem setRepresentedObject:path];

	[transcriptFolder selectItem:menuItem];
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

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [transcriptFolder itemAtIndex:[transcriptFolder indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[[sheet directoryURL] path]];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[[sheet directoryURL] path]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[[sheet directoryURL] path]];

		[[NSUserDefaults standardUserDefaults] setObject:[[sheet directoryURL] path] forKey:@"JVChatTranscriptFolder"];
	}

	[transcriptFolder selectItemAtIndex:[transcriptFolder indexOfItemWithTag:2]];
}
@end
