#import <Cocoa/Cocoa.h>
#import "JVAdvancedPreferences.h"

@implementation JVAdvancedPreferences
- (NSString *) preferencesNibName {
	return @"JVAdvancedPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"AdvancedPreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	[openConsole setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"]];
	[verboseConsole setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatVerboseConsoleMessages"]];
	[hideMsgsInConsole setState:! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatConsoleIgnoreUserChatMessages"]];
}

- (IBAction) toggleShowConsoleBeforeConnecting:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVChatOpenConsoleOnConnect"];
}

- (IBAction) toggleVerboseSetting:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVChatVerboseConsoleMessages"];
}

- (IBAction) toggleHidePrivateMessages:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL) ! [sender state] forKey:@"JVChatConsoleIgnoreUserChatMessages"];
}
@end
