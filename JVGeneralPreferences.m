#import "JVGeneralPreferences.h"

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
@end
