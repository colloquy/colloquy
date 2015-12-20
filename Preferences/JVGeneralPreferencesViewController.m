#import "JVGeneralPreferencesViewController.h"
#import "JVBuddy.h"

extern const NSStringEncoding JVAllowedTextEncodings[];

/*
@protocol MASPreferencesViewController <NSObject>

@optional

- (void)viewWillAppear;
- (void)viewDidDisappear;
- (NSView *)initialKeyView;

@property (nonatomic, readonly) BOOL hasResizableWidth;
@property (nonatomic, readonly) BOOL hasResizableHeight;

@required

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSImage *toolbarItemImage;
@property (nonatomic, readonly) NSString *toolbarItemLabel;

@end

*/

@interface JVGeneralPreferencesViewController()

@property(nonatomic, weak) IBOutlet NSPopUpButton *encodingPopUpButton;

- (void) buildEncodingMenu;

@end


@implementation JVGeneralPreferencesViewController

- (void) awakeFromNib {
	[self buildEncodingMenu];
}

- (void) setPreferencesView:(NSView *)view {
	self.view = view;
}

- (void) set_preferencesView:(NSView *)view {
	self.view = view;
}

#pragma mark MASPreferencesViewController

- (NSString *) identifier {
	return @"JVGeneralPreferences";
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

#pragma mark Private

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
