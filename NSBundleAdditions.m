#import <Cocoa/Cocoa.h>
#import "NSBundleAdditions.h"

@implementation NSBundle (NSBundleAdditions)
- (NSString *) displayName {
	NSDictionary *info = [self localizedInfoDictionary];
	NSString *label = [info objectForKey:@"CFBundleName"];
	if( ! label ) label = [self objectForInfoDictionaryKey:@"CFBundleName"];
	if( ! label ) label = [self bundleIdentifier];
	return [[label retain] autorelease];
}
@end
