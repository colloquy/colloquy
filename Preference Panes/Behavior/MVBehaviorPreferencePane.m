#import <Cocoa/Cocoa.h>
#import "MVBehaviorPreferencePane.h"

@implementation MVBehaviorPreferencePane
- (id) initWithBundle:(NSBundle *) bundle {
	if( ! ( self = [super initWithBundle:bundle] ) ||
		! [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"cc.javelin.colloquy"] ) {
		[self autorelease];
		self = nil;
	}
	return self;
}

- (void) mainViewDidLoad {
	BOOL boolValue = NO;

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] )
		[pressReturn selectCellWithTag:0];
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] )
		[pressReturn selectCellWithTag:1];
	else [pressReturn selectCellWithTag:2];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnEnter"] )
		[pressEnter selectCellWithTag:0];
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnEnter"] )
		[pressEnter selectCellWithTag:1];
	else [pressEnter selectCellWithTag:2];

	[closeWindow selectCellWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatHideOnWindowClose"]];

	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"];
	[autoActions setState:(NSCellStateValue) boolValue];
}

- (void) didUnselect {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction) pressReturnChoice:(id) sender {
	if( [[sender selectedCell] tag] == 0 ) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"MVChatSendOnReturn"];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatActionOnReturn"];
	} else if( [[sender selectedCell] tag] == 1 ) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"MVChatActionOnReturn"];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatSendOnReturn"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatSendOnReturn"];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatActionOnReturn"];
	}
}

- (IBAction) pressEnterChoice:(id) sender {
	if( [[sender selectedCell] tag] == 0 ) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"MVChatSendOnEnter"];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatActionOnEnter"];
	} else if( [[sender selectedCell] tag] == 1 ) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"MVChatActionOnEnter"];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatSendOnEnter"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatSendOnEnter"];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatActionOnEnter"];
	}
}

- (IBAction) closeWindowChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[[sender selectedCell] tag]] forKey:@"MVChatHideOnWindowClose"];
}

- (IBAction) autoActionChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatNaturalActions"];
}

- (IBAction) showHiddenRoomsChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatShowHiddenOnRoomMessage"];
}

- (IBAction) showHiddenPrivateMessagesChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatShowHiddenOnPrivateMessage"];
}
@end