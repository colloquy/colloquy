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

+ (NSColor *) colorWithCSSAttributeValue:(NSString *) attribute {
	NSColor *ret = [self colorWithHTMLAttributeValue:attribute];
	NSCharacterSet *whites = [NSCharacterSet whitespaceCharacterSet];

	if( ! ret && [attribute hasPrefix:@"rgb"] ) {
		BOOL hasAlpha = [attribute hasPrefix:@"rgba"];
		NSScanner *scanner = [NSScanner scannerWithString:attribute];
		[scanner scanCharactersFromSet:whites intoString:nil];
		if( [scanner scanUpToString:@"(" intoString:nil] ) {
			double red = 0., green = 0., blue = 0., alpha = 1.;
			BOOL redPrecent = NO, greenPrecent = NO, bluePrecent = NO;
			[scanner scanString:@"(" intoString:nil];
			[scanner scanCharactersFromSet:whites intoString:nil];
			if( [scanner scanDouble:&red] ) {
				redPrecent = [scanner scanString:@"%" intoString:nil];
				[scanner scanCharactersFromSet:whites intoString:nil];
				[scanner scanString:@"," intoString:nil];
				[scanner scanCharactersFromSet:whites intoString:nil];
				if( [scanner scanDouble:&green] ) {
					greenPrecent = [scanner scanString:@"%" intoString:nil];
					[scanner scanCharactersFromSet:whites intoString:nil];
					[scanner scanString:@"," intoString:nil];
					[scanner scanCharactersFromSet:whites intoString:nil];
					if( [scanner scanDouble:&blue] ) {
						bluePrecent = [scanner scanString:@"%" intoString:nil];
						[scanner scanCharactersFromSet:whites intoString:nil];
						red = MAX( 0., MIN( ( redPrecent ? 100. : 255. ), red ) );
						green = MAX( 0., MIN( ( greenPrecent ? 100. : 255. ), green ) );
						blue = MAX( 0., MIN( ( bluePrecent ? 100. : 255. ), blue ) );
						if( hasAlpha ) {
							[scanner scanString:@"," intoString:nil];
							[scanner scanCharactersFromSet:whites intoString:nil];
							if( [scanner scanDouble:&alpha] ) {
								[scanner scanCharactersFromSet:whites intoString:nil];
								[scanner scanString:@")" intoString:nil];
								alpha = MAX( 0., MIN( 1., alpha ) );
								ret = [self colorWithCalibratedRed:( redPrecent ? red / 100. : red / 255. ) green:( greenPrecent ? green / 100. : green / 255. ) blue:( bluePrecent ? blue / 100. : blue / 255. ) alpha:alpha];
							}
						} else {
							ret = [self colorWithCalibratedRed:( redPrecent ? red / 100. : red / 255. ) green:( greenPrecent ? green / 100. : green / 255. ) blue:( bluePrecent ? blue / 100. : blue / 255. ) alpha:1.];
						}
					}
				}
			}
		}
	}

	return ret;
}

- (NSString *) HTMLAttributeValue {
	float red = 0., green = 0., blue = 0.;
	[[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:NULL];
	return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}

- (NSString *) CSSAttributeValue {
	float red = 0., green = 0., blue = 0., alpha = 0.;
	[[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:&alpha];
	if( alpha ) return [NSString stringWithFormat:@"rgba(%d,%d,%d,%f)", (int)(red * 255), (int)(green * 255), (int)(blue * 255), alpha];
	return [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255), (int)(green * 255), (int)(blue * 255)];
}
@end
