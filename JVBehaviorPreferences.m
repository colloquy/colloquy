#import <Cocoa/Cocoa.h>
#import "JVBehaviorPreferences.h"

@implementation JVBehaviorPreferences
- (NSString *) preferencesNibName {
	return @"JVBehaviorPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"BehaviorPreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	[checkSpelling setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatSpellChecking"]];
	[detectNaturalActions setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"]];

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

	if( NSAppKitVersionNumber >= 700. ) {
		[tabKeyComplete setEnabled:YES];
		[tabKeyComplete setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVUsePantherTextCompleteOnTab"]];
	} else {
		[tabKeyCompleteLabel setObjectValue:@""];
	}
}

- (IBAction) changeSpellChecking:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVChatSpellChecking"];
}

- (IBAction) changeNaturalActionDetection:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"MVChatNaturalActions"];
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

- (IBAction) changeSendHistory:(id) sender {
	int size = [sender intValue];
	[sendHistory setIntValue:size];
	[sendHistoryStepper setIntValue:size];
	[[NSUserDefaults standardUserDefaults] setInteger:[sendHistory intValue] forKey:@"JVChatMaximumHistory"];
}

- (IBAction) changeTabKeyComplete:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVUsePantherTextCompleteOnTab"];
}
@end
