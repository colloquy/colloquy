#import <Cocoa/Cocoa.h>
#import "JVInterfacePreferences.h"

@implementation JVInterfacePreferences
- (NSString *) preferencesNibName {
	return @"JVInterfacePreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"InterfacePreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
} 

- (void) initializeFromDefaults {
	[[newRooms menu] setAutoenablesItems:NO];
	[[newChats menu] setAutoenablesItems:NO];
	[[newTranscripts menu] setAutoenablesItems:NO];
	[[newConsoles menu] setAutoenablesItems:NO];

	int value = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatRoomPreferredOpenMode"] & ~32;
	int index = [newRooms indexOfItemWithTag:value];
	if( index >= 0 ) [newRooms selectItemAtIndex:index];
	[self changePreferredWindow:newRooms];

	value = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVDirectChatPreferredOpenMode"] & ~32;
	index = [newChats indexOfItemWithTag:value];
	if( index >= 0 ) [newChats selectItemAtIndex:index];
	[self changePreferredWindow:newChats];

	value = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptPreferredOpenMode"] & ~32;
	index = [newTranscripts indexOfItemWithTag:value];
	if( index >= 0 ) [newTranscripts selectItemAtIndex:index];
	[self changePreferredWindow:newTranscripts];

	value = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatConsolePreferredOpenMode"] & ~32;
	index = [newConsoles indexOfItemWithTag:value];
	if( index >= 0 ) [newConsoles selectItemAtIndex:index];
	[self changePreferredWindow:newConsoles];

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
}

- (IBAction) changeSendHistory:(id) sender {
	int size = [sender intValue];
	[sendHistory setIntValue:size];
	[sendHistoryStepper setIntValue:size];
	[[NSUserDefaults standardUserDefaults] setInteger:[sendHistory intValue] forKey:@"JVChatMaximumHistory"];
}

- (IBAction) changePreferredWindow:(id) sender {
	NSString *key = nil;

	if( sender == newRooms ) key = @"JVChatRoomPreferredOpenMode";
	else if( sender == newChats ) key = @"JVDirectChatPreferredOpenMode";
	else if( sender == newTranscripts ) key = @"JVChatTranscriptPreferredOpenMode";
	else if( sender == newConsoles ) key = @"JVChatConsolePreferredOpenMode";
	else return;

	int new = [[sender selectedItem] tag];
	BOOL groupByServer = (BOOL) [[NSUserDefaults standardUserDefaults] integerForKey:key] & 32;

	if( [[sender selectedItem] tag] == 32 ) {
		id <NSMenuItem> item = [sender selectedItem];
		new = [[NSUserDefaults standardUserDefaults] integerForKey:key] & ~32;
		groupByServer = ! groupByServer;
		[sender selectItemAtIndex:[sender indexOfItemWithTag:new]];
		[item setState:( groupByServer ? NSOnState : NSOffState )];
	} else if( [[sender selectedItem] tag] == 0 || [[sender selectedItem] tag] == 1 || [[sender selectedItem] tag] == 4 ) {
		id <NSMenuItem> item = ( [sender indexOfItemWithTag:32] >= 0 ? [sender itemAtIndex:[sender indexOfItemWithTag:32]] : nil );
		[item setState:NSOffState];
		[item setEnabled:NO];
		groupByServer = NO;
	} else {
		id <NSMenuItem> item = ( [sender indexOfItemWithTag:32] >= 0 ? [sender itemAtIndex:[sender indexOfItemWithTag:32]] : nil );
		[item setState:( groupByServer ? NSOnState : NSOffState )];
		[item setEnabled:YES];
	}

	if( groupByServer ) new |= 32;

	[[NSUserDefaults standardUserDefaults] setInteger:new forKey:key];
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
@end
