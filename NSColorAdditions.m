#import <Cocoa/Cocoa.h>
#import "NSColorAdditions.h"

@implementation NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) hexcolor {
	if( [hexcolor length] < 6 ) return nil; // We should add support for short-hand hex colors too, like #fff, etc.
	NSScanner *scanner = [NSScanner scannerWithString:( [hexcolor hasPrefix:@"#"] ? [hexcolor substringFromIndex:1] : hexcolor )];
	unsigned int color = 0;
	if( ! [scanner scanHexInt:&color] ) return nil;
	return [self colorWithCalibratedRed:( ( color >> 16 ) & 0xff ) / 255. green:( ( color >> 8 ) & 0xff ) / 255. blue:( color & 0xff ) / 255. alpha:1.];
}

- (NSString *) HTMLAttributeValue {
	float red = 0., green = 0., blue = 0.;
	[[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:NULL];
	return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}
@end
