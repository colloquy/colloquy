#import <Cocoa/Cocoa.h>
#import "NSColorAdditions.h"

@implementation NSColor (NSColorAdditions)
- (NSString *) htmlAttributeValue {
	float red = 0., green = 0., blue = 0.;
	[[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:NULL];
	return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}
@end
