#import "JVGeneralPreferences.h"
#import <Cocoa/Cocoa.h>

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

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] )
		[returnKeyAction selectItemAtIndex:[returnKeyAction indexOfItemWithTag:0]];
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] )
		[returnKeyAction selectItemAtIndex:[returnKeyAction indexOfItemWithTag:1]];
	else [returnKeyAction selectItemAtIndex:[returnKeyAction indexOfItemWithTag:2]];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnEnter"] )
		[enterKeyAction selectItemAtIndex:[enterKeyAction indexOfItemWithTag:0]];
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnEnter"] )
		[enterKeyAction selectItemAtIndex:[enterKeyAction indexOfItemWithTag:1]];
	else [enterKeyAction selectItemAtIndex:[enterKeyAction indexOfItemWithTag:2]];

	[sendHistory setIntValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatMaximumHistory"]];
	[sendHistoryStepper setIntValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatMaximumHistory"]];

	[detectNaturalActions setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"]];
	[autoCheckVersion setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAutomaticSoftwareUpdateCheck"]];
}

- (void) saveChanges {
	[[NSUserDefaults standardUserDefaults] setInteger:[sendHistory intValue] forKey:@"JVChatMaximumHistory"];
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

- (IBAction) changeSendOnReturnAction:(id) sender {
	if( [[sender selectedItem] tag] == 0 ) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MVChatSendOnReturn"];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatActionOnReturn"];
	} else if( [[sender selectedItem] tag] == 1 ) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MVChatActionOnReturn"];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatSendOnReturn"];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatSendOnReturn"];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatActionOnReturn"];
	}
}

- (IBAction) changeSendOnEnterAction:(id) sender {
	if( [[sender selectedItem] tag] == 0 ) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MVChatSendOnEnter"];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatActionOnEnter"];
	} else if( [[sender selectedItem] tag] == 1 ) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MVChatActionOnEnter"];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatSendOnEnter"];
	} else {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatSendOnEnter"];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MVChatActionOnEnter"];
	}
}

- (IBAction) changeNaturalActionDetection:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"MVChatNaturalActions"];
}

- (IBAction) changeAutomaticVersionCheck:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVEnableAutomaticSoftwareUpdateCheck"];
}
@end
