#import "JVGeneralPreferences.h"
#import <Cocoa/Cocoa.h>
#import "JVBuddy.h"

@implementation JVGeneralPreferences
- (NSString *) preferencesNibName {
	return @"JVGeneralPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"GeneralPreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	[self buildEncodingMenu];

	[yourName selectItemAtIndex:[yourName indexOfItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"]]];
	[buddyNames selectItemAtIndex:[yourName indexOfItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatBuddyNameStyle"]]];

	[checkSpelling setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatSpellChecking"]];
	[detectNaturalActions setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"]];
	[autoCheckVersion setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"]];
}

- (void) buildEncodingMenu {
	extern const NSStringEncoding JVAllowedTextEncodings[];
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *menuItem = nil;
	unsigned int i = 0;
	NSStringEncoding defaultEncoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	for( i = 0; JVAllowedTextEncodings[i]; i++ ) {
		if( JVAllowedTextEncodings[i] == (NSStringEncoding) -1 ) {
			[menu addItem:[NSMenuItem separatorItem]];
			continue;
		}

		menuItem = [[[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:JVAllowedTextEncodings[i]] action:@selector( changeEncoding: ) keyEquivalent:@""] autorelease];
		if( defaultEncoding == JVAllowedTextEncodings[i] ) [menuItem setState:NSOnState];
		[menuItem setTag:JVAllowedTextEncodings[i]];
		[menuItem setTarget:self];
		[menu addItem:menuItem];
	}

	[encoding setMenu:menu];
}

- (IBAction) changeEncoding:(id) sender {
	[[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"JVChatEncoding"];
}

- (IBAction) changeSelfPreferredName:(id) sender {
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedItem] tag] forKey:@"JVChatSelfNameStyle"];
}

- (IBAction) changeBuddyPreferredName:(id) sender {
	[JVBuddy setPreferredName:(JVBuddyName)[[sender selectedItem] tag]];
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender selectedItem] tag] forKey:@"JVChatBuddyNameStyle"];
}

- (IBAction) changeSpellChecking:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVChatSpellChecking"];
}

- (IBAction) changeNaturalActionDetection:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"MVChatNaturalActions"];
}

- (IBAction) changeAutomaticVersionCheck:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVEnableAutomaticSoftwareUpdateCheck"];
}
@end
