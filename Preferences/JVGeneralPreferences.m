#import "JVGeneralPreferences.h"
#import "JVBuddy.h"

extern const NSStringEncoding JVAllowedTextEncodings[];

@implementation JVGeneralPreferences
- (NSString *) preferencesNibName {
	return @"JVGeneralPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [NSImage imageNamed:@"GeneralPreferences"];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	[self buildEncodingMenu];
}

- (void) buildEncodingMenu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *menuItem = nil;
	NSUInteger i = 0;
	NSStringEncoding defaultEncoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

	for( i = 0; JVAllowedTextEncodings[i]; i++ ) {
		if( JVAllowedTextEncodings[i] == (NSStringEncoding) -1 ) {
			[menu addItem:[NSMenuItem separatorItem]];
			continue;
		}

		menuItem = [[[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:JVAllowedTextEncodings[i]] action:NULL keyEquivalent:@""] autorelease];
		if( defaultEncoding == JVAllowedTextEncodings[i] ) [menuItem setState:NSOnState];
		[menuItem setTag:JVAllowedTextEncodings[i]];
		[menu addItem:menuItem];
	}

	[menu setAutoenablesItems:NO];
	[encoding setMenu:menu];
}
@end
