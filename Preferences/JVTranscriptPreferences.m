#import "JVTranscriptPreferences.h"

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
	[icon setScalesWhenResized:YES];
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
		NSOpenPanel *openPanel = [[NSOpenPanel openPanel] retain];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setCanChooseFiles:NO];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setResolvesAliases:NO];
		[openPanel beginSheetForDirectory:folder file:nil types:nil modalForWindow:[[self viewForPreferenceNamed:nil] window] modalDelegate:self didEndSelector:@selector( saveDownloadsOpenPanelDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	}
}

- (void) saveDownloadsOpenPanelDidEnd:(NSOpenPanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSMenuItem *menuItem = [transcriptFolder itemAtIndex:[transcriptFolder indexOfItemWithTag:2]];
		NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[sheet directory]];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];

		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:[sheet directory]]];
		[menuItem setImage:icon];
		[menuItem setRepresentedObject:[sheet directory]];

		[[NSUserDefaults standardUserDefaults] setObject:[sheet directory] forKey:@"JVChatTranscriptFolder"];
	}

	[transcriptFolder selectItemAtIndex:[transcriptFolder indexOfItemWithTag:2]];
}
@end
