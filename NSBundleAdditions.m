#import <Cocoa/Cocoa.h>
#import "NSBundleAdditions.h"

@implementation NSBundle (NSBundleAdditions)
- (NSComparisonResult) compare:(NSBundle *) bundle {
	return [[self displayName] compare:[bundle displayName]];
}

- (NSString *) displayName {
	NSString *label = [self objectForInfoDictionaryKey:@"CFBundleName"];
	if( ! label ) label = [self bundleIdentifier];
	return [[label retain] autorelease];
}
@end
