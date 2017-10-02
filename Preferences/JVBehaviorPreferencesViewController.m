#import "JVBehaviorPreferencesViewController.h"

#import "JVChatController.h"
#import "JVChatRoomPanel.h"


@interface JVBehaviorPreferencesViewController ()

@property(nonatomic, strong) IBOutlet NSPopUpButton *returnKeyAction;
@property(nonatomic, strong) IBOutlet NSPopUpButton *enterKeyAction;

- (void) initializeFromDefaults;

- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;

@end


@implementation JVBehaviorPreferencesViewController

- (void)awakeFromNib {
	[self initializeFromDefaults];
}


#pragma mark - MASPreferencesViewController

- (NSString *) viewIdentifier {
	return @"JVBehaviorPreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"BehaviorPreferences"];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString( @"Behavior", "behavior preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark - Private

- (void) initializeFromDefaults {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] )
		[self.returnKeyAction selectItemAtIndex:[self.returnKeyAction indexOfItemWithTag:0]];
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] )
		[self.returnKeyAction selectItemAtIndex:[self.returnKeyAction indexOfItemWithTag:1]];
	else [self.returnKeyAction selectItemAtIndex:[self.returnKeyAction indexOfItemWithTag:2]];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnEnter"] )
		[self.enterKeyAction selectItemAtIndex:[self.enterKeyAction indexOfItemWithTag:0]];
	else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnEnter"] )
		[self.enterKeyAction selectItemAtIndex:[self.enterKeyAction indexOfItemWithTag:1]];
	else [self.enterKeyAction selectItemAtIndex:[self.enterKeyAction indexOfItemWithTag:2]];
}


#pragma mark -

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
