#import "JVGeneralPreferencesViewController.h"

#import "JVBuddy.h"


extern const NSStringEncoding JVAllowedTextEncodings[];


@interface JVGeneralPreferencesViewController()

@property(nonatomic, strong) IBOutlet NSPopUpButton *encodingPopUpButton;

- (void) buildEncodingMenu;

@end


@implementation JVGeneralPreferencesViewController

- (void) awakeFromNib {
	[self buildEncodingMenu];
}


#pragma mark MASPreferencesViewController

- (NSString *) identifier {
	return @"JVGeneralPreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"GeneralPreferences"];
}

- (NSString *) toolbarItemLabel {
	return NSLocalizedString( @"General", "general preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark - Private

- (void) buildEncodingMenu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *menuItem = nil;
	NSUInteger i = 0;
	NSStringEncoding defaultEncoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	for( i = 0; JVAllowedTextEncodings[i]; i++ ) {
		if( JVAllowedTextEncodings[i] == (NSStringEncoding) -1 ) {
			[menu addItem:[NSMenuItem separatorItem]];
			continue;
		}

		menuItem = [[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:JVAllowedTextEncodings[i]] action:NULL keyEquivalent:@""];
		if( defaultEncoding == JVAllowedTextEncodings[i] ) [menuItem setState:NSOnState];
		[menuItem setTag:JVAllowedTextEncodings[i]];
		[menu addItem:menuItem];
	}

	[menu setAutoenablesItems:NO];
	[self.encodingPopUpButton setMenu:menu];
}

@end
