#import <Cocoa/Cocoa.h>
#import "NSBundleAdditions.h"

@implementation NSBundle (NSBundleAdditions)
- (NSString *) displayName {
	NSString *label = [self objectForInfoDictionaryKey:@"CFBundleName"];
	if( ! label ) label = [self bundleIdentifier];
	return [[label retain] autorelease];
}
@end
