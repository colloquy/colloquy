#import <Cocoa/Cocoa.h>
#import "MVIdentityPreferencePane.h"

@implementation MVIdentityPreferencePane
- (id) initWithBundle:(NSBundle *) bundle {
	if( ! ( self = [super initWithBundle:bundle] ) ||
		! [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"cc.javelin.colloquy"] ) {
		[self autorelease];
		self = nil;
	}
	return self;
}

- (void) mainViewDidLoad {
	id value = nil;

	value = [[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatRealName"];
	if( ! value ) value = NSFullUserName();
	if( value ) [realName setStringValue:value];
	value = [[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatInformation"];
	if( value ) [information replaceCharactersInRange:NSMakeRange( 0., 0. ) withString:value];
}

- (void) didUnselect {
	[[NSUserDefaults standardUserDefaults] setObject:[realName stringValue] forKey:@"MVChatRealName"];
	[[NSUserDefaults standardUserDefaults] setObject:[information string] forKey:@"MVChatInformation"];

	[[NSUserDefaults standardUserDefaults] synchronize];
}
@end